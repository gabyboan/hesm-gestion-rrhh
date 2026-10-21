-- Require francos permissions for initial balance RPCs.
--
-- legajo-digital can show these values in the edit screen, but loading or
-- deleting the initial bank belongs to the francos permissions model:
-- can_francos_read() for reading and can_francos_write() for mutations.

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
  if auth.uid() is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_read() then
    raise exception 'Sin permiso para ver francos.';
  end if;

  return query
  select
    fm.id,
    fm.fecha,
    fm.minutos,
    fm.observacion
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
  if auth.uid() is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_write() then
    raise exception 'Sin permiso para cargar francos.';
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
      observacion = p_observacion,
      usuario_modifica = auth.uid()
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
    p_observacion,
    auth.uid()
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
  if auth.uid() is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_francos_write() then
    raise exception 'Sin permiso para cargar francos.';
  end if;

  update public.francos_movimientos
  set anulado = true,
      anulado_at = now(),
      anulado_por = auth.uid(),
      anulacion_motivo = 'Banco inicial eliminado desde legajo-digital',
      usuario_modifica = auth.uid()
  where dni = p_dni
    and carrera_id = p_carrera_id
    and motivo = 'saldo_inicial'
    and anulado = false;

  return found;
end;
$function$;
notify pgrst, 'reload schema';
