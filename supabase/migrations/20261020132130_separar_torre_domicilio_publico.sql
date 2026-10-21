-- Estructura publica separada de las importaciones nominales locales.
-- No incluye documentos, domicilios ni asignaciones de usuarios reales.
alter table public.persona_domicilios
  add column if not exists torre text;

create schema if not exists private;
grant usage on schema private to authenticated;

-- La lectura medica requiere un permiso diferente al de edicion de legajos.
-- El acceso elevado queda en el esquema privado y valida la sesion y el rol.
create or replace function private.medicos_domicilio_actual(p_dni bigint)
returns table (
  calle text,
  numero text,
  barrio text,
  manzana text,
  lote text,
  casa text,
  monoblock text,
  piso text,
  departamento text,
  referencias text,
  otros_datos text,
  localidad_nombre text,
  provincia_nombre text,
  torre text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;

  return query
  select d.calle, d.numero, d.barrio, d.manzana, d.lote, d.casa,
    d.monoblock, d.piso, d.departamento, d.referencias, d.otros_datos,
    d.localidad_nombre, d.provincia_nombre, d.torre
  from public.persona_domicilios d
  where d.persona_dni = p_dni and d.vigente_hasta is null;
end;
$function$;

revoke all on function private.medicos_domicilio_actual(bigint)
  from public, anon;
grant execute on function private.medicos_domicilio_actual(bigint)
  to authenticated;

-- PostgreSQL exige recrear la funcion al ampliar las columnas de retorno.
-- Sin CASCADE: una dependencia desconocida debe impedir la migracion.
drop function public.rpc_medicos_domicilio(bigint);
create function public.rpc_medicos_domicilio(p_dni bigint)
returns table (
  calle text,
  numero text,
  barrio text,
  manzana text,
  lote text,
  casa text,
  monoblock text,
  piso text,
  departamento text,
  referencias text,
  otros_datos text,
  localidad_nombre text,
  provincia_nombre text,
  torre text
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select * from private.medicos_domicilio_actual(p_dni);
$function$;

revoke all on function public.rpc_medicos_domicilio(bigint)
  from public, anon;
grant execute on function public.rpc_medicos_domicilio(bigint)
  to authenticated;

notify pgrst, 'reload schema';
