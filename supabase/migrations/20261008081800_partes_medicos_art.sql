alter table public.partes_medicos
  add column if not exists es_art boolean not null default false;

alter table public.partes_medicos
  drop constraint if exists partes_medicos_art_tipo_chk;

alter table public.partes_medicos
  add constraint partes_medicos_art_tipo_chk
  check (not es_art or tipo <> 'DOMICILIO_FAMILIAR');

alter table public.partes_medicos
  add column if not exists familiar_dni bigint;

alter table public.partes_medicos
  drop constraint if exists partes_medicos_familiar_dni_chk;

alter table public.partes_medicos
  add constraint partes_medicos_familiar_dni_chk check (
    familiar_dni is null
    or (familiar_dni > 0 and tipo = 'DOMICILIO_FAMILIAR')
  );

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
  familiar_parentesco text,
  es_art boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
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
    pm.created_at
  from public.partes_medicos pm
  where pm.anulado_at is null
    and (
      p_buscar is null
      or trim(p_buscar) = ''
      or pm.dni::text ilike '%' || trim(p_buscar) || '%'
      or pm.empleado_legajo::text ilike '%' || trim(p_buscar) || '%'
      or pm.empleado_apellido ilike '%' || trim(p_buscar) || '%'
      or pm.empleado_nombre ilike '%' || trim(p_buscar) || '%'
      or coalesce(pm.familiar_apellido_nombre, '') ilike
        '%' || trim(p_buscar) || '%'
    )
  order by pm.fecha desc, pm.id desc
  limit 500;
end;
$function$;

revoke execute on function public.rpc_medicos_registros(text) from public, anon;
grant execute on function public.rpc_medicos_registros(text) to authenticated;

drop function public.rpc_medicos_crear(bigint, text, text, integer, text);

create function public.rpc_medicos_crear(
  p_dni bigint,
  p_tipo text,
  p_familiar_apellido_nombre text default null,
  p_familiar_edad integer default null,
  p_familiar_parentesco text default null,
  p_es_art boolean default false,
  p_familiar_dni bigint default null
)
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_persona public.personas%rowtype;
  v_tipo text := upper(trim(coalesce(p_tipo, '')));
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
    es_art
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
    coalesce(p_es_art, false)
  )
  returning id into v_id;

  return v_id;
end;
$function$;

revoke execute on function public.rpc_medicos_crear(bigint, text, text, integer, text, boolean, bigint)
from public, anon;
grant execute on function public.rpc_medicos_crear(bigint, text, text, integer, text, boolean, bigint)
to authenticated;

notify pgrst, 'reload schema';
