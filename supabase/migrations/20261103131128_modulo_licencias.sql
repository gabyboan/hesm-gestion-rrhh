begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

insert into public.roles(codigo, nombre) values
  ('LICENCIAS_LECTURA', 'Licencias: consultar e informar'),
  ('LICENCIAS_CARGA', 'Licencias: cargar registros'),
  ('LICENCIAS_ADM', 'Licencias: modificar y anular registros')
on conflict (codigo) do nothing;

create function public.can_licencias_read() returns boolean
language sql stable security invoker set search_path = '' as $$
  select (select auth.uid()) is not null and public.has_role_code('LICENCIAS_LECTURA');
$$;
create function public.can_licencias_create() returns boolean
language sql stable security invoker set search_path = '' as $$
  select public.can_licencias_read() and public.has_role_code('LICENCIAS_CARGA');
$$;
create function public.can_licencias_admin() returns boolean
language sql stable security invoker set search_path = '' as $$
  select public.can_licencias_read() and public.has_role_code('LICENCIAS_ADM');
$$;

create table public.licencias_tipos (
  id smallint primary key,
  nombre text not null unique
);
insert into public.licencias_tipos(id, nombre) values
  (1, 'Enf. de Corto Tratamiento'), (2, 'Enf. de LARGO Tratamiento'),
  (3, 'Cuidado de Fliar. Enfermo'), (4, 'Franco'), (5, 'Imprevisto'),
  (6, 'Lic. Anual'), (7, 'Lic. Profiláctica'), (8, 'ART - Licencia'),
  (9, 'Lic. por Estudio'), (10, 'Lic. por Capacitación'), (11, 'Lic. por Duelo'),
  (12, 'Lic. por Maternidad'), (13, 'Lic. por Paternidad'), (14, 'Lic. por Matrimonio'),
  (15, 'Lic. por Donación de Sangre'), (16, 'Lic. Gremial'), (17, 'Lic. Deportiva'),
  (18, 'Comisión'), (19, 'Día de Suspensión'), (20, 'Lic. por Personal de Riesgo'),
  (21, 'Lic Sin Goce de Haberes'), (22, 'Lic Aislamiento'),
  (23, 'Lic. por Violencia de Género'), (24, 'Paro de Colectivos'),
  (25, 'Lic. por Sintomas de Vacunación'), (26, 'Lic. Paro Legal'),
  (27, 'Falta CON Aviso'), (28, 'Falta SIN Aviso'),
  (29, 'Lic. Por Adopción/Guarda'), (30, 'Lic. Festividad Religiosa');

create table public.licencias_registros (
  id bigint generated always as identity primary key,
  -- El DNI y nombre del informe son evidencia histórica independiente de la ficha.
  dni bigint not null check (dni between 1000000 and 99999999),
  persona_dni bigint references public.personas(dni) on delete set null,
  apellido_nombre text not null check (btrim(apellido_nombre) <> ''),
  carrera text not null default '',
  situacion_revista text not null default '',
  funcion text not null default '',
  tipo_id smallint not null references public.licencias_tipos(id),
  desde date not null,
  hasta date not null,
  dias integer generated always as (hasta - desde + 1) stored,
  observacion text check (char_length(observacion) <= 2000),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  anulado_at timestamptz,
  anulado_by uuid,
  origen_archivo text,
  origen_fila integer,
  origen_datos jsonb,
  check (hasta >= desde),
  check ((origen_archivo is null) = (origen_fila is null)),
  unique (origen_archivo, origen_fila)
);
create index licencias_registros_persona_idx on public.licencias_registros(persona_dni);
create index licencias_registros_dni_fecha_idx on public.licencias_registros(dni, desde desc);
create index licencias_registros_fechas_idx on public.licencias_registros(desde desc, hasta);
create index licencias_registros_tipo_idx on public.licencias_registros(tipo_id);

create table public.licencias_importacion_pendientes (
  id bigint generated always as identity primary key,
  origen_archivo text not null,
  origen_fila integer not null,
  motivo text not null,
  datos jsonb not null,
  created_at timestamptz not null default now(),
  unique (origen_archivo, origen_fila)
);
alter table public.licencias_tipos enable row level security;
alter table public.licencias_registros enable row level security;
alter table public.licencias_importacion_pendientes enable row level security;
revoke all on public.licencias_tipos, public.licencias_registros,
  public.licencias_importacion_pendientes from public, anon, authenticated;
grant select on public.licencias_tipos, public.licencias_registros,
  public.licencias_importacion_pendientes to authenticated;
revoke all on sequence public.licencias_registros_id_seq,
  public.licencias_importacion_pendientes_id_seq from public, anon, authenticated;
create policy licencias_tipos_lectura on public.licencias_tipos
  for select to authenticated using ((select public.can_licencias_read()));
create policy licencias_registros_lectura on public.licencias_registros
  for select to authenticated using ((select public.can_licencias_read()));
create policy licencias_pendientes_lectura on public.licencias_importacion_pendientes
  for select to authenticated using ((select public.can_licencias_read()));

-- Consulta acotada del padrón sin conceder acceso a las tablas de legajos.
create function private.licencias_personas(p_buscar text default null, p_dni bigint default null)
returns table(dni bigint, apellido_nombre text, legajo integer, carrera text,
  situacion_revista text, funcion text, activo boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not public.can_licencias_read() then
    raise exception 'Sin permiso para consultar licencias.' using errcode = '42501';
  end if;
  return query
  select p.dni, btrim(p.apellido || ' ' || p.nombre), p.legajo,
    coalesce((select string_agg(c.nombre, ', ' order by c.nombre)
      from public.persona_carreras pc join public.carreras c on c.id = pc.carrera_id
      where pc.dni = p.dni), ''),
    coalesce((select string_agg(s.nombre, ', ' order by s.nombre)
      from public.persona_situacion_revista ps join public.situacion_revista s on s.id = ps.situacion_id
      where ps.dni = p.dni), ''),
    coalesce((select string_agg(f.nombre, ', ' order by f.nombre)
      from public.persona_funciones pf join public.funciones f on f.id = pf.funcion_id
      where pf.dni = p.dni), ''),
    not exists(select 1 from public.persona_inactivo pi where pi.dni = p.dni)
  from public.personas p
  where (p_dni is null or p.dni = p_dni)
    and public.busqueda_coincide(array[p.apellido, p.nombre, p.dni::text, p.legajo::text],
      public.busqueda_terminos(p_buscar))
  order by p.apellido, p.nombre, p.dni limit 100;
end;
$$;
create function public.rpc_licencias_personas(p_buscar text default null)
returns table(dni bigint, apellido_nombre text, legajo integer, carrera text,
  situacion_revista text, funcion text, activo boolean)
language sql stable security invoker set search_path = '' as $$
  select * from private.licencias_personas(p_buscar, null);
$$;

create function private.licencias_guardar(p_id bigint, p_dni bigint, p_tipo_id smallint,
  p_desde date, p_hasta date, p_observacion text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_persona record;
  v_id bigint;
  v_anterior public.licencias_registros;
begin
  if (select auth.uid()) is null or
    (p_id is null and not public.can_licencias_create()) or
    (p_id is not null and not public.can_licencias_admin()) then
    raise exception 'Sin permiso para guardar licencias.' using errcode = '42501';
  end if;
  if p_desde is null or p_hasta is null or p_hasta < p_desde then
    raise exception 'El período de la licencia es inválido.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.licencias_tipos where id = p_tipo_id) then
    raise exception 'Tipo de licencia inválido.' using errcode = '22023';
  end if;
  if p_id is not null then
    select * into v_anterior from public.licencias_registros
      where id = p_id and anulado_at is null for update;
    if not found then raise exception 'La licencia no existe o fue anulada.'; end if;
    if v_anterior.dni <> p_dni then raise exception 'No se puede cambiar la persona de una licencia.'; end if;
  end if;
  -- Serializa la comprobación de duplicados para cargas de la misma persona.
  perform 1 from public.personas where dni = p_dni for update;
  select * into v_persona from private.licencias_personas(null, p_dni);
  if not found then
    if p_id is null then raise exception 'La persona no tiene ficha. Revisá su DNI.'; end if;
  end if;
  if exists (select 1 from public.persona_inactividad_periodos pip
    where pip.persona_dni = p_dni and pip.fecha_desde <= p_hasta
      and (pip.fecha_hasta is null or pip.fecha_hasta >= p_desde))
    or exists (select 1 from public.persona_inactivo pi
      where pi.dni = p_dni and coalesce(pi.fecha, p_desde) <= p_hasta) then
    raise exception 'La persona estuvo inactiva durante el período indicado.';
  end if;
  if (p_id is null or (v_anterior.tipo_id,v_anterior.desde,v_anterior.hasta)
      is distinct from (p_tipo_id,p_desde,p_hasta)) and exists (
    select 1 from public.licencias_registros l where l.dni = p_dni
    and l.tipo_id = p_tipo_id and l.desde = p_desde and l.hasta = p_hasta
    and l.anulado_at is null and (p_id is null or l.id <> p_id)) then
    raise exception 'Ya existe una licencia del mismo tipo y período para esta persona.';
  end if;
  if p_id is null then
    insert into public.licencias_registros(dni, persona_dni, apellido_nombre, carrera,
      situacion_revista, funcion, tipo_id, desde, hasta, observacion, created_by, updated_by)
    values (p_dni, p_dni, v_persona.apellido_nombre, v_persona.carrera,
      v_persona.situacion_revista, v_persona.funcion, p_tipo_id, p_desde, p_hasta,
      nullif(btrim(p_observacion), ''), (select auth.uid()), (select auth.uid()))
    returning id into v_id;
  else
    update public.licencias_registros set tipo_id = p_tipo_id, desde = p_desde,
      hasta = p_hasta, observacion = nullif(btrim(p_observacion), ''),
      updated_at = now(), updated_by = (select auth.uid()) where id = p_id returning id into v_id;
  end if;
  return v_id;
end;
$$;
create function public.rpc_licencias_guardar(p_id bigint, p_dni bigint, p_tipo_id smallint,
  p_desde date, p_hasta date, p_observacion text default null)
returns bigint language sql security invoker set search_path = '' as $$
  select private.licencias_guardar(p_id, p_dni, p_tipo_id, p_desde, p_hasta, p_observacion);
$$;
create function private.licencias_anular(p_id bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_filas integer;
begin
  if (select auth.uid()) is null or not public.can_licencias_admin() then
    raise exception 'Sin permiso para anular licencias.' using errcode = '42501';
  end if;
  update public.licencias_registros set anulado_at = now(), anulado_by = (select auth.uid()),
    updated_at = now(), updated_by = (select auth.uid()) where id = p_id and anulado_at is null;
  get diagnostics v_filas = row_count;
  return v_filas = 1;
end;
$$;
create function public.rpc_licencias_anular(p_id bigint) returns boolean
language sql security invoker set search_path = '' as $$ select private.licencias_anular(p_id); $$;

revoke all on function public.can_licencias_read(), public.can_licencias_create(),
  public.can_licencias_admin(), public.rpc_licencias_personas(text),
  public.rpc_licencias_guardar(bigint,bigint,smallint,date,date,text), public.rpc_licencias_anular(bigint),
  private.licencias_personas(text,bigint), private.licencias_guardar(bigint,bigint,smallint,date,date,text),
  private.licencias_anular(bigint) from public, anon, authenticated;
grant execute on function public.can_licencias_read(), public.can_licencias_create(),
  public.can_licencias_admin(), public.rpc_licencias_personas(text),
  public.rpc_licencias_guardar(bigint,bigint,smallint,date,date,text), public.rpc_licencias_anular(bigint),
  private.licencias_personas(text,bigint), private.licencias_guardar(bigint,bigint,smallint,date,date,text),
  private.licencias_anular(bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
