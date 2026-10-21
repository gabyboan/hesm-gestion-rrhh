create or replace function public.rpc_medicos_domicilio(p_dni bigint)
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
  provincia_nombre text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;

  return query
  select
    d.calle,
    d.numero,
    d.barrio,
    d.manzana,
    d.lote,
    d.casa,
    d.monoblock,
    d.piso,
    d.departamento,
    d.referencias,
    d.otros_datos,
    d.localidad_nombre,
    d.provincia_nombre
  from public.persona_domicilios d
  where d.persona_dni = p_dni
    and d.vigente_hasta is null
  limit 1;
end;
$function$;

revoke execute on function public.rpc_medicos_domicilio(bigint) from public, anon;
grant execute on function public.rpc_medicos_domicilio(bigint) to authenticated;

notify pgrst, 'reload schema';
