-- Enforce FRANCOS_LECTURA on the public listing and movement RPCs.
-- This prevents clients from seeing stale or partial francos data when they
-- only have action roles such as FRANCOS_CARGA or FRANCOS_ADM.

drop function if exists public.rpc_francos_listado(text);
create function public.rpc_francos_listado(
  p_buscar text default null
)
returns table (
  dni bigint,
  apellido text,
  nombre text,
  carrera_id bigint,
  carrera text,
  saldo_minutos integer,
  tiene_horas_cargadas boolean
)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_read() then
    raise exception 'Sin permiso para ver francos.';
  end if;

  return query
  select
    p.dni,
    p.apellido,
    p.nombre,
    pc.carrera_id,
    c.nombre as carrera,
    coalesce(sum(fm.minutos) filter (where fm.anulado = false), 0)::integer
      as saldo_minutos,
    true as tiene_horas_cargadas
  from public.personas p
  join public.persona_carreras pc on pc.dni = p.dni
  join public.carreras c on c.id = pc.carrera_id
  left join public.francos_movimientos fm
    on fm.dni = p.dni
   and fm.carrera_id = pc.carrera_id
   and fm.anulado = false
  where (
      p_buscar is null
      or p_buscar = ''
      or p.dni::text ilike '%' || p_buscar || '%'
      or p.apellido ilike '%' || p_buscar || '%'
      or p.nombre ilike '%' || p_buscar || '%'
      or c.nombre ilike '%' || p_buscar || '%'
    )
  group by p.dni, p.apellido, p.nombre, pc.carrera_id, c.nombre
  order by p.apellido, p.nombre, p.dni, c.nombre;
end;
$function$;
drop function if exists public.rpc_francos_movimientos(bigint, bigint);
create function public.rpc_francos_movimientos(
  p_dni bigint,
  p_carrera_id bigint
)
returns table (
  id bigint,
  dni bigint,
  carrera_id bigint,
  fecha date,
  periodo date,
  minutos integer,
  motivo text,
  observacion text,
  usuario_carga uuid,
  usuario_carga_nombre text,
  usuario_carga_apellido text,
  usuario_modifica uuid,
  created_at timestamp without time zone,
  updated_at timestamp without time zone
)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_read() then
    raise exception 'Sin permiso para ver francos.';
  end if;

  return query
  select
    fm.id,
    fm.dni,
    fm.carrera_id,
    fm.fecha,
    fm.periodo,
    fm.minutos,
    fm.motivo,
    null::text as observacion,
    fm.usuario_carga,
    u.nombre as usuario_carga_nombre,
    u.apellido as usuario_carga_apellido,
    fm.usuario_modifica,
    fm.created_at,
    fm.updated_at
  from public.francos_movimientos fm
  left join public.usuarios u
    on u.auth_user_id = fm.usuario_carga
    or u.id = fm.usuario_carga
  where fm.dni = p_dni
    and fm.carrera_id = p_carrera_id
    and fm.anulado = false
  order by fm.fecha desc, fm.id desc;
end;
$function$;
grant execute on function public.rpc_francos_listado(text) to authenticated;
grant execute on function public.rpc_francos_movimientos(bigint, bigint)
to authenticated;
notify pgrst, 'reload schema';
