-- Split francos permissions between usage and bank administration.
--
-- FRANCOS_CARGA can use/rest banked hours.
-- FRANCOS_ADM can add initial bank hours, edit movements, and annul movements.
-- The p_observacion parameters are kept for client compatibility but are no
-- longer persisted by these RPCs.

create or replace function public.has_role_code(p_codigo text)
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
    join public.roles r on r.id = ur.rol_id
    where (
        ur.usuario_id = (select auth.uid())
        or u.auth_user_id = (select auth.uid())
      )
      and r.codigo = p_codigo
  );
$function$;
create or replace function public.can_francos_use_bank()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('FRANCOS_CARGA')
      or public.has_role_code('FRANCOS_ADM');
$function$;
create or replace function public.can_francos_admin_bank()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('FRANCOS_ADM');
$function$;
drop function if exists public.rpc_francos_crear(
  bigint,
  bigint,
  date,
  integer,
  text,
  text
);
drop function if exists public.rpc_francos_crear(
  integer,
  integer,
  date,
  integer,
  text,
  text
);
create function public.rpc_francos_crear(
  p_dni bigint,
  p_carrera_id bigint,
  p_fecha date,
  p_minutos integer,
  p_motivo text,
  p_observacion text default null
)
returns public.francos_movimientos
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.francos_movimientos;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if p_fecha is null then
    raise exception 'Debe indicar la fecha.';
  end if;

  if p_minutos is null or p_minutos = 0 then
    raise exception 'Los minutos deben ser distintos de cero.';
  end if;

  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Debe indicar un motivo.';
  end if;

  if p_minutos > 0 and not public.can_francos_admin_bank() then
    raise exception 'Sin permiso para sumar banco de francos.';
  end if;

  if p_minutos < 0 and not public.can_francos_use_bank() then
    raise exception 'Sin permiso para usar francos.';
  end if;

  if not public.can_access_person(p_dni) then
    raise exception 'Sin permiso para acceder a la persona.';
  end if;

  insert into public.francos_movimientos (
    dni,
    carrera_id,
    fecha,
    periodo,
    minutos,
    motivo,
    observacion,
    usuario_carga
  )
  values (
    p_dni,
    p_carrera_id,
    p_fecha,
    date_trunc('month', p_fecha)::date,
    p_minutos,
    trim(p_motivo),
    null,
    (select auth.uid())
  )
  returning * into v_row;

  return v_row;
end;
$function$;
drop function if exists public.rpc_francos_modificar(
  bigint,
  date,
  integer,
  text,
  text
);
drop function if exists public.rpc_francos_modificar(
  integer,
  date,
  integer,
  text,
  text
);
create function public.rpc_francos_modificar(
  p_id bigint,
  p_fecha date,
  p_minutos integer,
  p_motivo text,
  p_observacion text default null
)
returns public.francos_movimientos
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.francos_movimientos;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_admin_bank() then
    raise exception 'Sin permiso para administrar movimientos de francos.';
  end if;

  if p_fecha is null then
    raise exception 'Debe indicar la fecha.';
  end if;

  if p_minutos is null or p_minutos = 0 then
    raise exception 'Los minutos deben ser distintos de cero.';
  end if;

  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Debe indicar un motivo.';
  end if;

  update public.francos_movimientos
  set fecha = p_fecha,
      periodo = date_trunc('month', p_fecha)::date,
      minutos = p_minutos,
      motivo = trim(p_motivo),
      observacion = null,
      usuario_modifica = (select auth.uid()),
      updated_at = now()
  where id = p_id
    and anulado = false
  returning * into v_row;

  if not found then
    raise exception 'Movimiento de francos no encontrado.';
  end if;

  return v_row;
end;
$function$;
drop function if exists public.rpc_francos_eliminar(bigint, text);
drop function if exists public.rpc_francos_eliminar(integer, text);
create function public.rpc_francos_eliminar(
  p_id bigint,
  p_anulacion_motivo text default null
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_admin_bank() then
    raise exception 'Sin permiso para administrar movimientos de francos.';
  end if;

  update public.francos_movimientos
  set anulado = true,
      anulado_at = now(),
      anulado_por = (select auth.uid()),
      anulacion_motivo = nullif(trim(p_anulacion_motivo), ''),
      usuario_modifica = (select auth.uid()),
      updated_at = now()
  where id = p_id
    and anulado = false;

  return found;
end;
$function$;
create or replace function public.rpc_francos_saldo_inicial_actual(
  p_dni bigint,
  p_carrera_id bigint
)
returns table (
  id bigint,
  fecha date,
  minutos integer,
  observacion text
)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_use_bank() then
    raise exception 'Sin permiso para ver francos.';
  end if;

  return query
  select
    fm.id,
    fm.fecha,
    fm.minutos,
    null::text as observacion
  from public.francos_movimientos fm
  where fm.dni = p_dni
    and fm.carrera_id = p_carrera_id
    and fm.motivo = 'saldo_inicial'
    and fm.anulado = false
  order by fm.fecha desc, fm.id desc
  limit 1;
end;
$function$;
create or replace function public.rpc_francos_saldo_inicial(
  p_dni bigint,
  p_carrera_id bigint,
  p_fecha date,
  p_minutos integer,
  p_observacion text default null
)
returns public.francos_movimientos
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.francos_movimientos;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_admin_bank() then
    raise exception 'Sin permiso para cargar banco inicial de francos.';
  end if;

  if p_fecha is null then
    raise exception 'Debe indicar la fecha del banco inicial.';
  end if;

  if p_minutos is null or p_minutos = 0 then
    raise exception 'Los minutos deben ser distintos de cero.';
  end if;

  if not public.can_access_person(p_dni) then
    raise exception 'Sin permiso para acceder a la persona.';
  end if;

  update public.francos_movimientos
  set fecha = p_fecha,
      periodo = date_trunc('month', p_fecha)::date,
      minutos = p_minutos,
      observacion = null,
      usuario_modifica = (select auth.uid()),
      updated_at = now()
  where dni = p_dni
    and carrera_id = p_carrera_id
    and motivo = 'saldo_inicial'
    and anulado = false
  returning * into v_row;

  if found then
    return v_row;
  end if;

  insert into public.francos_movimientos (
    dni,
    carrera_id,
    fecha,
    periodo,
    minutos,
    motivo,
    observacion,
    usuario_carga
  )
  values (
    p_dni,
    p_carrera_id,
    p_fecha,
    date_trunc('month', p_fecha)::date,
    p_minutos,
    'saldo_inicial',
    null,
    (select auth.uid())
  )
  returning * into v_row;

  return v_row;
end;
$function$;
create or replace function public.rpc_francos_saldo_inicial_eliminar(
  p_dni bigint,
  p_carrera_id bigint
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_admin_bank() then
    raise exception 'Sin permiso para eliminar banco inicial de francos.';
  end if;

  if not public.can_access_person(p_dni) then
    raise exception 'Sin permiso para acceder a la persona.';
  end if;

  update public.francos_movimientos
  set anulado = true,
      anulado_at = now(),
      anulado_por = (select auth.uid()),
      anulacion_motivo = 'Banco inicial eliminado',
      usuario_modifica = (select auth.uid()),
      updated_at = now()
  where dni = p_dni
    and carrera_id = p_carrera_id
    and motivo = 'saldo_inicial'
    and anulado = false;

  return found;
end;
$function$;
revoke execute on function public.has_role_code(text) from public, anon;
revoke execute on function public.can_francos_use_bank() from public, anon;
revoke execute on function public.can_francos_admin_bank() from public, anon;
grant execute on function public.has_role_code(text) to authenticated;
grant execute on function public.can_francos_use_bank() to authenticated;
grant execute on function public.can_francos_admin_bank() to authenticated;
grant execute on function public.rpc_francos_crear(
  bigint,
  bigint,
  date,
  integer,
  text,
  text
) to authenticated;
grant execute on function public.rpc_francos_modificar(
  bigint,
  date,
  integer,
  text,
  text
) to authenticated;
grant execute on function public.rpc_francos_eliminar(bigint, text)
to authenticated;
notify pgrst, 'reload schema';
