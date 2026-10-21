-- Amplia el guardado atomico de la ficha sin duplicar el modulo de asistencia.
-- Cuando cambia el domicilio vigente, se cierra el anterior y se crea una nueva
-- version para conservar la trazabilidad del legajo.
drop function if exists public.rpc_persona_guardar(
  bigint, text, text, date, text, text, integer, bigint, bigint, boolean
);
create function public.rpc_persona_guardar(
  p_dni bigint,
  p_apellido text,
  p_nombre text,
  p_fecha_nacimiento date,
  p_email text,
  p_telefono text,
  p_legajo integer,
  p_carrera_id bigint,
  p_situacion_id bigint,
  p_horario_rotativo boolean default null,
  p_cuil bigint default null,
  p_reloj integer default null,
  p_indice text default null,
  p_sexo_id bigint default null,
  p_numero_contacto bigint default null,
  p_estado_civil text default null,
  p_fecha_ingreso date default null,
  p_formacion_estudio text default null,
  p_matricula text default null,
  p_nivel_escolaridad text default null,
  p_fecha_inicio_tarea_especifica date default null,
  p_observacion text default null,
  p_domicilio jsonb default null
)
returns void
language plpgsql
security invoker
set search_path to ''
as $function$
declare
  v_calle text;
  v_numero text;
  v_barrio text;
  v_manzana text;
  v_lote text;
  v_monoblock text;
  v_piso text;
  v_departamento text;
  v_referencias text;
  v_otros_datos text;
  v_provincia_georef_id text;
  v_provincia_nombre text;
  v_localidad_georef_id text;
  v_localidad_nombre text;
  v_tiene_domicilio boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not private.has_legajo_edit_role() then
    raise exception 'Sin permiso para editar legajos.';
  end if;

  if p_dni is null or p_dni <= 0 then
    raise exception 'DNI invalido.';
  end if;

  if nullif(btrim(p_apellido), '') is null
    or nullif(btrim(p_nombre), '') is null then
    raise exception 'Apellido y nombre son obligatorios.';
  end if;

  if p_legajo is not null and p_legajo <= 0 then
    raise exception 'Legajo invalido.';
  end if;

  if p_reloj is not null and p_reloj <= 0 then
    raise exception 'Numero de reloj invalido.';
  end if;

  if p_cuil is not null and (p_cuil < 10000000000 or p_cuil > 99999999999) then
    raise exception 'CUIL invalido: debe contener 11 digitos.';
  end if;

  if p_numero_contacto is not null and p_numero_contacto <= 0 then
    raise exception 'Numero de contacto invalido.';
  end if;

  if p_fecha_nacimiento is not null and p_fecha_nacimiento > current_date then
    raise exception 'La fecha de nacimiento no puede ser futura.';
  end if;

  if p_carrera_id is null or not exists (
    select 1 from public.carreras c where c.id = p_carrera_id
  ) then
    raise exception 'Carrera invalida.';
  end if;

  if p_situacion_id is null or not exists (
    select 1 from public.situacion_revista situacion where situacion.id = p_situacion_id
  ) then
    raise exception 'Situacion de revista invalida.';
  end if;

  if p_sexo_id is not null and not exists (
    select 1 from public.sexos sexo where sexo.id = p_sexo_id
  ) then
    raise exception 'Sexo invalido.';
  end if;

  if p_domicilio is not null and jsonb_typeof(p_domicilio) <> 'object' then
    raise exception 'Domicilio invalido.';
  end if;

  insert into public.personas as persona (
    dni, apellido, nombre, fecha_nacimiento, email, telefono, legajo,
    horario_rotativo, cuil, reloj, indice, sexo_id, numero_contacto,
    estado_civil, fecha_ingreso, formacion_estudio, matricula,
    nivel_escolaridad, fecha_inicio_tarea_especifica, observacion,
    created_by, updated_by
  )
  values (
    p_dni, btrim(p_apellido), btrim(p_nombre), p_fecha_nacimiento,
    nullif(btrim(p_email), ''), nullif(btrim(p_telefono), ''), p_legajo,
    coalesce(p_horario_rotativo, false), p_cuil, p_reloj,
    nullif(btrim(p_indice), ''), p_sexo_id, p_numero_contacto,
    nullif(btrim(p_estado_civil), ''), p_fecha_ingreso,
    nullif(btrim(p_formacion_estudio), ''), nullif(btrim(p_matricula), ''),
    nullif(btrim(p_nivel_escolaridad), ''), p_fecha_inicio_tarea_especifica,
    nullif(btrim(p_observacion), ''), (select auth.uid()), (select auth.uid())
  )
  on conflict (dni) do update
  set
    apellido = excluded.apellido,
    nombre = excluded.nombre,
    fecha_nacimiento = excluded.fecha_nacimiento,
    email = excluded.email,
    telefono = excluded.telefono,
    legajo = excluded.legajo,
    horario_rotativo = coalesce(p_horario_rotativo, persona.horario_rotativo),
    cuil = excluded.cuil,
    reloj = excluded.reloj,
    indice = excluded.indice,
    sexo_id = excluded.sexo_id,
    numero_contacto = excluded.numero_contacto,
    estado_civil = excluded.estado_civil,
    fecha_ingreso = excluded.fecha_ingreso,
    formacion_estudio = excluded.formacion_estudio,
    matricula = excluded.matricula,
    nivel_escolaridad = excluded.nivel_escolaridad,
    fecha_inicio_tarea_especifica = excluded.fecha_inicio_tarea_especifica,
    observacion = excluded.observacion,
    updated_at = now(),
    updated_by = (select auth.uid());

  insert into public.persona_carreras (dni, carrera_id)
  values (p_dni, p_carrera_id)
  on conflict (dni) do update set carrera_id = excluded.carrera_id;

  delete from public.persona_situacion_revista where dni = p_dni;

  insert into public.persona_situacion_revista (dni, situacion_id)
  values (p_dni, p_situacion_id);

  if p_domicilio is not null then
    v_calle := nullif(btrim(p_domicilio ->> 'calle'), '');
    v_numero := nullif(btrim(p_domicilio ->> 'numero'), '');
    v_barrio := nullif(btrim(p_domicilio ->> 'barrio'), '');
    v_manzana := nullif(btrim(p_domicilio ->> 'manzana'), '');
    v_lote := nullif(btrim(p_domicilio ->> 'lote'), '');
    v_monoblock := nullif(btrim(p_domicilio ->> 'monoblock'), '');
    v_piso := nullif(btrim(p_domicilio ->> 'piso'), '');
    v_departamento := nullif(btrim(p_domicilio ->> 'departamento'), '');
    v_referencias := nullif(btrim(p_domicilio ->> 'referencias'), '');
    v_otros_datos := nullif(btrim(p_domicilio ->> 'otros_datos'), '');
    v_provincia_georef_id := nullif(btrim(p_domicilio ->> 'provincia_georef_id'), '');
    v_provincia_nombre := nullif(btrim(p_domicilio ->> 'provincia_nombre'), '');
    v_localidad_georef_id := nullif(btrim(p_domicilio ->> 'localidad_georef_id'), '');
    v_localidad_nombre := nullif(btrim(p_domicilio ->> 'localidad_nombre'), '');
    v_tiene_domicilio := coalesce(
      v_calle, v_numero, v_barrio, v_manzana, v_lote, v_monoblock, v_piso,
      v_departamento, v_referencias, v_otros_datos, v_provincia_georef_id,
      v_provincia_nombre, v_localidad_georef_id, v_localidad_nombre
    ) is not null;

    if not v_tiene_domicilio then
      update public.persona_domicilios
      set vigente_hasta = current_date,
          updated_at = now(),
          updated_by = (select auth.uid())
      where persona_dni = p_dni and vigente_hasta is null;
    elsif not exists (
      select 1
      from public.persona_domicilios d
      where d.persona_dni = p_dni
        and d.vigente_hasta is null
        and (d.calle, d.numero, d.barrio, d.manzana, d.lote, d.monoblock,
             d.piso, d.departamento, d.referencias, d.otros_datos,
             d.provincia_georef_id, d.provincia_nombre,
             d.localidad_georef_id, d.localidad_nombre)
            is not distinct from
            (v_calle, v_numero, v_barrio, v_manzana, v_lote, v_monoblock,
             v_piso, v_departamento, v_referencias, v_otros_datos,
             v_provincia_georef_id, v_provincia_nombre,
             v_localidad_georef_id, v_localidad_nombre)
    ) then
      update public.persona_domicilios
      set vigente_hasta = current_date,
          updated_at = now(),
          updated_by = (select auth.uid())
      where persona_dni = p_dni and vigente_hasta is null;

      insert into public.persona_domicilios (
        persona_dni, calle, numero, barrio, manzana, lote, monoblock, piso,
        departamento, referencias, otros_datos, provincia_georef_id,
        provincia_nombre, localidad_georef_id, localidad_nombre,
        created_by, updated_by
      ) values (
        p_dni, v_calle, v_numero, v_barrio, v_manzana, v_lote, v_monoblock,
        v_piso, v_departamento, v_referencias, v_otros_datos,
        v_provincia_georef_id, v_provincia_nombre, v_localidad_georef_id,
        v_localidad_nombre, (select auth.uid()), (select auth.uid())
      );
    end if;
  end if;
end;
$function$;
revoke all on function public.rpc_persona_guardar(
  bigint, text, text, date, text, text, integer, bigint, bigint, boolean,
  bigint, integer, text, bigint, bigint, text, date, text, text, text,
  date, text, jsonb
) from public, anon;
grant execute on function public.rpc_persona_guardar(
  bigint, text, text, date, text, text, integer, bigint, bigint, boolean,
  bigint, integer, text, bigint, bigint, text, date, text, text, text,
  date, text, jsonb
) to authenticated;
notify pgrst, 'reload schema';
