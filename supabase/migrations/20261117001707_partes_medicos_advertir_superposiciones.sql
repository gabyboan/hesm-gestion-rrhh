begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- Los duplicados y las superposiciones se bloquean sin excepción por confirmación.

-- Conserva la emisión, el QR, el domicilio y las validaciones originales,
-- cerrando el acceso directo a las implementaciones sin comprobación de fechas.
alter function public.rpc_medicos_crear(bigint,text,text,integer,text,boolean,bigint,text,integer)
  set schema private;
alter function private.rpc_medicos_crear(bigint,text,text,integer,text,boolean,bigint,text,integer)
  rename to medicos_crear_base;
alter function private.medicos_control_guardar(text,date,integer,text,text,integer,text)
  rename to medicos_control_guardar_base;
revoke all on function private.medicos_crear_base(bigint,text,text,integer,text,boolean,bigint,text,integer),
  private.medicos_control_guardar_base(text,date,integer,text,text,integer,text)
  from public, anon, authenticated;
drop function public.rpc_medicos_control_guardar(text,date,integer,text,text,integer,text);

create function private.medicos_conflictos(p_dni bigint, p_desde date, p_hasta date,
  p_tipo text, p_es_art boolean, p_familiar_dni bigint, p_familiar_nombre text,
  p_excluir_id bigint default null)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', pm.id, 'tipo', pm.tipo, 'es_art', pm.es_art,
    'familiar', pm.familiar_apellido_nombre,
    'fecha_desde', case when c.dias_aprobados > 0 and
      c.fecha_desde <= p_hasta and c.fecha_hasta >= p_desde then c.fecha_desde else pm.fecha end,
    'fecha_hasta', case when c.dias_aprobados > 0 and
      c.fecha_desde <= p_hasta and c.fecha_hasta >= p_desde then c.fecha_hasta else pm.fecha end,
    'version', coalesce(c.version, 0),
    'duplicado', pm.tipo = p_tipo and pm.es_art = p_es_art and
      (p_tipo <> 'DOMICILIO_FAMILIAR' or
        (case when pm.familiar_dni is not null and p_familiar_dni is not null
          then pm.familiar_dni = p_familiar_dni
          else lower(btrim(coalesce(pm.familiar_apellido_nombre, ''))) =
            lower(btrim(coalesce(p_familiar_nombre, ''))) end)) and
      ((p_desde = p_hasta and pm.fecha = p_desde) or
        (c.dias_aprobados > 0 and c.fecha_desde = p_desde and c.fecha_hasta = p_hasta))
  ) order by pm.id), '[]'::jsonb)
  from public.partes_medicos pm
  left join lateral (
    select control.version, control.fecha_desde, control.fecha_hasta, control.dias_aprobados
    from public.partes_medicos_controles control
    where control.parte_id = pm.id order by control.version desc limit 1
  ) c on true
  where pm.dni = p_dni and pm.anulado_at is null and pm.id is distinct from p_excluir_id
    and ((pm.fecha between p_desde and p_hasta) or
      (c.dias_aprobados > 0 and c.fecha_desde <= p_hasta and c.fecha_hasta >= p_desde));
$$;

create function private.medicos_exigir_sin_conflictos(p_conflictos jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if jsonb_array_length(p_conflictos) > 0 then
    raise exception 'Hay partes médicos duplicados o con fechas superpuestas.'
      using errcode = 'PMP01', detail = p_conflictos::text;
  end if;
end;
$$;

create function private.medicos_crear_con_validacion(p_datos jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_dni bigint := (p_datos->>'dni')::bigint;
  v_tipo text := upper(btrim(coalesce(p_datos->>'tipo', '')));
  v_fecha date := timezone('America/Argentina/Buenos_Aires', now())::date;
  v_conflictos jsonb;
  v_id bigint;
begin
  if (select auth.uid()) is null or not public.can_medicos_create() then
    raise exception 'Sin permiso para emitir partes médicos.' using errcode = '42501';
  end if;
  perform private.exigir_mfa_si_activado();
  perform private.gestion_sesion_exigir();
  -- Emisiones y devoluciones de una persona se comprueban en el mismo orden.
  perform 1 from public.personas where dni = v_dni for update;
  v_conflictos := private.medicos_conflictos(v_dni, v_fecha, v_fecha, v_tipo,
    coalesce((p_datos->>'es_art')::boolean, false),
    (p_datos->>'familiar_dni')::bigint, p_datos->>'familiar_apellido_nombre');
  perform private.medicos_exigir_sin_conflictos(v_conflictos);
  v_id := private.medicos_crear_base(v_dni, v_tipo,
    p_datos->>'familiar_apellido_nombre', (p_datos->>'familiar_edad')::integer,
    p_datos->>'familiar_parentesco', (p_datos->>'es_art')::boolean,
    (p_datos->>'familiar_dni')::bigint, p_datos->>'aclaracion_fecha_turno',
    (p_datos->>'familiar_edad_meses')::integer);
  return v_id;
end;
$$;

create function public.rpc_medicos_crear(p_dni bigint, p_tipo text,
  p_familiar_apellido_nombre text default null, p_familiar_edad integer default null,
  p_familiar_parentesco text default null, p_es_art boolean default false,
  p_familiar_dni bigint default null, p_aclaracion_fecha_turno text default null,
  p_familiar_edad_meses integer default null)
returns bigint language sql security invoker set search_path = '' as $$
  select private.medicos_crear_con_validacion(jsonb_build_object(
    'dni',p_dni, 'tipo',p_tipo, 'familiar_apellido_nombre',p_familiar_apellido_nombre,
    'familiar_edad',p_familiar_edad, 'familiar_parentesco',p_familiar_parentesco,
    'es_art',p_es_art, 'familiar_dni',p_familiar_dni,
    'aclaracion_fecha_turno',p_aclaracion_fecha_turno, 'familiar_edad_meses',p_familiar_edad_meses
  ));
$$;

create function private.medicos_control_guardar(p_codigo text, p_fecha_desde date,
  p_dias_aprobados integer, p_medico_nombre text, p_medico_matricula text,
  p_version_esperada integer, p_motivo_rectificacion text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_parte public.partes_medicos%rowtype;
  v_version integer;
  v_conflictos jsonb := '[]'::jsonb;
  v_control jsonb;
begin
  if (select auth.uid()) is null or not public.can_medicos_control() then
    raise exception 'Sin permiso para controlar devoluciones.' using errcode = '42501';
  end if;
  perform private.exigir_mfa_si_activado();
  perform private.gestion_sesion_exigir();
  select * into v_parte from public.partes_medicos where codigo_qr = upper(p_codigo);
  if not found then raise exception 'Parte medico no encontrado.'; end if;
  perform 1 from public.personas where dni = v_parte.dni for update;
  -- Respeta la versión consultada antes de comprobar las coincidencias.
  select coalesce(max(version), 0) into v_version
    from public.partes_medicos_controles where parte_id = v_parte.id;
  if p_version_esperada is null or p_version_esperada <> v_version then
    raise exception 'El control cambio. Volve a consultar el parte antes de guardar.';
  end if;
  if v_version > 0 and not public.can_medicos_admin() then
    raise exception 'Solo un administrador de medicos puede rectificar un control.';
  end if;
  if p_fecha_desde is null or p_dias_aprobados is null or p_dias_aprobados not between 0 and 3650 then
    raise exception 'Completa la fecha de inicio y los dias aprobados (0 a 3650).';
  end if;
  if p_dias_aprobados > 0 then
    v_conflictos := private.medicos_conflictos(v_parte.dni, p_fecha_desde,
      p_fecha_desde + p_dias_aprobados - 1, v_parte.tipo, v_parte.es_art,
      v_parte.familiar_dni, v_parte.familiar_apellido_nombre, v_parte.id);
  end if;
  perform private.medicos_exigir_sin_conflictos(v_conflictos);
  v_control := private.medicos_control_guardar_base(p_codigo, p_fecha_desde,
    p_dias_aprobados, p_medico_nombre, p_medico_matricula, p_version_esperada, p_motivo_rectificacion);
  return v_control;
end;
$$;

create function public.rpc_medicos_control_guardar(p_codigo text, p_fecha_desde date,
  p_dias_aprobados integer, p_medico_nombre text, p_medico_matricula text,
  p_version_esperada integer, p_motivo_rectificacion text default null)
returns jsonb language sql security invoker set search_path = '' as $$
  select private.medicos_control_guardar(p_codigo, p_fecha_desde, p_dias_aprobados,
    p_medico_nombre, p_medico_matricula, p_version_esperada, p_motivo_rectificacion);
$$;

revoke all on function private.medicos_conflictos(bigint,date,date,text,boolean,bigint,text,bigint),
  private.medicos_exigir_sin_conflictos(jsonb), private.medicos_crear_con_validacion(jsonb),
  private.medicos_control_guardar(text,date,integer,text,text,integer,text),
  public.rpc_medicos_crear(bigint,text,text,integer,text,boolean,bigint,text,integer),
  public.rpc_medicos_control_guardar(text,date,integer,text,text,integer,text)
  from public, anon, authenticated;
grant execute on function private.medicos_crear_con_validacion(jsonb),
  private.medicos_control_guardar(text,date,integer,text,text,integer,text),
  public.rpc_medicos_crear(bigint,text,text,integer,text,boolean,bigint,text,integer),
  public.rpc_medicos_control_guardar(text,date,integer,text,text,integer,text) to authenticated;

notify pgrst, 'reload schema';
commit;
