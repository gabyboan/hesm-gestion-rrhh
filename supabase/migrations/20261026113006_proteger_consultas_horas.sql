-- Cierra lecturas de horas sin permiso. Contratos contrastados con PostgreSQL 17.
-- Mantiene nombres, argumentos, columnas y tipos de los RPC existentes.
-- Validar en staging antes de aplicar al proyecto compartido.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $$
begin
  if to_regprocedure('public.rpc_horas_registros_periodo(date)') is null
    or to_regprocedure('public.rpc_listado_horas_oficiales()') is null
    or to_regprocedure('public.can_horas_read()') is null then
    raise exception 'Faltan contratos de Horas. Revisar el esquema antes de aplicar.';
  end if;
end;
$$;

create or replace function private.horas_registros_periodo(p_periodo date)
returns table (
  id bigint, dni integer, carrera_id integer, fecha date, periodo date,
  tipo text, minutos integer, minutos_aplicados integer, minutos_excedidos integer,
  excedido boolean, created_at timestamptz, usuario_carga uuid,
  usuario_carga_nombre text, usuario_carga_apellido text
)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.' using errcode = '42501';
  end if;
  if public.can_horas_read() is not true then
    raise exception 'Sin permiso para ver registros.' using errcode = '42501';
  end if;
  return query
  select hr.id, hr.dni::integer, hr.carrera_id, hr.fecha, hr.periodo, hr.tipo,
    hr.minutos, coalesce(hr.minutos_aplicados, 0)::integer,
    coalesce(hr.minutos_excedidos, 0)::integer, coalesce(hr.excedido, false),
    hr.created_at::timestamptz, hr.usuario_carga, u.nombre, u.apellido
  from public.horas_registros hr
  left join public.usuarios u on u.auth_user_id = hr.usuario_carga or u.id = hr.usuario_carga
  where hr.periodo = p_periodo
  order by hr.fecha desc, hr.id desc;
end;
$$;

create or replace function public.rpc_horas_registros_periodo(p_periodo date)
returns table (
  id bigint, dni integer, carrera_id integer, fecha date, periodo date,
  tipo text, minutos integer, minutos_aplicados integer, minutos_excedidos integer,
  excedido boolean, created_at timestamptz, usuario_carga uuid,
  usuario_carga_nombre text, usuario_carga_apellido text
)
language sql stable security invoker set search_path = ''
as $$ select * from private.horas_registros_periodo(p_periodo); $$;

create or replace function private.listado_horas_oficiales()
returns table (dni bigint, apellido text, nombre text, carrera_id bigint)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.' using errcode = '42501';
  end if;
  if public.can_horas_read() is not true then
    raise exception 'Sin permiso para ver registros.' using errcode = '42501';
  end if;
  return query
  select v.dni, v.apellido, v.nombre, v.carrera_id
  from public.vw_listado_horas_oficiales v
  order by v.apellido, v.nombre, v.dni, v.carrera_id;
end;
$$;

create or replace function public.rpc_listado_horas_oficiales()
returns table (dni bigint, apellido text, nombre text, carrera_id bigint)
language sql stable security invoker set search_path = ''
as $$ select * from private.listado_horas_oficiales(); $$;

grant usage on schema private to authenticated;
revoke all on function private.horas_registros_periodo(date), private.listado_horas_oficiales() from public, anon;
grant execute on function private.horas_registros_periodo(date), private.listado_horas_oficiales() to authenticated;
revoke all on function public.rpc_listado_horas_oficiales() from public, anon;
grant execute on function public.rpc_listado_horas_oficiales() to authenticated;

-- El portal publico usa otros tres RPC exclusivos de service_role.
-- Estas firmas son de escritorio y deben requerir una sesion autenticada.
do $$
declare v_firma text; v_funcion regprocedure;
begin
  foreach v_firma in array array[
    'public.rpc_horas_registros_periodo(date)',
    'public.rpc_horas_registros_mes(bigint,integer,date)',
    'public.rpc_francos_crear(bigint,bigint,date,integer,text,text)',
    'public.rpc_francos_eliminar(bigint,text)',
    'public.rpc_francos_modificar(bigint,date,integer,text,text)',
    'public.rpc_francos_movimientos(bigint,bigint)',
    'public.rpc_imprevistos_crear(integer,integer,date,text,integer)',
    'public.rpc_imprevistos_eliminar(bigint)',
    'public.rpc_imprevistos_modificar(bigint,date,text,integer)',
    'public.rpc_imprevistos_registros(integer,integer,integer)',
    'public.usuario_tiene_rol(text)'
  ] loop
    v_funcion := to_regprocedure(v_firma);
    -- Algunas instalaciones no usan todos los modulos; no crear firmas ficticias.
    if v_funcion is not null then
      execute format('revoke execute on function %s from public, anon', v_funcion);
      execute format('grant execute on function %s to authenticated', v_funcion);
      if has_function_privilege('anon', v_funcion, 'EXECUTE') then
        raise exception 'Anon aun puede ejecutar % mediante otro rol. Revisar membresias.', v_firma;
      end if;
    end if;
  end loop;
end;
$$;
notify pgrst, 'reload schema';
commit;
