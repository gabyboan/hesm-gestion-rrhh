alter table public.partes_medicos
  add column familiar_edad_meses integer;

alter table public.partes_medicos
  add constraint partes_medicos_familiar_edad_meses_chk
  check (familiar_edad_meses is null or familiar_edad_meses between 0 and 11);

alter table public.partes_medicos
  drop constraint partes_medicos_familiar_chk;

alter table public.partes_medicos
  add constraint partes_medicos_familiar_chk check (
    (
      tipo = 'DOMICILIO_FAMILIAR'
      and nullif(trim(familiar_apellido_nombre), '') is not null
      and familiar_edad is not null
      and (familiar_edad_meses is null or familiar_edad = 0)
      and nullif(trim(familiar_parentesco), '') is not null
    )
    or (
      tipo <> 'DOMICILIO_FAMILIAR'
      and familiar_apellido_nombre is null
      and familiar_edad is null
      and familiar_edad_meses is null
      and familiar_parentesco is null
    )
  );

comment on column public.partes_medicos.familiar_edad_meses is
  'Edad del familiar en meses cumplidos cuando tiene menos de un año.';

drop function public.rpc_medicos_registros(text);
create function public.rpc_medicos_registros(p_buscar text default null)
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
  familiar_edad_meses integer,
  familiar_parentesco text,
  es_art boolean,
  aclaracion_fecha_turno text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
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
    pm.familiar_edad_meses,
    pm.familiar_parentesco,
    pm.es_art,
    pm.aclaracion_fecha_turno,
    pm.created_at
  from public.partes_medicos pm
  where pm.anulado_at is null
    and public.busqueda_coincide(
      array[
        pm.dni::text,
        pm.empleado_legajo::text,
        pm.empleado_apellido,
        pm.empleado_nombre,
        pm.familiar_apellido_nombre,
        pm.familiar_dni::text,
        pm.aclaracion_fecha_turno
      ],
      v_terminos
    )
  order by pm.fecha desc, pm.id desc
  limit 500;
end;
$function$;

revoke execute on function public.rpc_medicos_registros(text) from public, anon;
grant execute on function public.rpc_medicos_registros(text) to authenticated;

drop function public.rpc_medicos_crear(
  bigint, text, text, integer, text, boolean, bigint, text
);
create function public.rpc_medicos_crear(
  p_dni bigint,
  p_tipo text,
  p_familiar_apellido_nombre text default null,
  p_familiar_edad integer default null,
  p_familiar_parentesco text default null,
  p_es_art boolean default false,
  p_familiar_dni bigint default null,
  p_aclaracion_fecha_turno text default null,
  p_familiar_edad_meses integer default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
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
  if v_persona.legajo is not null and v_persona.legajo <= 0 then
    raise exception 'El numero de legajo debe ser positivo.';
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
  if p_familiar_edad_meses is not null and (
    p_familiar_edad_meses < 0
    or p_familiar_edad_meses > 11
    or p_familiar_edad <> 0
  ) then
    raise exception 'La edad en meses debe ser de 0 a 11 y corresponder a menos de un año.';
  end if;
  if v_tipo <> 'DOMICILIO_FAMILIAR' and p_familiar_edad_meses is not null then
    raise exception 'Solo los partes por familiar pueden incluir edad en meses.';
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
    familiar_edad_meses,
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
      then p_familiar_edad_meses end,
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
  bigint, text, text, integer, text, boolean, bigint, text, integer
) from public, anon;
grant execute on function public.rpc_medicos_crear(
  bigint, text, text, integer, text, boolean, bigint, text, integer
) to authenticated;

notify pgrst, 'reload schema';
