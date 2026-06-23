-- Modulo de imprevistos.
--
-- Reglas:
-- - Solo aplica a carrera 1 y 3.
-- - Maximo 3 imprevistos activos por persona/carrera/anio.
-- - No se pueden cargar en dias consecutivos para la misma persona/carrera.
--
-- Nota:
-- Este script asume que existe public.vw_listado_horas con columnas:
-- dni, apellido, nombre, carrera_id, carrera.
-- Si el listado definitivo usa otra vista/RPC, ajustar rpc_imprevistos_listado.
--
-- Roles esperados:
-- IMPREVISTOS_LECTURA: puede ver cupos y registros.
-- IMPREVISTOS_CARGA: puede ver y agendar imprevistos.
-- IMPREVISTOS_ADM: puede ver, agendar, modificar y eliminar imprevistos.

create table if not exists public.imprevistos_registros (
  id bigserial primary key,
  dni integer not null,
  carrera_id integer not null,
  fecha date not null,
  anio integer generated always as (extract(year from fecha)::integer) stored,
  observacion text,
  numero_orden integer,
  usuario_carga uuid default auth.uid(),
  usuario_elimina uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint imprevistos_carrera_chk check (carrera_id in (1, 3))
);
create unique index if not exists imprevistos_unico_dia_activo_idx
  on public.imprevistos_registros (dni, carrera_id, fecha)
  where deleted_at is null;
create index if not exists imprevistos_persona_anio_idx
  on public.imprevistos_registros (dni, carrera_id, anio)
  where deleted_at is null;
create index if not exists imprevistos_fecha_idx
  on public.imprevistos_registros (fecha)
  where deleted_at is null;
create or replace function public.usuario_tiene_rol(p_codigo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuario_roles ur
    join public.roles r on r.id = ur.rol_id
    where ur.usuario_id = auth.uid()
      and r.codigo = p_codigo
  );
$$;
create or replace function public.can_imprevistos_read()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.usuario_tiene_rol('IMPREVISTOS_LECTURA')
    or public.usuario_tiene_rol('IMPREVISTOS_CARGA')
    or public.usuario_tiene_rol('IMPREVISTOS_ADM');
$$;
create or replace function public.can_imprevistos_create()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.usuario_tiene_rol('IMPREVISTOS_CARGA')
    or public.usuario_tiene_rol('IMPREVISTOS_ADM');
$$;
create or replace function public.can_imprevistos_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.usuario_tiene_rol('IMPREVISTOS_ADM');
$$;
create or replace function public.rpc_imprevistos_listado(
  p_anio integer,
  p_buscar text default null
)
returns table (
  dni integer,
  apellido text,
  nombre text,
  carrera_id integer,
  carrera text,
  usados integer,
  restantes integer
)
language sql
stable
security definer
set search_path = public
as $$
  with personas as (
    select distinct
      vh.dni::integer as dni,
      vh.apellido::text as apellido,
      vh.nombre::text as nombre,
      vh.carrera_id::integer as carrera_id,
      vh.carrera::text as carrera
    from public.vw_listado_horas vh
    where public.can_imprevistos_read()
      and vh.carrera_id in (1, 3)
      and (
        p_buscar is null
        or p_buscar = ''
        or vh.dni::text ilike '%' || p_buscar || '%'
        or vh.apellido ilike '%' || p_buscar || '%'
        or vh.nombre ilike '%' || p_buscar || '%'
        or vh.carrera ilike '%' || p_buscar || '%'
        or vh.carrera_id::text ilike '%' || p_buscar || '%'
      )
  ),
  usos as (
    select
      ir.dni,
      ir.carrera_id,
      count(*)::integer as usados
    from public.imprevistos_registros ir
    where ir.deleted_at is null
      and ir.anio = p_anio
    group by ir.dni, ir.carrera_id
  )
  select
    p.dni,
    p.apellido,
    p.nombre,
    p.carrera_id,
    p.carrera,
    coalesce(u.usados, 0)::integer as usados,
    greatest(3 - coalesce(u.usados, 0), 0)::integer as restantes
  from personas p
  left join usos u
    on u.dni = p.dni
   and u.carrera_id = p.carrera_id
  order by p.apellido, p.nombre, p.dni, p.carrera_id;
$$;
create or replace function public.rpc_imprevistos_registros(
  p_dni integer,
  p_carrera_id integer,
  p_anio integer
)
returns table (
  id bigint,
  dni integer,
  carrera_id integer,
  fecha date,
  anio integer,
  observacion text,
  numero_orden integer,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ir.id,
    ir.dni,
    ir.carrera_id,
    ir.fecha,
    ir.anio,
    coalesce(ir.observacion, '')::text as observacion,
    ir.numero_orden,
    ir.created_at
  from public.imprevistos_registros ir
  where public.can_imprevistos_read()
    and ir.deleted_at is null
    and ir.dni = p_dni
    and ir.carrera_id = p_carrera_id
    and ir.anio = p_anio
  order by ir.fecha desc, ir.id desc;
$$;
create or replace function public.rpc_imprevistos_crear(
  p_dni integer,
  p_carrera_id integer,
  p_fecha date,
  p_observacion text default null,
  p_numero_orden integer default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_anio integer := extract(year from p_fecha)::integer;
  v_usados integer;
  v_id bigint;
begin
  if not public.can_imprevistos_create() then
    raise exception 'Sin permiso para cargar imprevistos.';
  end if;

  if p_carrera_id not in (1, 3) then
    raise exception 'Los imprevistos solo aplican a carrera 1 y 3.';
  end if;

  select count(*)::integer
    into v_usados
  from public.imprevistos_registros ir
  where ir.deleted_at is null
    and ir.dni = p_dni
    and ir.carrera_id = p_carrera_id
    and ir.anio = v_anio;

  if v_usados >= 3 then
    raise exception 'La persona ya utilizo los 3 imprevistos del anio.';
  end if;

  if exists (
    select 1
    from public.imprevistos_registros ir
    where ir.deleted_at is null
      and ir.dni = p_dni
      and ir.carrera_id = p_carrera_id
      and ir.fecha in (p_fecha - 1, p_fecha + 1)
  ) then
    raise exception 'No se pueden cargar imprevistos en dias consecutivos.';
  end if;

  insert into public.imprevistos_registros (
    dni,
    carrera_id,
    fecha,
    observacion,
    numero_orden,
    usuario_carga
  )
  values (
    p_dni,
    p_carrera_id,
    p_fecha,
    nullif(trim(coalesce(p_observacion, '')), ''),
    p_numero_orden,
    auth.uid()
  )
  returning id into v_id;

  return v_id;
end;
$$;
create or replace function public.rpc_imprevistos_modificar(
  p_id bigint,
  p_fecha date,
  p_observacion text default null,
  p_numero_orden integer default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dni integer;
  v_carrera_id integer;
  v_anio integer := extract(year from p_fecha)::integer;
  v_usados integer;
begin
  if not public.can_imprevistos_admin() then
    raise exception 'Sin permiso para modificar imprevistos.';
  end if;

  select ir.dni, ir.carrera_id
    into v_dni, v_carrera_id
  from public.imprevistos_registros ir
  where ir.id = p_id
    and ir.deleted_at is null;

  if not found then
    return false;
  end if;

  select count(*)::integer
    into v_usados
  from public.imprevistos_registros ir
  where ir.deleted_at is null
    and ir.id <> p_id
    and ir.dni = v_dni
    and ir.carrera_id = v_carrera_id
    and ir.anio = v_anio;

  if v_usados >= 3 then
    raise exception 'La persona ya utilizo los 3 imprevistos del anio.';
  end if;

  if exists (
    select 1
    from public.imprevistos_registros ir
    where ir.deleted_at is null
      and ir.id <> p_id
      and ir.dni = v_dni
      and ir.carrera_id = v_carrera_id
      and ir.fecha in (p_fecha - 1, p_fecha + 1)
  ) then
    raise exception 'No se pueden cargar imprevistos en dias consecutivos.';
  end if;

  update public.imprevistos_registros
     set fecha = p_fecha,
         observacion = nullif(trim(coalesce(p_observacion, '')), ''),
         numero_orden = p_numero_orden,
         updated_at = now()
   where id = p_id
     and deleted_at is null;

  return found;
end;
$$;
create or replace function public.rpc_imprevistos_eliminar(p_id bigint)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.can_imprevistos_admin() then
    raise exception 'Sin permiso para eliminar imprevistos.';
  end if;

  update public.imprevistos_registros
     set deleted_at = now(),
         usuario_elimina = auth.uid(),
         updated_at = now()
   where id = p_id
     and deleted_at is null;

  return found;
end;
$$;
