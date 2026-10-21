-- Ampliar la aclaracion sin modificar los permisos ni los datos existentes.
create or replace function public.rpc_medicos_crear(
  p_dni bigint,
  p_tipo text,
  p_familiar_apellido_nombre text default null,
  p_familiar_edad integer default null,
  p_familiar_parentesco text default null,
  p_es_art boolean default false,
  p_familiar_dni bigint default null,
  p_aclaracion_fecha_turno text default null
)
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_persona public.personas%rowtype;
  v_tipo text := upper(trim(coalesce(p_tipo, '')));
  v_aclaracion_fecha_turno text :=
    nullif(trim(coalesce(p_aclaracion_fecha_turno, '')), '');
  v_id bigint;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_create() then
    raise exception 'Sin permiso para emitir partes medicos.';
  end if;

  select *
  into v_persona
  from public.personas p
  where p.dni = p_dni;

  if not found then
    raise exception 'La persona no existe.';
  end if;
  if v_persona.legajo is null or v_persona.legajo <= 0 then
    raise exception 'La persona debe tener numero de legajo.';
  end if;
  if v_tipo not in ('DOMICILIO', 'CONSULTORIO', 'CANJE', 'DOMICILIO_FAMILIAR') then
    raise exception 'Tipo de parte medico invalido.';
  end if;
  if v_tipo = 'DOMICILIO_FAMILIAR' and (
    nullif(trim(coalesce(p_familiar_apellido_nombre, '')), '') is null
    or p_familiar_edad is null
    or nullif(trim(coalesce(p_familiar_parentesco, '')), '') is null
  ) then
    raise exception 'Completa nombre, edad y parentesco del familiar.';
  end if;
  if v_tipo = 'DOMICILIO_FAMILIAR' and coalesce(p_es_art, false) then
    raise exception 'El parte por familiar no puede marcarse como ART.';
  end if;
  if p_familiar_dni is not null and p_familiar_dni <= 0 then
    raise exception 'El DNI del familiar debe ser positivo.';
  end if;
  if v_tipo <> 'DOMICILIO_FAMILIAR' and p_familiar_dni is not null then
    raise exception 'Solo los partes por familiar pueden incluir DNI familiar.';
  end if;
  if length(v_aclaracion_fecha_turno) > 90 then
    raise exception 'La aclaracion de fecha o turno no puede superar 90 caracteres.';
  end if;

  insert into public.partes_medicos (
    dni,
    tipo,
    empleado_apellido,
    empleado_nombre,
    empleado_legajo,
    familiar_apellido_nombre,
    familiar_dni,
    familiar_edad,
    familiar_parentesco,
    es_art,
    aclaracion_fecha_turno
  )
  values (
    v_persona.dni,
    v_tipo,
    trim(v_persona.apellido),
    trim(v_persona.nombre),
    v_persona.legajo,
    case when v_tipo = 'DOMICILIO_FAMILIAR'
      then trim(p_familiar_apellido_nombre) end,
    case when v_tipo = 'DOMICILIO_FAMILIAR'
      then p_familiar_dni end,
    case when v_tipo = 'DOMICILIO_FAMILIAR' then p_familiar_edad end,
    case when v_tipo = 'DOMICILIO_FAMILIAR'
      then trim(p_familiar_parentesco) end,
    coalesce(p_es_art, false),
    v_aclaracion_fecha_turno
  )
  returning id into v_id;

  return v_id;
end;
$function$;

revoke execute on function public.rpc_medicos_crear(
  bigint, text, text, integer, text, boolean, bigint, text
) from public, anon;
grant execute on function public.rpc_medicos_crear(
  bigint, text, text, integer, text, boolean, bigint, text
) to authenticated;

notify pgrst, 'reload schema';
