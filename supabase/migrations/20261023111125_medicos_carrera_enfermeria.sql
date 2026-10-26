begin;

-- Una consulta por lote para identificar la carrera vigente de los agentes.
-- AD/AC/PC describen la solicitud y no determinan la carrera del empleado.
grant usage on schema private to authenticated;

create or replace function private.medicos_carreras(p_dnis bigint[])
returns table (dni bigint, carrera_nombre text, es_enfermeria boolean)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null then raise exception 'No autenticado.'; end if;
  if public.can_medicos_read() is not true then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;
  if p_dnis is null then raise exception 'Indica las personas a consultar.'; end if;
  return query
  select pc.dni, c.nombre, public.busqueda_normalizar(c.nombre) = 'enfermeria'
  from public.persona_carreras pc
  join public.carreras c on c.id = pc.carrera_id
  where pc.dni = any(p_dnis);
end;
$$;
revoke all on function private.medicos_carreras(bigint[]) from public, anon, authenticated;
grant execute on function private.medicos_carreras(bigint[]) to authenticated;

create or replace function public.rpc_medicos_carreras(p_dnis bigint[])
returns table (dni bigint, carrera_nombre text, es_enfermeria boolean)
language sql stable security invoker set search_path = ''
as $$ select * from private.medicos_carreras(p_dnis); $$;
revoke all on function public.rpc_medicos_carreras(bigint[]) from public, anon;
grant execute on function public.rpc_medicos_carreras(bigint[]) to authenticated;

notify pgrst, 'reload schema';
commit;
