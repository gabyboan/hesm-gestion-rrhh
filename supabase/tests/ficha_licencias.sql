\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database() <> 'licencias_test' then
    raise exception 'Solo la base aislada licencias_test.';
  end if;
end; $$;

-- El lote existe antes del cambio; se debe preservar y apartar.
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila,origen_datos)
values(12345678,12345678,'PRUEBA LICENCIAS',6,'2026-02-01','2026-02-02',
  'a164de3f55f1d1de5bffd8b6d43f87087850a87b14f2a8b212e9abe881b8905e',2,'{"B":"PRUEBA LICENCIAS"}');
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta)
values(12345678,12345678,'PRUEBA LICENCIAS',6,'2026-12-30','2027-01-02');
insert into public.licencias_importacion_pendientes(origen_archivo,origen_fila,motivo,datos)
values('archivo-prueba',3,'DNI vacío','{"A":""}');

\ir ../migrations/20261103135810_ficha_y_revision_importaciones_licencias.sql
\ir ../migrations/20261103135839_modulo_ficha_consulta_licencias.sql

create function pg_temp.validar(ok boolean,mensaje text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló: %', mensaje; end if; end;
$$;
create function pg_temp.denegar(consulta text,estado text default '42501') returns void language plpgsql as $$
begin
  begin execute consulta;
  exception when others then if sqlstate=estado then return; end if; raise; end;
  raise exception 'Operación indebidamente permitida: %',consulta;
end;
$$;

select pg_temp.validar((select count(*)=2 from public.licencias_registros),'Se conserva todo el historial');
select pg_temp.validar((select count(*)=1 from public.licencias_registros where not importacion_confirmada),'Lote apartado');
select pg_temp.validar((select origen_datos->>'B'='PRUEBA LICENCIAS' from public.licencias_registros where not importacion_confirmada),'Datos originales intactos');
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
set local role anon;
select pg_temp.denegar('select public.can_ficha_read()');
select pg_temp.denegar('select * from public.rpc_ficha_personas()');
reset role;
set local role authenticated;
select pg_temp.validar(not public.can_ficha_read(),'Sin rol no accede a Ficha');
select pg_temp.denegar('select * from public.rpc_ficha_personas()');
select pg_temp.denegar('select * from public.rpc_licencias_importadas_resumen()');
reset role;
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id
  from public.roles where codigo='FICHA_LECTURA';
set local role authenticated;
select pg_temp.validar(public.can_ficha_read() and not public.can_licencias_read(),'Ficha independiente de Licencias');
select pg_temp.validar((select count(*)=1 from public.rpc_ficha_personas('PRUEBA LICENCIAS')),'Padrón desde Ficha');
select pg_temp.validar((select count(*)=1 from public.licencias_registros),'Ficha excluye importación apartada');
select pg_temp.validar((select count(*)=0 from public.licencias_importacion_pendientes),'No expone pendientes a Ficha');
select pg_temp.denegar('select * from public.rpc_licencias_personas()');
select pg_temp.denegar('select public.rpc_licencias_guardar(null,12345678,6::smallint,current_date,current_date)');
select pg_temp.denegar('select public.rpc_licencias_anular(0)');
select pg_temp.denegar('update public.licencias_registros set importacion_confirmada=true');
reset role;
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id
  from public.roles where codigo in ('LICENCIAS_LECTURA','LICENCIAS_CARGA','LICENCIAS_ADM');
set local role authenticated;
select pg_temp.validar((select sum(registros)=1 from public.rpc_licencias_importadas_resumen()),'Revisión aparte disponible al administrador');
select pg_temp.validar((select count(*)=1 from public.licencias_importacion_pendientes),'Administrador consulta filas con errores');
select pg_temp.denegar($q$select public.rpc_licencias_guardar(null,12345678,6::smallint,'2025-12-31','2026-01-01')$q$,'22023');
-- La carga nueva del mismo período no es bloqueada por el lote no confirmado.
select public.rpc_licencias_guardar(null,12345678,6::smallint,'2026-02-01','2026-02-02');
select pg_temp.validar((select count(*)=2 from public.licencias_registros),'Nueva carga aparece una sola vez');
reset role;
select set_config('hesm.licencia_apartada',(select id::text from public.licencias_registros where not importacion_confirmada limit 1),true);
set local role authenticated;
select pg_temp.validar(not public.rpc_licencias_anular(current_setting('hesm.licencia_apartada')::bigint),'No anula un registro apartado');
select pg_temp.denegar('select public.rpc_licencias_guardar(current_setting(''hesm.licencia_apartada'')::bigint,12345678,6::smallint,current_date,current_date)','P0001');
reset role;
delete from public.usuario_roles where rol_id=(select id from public.roles where codigo='FICHA_LECTURA');
set local role authenticated;
select pg_temp.denegar('select * from public.rpc_ficha_personas()');
reset role;
-- Todo ingreso futuro del Excel permanece apartado, aun si el cliente declara lo contrario.
insert into public.licencias_registros(dni,apellido_nombre,tipo_id,desde,hasta,origen_archivo,origen_fila,importacion_confirmada)
values(12345678,'PRUEBA LICENCIAS',6,'2026-03-01','2026-03-01','otro-archivo',4,true);
select pg_temp.validar((select not importacion_confirmada from public.licencias_registros where origen_archivo='otro-archivo'),'No confirma importaciones automáticamente');
rollback;
select 'OK: Ficha conectada, importación conservada y excluida, permisos y límite 2026' as resultado;
