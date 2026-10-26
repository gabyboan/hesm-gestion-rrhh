-- Identificación persistente del papel y registro de su devolución.
-- Aplicar antes de distribuir el escritorio con QR. No modifica rpc_medicos_crear.
begin;

create schema if not exists private;

-- Siete posiciones para el número de parte y un dígito de control Luhn.
-- Pasados 9.999.999 partes crece sin truncar ni reutilizar identificadores.
create function private.medicos_codigo(p_id bigint)
returns text language plpgsql immutable strict parallel safe
security invoker set search_path = ''
as $$
declare
  v_base text := lpad(p_id::text, greatest(7, length(p_id::text)), '0');
  v_suma integer := 0;
  v_digito integer;
  v_duplicar boolean := true;
begin
  if p_id <= 0 then raise exception 'Numero de parte invalido.'; end if;
  for v_i in reverse length(v_base)..1 loop
    v_digito := substr(v_base, v_i, 1)::integer;
    if v_duplicar then
      v_digito := v_digito * 2;
      if v_digito > 9 then v_digito := v_digito - 9; end if;
    end if;
    v_suma := v_suma + v_digito;
    v_duplicar := not v_duplicar;
  end loop;
  return v_base || ((10 - v_suma % 10) % 10)::text;
end;
$$;
revoke all on function private.medicos_codigo(bigint) from public, anon, authenticated;

alter table public.partes_medicos
  add column codigo_qr text not null
    generated always as (private.medicos_codigo(id)) stored,
  add constraint partes_medicos_codigo_qr_key unique (codigo_qr),
  add constraint partes_medicos_codigo_qr_chk check (codigo_qr ~ '^[0-9]{8,20}$');

insert into public.roles (codigo, nombre)
values ('MEDICOS_CONTROL', 'Partes medicos - Control de devolucion')
on conflict (codigo) do update set nombre = excluded.nombre;

create function public.can_medicos_control()
returns boolean language sql stable security invoker set search_path = ''
as $$
  select (select auth.uid()) is not null
    and public.can_medicos_read() and public.has_role_code('MEDICOS_CONTROL');
$$;
revoke all on function public.can_medicos_control() from public, anon;
grant execute on function public.can_medicos_control() to authenticated;

create table public.partes_medicos_controles (
  id bigint generated always as identity primary key,
  parte_id bigint not null references public.partes_medicos(id),
  version integer not null check (version > 0),
  fecha_desde date not null,
  dias_aprobados integer not null check (dias_aprobados between 0 and 3650),
  fecha_hasta date generated always as (
    case when dias_aprobados = 0 then null
      else fecha_desde + (dias_aprobados - 1) end
  ) stored,
  medico_nombre text not null check (length(trim(medico_nombre)) between 1 and 150),
  medico_matricula text not null check (length(trim(medico_matricula)) between 1 and 50),
  motivo_rectificacion text,
  usuario_registro uuid not null default auth.uid(),
  registrado_at timestamptz not null default clock_timestamp(),
  unique (parte_id, version),
  check (
    (version = 1 and motivo_rectificacion is null)
    or (version > 1 and coalesce(length(trim(motivo_rectificacion)), 0) between 1 and 500)
  )
);
alter table public.partes_medicos_controles enable row level security;
revoke all on public.partes_medicos_controles from public, anon, authenticated;
revoke all on sequence public.partes_medicos_controles_id_seq from public, anon, authenticated;
comment on table public.partes_medicos_controles is
  'Devoluciones del papel, sin UPDATE/DELETE de clientes. Cero dias indica sin dias aprobados. El QR no acredita por si solo una aprobacion medica.';

-- Los helpers con privilegios residen fuera del esquema expuesto por PostgREST.
-- Cada entrada verifica sesión y permisos; las RPC públicas son INVOKER.
grant usage on schema private to authenticated;

create function private.medicos_documento(p_id bigint, p_codigo text)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_parte public.partes_medicos%rowtype;
begin
  if (select auth.uid()) is null then raise exception 'No autenticado.'; end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;
  if (p_id is null) = (p_codigo is null) then
    raise exception 'Indica el numero de parte o su codigo.';
  end if;
  select pm.* into v_parte from public.partes_medicos pm
  where (p_id is not null and pm.id = p_id)
     or (p_codigo is not null and pm.codigo_qr = upper(p_codigo));
  if not found then raise exception 'Parte medico no encontrado.'; end if;
  return jsonb_build_object(
    'parte', to_jsonb(v_parte),
    'controles', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.version desc)
      from public.partes_medicos_controles c where c.parte_id = v_parte.id
    ), '[]'::jsonb)
  );
end;
$$;
revoke all on function private.medicos_documento(bigint, text) from public, anon, authenticated;
grant execute on function private.medicos_documento(bigint, text) to authenticated;

create function public.rpc_medicos_documento(p_id bigint default null, p_codigo text default null)
returns jsonb language sql stable security invoker set search_path = ''
as $$ select private.medicos_documento(p_id, p_codigo); $$;
revoke all on function public.rpc_medicos_documento(bigint, text) from public, anon;
grant execute on function public.rpc_medicos_documento(bigint, text) to authenticated;

create function private.medicos_registros_qr(p_buscar text)
returns setof public.partes_medicos
language plpgsql stable security definer set search_path = ''
as $$
declare v_terminos text[] := public.busqueda_terminos(p_buscar);
begin
  if (select auth.uid()) is null then raise exception 'No autenticado.'; end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;
  return query select pm.* from public.partes_medicos pm
  where pm.anulado_at is null and public.busqueda_coincide(array[
    pm.dni::text, pm.empleado_legajo::text, pm.empleado_apellido,
    pm.empleado_nombre, pm.familiar_apellido_nombre, pm.familiar_dni::text,
    pm.aclaracion_fecha_turno, pm.id::text, pm.codigo_qr,
    'PM-' || regexp_replace(pm.codigo_qr, '(.{4})(?=.)', '\1-', 'g')
  ], v_terminos)
  order by pm.fecha desc, pm.id desc limit 500;
end;
$$;
revoke all on function private.medicos_registros_qr(text) from public, anon, authenticated;
grant execute on function private.medicos_registros_qr(text) to authenticated;
drop function public.rpc_medicos_registros(text);
create function public.rpc_medicos_registros(p_buscar text default null)
returns setof public.partes_medicos
language sql stable security invoker set search_path = ''
as $$ select * from private.medicos_registros_qr(p_buscar); $$;
revoke all on function public.rpc_medicos_registros(text) from public, anon;
grant execute on function public.rpc_medicos_registros(text) to authenticated;

create function private.medicos_control_guardar(
  p_codigo text, p_fecha_desde date, p_dias_aprobados integer,
  p_medico_nombre text, p_medico_matricula text, p_version_esperada integer,
  p_motivo_rectificacion text
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_parte public.partes_medicos%rowtype;
  v_version integer;
  v_control public.partes_medicos_controles%rowtype;
begin
  if (select auth.uid()) is null then raise exception 'No autenticado.'; end if;
  if not public.can_medicos_control() then
    raise exception 'Sin permiso para controlar devoluciones. Falta MEDICOS_CONTROL.';
  end if;
  -- El bloqueo también serializa controles simultáneos y la anulación del parte.
  select pm.* into v_parte from public.partes_medicos pm
  where pm.codigo_qr = upper(p_codigo) for update;
  if not found then raise exception 'Parte medico no encontrado.'; end if;
  if v_parte.anulado_at is not null then
    raise exception 'El parte esta anulado. No se puede registrar su devolucion.';
  end if;
  select coalesce(max(c.version), 0) into v_version
  from public.partes_medicos_controles c where c.parte_id = v_parte.id;
  if p_version_esperada is null or p_version_esperada <> v_version then
    raise exception 'El control cambio. Volve a consultar el parte antes de guardar.';
  end if;
  if v_version > 0 and not public.can_medicos_admin() then
    raise exception 'Solo un administrador de medicos puede rectificar un control.';
  end if;
  if p_fecha_desde is null or p_dias_aprobados is null
    or p_dias_aprobados not between 0 and 3650 then
    raise exception 'Completa la fecha de inicio y los dias aprobados (0 a 3650).';
  end if;
  if coalesce(length(trim(p_medico_nombre)), 0) not between 1 and 150
    or coalesce(length(trim(p_medico_matricula)), 0) not between 1 and 50 then
    raise exception 'Completa nombre y matricula del medico que figura en el papel.';
  end if;
  if v_version > 0 and coalesce(length(trim(p_motivo_rectificacion)), 0) not between 1 and 500 then
    raise exception 'Indica el motivo de la rectificacion (hasta 500 caracteres).';
  end if;
  insert into public.partes_medicos_controles (
    parte_id, version, fecha_desde, dias_aprobados, medico_nombre,
    medico_matricula, motivo_rectificacion, usuario_registro
  ) values (
    v_parte.id, v_version + 1, p_fecha_desde, p_dias_aprobados,
    trim(p_medico_nombre), trim(p_medico_matricula),
    case when v_version > 0 then trim(p_motivo_rectificacion) end,
    auth.uid()
  ) returning * into v_control;
  return to_jsonb(v_control);
end;
$$;
revoke all on function private.medicos_control_guardar(text,date,integer,text,text,integer,text)
  from public, anon, authenticated;
grant execute on function private.medicos_control_guardar(text,date,integer,text,text,integer,text)
  to authenticated;

create function public.rpc_medicos_control_guardar(
  p_codigo text, p_fecha_desde date, p_dias_aprobados integer,
  p_medico_nombre text, p_medico_matricula text, p_version_esperada integer,
  p_motivo_rectificacion text default null
)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.medicos_control_guardar(
  p_codigo, p_fecha_desde, p_dias_aprobados, p_medico_nombre,
  p_medico_matricula, p_version_esperada, p_motivo_rectificacion
); $$;
revoke all on function public.rpc_medicos_control_guardar(text,date,integer,text,text,integer,text)
  from public, anon;
grant execute on function public.rpc_medicos_control_guardar(text,date,integer,text,text,integer,text)
  to authenticated;

-- Verificar el backfill y los accesos antes de confirmar la migración.
do $$
declare v_total bigint;
begin
  select count(*) into v_total from public.partes_medicos;
  if exists (select 1 from public.partes_medicos
      where codigo_qr is null or codigo_qr !~ '^[0-9]{8,20}$'
        or codigo_qr <> private.medicos_codigo(id))
    or (select count(distinct codigo_qr) from public.partes_medicos) <> v_total then
    raise exception 'La verificacion de codigos QR fallo.';
  end if;
  if private.medicos_codigo(42) <> '00000422'
    or private.medicos_codigo(100) <> '00001008' then
    raise exception 'El digito de control no coincide con el contrato del lector.';
  end if;
  if has_table_privilege('authenticated', 'public.partes_medicos_controles', 'INSERT,UPDATE,DELETE')
    or has_table_privilege('anon', 'public.partes_medicos_controles', 'SELECT,INSERT,UPDATE,DELETE')
    or has_function_privilege('anon', 'public.rpc_medicos_documento(bigint,text)', 'EXECUTE')
    or has_function_privilege('anon', 'public.rpc_medicos_control_guardar(text,date,integer,text,text,integer,text)', 'EXECUTE')
    or not (select relrowsecurity from pg_class where oid = 'public.partes_medicos_controles'::regclass) then
    raise exception 'La verificacion de permisos de control medico fallo.';
  end if;
  raise notice 'QR verificado: % partes con codigo unico y permisos de control protegidos.', v_total;
end;
$$;

notify pgrst, 'reload schema';
commit;
