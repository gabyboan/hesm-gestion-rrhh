-- Reglas compartidas con lib/core/utils/search_query.dart.
-- Los términos son literales (%, _ y comillas no son operadores).
create or replace function public.busqueda_normalizar(p_texto text)
returns text
language plpgsql immutable parallel safe
security invoker
set search_path = ''
as $function$
declare
  v_texto text := lower(translate(coalesce(p_texto, ''),
    'ÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇáàäâãåéèëêíìïîóòöôõúùüûñç',
    'AAAAAAEEEEIIIIOOOOOUUUUNCaaaaaaeeeeiiiiooooouuuunc'));
begin
  v_texto := regexp_replace(v_texto, U&'[\0300-\036f]', '', 'g');
  -- DNI/CUIL con puntos, comas o guiones, incluso junto a un nombre.
  while v_texto ~ '[0-9][.,-][0-9]' loop
    v_texto := regexp_replace(v_texto, '([0-9])[.,-]([0-9])', '\1\2', 'g');
  end loop;
  return btrim(regexp_replace(v_texto, '[[:space:] ,;:()/\\|+-]+', ' ', 'g'));
end;
$function$;

create or replace function public.busqueda_terminos(p_buscar text)
returns text[]
language sql immutable parallel safe
security invoker
set search_path = ''
as $function$
  select string_to_array(public.busqueda_normalizar(p_buscar), ' ');
$function$;

create or replace function public.busqueda_coincide(p_campos text[], p_terminos text[])
returns boolean
language sql immutable parallel safe
security invoker
set search_path = ''
as $function$
  select not exists (
    select 1
    from unnest(p_terminos) as t(termino)
    where strpos(public.busqueda_normalizar(array_to_string(p_campos, ' ')), t.termino) = 0
  );
$function$;

revoke all on function public.busqueda_normalizar(text) from public, anon;
revoke all on function public.busqueda_terminos(text) from public, anon;
revoke all on function public.busqueda_coincide(text[], text[]) from public, anon;
grant execute on function public.busqueda_normalizar(text) to authenticated;
grant execute on function public.busqueda_terminos(text) to authenticated;
grant execute on function public.busqueda_coincide(text[], text[]) to authenticated;


create or replace function public.rpc_francos_listado(
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
declare
  v_terminos text[] := public.busqueda_terminos(p_buscar);
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
  where public.busqueda_coincide(
      array[p.dni::text, p.apellido, p.nombre, pc.carrera_id::text, c.nombre], v_terminos
    )
  group by p.dni, p.apellido, p.nombre, pc.carrera_id, c.nombre
  order by p.apellido, p.nombre, p.dni, c.nombre;
end;
$function$;
revoke execute on function public.rpc_francos_listado(text) from public, anon;
grant execute on function public.rpc_francos_listado(text) to authenticated;


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
  with parametros as materialized (
    select public.busqueda_terminos(p_buscar) as terminos
  ), personas as (
    select distinct
      vh.dni::integer as dni,
      vh.apellido::text as apellido,
      vh.nombre::text as nombre,
      vh.carrera_id::integer as carrera_id,
      vh.carrera::text as carrera
    from public.vw_listado_horas vh
    where public.can_imprevistos_read()
      and vh.carrera_id in (1, 3)
      and public.busqueda_coincide(
      array[vh.dni::text, vh.apellido, vh.nombre, vh.carrera_id::text, vh.carrera], (select terminos from parametros)
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
revoke execute on function public.rpc_imprevistos_listado(integer, text) from public, anon;
grant execute on function public.rpc_imprevistos_listado(integer, text) to authenticated;


create or replace function public.rpc_medicos_personas(p_buscar text default null)
returns table (
  dni bigint,
  apellido text,
  nombre text,
  legajo integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_terminos text[] := public.busqueda_terminos(p_buscar);
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;

  return query
  select p.dni, p.apellido, p.nombre, p.legajo
  from public.personas p
  where not exists (
      select 1 from public.persona_inactivo pi where pi.dni = p.dni
    )
    and public.busqueda_coincide(
      array[p.dni::text, p.legajo::text, p.apellido, p.nombre], v_terminos
    )
  order by p.apellido, p.nombre, p.dni;
end;
$function$;
revoke execute on function public.rpc_medicos_personas(text) from public, anon;
grant execute on function public.rpc_medicos_personas(text) to authenticated;


create or replace function public.rpc_medicos_registros(p_buscar text default null)
returns table (
  id bigint,
  dni bigint,
  fecha date,
  tipo text,
  empleado_apellido text,
  empleado_nombre text,
  empleado_legajo integer,
  familiar_apellido_nombre text,
  familiar_dni bigint,
  familiar_edad integer,
  familiar_parentesco text,
  es_art boolean,
  aclaracion_fecha_turno text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_terminos text[] := public.busqueda_terminos(p_buscar);
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;

  return query
  select
    pm.id,
    pm.dni,
    pm.fecha,
    pm.tipo,
    pm.empleado_apellido,
    pm.empleado_nombre,
    pm.empleado_legajo,
    pm.familiar_apellido_nombre,
    pm.familiar_dni,
    pm.familiar_edad,
    pm.familiar_parentesco,
    pm.es_art,
    pm.aclaracion_fecha_turno,
    pm.created_at
  from public.partes_medicos pm
  where pm.anulado_at is null
    and public.busqueda_coincide(
      array[pm.dni::text, pm.empleado_legajo::text, pm.empleado_apellido, pm.empleado_nombre,
        pm.familiar_apellido_nombre, pm.familiar_dni::text, pm.aclaracion_fecha_turno], v_terminos
    )
  order by pm.fecha desc, pm.id desc
  limit 500;
end;
$function$;
revoke execute on function public.rpc_medicos_registros(text) from public, anon;
grant execute on function public.rpc_medicos_registros(text) to authenticated;

-- Filtrar en el servidor antes del limite de resultados. SECURITY INVOKER
-- conserva las politicas RLS de la vista y de sus tablas subyacentes.
create or replace function public.rpc_suplencias_listado(p_buscar text default null)
returns setof public.vw_suplencias_detalle_servicio
language sql stable
security invoker
set search_path = ''
as $function$
  with parametros as materialized (
    select public.busqueda_terminos(p_buscar) as terminos
  )
  select s.*
  from public.vw_suplencias_detalle_servicio s
  where (select public.can_suplencias_read())
    and public.busqueda_coincide(array[
      s.suplente_dni::text, s.suplente_apellido, s.suplente_nombre,
      s.suplente_servicio, s.titular_dni::text, s.titular_apellido,
      s.titular_nombre, s.titular_servicio, s.motivo
    ], (select terminos from parametros));
$function$;
revoke execute on function public.rpc_suplencias_listado(text) from public, anon;
grant execute on function public.rpc_suplencias_listado(text) to authenticated;

notify pgrst, 'reload schema';
