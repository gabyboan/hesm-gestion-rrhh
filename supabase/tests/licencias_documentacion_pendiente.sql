\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end; $$;
\ir ../migrations/20261110113656_fichas_documentacion_pendiente.sql
create function pg_temp.verificar(ok boolean,mensaje text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló: %',mensaje; end if; end; $$;
create function pg_temp.rechazar(consulta text) returns void language plpgsql as $$
begin
  begin execute consulta;
  exception when sqlstate '42501' then return; end;
  raise exception 'Operación indebidamente permitida';
end; $$;
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo='FICHA_LECTURA' on conflict do nothing;
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila,origen_datos,documentacion_pendiente)
values(12345678,12345678,'PRUEBA LICENCIAS',16,'2026-04-09','2026-04-09',
  'pdf:documentacion-prueba',2118,'{"pagina":21,"lectura_original":"08/04"}',true),
 (12345678,12345678,'PRUEBA LICENCIAS',16,'2026-03-05','2026-03-05',
  'pdf:documentacion-prueba',405,'{"pagina":4}',false),
 (12345678,12345678,'PRUEBA LICENCIAS',16,'2026-04-10','2026-04-10',
  'pdf:documentacion-prueba',2119,'{"pagina":21}',true);
update public.licencias_registros set importacion_confirmada=true
where origen_archivo='pdf:documentacion-prueba' and origen_fila<>2119;
set local role authenticated;
select pg_temp.verificar((select r->>'documentacion_pendiente'='true'
  and r->>'numero_orden' is null and r->'tipo'->>'codigo' is null
  and r->>'desde'='2026-04-09' and r->>'hasta'='2026-04-09'
  and r->>'dias'='1' and r->>'categoria_excel_id'='16'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'origen_fila'='2118'),
  'Ficha muestra anotación pendiente sin inventar código u orden');
select pg_temp.verificar((select r->>'documentacion_pendiente'='false' and r->>'numero_orden' is null
  from public.rpc_licencias_historial(2026,12345678) r where r->>'origen_fila'='405'),
  'No convierte en pendiente cada licencia sin orden');
select pg_temp.verificar(not exists(select 1 from public.rpc_licencias_historial(2026,12345678) r
  where r->>'origen_fila'='2119'),'La marca no reactiva importaciones apartadas');
select pg_temp.rechazar($q$update public.licencias_registros set documentacion_pendiente=false
  where origen_archivo='pdf:documentacion-prueba'$q$);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()');
reset role;
rollback;
select 'OK: documentación pendiente visible, sin código u orden inventados y con permisos conservados';
