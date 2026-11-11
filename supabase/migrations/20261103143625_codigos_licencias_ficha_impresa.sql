begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- Código operativo provisto por el usuario; el ID interno no es el código.
alter table public.licencias_tipos
  add column codigo text unique check (codigo ~ '^[0-9]{2}$'),
  add column columna_ficha text check (columna_ficha in (
    'ANUAL','ENFERMEDAD','PROFILACTICA','FRANCO','MATERNIDAD','ESTUDIO','ART8','FALTA_CA','FALTA_SA'
  )),
  add column habilitado_para_carga boolean not null default false;

-- Los tipos anteriores se conservan para que el Excel apartado mantenga su significado.
insert into public.licencias_tipos(id,codigo,nombre,columna_ficha,habilitado_para_carga)
select (100+codigo::integer)::smallint,codigo,nombre,columna,true from (values
 ('01','Licencia Anual Ordinaria (Vacaciones)','ANUAL'),
 ('02','Licencia Profiláctica','PROFILACTICA'),
 ('03','Licencia por Salud Mental','PROFILACTICA'),
 ('04','Enfermedad del Agente (Corto tratamiento, hasta 20 días)','ENFERMEDAD'),
 ('05','Enfermedad del Agente (+20 días con goce de sueldo)','ENFERMEDAD'),
 ('06','Enfermedad del Agente (+20 días sin goce de sueldo)','ENFERMEDAD'),
 ('07','Enfermedad de Tratamiento Prolongado','ENFERMEDAD'),
 ('08','Tratamiento Prolongado (+1 año sin goce de sueldo)','ENFERMEDAD'),
 ('09','Tratamiento Prolongado (+1 año con goce de sueldo)','ENFERMEDAD'),
 ('10','Atención de Familiar Enfermo (Hasta 5 días)','ENFERMEDAD'),
 ('11','Atención de Familiar Enfermo (Extensión de +5 días)','ENFERMEDAD'),
 ('12','Enfermedad por Accidente de Trabajo o Acto de Servicio','ENFERMEDAD'),
 ('13','Licencia por Prenatal','MATERNIDAD'),
 ('14','Licencia por Maternidad','MATERNIDAD'),
 ('15','Licencia por Nacimiento (Paternidad / Co-parentalidad)',null),
 ('16','Licencia por Matrimonio del Agente',null),
 ('17','Licencia por Matrimonio de Hijo',null),
 ('18','Fallecimiento de Cónyuge, Hijos o Padres',null),
 ('19','Fallecimiento de Hermanos',null),
 ('20','Fallecimiento de Abuelos o Nietos',null),
 ('21','Fallecimiento de Tíos, Primos o Suegros',null),
 ('22','Licencia por Examen (Secundario, terciario o universitario)','ESTUDIO'),
 ('23','Examen de Postgrado / Especializaciones Médicas','ESTUDIO'),
 ('24','Razones Particulares (Con goce de haberes / Permisos breves)',null),
 ('25','Razones Particulares (Sin goce de haberes / Licencia prolongada)',null),
 ('26','Licencia por Donación de Sangre',null),
 ('27','Licencia por Mudanza',null),
 ('43','Imprevistos (Fuerza mayor o emergencias no planificadas)','ART8'),
 ('59','Designación en Cargo Técnico o de Mayor Jerarquía',null),
 ('60','Franco Compensatorio','FRANCO'),
 ('61','Comisión de Servicio',null),
 ('62','Falta con Aviso (Hasta 2 días)','FALTA_CA'),
 ('63','Falta con Aviso (Más de 2 días)','FALTA_CA'),
 ('64','Falta sin Aviso (Hasta 2 días)','FALTA_SA'),
 ('65','Falta sin Aviso (Hasta 10 días)','FALTA_SA'),
 ('66','Suspensión por Pena Disciplinaria',null),
 ('67','Suspensión por Sumario Administrativo',null),
 ('70','Licencia Gremial',null),
 ('98','Imprevisto Operativo / Urgencia','ART8')
) as catalogo(codigo,nombre,columna);

alter table public.licencias_registros
  add column dni_familiar bigint check (dni_familiar between 1 and 99999999),
  add column numero_orden integer check (numero_orden > 0),
  add column cantidad_ficha text check (char_length(cantidad_ficha)<=12);

create function private.licencias_validar_catalogo() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.origen_archivo is null and
    (tg_op='INSERT' or new.tipo_id is distinct from old.tipo_id) and not exists (
      select 1 from public.licencias_tipos where id=new.tipo_id and habilitado_para_carga
    ) then
    raise exception 'Seleccioná un código de licencia habilitado.' using errcode='22023';
  end if;
  return new;
end;
$$;
revoke all on function private.licencias_validar_catalogo() from public,anon,authenticated;
create trigger licencias_validar_catalogo before insert or update of tipo_id
  on public.licencias_registros for each row execute function private.licencias_validar_catalogo();

-- La firma anterior sigue disponible y preserva los nuevos datos al editar.
create function private.licencias_guardar_con_datos(p_id bigint,p_dni bigint,p_tipo_id smallint,
  p_desde date,p_hasta date,p_observacion text,p_dni_familiar bigint,p_numero_orden integer,p_cantidad_ficha text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
  if (select auth.uid()) is null or
    (p_id is null and not public.can_licencias_create()) or
    (p_id is not null and not public.can_licencias_admin()) then
    raise exception 'Sin permiso para guardar licencias.' using errcode='42501';
  end if;
  if p_dni_familiar is not null and (p_dni_familiar<1 or p_dni_familiar>99999999) then
    raise exception 'DNI del familiar inválido.' using errcode='22023';
  end if;
  if p_numero_orden is not null and p_numero_orden<1 then
    raise exception 'Número de orden inválido.' using errcode='22023';
  end if;
  if char_length(p_cantidad_ficha)>12 then
    raise exception 'La cantidad en ficha admite hasta 12 caracteres.' using errcode='22023';
  end if;
  v_id := private.licencias_guardar(p_id,p_dni,p_tipo_id,p_desde,p_hasta,p_observacion);
  update public.licencias_registros set dni_familiar=p_dni_familiar,numero_orden=p_numero_orden,
    cantidad_ficha=nullif(btrim(p_cantidad_ficha),'') where id=v_id;
  return v_id;
end;
$$;
create function public.rpc_licencias_guardar_con_datos(p_id bigint,p_dni bigint,p_tipo_id smallint,
  p_desde date,p_hasta date,p_observacion text,p_dni_familiar bigint,p_numero_orden integer,p_cantidad_ficha text default null)
returns bigint language sql security invoker set search_path = '' as $$
  select private.licencias_guardar_con_datos(p_id,p_dni,p_tipo_id,p_desde,p_hasta,p_observacion,p_dni_familiar,p_numero_orden,p_cantidad_ficha);
$$;
revoke all on function private.licencias_guardar_con_datos(bigint,bigint,smallint,date,date,text,bigint,integer,text),
  public.rpc_licencias_guardar_con_datos(bigint,bigint,smallint,date,date,text,bigint,integer,text)
  from public,anon,authenticated;
grant execute on function private.licencias_guardar_con_datos(bigint,bigint,smallint,date,date,text,bigint,integer,text),
  public.rpc_licencias_guardar_con_datos(bigint,bigint,smallint,date,date,text,bigint,integer,text)
  to authenticated;
-- Regla indicada por el usuario: tres cargas de Art. 8 por persona y año,
-- en orden de carga: 43, 98, 98. Una carga puede abarcar varios días.
create function private.licencias_ordenar_art8() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_scope record;v_total integer;v_43 smallint;v_98 smallint;
begin
  if pg_trigger_depth()>1 then return new; end if;
  if not new.importacion_confirmada and (tg_op='INSERT' or not old.importacion_confirmada) then return new; end if;
  if not exists(select 1 from public.licencias_tipos where codigo in('43','98')
    and (id=new.tipo_id or (tg_op='UPDATE' and id=old.tipo_id))) then return new; end if;
  select id into v_43 from public.licencias_tipos where codigo='43';
  select id into v_98 from public.licencias_tipos where codigo='98';
  for v_scope in select distinct dni,anio from (values
    (new.dni,extract(year from new.desde)::integer),
    (case when tg_op='UPDATE' then old.dni end,case when tg_op='UPDATE' then extract(year from old.desde)::integer end)
  ) s(dni,anio) where dni is not null order by dni,anio loop
    perform 1 from public.personas where dni=v_scope.dni for update;
    select count(*) into v_total from public.licencias_registros l
    where l.dni=v_scope.dni and l.importacion_confirmada and l.anulado_at is null
      and l.tipo_id in(v_43,v_98) and l.desde>=make_date(v_scope.anio,1,1) and l.desde<make_date(v_scope.anio+1,1,1);
    if v_total>3 then raise exception 'Art. 8 permite tres cargas por persona y año: 43, 98, 98.' using errcode='22023'; end if;
    with ordenadas as (
      select l.id,case when row_number() over(order by l.id)=1 then v_43 else v_98 end as tipo_correcto
      from public.licencias_registros l where l.dni=v_scope.dni and l.importacion_confirmada and l.anulado_at is null
        and l.tipo_id in(v_43,v_98) and l.desde>=make_date(v_scope.anio,1,1) and l.desde<make_date(v_scope.anio+1,1,1)
    ) update public.licencias_registros l set tipo_id=o.tipo_correcto,
      updated_at=now(),updated_by=coalesce((select auth.uid()),l.updated_by)
    from ordenadas o where l.id=o.id and l.tipo_id<>o.tipo_correcto;
  end loop;
  return new;
end;
$$;
revoke all on function private.licencias_ordenar_art8() from public,anon,authenticated;
create trigger licencias_ordenar_art8 after insert or update of tipo_id,desde,anulado_at,importacion_confirmada
  on public.licencias_registros for each row execute function private.licencias_ordenar_art8();

create or replace function private.licencias_guardar(p_id bigint, p_dni bigint, p_tipo_id smallint,
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
  if p_desde is null or p_hasta is null or p_hasta < p_desde or p_desde < date '2026-01-01' then
    raise exception 'El período de la licencia es inválido.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.licencias_tipos where id = p_tipo_id) then
    raise exception 'Tipo de licencia inválido.' using errcode = '22023';
  end if;
  -- Toda escritura toma primero el bloqueo de la persona.
  perform 1 from public.personas where dni = p_dni for update;
  if p_id is not null then
    select * into v_anterior from public.licencias_registros
      where id = p_id and anulado_at is null and importacion_confirmada for update;
    if not found then raise exception 'La licencia no existe o fue anulada.'; end if;
    if v_anterior.dni <> p_dni then raise exception 'No se puede cambiar la persona de una licencia.'; end if;
  end if;
  -- Serializa la comprobación de duplicados para cargas de la misma persona.
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
    and (l.tipo_id = p_tipo_id or (
      exists(select 1 from public.licencias_tipos where id=p_tipo_id and codigo in('43','98'))
      and exists(select 1 from public.licencias_tipos where id=l.tipo_id and codigo in('43','98'))))
    and l.desde = p_desde and l.hasta = p_hasta
    and l.importacion_confirmada and l.anulado_at is null and (p_id is null or l.id <> p_id)) then
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

create or replace function private.licencias_anular(p_id bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_filas integer; v_dni bigint;
begin
  if (select auth.uid()) is null or not public.can_licencias_admin() then
    raise exception 'Sin permiso para anular licencias.' using errcode = '42501';
  end if;
  select dni into v_dni from public.licencias_registros where id=p_id and importacion_confirmada;
  perform 1 from public.personas where dni=v_dni for update;
  update public.licencias_registros set anulado_at = now(), anulado_by = (select auth.uid()),
    updated_at = now(), updated_by = (select auth.uid()) where id = p_id and anulado_at is null and importacion_confirmada;
  get diagnostics v_filas = row_count;
  return v_filas = 1;
end;
$$;

notify pgrst,'reload schema';
commit;
