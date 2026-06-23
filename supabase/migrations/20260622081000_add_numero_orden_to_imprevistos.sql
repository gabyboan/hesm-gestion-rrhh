alter table public.imprevistos_registros
  add column if not exists numero_orden integer;

drop function if exists public.rpc_imprevistos_registros(integer, integer, integer);
drop function if exists public.rpc_imprevistos_crear(integer, integer, date, text);
drop function if exists public.rpc_imprevistos_crear(integer, integer, date, text, integer);
drop function if exists public.rpc_imprevistos_modificar(bigint, date, text);
drop function if exists public.rpc_imprevistos_modificar(bigint, date, text, integer);

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

grant execute on function public.rpc_imprevistos_registros(integer, integer, integer)
to authenticated;
grant execute on function public.rpc_imprevistos_crear(integer, integer, date, text, integer)
to authenticated;
grant execute on function public.rpc_imprevistos_modificar(bigint, date, text, integer)
to authenticated;

notify pgrst, 'reload schema';
