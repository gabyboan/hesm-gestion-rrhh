-- Identifica la carrera habilitada para la vista preliminar sin abrir
-- informacion personal a los clientes. La invoca solamente el Worker con
-- service_role, despues de validar Turnstile.
create or replace function public.rpc_consulta_horas_carrera_preliminar(
  p_dni bigint
)
returns table (
  apellido text,
  nombre text,
  carrera_id integer
)
language sql
stable
security definer
set search_path = public
as $function$
  select
    p.apellido::text,
    p.nombre::text,
    pc.carrera_id::integer
  from public.personas p
  join public.persona_carreras pc
    on pc.dni = p.dni
  where p.dni = p_dni
    and pc.carrera_id in (1, 2, 3)
  limit 1;
$function$;
revoke execute on function public.rpc_consulta_horas_carrera_preliminar(bigint)
  from public, anon, authenticated;
grant execute on function public.rpc_consulta_horas_carrera_preliminar(bigint)
  to service_role;
notify pgrst, 'reload schema';
