-- Separate asistencia permissions from the francos/banco de horas module.
--
-- Legajo roles can read/manage attendance schedules without receiving access
-- to francos movements or banked hours.
--
-- Roles:
-- - 19, 20: legajo write/manage.
-- - 21: legajo read.
--
-- Francos permissions remain independent:
-- - can_francos_read/write/manage controls francos movements.
-- - can_asistencia_read/manage controls attendance schedules.

create or replace function public.has_legajo_role_ids(p_role_ids bigint[])
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1
    from public.usuario_roles ur
    left join public.usuarios u on u.id = ur.usuario_id
    where (
        ur.usuario_id = (select auth.uid())
        or u.auth_user_id = (select auth.uid())
      )
      and ur.rol_id = any(p_role_ids)
  );
$function$;
create or replace function public.can_asistencia_read()
returns boolean
language sql
stable
set search_path to 'public'
as $function$
  select public.can_francos_read()
      or public.has_legajo_role_ids(array[19, 20, 21]::bigint[]);
$function$;
create or replace function public.can_asistencia_manage()
returns boolean
language sql
stable
set search_path to 'public'
as $function$
  select public.can_francos_manage()
      or public.has_legajo_role_ids(array[19, 20]::bigint[]);
$function$;
drop policy if exists p_francos_horarios_select
  on public.francos_horarios_persona;
create policy p_francos_horarios_select
on public.francos_horarios_persona
for select
using (public.can_asistencia_read());
drop policy if exists p_francos_horarios_insert
  on public.francos_horarios_persona;
create policy p_francos_horarios_insert
on public.francos_horarios_persona
for insert
with check (
  public.can_asistencia_manage()
  and usuario_carga = (select auth.uid())
);
drop policy if exists p_francos_horarios_update
  on public.francos_horarios_persona;
create policy p_francos_horarios_update
on public.francos_horarios_persona
for update
using (public.can_asistencia_manage())
with check (public.can_asistencia_manage());
drop policy if exists p_francos_horarios_delete
  on public.francos_horarios_persona;
create policy p_francos_horarios_delete
on public.francos_horarios_persona
for delete
using (public.can_asistencia_manage());
create or replace function public.rpc_francos_horario(
  p_dni bigint,
  p_carrera_id bigint
)
returns table (
  id bigint,
  dni bigint,
  carrera_id bigint,
  dia_semana smallint,
  hora_desde text,
  hora_hasta text,
  minutos integer,
  usuario_carga uuid,
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

  if not public.can_asistencia_read() then
    raise exception 'Sin permiso para ver asistencia.';
  end if;

  return query
  select
    fh.id,
    fh.dni,
    fh.carrera_id,
    fh.dia_semana,
    to_char(fh.hora_desde, 'HH24:MI') as hora_desde,
    to_char(fh.hora_hasta, 'HH24:MI') as hora_hasta,
    public.francos_horario_minutos(fh.hora_desde, fh.hora_hasta) as minutos,
    fh.usuario_carga,
    fh.usuario_modifica,
    fh.created_at,
    fh.updated_at
  from public.francos_horarios_persona fh
  where fh.dni = p_dni
    and fh.carrera_id = p_carrera_id
  order by fh.dia_semana, fh.hora_desde, fh.hora_hasta;
end;
$function$;
create or replace function public.rpc_francos_horario_guardar(
  p_dni bigint,
  p_carrera_id bigint,
  p_items jsonb
)
returns table (
  id bigint,
  dni bigint,
  carrera_id bigint,
  dia_semana smallint,
  hora_desde text,
  hora_hasta text,
  minutos integer,
  usuario_carga uuid,
  usuario_modifica uuid,
  created_at timestamp without time zone,
  updated_at timestamp without time zone
)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_item jsonb;
  v_dia smallint;
  v_desde time without time zone;
  v_hasta time without time zone;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_asistencia_manage() then
    raise exception 'Sin permiso para modificar asistencia.';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Los horarios deben enviarse como un array JSON.';
  end if;

  delete from public.francos_horarios_persona fh
  where fh.dni = p_dni
    and fh.carrera_id = p_carrera_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_dia := (v_item ->> 'dia_semana')::smallint;
    v_desde := (v_item ->> 'hora_desde')::time;
    v_hasta := (v_item ->> 'hora_hasta')::time;

    if v_dia not between 1 and 7 then
      raise exception 'Dia de semana invalido: %', v_dia;
    end if;

    if v_hasta <= v_desde then
      raise exception 'El horario hasta debe ser mayor que desde.';
    end if;

    if extract(second from v_desde) <> 0
        or extract(second from v_hasta) <> 0 then
      raise exception 'Los horarios deben cargarse sin segundos.';
    end if;

    insert into public.francos_horarios_persona (
      dni,
      carrera_id,
      dia_semana,
      hora_desde,
      hora_hasta,
      usuario_carga,
      usuario_modifica
    )
    values (
      p_dni,
      p_carrera_id,
      v_dia,
      v_desde,
      v_hasta,
      (select auth.uid()),
      (select auth.uid())
    );
  end loop;

  return query
  select *
  from public.rpc_francos_horario(p_dni, p_carrera_id);
end;
$function$;
revoke execute on function public.has_legajo_role_ids(bigint[]) from public, anon;
revoke execute on function public.can_asistencia_read() from public, anon;
revoke execute on function public.can_asistencia_manage() from public, anon;
revoke execute on function public.rpc_francos_horario(bigint, bigint)
  from public, anon;
revoke execute on function public.rpc_francos_horario_guardar(bigint, bigint, jsonb)
  from public, anon;
grant execute on function public.has_legajo_role_ids(bigint[]) to authenticated;
grant execute on function public.can_asistencia_read() to authenticated;
grant execute on function public.can_asistencia_manage() to authenticated;
grant execute on function public.rpc_francos_horario(bigint, bigint)
  to authenticated;
grant execute on function public.rpc_francos_horario_guardar(bigint, bigint, jsonb)
  to authenticated;
