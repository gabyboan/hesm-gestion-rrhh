\set ON_ERROR_STOP on
-- Solo una restauracion local sin puertos. Todas las filas de prueba se revierten.
do $$ begin
  if current_database()<>'hesm_restore_test' or inet_server_addr() is not null then
    raise exception 'Se requiere hesm_restore_test aislada por socket local.';
  end if;
end; $$;

begin;
set local timezone='UTC';
set local search_path=pg_catalog;

-- Ejercitar las tres funciones de permiso usando la relacion Auth-perfil existente.
-- No se imprimen identidades ni datos de empleados.
do $roles$
declare caso record; uid uuid; puede_leer boolean; puede_escribir boolean; puede_borrar boolean;
begin
  for caso in select * from (values
    ('sin_identidad',null::text,false,false,false),
    ('sin_rol','',false,false,false),
    ('carga','HORAS_CARGA',true,true,false),
    ('administracion','HORAS_CARGA_ADM',true,true,true)
  ) t(nombre,codigo,leer,escribir,borrar) loop
    uid=null;
    if caso.nombre='sin_rol' then
      uid='00000000-0000-4000-8000-000000000099';
      if exists(select 1 from public.usuarios where auth_user_id=uid or id=uid) then
        raise exception 'El UUID ficticio no esta libre.';
      end if;
    elsif caso.codigo is not null and caso.codigo<>'' then
      select u.auth_user_id into uid from public.usuarios u
      join public.usuario_roles ur on ur.usuario_id=u.id
      join public.roles r on r.id=ur.rol_id where r.codigo=caso.codigo
        and (caso.nombre<>'carga' or not exists(
          select 1 from public.usuario_roles ur2 join public.roles r2 on r2.id=ur2.rol_id
          where ur2.usuario_id=u.id and r2.codigo='HORAS_CARGA_ADM')) limit 1;
      if uid is null then raise exception 'Falta un perfil para el caso %',caso.nombre; end if;
    end if;
    perform set_config('request.jwt.claim.sub',coalesce(uid::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',uid)::text,true);
    execute 'set local role authenticated';
    select public.can_horas_read(),public.can_horas_write(),public.can_horas_delete()
      into puede_leer,puede_escribir,puede_borrar;
    execute 'reset role';
    if puede_leer is distinct from caso.leer or puede_escribir is distinct from caso.escribir
      or puede_borrar is distinct from caso.borrar then
      raise exception 'Cambio de permisos en el caso %',caso.nombre;
    end if;
  end loop;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
end;
$roles$;

do $calculo$
declare caso record; resultado integer;
begin
  for caso in select * from (values
    ('08:00'::time,'14:00'::time,360),('08:00'::time,'09:30'::time,90),
    ('08:00'::time,'08:00'::time,0),('09:00'::time,'08:00'::time,-60),
    ('23:00'::time,'01:00'::time,-1320),(null::time,'08:00'::time,null::integer)
  ) t(desde,hasta,minutos) loop
    resultado=public.francos_horario_minutos(caso.desde,caso.hasta);
    if resultado is distinct from caso.minutos then raise exception 'Cambio en calculo de horarios.'; end if;
  end loop;
end;
$calculo$;

-- Persona ficticia creada solamente dentro de esta transaccion aislada.
insert into public.personas(dni,apellido,nombre) values(99999997,'FIXTURE','SEARCH PATH');
insert into public.persona_carreras(dni,carrera_id) values(99999997,1);
do $$ begin
  perform set_config('request.jwt.claim.sub',
    (select id::text from auth.users order by id limit 1),true);
end; $$;

do $francos$
declare registro public.francos_movimientos; horario public.francos_horarios_persona;
begin
  insert into public.francos_movimientos(dni,carrera_id,fecha,periodo,minutos,motivo,observacion,usuario_carga)
    values(99999997,1,'2099-02-15','2000-01-01',30,'  motivo ficticio  ','   ',auth.uid())
    returning * into registro;
  if registro.periodo<>'2099-02-01'::date or registro.motivo<>'motivo ficticio'
    or registro.observacion is not null or registro.created_at is null or registro.updated_at is null then
    raise exception 'Cambio en normalizacion INSERT de Francos.';
  end if;
  update public.francos_movimientos set fecha='2099-03-15',motivo='  actualizado  ',anulado=true
    where id=registro.id returning * into registro;
  if registro.periodo<>'2099-03-01'::date or registro.motivo<>'actualizado'
    or registro.anulado_at is null then raise exception 'Cambio en normalizacion UPDATE de Francos.'; end if;

  insert into public.francos_horarios_persona(dni,carrera_id,dia_semana,hora_desde,hora_hasta,usuario_carga)
    values(99999997,1,1,'08:00','14:00',auth.uid()) returning * into horario;
  if horario.created_at is null or horario.updated_at is null then
    raise exception 'Faltan fechas del horario.';
  end if;
  update public.francos_horarios_persona set hora_hasta='13:30' where id=horario.id returning * into horario;
  if public.francos_horario_minutos(horario.hora_desde,horario.hora_hasta)<>330 then
    raise exception 'Cambio en UPDATE del horario.';
  end if;
  begin
    insert into public.francos_horarios_persona(dni,carrera_id,dia_semana,hora_desde,hora_hasta,usuario_carga)
      values(99999997,1,2,'08:00:01','14:00',auth.uid());
    raise exception using errcode='ZX001',message='Se aceptaron segundos.';
  exception when raise_exception then null; end;
  begin
    insert into public.francos_horarios_persona(dni,carrera_id,dia_semana,hora_desde,hora_hasta,usuario_carga)
      values(99999997,1,2,'08:00','14:00:01',auth.uid());
    raise exception using errcode='ZX001',message='Se aceptaron segundos en hora_hasta.';
  exception when raise_exception then null; end;
end;
$francos$;

do $horas$
declare registro public.horas_registros; ids bigint[]='{}'; i integer; dato record;
begin
  -- Tres horas mensuales: 120 aplicadas, luego 60 aplicadas + 60 excedidas.
  insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
    values(99999997,1,'2099-04-01','2000-01-01','PARTICULAR',120,auth.uid()) returning * into registro;
  if registro.periodo<>'2099-04-01'::date or registro.minutos_aplicados<>120
    or registro.minutos_excedidos<>0 or registro.excedido then raise exception 'Primer particular incorrecto.'; end if;
  ids=array_append(ids,registro.id);
  insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
    values(99999997,1,'2099-04-02','2000-01-01','PARTICULAR',120,auth.uid()) returning * into registro;
  if registro.minutos_aplicados<>60 or registro.minutos_excedidos<>60 or not registro.excedido then
    raise exception 'Reparto aplicado/excedido incorrecto.';
  end if;
  for i in 3..6 loop
    insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
      values(99999997,1,'2099-04-01'::date+i,'2000-01-01','PARTICULAR',30,auth.uid()) returning * into registro;
    if registro.minutos_aplicados<>0 or registro.minutos_excedidos<>30 or not registro.excedido then
      raise exception 'Excedente posterior incorrecto.';
    end if;
  end loop;
  begin
    insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
      values(99999997,1,'2099-04-15','2000-01-01','PARTICULAR',30,auth.uid());
    raise exception using errcode='ZX001',message='Se acepto un septimo particular.';
  exception when raise_exception then null; end;

  insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
    values(99999997,1,'2099-04-18','2000-01-01','OFICIAL',600,auth.uid()) returning * into registro;
  if registro.minutos_aplicados<>0 or registro.minutos_excedidos<>0 or registro.excedido then
    raise exception 'OFICIAL consumio cupo.';
  end if;
  insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
    values(99999997,1,'2099-04-19','2000-01-01','ENFERMEDAD',null,auth.uid()) returning * into registro;
  if registro.minutos_aplicados<>0 or registro.minutos_excedidos<>0 or registro.excedido then
    raise exception 'ENFERMEDAD consumio cupo.';
  end if;
  begin
    insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
      values(99999997,1,'2099-04-20','2000-01-01','ENFERMEDAD',null,auth.uid());
    raise exception using errcode='ZX001',message='Se acepto segunda enfermedad mensual.';
  exception when raise_exception then null; end;

  -- Cada columna derivada debe seguir protegida; comprobacion antes de triggers de recalculo.
  for dato in select * from (values
    ('periodo',quote_literal('2000-01-01')||'::date'),('minutos_aplicados','999'),
    ('minutos_excedidos','999'),('excedido','true')
  ) t(columna,valor) loop
    begin
      execute format('update public.horas_registros set %I=%s where id=$1',dato.columna,dato.valor) using ids[1];
      raise exception using errcode='ZX001',message='Se permitio cambiar una columna derivada.';
    exception when raise_exception then null; end;
  end loop;
  update public.horas_registros set minutos=minutos where id=ids[1];
end;
$horas$;

select jsonb_build_object('roles_horas',4,'calculos_horario',6,'triggers',4,
 'particulares_cupo_y_maximo',true,'enfermedad_unica',true,'oficial_sin_cupo',true,
 'columnas_derivadas_protegidas',4,'datos_ficticios_revertidos_al_final',true) as pruebas;
rollback;
