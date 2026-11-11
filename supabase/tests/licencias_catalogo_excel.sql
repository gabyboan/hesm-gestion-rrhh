\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end; $$;

-- Datos históricos previos: no se borran aunque su código deje de ofrecerse.
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila,origen_datos)
values(12345678,12345678,'PRUEBA LICENCIAS',7,'2026-07-01','2026-07-02','catalogo-prueba',7001,'{"original":true}'),
 (12345678,12345678,'PRUEBA LICENCIAS',3,'2026-07-03','2026-07-03','catalogo-prueba',7002,'{}'),
 (12345678,12345678,'PRUEBA LICENCIAS',102,'2026-07-06','2026-07-06','catalogo-prueba',7003,'{}'),
 (12345678,12345678,'PRUEBA LICENCIAS',7,'2026-07-07','2026-07-07','catalogo-prueba',7004,'{}');
update public.licencias_registros set importacion_confirmada=true
where origen_archivo='catalogo-prueba' and origen_fila<>7004;
create temporary table originales_catalogo as select * from public.licencias_registros;
\ir ../migrations/20261105103330_catalogo_licencias_segun_excel.sql

create function pg_temp.verificar(ok boolean,mensaje text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló: %',mensaje; end if; end;
$$;
create function pg_temp.rechazar(consulta text,estado text default '42501') returns void language plpgsql as $$
begin
  begin execute consulta;
  exception when others then if sqlstate=estado then return; end if; raise; end;
  raise exception 'Operación indebidamente permitida: %',consulta;
end;
$$;
select pg_temp.verificar(not exists(
  (select * from public.licencias_registros except select * from originales_catalogo)
  union all(select * from originales_catalogo except select * from public.licencias_registros)),
  'La migración no modifica registros ni confirma importaciones');
select pg_temp.verificar((select count(distinct categoria_excel_id)=30 and count(*)=34
  from public.licencias_tipos_excel),'30 tipos del Excel, con variantes de código');
select pg_temp.verificar((select count(*)=1 and min(codigo)='03' and min(nombre)='Lic. Profiláctica'
  from public.licencias_tipos_excel where categoria_excel_id=7),'Profiláctica solo código 03');
select pg_temp.verificar(not exists(select 1 from public.licencias_tipos where habilitado_para_carga
  and categoria_excel_id is null),'No hay tipos habilitados ajenos al Excel');
select pg_temp.verificar((select array_agg(codigo order by codigo)=array['10','11']::text[]
  from public.licencias_tipos_excel where categoria_excel_id=3),'Familiar conserva las dos variantes');
select pg_temp.verificar((select array_agg(codigo)=array['29']::text[] from public.licencias_tipos_excel
  where categoria_excel_id=9),'Estudio usa exclusivamente código 29');
select pg_temp.verificar((select 'security_invoker=true'=any(reloptions)
  from pg_class where oid='public.licencias_tipos_excel'::regclass),'Vista respeta RLS');

begin;
set local role anon;
select pg_temp.rechazar('select * from public.licencias_tipos_excel');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.verificar((select count(*)=0 from public.licencias_tipos_excel),'Sin permisos no ve catálogo');
select pg_temp.rechazar('select * from public.rpc_licencias_historial()');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo in('LICENCIAS_ADM','FICHA_LECTURA');
set local role authenticated;
select pg_temp.verificar((select count(*)=34 from public.licencias_tipos_excel),'Lectura autorizada');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,102::smallint,'2026-08-03','2026-08-03')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,113::smallint,'2026-08-03','2026-08-03')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,124::smallint,'2026-08-03','2026-08-03')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,9::smallint,'2026-08-03','2026-08-03')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,143::smallint,'2026-08-03','2026-08-03')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,198::smallint,'2026-08-03','2026-08-03')$q$,'22023');
select public.rpc_licencias_guardar(null,12345678,103::smallint,'2026-08-03','2026-08-04','Profiláctica nueva');
select public.rpc_licencias_guardar(null,12345678,10::smallint,'2026-08-05','2026-08-05','Capacitación sin código inventado');
select public.rpc_licencias_guardar(null,12345678,29::smallint,'2026-08-06','2026-08-06','Adopción no es Estudio');
select public.rpc_licencias_guardar(null,12345678,110::smallint,'2026-08-07','2026-08-07','Familiar inicial');
select public.rpc_licencias_guardar(null,12345678,111::smallint,'2026-08-10','2026-08-10','Familiar extensión');
select pg_temp.verificar((select r->'tipo'->>'nombre'='Lic. Profiláctica' and r->'tipo'->>'codigo'='03'
  and r->'tipo'->>'columna_ficha'='PROFILACTICA' and r->>'categoria_excel_id'='7'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'observacion'='Profiláctica nueva'),
  'Ficha devuelve nombre del Excel y código 03');
select pg_temp.verificar((select count(*)=3 from public.rpc_licencias_historial(2026,12345678) r
  where r->>'categoria_excel_id'='3'),'Familiar agrupa histórico pendiente, 10 y 11');
select pg_temp.verificar((select r->'tipo'->>'codigo' is null and r->>'categoria_excel_id'='29'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'observacion'='Adopción no es Estudio'),
  'ID interno 29 no se confunde con el código operativo 29');
-- No se puede esquivar el catálogo editando un registro importado confirmado.
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(
  (select id from public.licencias_registros where origen_archivo='catalogo-prueba' and origen_fila=7001),
  12345678,102::smallint,'2026-07-01','2026-07-02')$q$,'22023');
select public.rpc_licencias_guardar((select id from public.licencias_registros
  where origen_archivo='catalogo-prueba' and origen_fila=7001),12345678,103::smallint,
  '2026-07-01','2026-07-02','Código confirmado');
select public.rpc_licencias_guardar((select id from public.licencias_registros
  where origen_archivo='catalogo-prueba' and origen_fila=7003),12345678,102::smallint,
  '2026-07-06','2026-07-06','Nota histórica');
select pg_temp.verificar((select count(*)=0 from public.licencias_registros
  where origen_archivo='catalogo-prueba' and origen_fila=7004),
  'Profilácticas apartadas no son visibles');
-- El cupo de 20 ya fue consumido por la prueba concurrente anterior.
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-09-01','2026-09-01')$q$,'22023');
select pg_temp.verificar((select bool_and(r->>'dias'='5' and r->>'categoria_excel_id'='9')
  from public.rpc_licencias_historial(2026,12345678) r where r->>'observacion'='Cupo concurrente'
  and r->>'desde'='2026-06-01'),'Se conserva el cómputo hábil en el historial');
reset role;
select pg_temp.verificar((select count(*)=1 from public.licencias_registros
  where origen_archivo='catalogo-prueba' and origen_fila=7004 and not importacion_confirmada),
  'Profilácticas apartadas siguen conservadas sin confirmar');
insert into public.carreras(id,nombre) values(1,'Prueba') on conflict do nothing;
insert into public.imprevistos_registros(dni,carrera_id,fecha,numero_orden)
values(12345678,1,'2026-09-03',801),(12345678,1,'2026-09-04',802);
set local role authenticated;
select pg_temp.verificar((select array_agg(r->'tipo'->>'codigo' order by (r->>'imprevisto_id')::bigint)=array['43','98']::text[]
  from public.rpc_licencias_historial(2026,12345678) r where r->>'categoria_excel_id'='5'),
  'Imprevistos conserva origen, agrupación y secuencia');
select pg_temp.verificar(not has_table_privilege('authenticated','public.licencias_tipos_excel','insert'),
  'El cliente no recibe permiso de escritura sobre el catálogo');
select pg_temp.rechazar('insert into public.licencias_tipos_excel(id,nombre) values(999,''Intruso'')','55000');
reset role;
rollback;
select 'OK: 30 tipos Excel, Profiláctica 03, variantes, permisos e historial conservados' as resultado;
