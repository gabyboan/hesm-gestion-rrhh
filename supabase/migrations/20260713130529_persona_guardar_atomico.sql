-- RISaMC es una carrera y las situaciones de revista se limitan al selector acordado.
update public.situacion_revista
set nombre = 'Residente'
where lower(trim(nombre)) = 'risamc';
insert into public.carreras (nombre)
select 'RISaMC'
where not exists (
  select 1
  from public.carreras
  where lower(trim(nombre)) = 'risamc'
);
insert into public.situacion_revista (nombre)
select nuevas.nombre
from (
  values
    ('Residente'::text),
    ('Suplente Ordinario - Licencias Varias'::text),
    ('Suplente Ordinario - Cargo Vacante'::text)
) as nuevas(nombre)
where not exists (
  select 1
  from public.situacion_revista actual
  where actual.nombre = nuevas.nombre
);
-- Guarda los datos basicos, la carrera y todas las situaciones de revista
-- como una unica operacion atomica. SECURITY INVOKER conserva las politicas
-- RLS existentes para el usuario autenticado que invoca el RPC.
create or replace function public.rpc_persona_guardar(
  p_dni bigint,
  p_apellido text,
  p_nombre text,
  p_fecha_nacimiento date,
  p_email text,
  p_telefono text,
  p_legajo integer,
  p_carrera_id bigint,
  p_situacion_id bigint,
  p_horario_rotativo boolean default null
)
returns void
language plpgsql
security invoker
set search_path to ''
as $function$
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

  if p_fecha_nacimiento is not null and p_fecha_nacimiento > current_date then
    raise exception 'La fecha de nacimiento no puede ser futura.';
  end if;

  if p_carrera_id is null or not exists (
    select 1
    from public.carreras c
    where c.id = p_carrera_id
  ) then
    raise exception 'Carrera invalida.';
  end if;

  if p_situacion_id is null or not exists (
    select 1
    from public.situacion_revista situacion
    where situacion.id = p_situacion_id
      and situacion.nombre in (
        'Residente',
        'Suplente Ordinario - Licencias Varias',
        'Suplente Ordinario - Cargo Vacante'
      )
  ) then
    raise exception 'Situacion de revista invalida.';
  end if;

  insert into public.personas as persona (
    dni,
    apellido,
    nombre,
    fecha_nacimiento,
    email,
    telefono,
    legajo,
    horario_rotativo,
    created_by,
    updated_by
  )
  values (
    p_dni,
    btrim(p_apellido),
    btrim(p_nombre),
    p_fecha_nacimiento,
    nullif(btrim(p_email), ''),
    nullif(btrim(p_telefono), ''),
    p_legajo,
    coalesce(p_horario_rotativo, false),
    (select auth.uid()),
    (select auth.uid())
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
    updated_at = now(),
    updated_by = (select auth.uid());

  insert into public.persona_carreras (dni, carrera_id)
  values (p_dni, p_carrera_id)
  on conflict (dni) do update
  set carrera_id = excluded.carrera_id;

  delete from public.persona_situacion_revista
  where dni = p_dni;

  insert into public.persona_situacion_revista (dni, situacion_id)
  values (p_dni, p_situacion_id);
end;
$function$;
revoke all on function public.rpc_persona_guardar(
  bigint,
  text,
  text,
  date,
  text,
  text,
  integer,
  bigint,
  bigint,
  boolean
) from public, anon;
grant execute on function public.rpc_persona_guardar(
  bigint,
  text,
  text,
  date,
  text,
  text,
  integer,
  bigint,
  bigint,
  boolean
) to authenticated;
notify pgrst, 'reload schema';
