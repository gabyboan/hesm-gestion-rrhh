\set ON_ERROR_STOP on
-- Exclusivo de una restauracion local; todas las escrituras ficticias se revierten.
do $$ begin
 if current_database()<>'hesm_restore_test' or inet_server_addr() is not null then
  raise exception 'Solo hesm_restore_test aislada por socket.';end if;
end;$$;
begin;
set local search_path=pg_catalog;
do $fixture$ declare u record;begin
 select id,auth_user_id into u from public.usuarios where auth_user_id is not null order by id limit 1;
 if u.id is null then raise exception 'Falta perfil fixture.';end if;
 insert into public.usuario_roles(usuario_id,rol_id)
 select u.id,r.id from public.roles r where
  (r.id in(19,20) or r.ver_todo or r.codigo in('HORAS_CARGA','HORAS_CARGA_ADM',
   'FRANCOS_LECTURA','FRANCOS_CARGA','FRANCOS_ADM','MEDICOS_LECTURA','MEDICOS_ESCRITURA',
   'MEDICOS_ADM','MEDICOS_CONTROL','IMPREVISTOS_LECTURA','IMPREVISTOS_CARGA','IMPREVISTOS_ADM'))
  and not exists(select 1 from public.usuario_roles ur where ur.usuario_id=u.id and ur.rol_id=r.id);
 perform set_config('request.jwt.claim.sub',u.auth_user_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u.auth_user_id,'role','authenticated','aal','aal1')::text,true);
end;$fixture$;
insert into public.personas(dni,apellido,nombre) values(99999996,'FIXTURE','PRIVILEGIOS');
insert into public.persona_carreras(dni,carrera_id) values(99999996,1);
insert into public.persona_situacion_revista(dni,situacion_id) values(99999996,1);
set local role authenticated;
do $rpc$ declare h public.horas_registros;fm public.francos_movimientos;id_imprevisto bigint;id_parte bigint;n integer;begin
 if not public.can_access_person(99999996) or not public.has_legajo_admin_role()
   or not public.has_legajo_role_ids(array[19]::bigint[]) then raise exception 'Los helpers no reconocen roles del fixture.';end if;
 if not public._condicion_ok(99999996,'TITULAR') or public._condicion_ok(99999996,'SUPLENTE')
   or not public._condicion_ok(99999996,'CUALQUIERA') then raise exception 'Cambio en condicion del fixture.';end if;
 if public.es_dia_laborable('2026-10-25') then raise exception 'Domingo considerado laborable.';end if;

 select * into h from public.rpc_cargar_hora(99999996,1,'2099-06-01','PARTICULAR',30);
 if h.minutos_aplicados<>30 or not public.rpc_borrar_hora(h.id) then raise exception 'Carga/borrado de Horas fallo.';end if;
 select * into fm from public.rpc_francos_saldo_inicial(99999996,1,'2099-06-01',120,'fixture');
 if fm.minutos<>120 then raise exception 'Saldo inicial incorrecto.';end if;
 select count(*) into n from public.rpc_francos_banco_inicial_listar(null,99999996,20,0);
 if n<>1 then raise exception 'Listado de banco incorrecto.';end if;
 select * into fm from public.rpc_francos_crear(99999996,1,'2099-06-02',30,'fixture',null);
 select * into fm from public.rpc_francos_modificar(fm.id,'2099-06-03',45,'fixture modificado',null);
 if fm.minutos<>45 or not public.rpc_francos_eliminar(fm.id,'fixture') then raise exception 'Modificar/anular Francos fallo.';end if;
 select * into fm from public.rpc_francos_crear(99999996,1,'2099-06-04',-30,'fixture consumo',null);
 if fm.minutos<>-30 then raise exception 'Consumo de banco incorrecto.';end if;
 if not public.rpc_francos_saldo_inicial_eliminar(99999996,1) then raise exception 'Eliminar banco fallo.';end if;
 perform * from public.rpc_francos_horario_guardar(99999996,1,
   '[{"dia_semana":3,"hora_desde":"08:30","hora_hasta":"14:00"}]'::jsonb);
 select count(*) into n from public.rpc_francos_horario(99999996,1) where minutos=330;
 if n<>1 then raise exception 'Guardar/leer horarios fallo.';end if;

 id_imprevisto=public.rpc_imprevistos_crear(99999996,1,'2099-06-10','fixture',42);
 if not public.rpc_imprevistos_modificar(id_imprevisto,'2099-06-13','fixture modificado',43) then
   raise exception 'Modificar Imprevistos fallo.';end if;
 select count(*) into n from public.rpc_imprevistos_registros(99999996,1,2099);
 if n<>1 or not public.rpc_imprevistos_eliminar(id_imprevisto) then raise exception 'Consultar/anular Imprevistos fallo.';end if;
 id_parte=public.rpc_medicos_crear(99999996,'CONSULTORIO');
 if not public.rpc_medicos_anular(id_parte) then raise exception 'Emitir/anular parte medico fallo.';end if;
end;$rpc$;
reset role;
do $$ begin
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000099","role":"authenticated","aal":"aal1"}',true);
end;$$;
set local role authenticated;
do $negative$ declare q text;msg text;begin
 foreach q in array array[
  'select public.rpc_cargar_hora(99999996,1,''2099-06-01'',''PARTICULAR'',30)',
  'select public.rpc_borrar_hora(0)',
  'select public.rpc_francos_crear(99999996,1,''2099-06-02'',30,''fixture'',null)',
  'select public.rpc_francos_modificar(0,''2099-06-02'',30,''fixture'',null)',
  'select public.rpc_francos_eliminar(0,''fixture'')',
  'select public.rpc_imprevistos_crear(99999996,1,''2099-06-10'',''fixture'',1)',
  'select public.rpc_imprevistos_modificar(0,''2099-06-10'',''fixture'',1)',
  'select public.rpc_imprevistos_eliminar(0)',
  'select public.rpc_medicos_crear(99999996,''CONSULTORIO'')',
  'select public.rpc_medicos_anular(0)'
 ] loop
  begin execute q;
   raise exception using errcode='ZX001',message='Una escritura sin roles fue aceptada.';
  exception when insufficient_privilege then null;
   when raise_exception then get stacked diagnostics msg=message_text;
    if msg not ilike 'Sin permiso%' then raise;end if;
  end;
 end loop;
end;$negative$;
reset role;
rollback;
