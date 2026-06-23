-- Allow FRANCOS_ADM to initialize positive francos bank movements even when
-- the person is not covered by regular per-person filters.

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
notify pgrst, 'reload schema';
