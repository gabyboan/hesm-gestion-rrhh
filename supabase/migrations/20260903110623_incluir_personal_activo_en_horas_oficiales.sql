-- El selector de horas oficiales debe incluir a toda persona activa que tenga
-- una carrera asignada, incluida RISAMC/Residente. Las bajas vigentes se
-- representan exclusivamente en persona_inactivo.
--
-- Se crea una RPC nueva para no modificar la firma ni el comportamiento de la
-- RPC histórica mientras otras versiones de la aplicación sigan en uso.
create or replace function public.rpc_listado_horas_oficiales_activas()
returns table (
  apellido text,
  nombre text,
  dni bigint,
  carrera_id bigint,
  carrera text
)
language plpgsql
stable
security definer
set search_path to ''
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_horas_write() then
    raise exception 'Sin permiso para cargar horas.';
  end if;

  return query
  select
    p.apellido::text,
    p.nombre::text,
    p.dni::bigint,
    pc.carrera_id::bigint,
    c.nombre::text
  from public.personas p
  join public.persona_carreras pc
    on pc.dni = p.dni
  join public.carreras c
    on c.id = pc.carrera_id
  where not exists (
    select 1
    from public.persona_inactivo pi
    where pi.dni = p.dni
  )
  order by p.apellido, p.nombre, p.dni;
end;
$function$;
revoke all on function public.rpc_listado_horas_oficiales_activas()
  from public, anon;
grant execute on function public.rpc_listado_horas_oficiales_activas()
  to authenticated;
notify pgrst, 'reload schema';
