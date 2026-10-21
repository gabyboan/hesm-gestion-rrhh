-- Limit francos movement durations.
--
-- Allowed movement size:
-- - minimum: 30 minutes
-- - maximum per movement/day: 360 minutes
-- - step: multiples of 15 minutes

create or replace function public.validar_francos_minutos(p_minutos integer)
returns void
language plpgsql
stable
set search_path to 'public'
as $function$
begin
  if p_minutos is null then
    raise exception 'Debe indicar minutos.';
  end if;

  if abs(p_minutos) < 30 then
    raise exception 'El minimo permitido es 30 minutos.';
  end if;

  if abs(p_minutos) > 360 then
    raise exception 'El maximo permitido por dia es 6 horas.';
  end if;

  if abs(p_minutos) % 15 <> 0 then
    raise exception 'Los minutos deben cargarse de 15 en 15.';
  end if;
end;
$function$;
create or replace function public.validar_francos_tope_dia(
  p_dni bigint,
  p_carrera_id bigint,
  p_fecha date,
  p_minutos integer,
  p_excluir_id bigint default null
)
returns void
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_total integer;
begin
  select coalesce(sum(abs(fm.minutos)), 0)::integer
  into v_total
  from public.francos_movimientos fm
  where fm.dni = p_dni
    and fm.carrera_id = p_carrera_id
    and fm.fecha = p_fecha
    and fm.anulado = false
    and (p_excluir_id is null or fm.id <> p_excluir_id);

  if v_total + abs(p_minutos) > 360 then
    raise exception 'El maximo permitido por dia es 6 horas.';
  end if;
end;
$function$;
create or replace function public.rpc_francos_crear(
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

  perform public.validar_francos_minutos(p_minutos);
  perform public.validar_francos_tope_dia(
    p_dni,
    p_carrera_id,
    p_fecha,
    p_minutos
  );

  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Debe indicar un motivo.';
  end if;

  if p_minutos > 0 and not public.can_francos_admin_bank() then
    raise exception 'Sin permiso para sumar banco de francos.';
  end if;

  if p_minutos < 0 and not public.can_francos_use_bank() then
    raise exception 'Sin permiso para usar francos.';
  end if;

  if not (
    public.can_francos_admin_bank()
    or public.can_access_person(p_dni)
  ) then
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
create or replace function public.rpc_francos_modificar(
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
  v_current public.francos_movimientos;
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

  perform public.validar_francos_minutos(p_minutos);

  select *
  into v_current
  from public.francos_movimientos
  where id = p_id
    and anulado = false;

  if not found then
    raise exception 'Movimiento de francos no encontrado.';
  end if;

  perform public.validar_francos_tope_dia(
    v_current.dni,
    v_current.carrera_id,
    p_fecha,
    p_minutos,
    p_id
  );

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

  return v_row;
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
  v_current_id bigint;
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

  perform public.validar_francos_minutos(p_minutos);

  select fm.id
  into v_current_id
  from public.francos_movimientos fm
  where fm.dni = p_dni
    and fm.carrera_id = p_carrera_id
    and fm.motivo = 'saldo_inicial'
    and fm.anulado = false
  order by fm.fecha desc, fm.id desc
  limit 1;

  perform public.validar_francos_tope_dia(
    p_dni,
    p_carrera_id,
    p_fecha,
    p_minutos,
    v_current_id
  );

  update public.francos_movimientos
  set fecha = p_fecha,
      periodo = date_trunc('month', p_fecha)::date,
      minutos = p_minutos,
      observacion = null,
      usuario_modifica = (select auth.uid()),
      updated_at = now()
  where id = v_current_id
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
grant execute on function public.validar_francos_minutos(integer)
to authenticated;
grant execute on function public.validar_francos_tope_dia(
  bigint,
  bigint,
  date,
  integer,
  bigint
) to authenticated;
notify pgrst, 'reload schema';
