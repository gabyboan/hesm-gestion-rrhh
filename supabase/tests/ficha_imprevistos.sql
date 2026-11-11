\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo la base aislada licencias_test.'; end if;
end; $$;

-- Contrato del módulo de origen; esta suite no necesita sus pantallas ni permisos de escritura.
create table public.imprevistos_registros(
  id bigserial primary key,dni integer not null,carrera_id integer not null,fecha date not null,
  anio integer generated always as (extract(year from fecha)::integer) stored,
  observacion text,numero_orden integer,deleted_at timestamptz
);
alter table public.imprevistos_registros enable row level security;
revoke all on public.imprevistos_registros from public,anon,authenticated;

\ir ../migrations/20261104142556_integrar_imprevistos_historial_ficha.sql

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

begin;
insert into public.personas(dni,apellido,nombre,legajo) values(23456789,'OTRA','PERSONA',43);
insert into public.carreras(id,nombre) values(1,'Escalafón General');
insert into public.imprevistos_registros(dni,carrera_id,fecha,numero_orden,deleted_at) values
  (12345678,1,'2026-09-09',101,null), -- primera carga, aunque su fecha sea posterior
  (12345678,1,'2026-01-02',202,null),
  (12345678,1,'2026-05-05',null,null), -- un número ausente se conserva ausente
  (23456789,1,'2026-06-06',404,null),
  (12345678,1,'2027-01-01',505,null),
  (12345678,1,'2025-01-01',606,null),
  (12345678,1,'2026-07-07',707,now()),
  (87654321,1,'2026-08-08',808,null); -- no se inventa una ficha para un DNI ausente
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila,origen_datos)
select 12345678,12345678,'PRUEBA LICENCIAS',t.id,f.fecha,f.fecha,
  'prueba-imprevistos-ficha',f.fila,'{"B":"PRUEBA LICENCIAS"}'::jsonb
from public.licencias_tipos t cross join (values ('2026-09-09'::date,10001),('2026-08-08'::date,10002)) f(fecha,fila)
where t.nombre='Imprevisto';
update public.licencias_registros set importacion_confirmada=true where origen_archivo='prueba-imprevistos-ficha';

set local role anon;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()');
reset role;
set local role authenticated;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()');
reset role;
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id
from public.roles where codigo='FICHA_LECTURA';
set local role authenticated;
select pg_temp.rechazar('select * from public.imprevistos_registros');
select pg_temp.verificar((select count(*)=5 from public.rpc_licencias_historial(2026)),
  'Cuatro imprevistos y una licencia, sin duplicar ni admitir imprevistos del Excel');
select pg_temp.verificar((select array_agg(r->'tipo'->>'codigo' order by (r->>'imprevisto_id')::bigint)=array['43','98','98']
  from public.rpc_licencias_historial(2026,12345678) r where r->>'imprevisto_id' is not null),
  '43,98,98 por orden de carga, no por fecha ni número de orden');
select pg_temp.verificar((select r->>'numero_orden'='101' and r->>'id'='-1' and r->>'dias'='1'
  and r->'tipo'->>'columna_ficha'='ART8' from public.rpc_licencias_historial(2026) r where r->>'imprevisto_id'='1'),
  'Identificador separado, número de orden, día y columna');
select pg_temp.verificar((select r->>'numero_orden' is null from public.rpc_licencias_historial(2026) r where r->>'imprevisto_id'='3'),
  'No se inventa un número de orden ausente');
select pg_temp.verificar((select count(*)=1 and bool_and(r->'tipo'->>'codigo'='43') from public.rpc_licencias_historial(2026,23456789) r),
  'Otra persona comienza con 43');
select pg_temp.verificar((select r->'tipo'->>'codigo'='43' from public.rpc_licencias_historial(2027) r where r->>'imprevisto_id'='5'),
  'Cada año comienza con 43');
select pg_temp.verificar((select count(*)=6 from public.rpc_licencias_historial()),'Acumulada desde 2026');
select pg_temp.verificar((select count(*)=0 from public.rpc_licencias_historial(2026,87654321)), 'No atribuye a una persona sin ficha');
select pg_temp.verificar((select count(*)=1 from public.rpc_licencias_historial(2026,null,0,1)), 'Paginación acotada');
select pg_temp.verificar((select a.r->>'id'<>b.r->>'id' from public.rpc_licencias_historial(2026,null,0,1) a(r)
  cross join public.rpc_licencias_historial(2026,null,1,1) b(r)), 'Páginas estables sin repetir filas');
select pg_temp.rechazar('select * from public.rpc_licencias_historial(2025)','22023');
select pg_temp.rechazar('select * from public.rpc_licencias_historial(2026,null,-1,1)','22023');
select pg_temp.rechazar('select * from public.rpc_licencias_historial(2026,null,0,501)','22023');
reset role;
update public.imprevistos_registros set fecha='2026-10-10',numero_orden=12345 where id=1;
set local role authenticated;
select pg_temp.verificar((select r->>'desde'='2026-10-10' and r->>'numero_orden'='12345'
  and r->'tipo'->>'codigo'='43' from public.rpc_licencias_historial(2026) r where r->>'imprevisto_id'='1'),
  'Los cambios de fecha y número se reflejan sin copiar ni cambiar el orden de carga');
reset role;
update public.imprevistos_registros set deleted_at=now() where id=1;
set local role authenticated;
select pg_temp.verificar((select count(*)=4 from public.rpc_licencias_historial(2026)),
  'Anulación desaparece sin que reaparezca el Excel anterior');
select pg_temp.verificar((select r->'tipo'->>'codigo'='43' from public.rpc_licencias_historial(2026) r where r->>'imprevisto_id'='2'),
  'Anulación reordena las cargas vigentes');
reset role;
update public.imprevistos_registros set fecha='2027-02-02' where id=2;
set local role authenticated;
select pg_temp.verificar((select r->'tipo'->>'codigo'='43' from public.rpc_licencias_historial(2026) r where r->>'imprevisto_id'='3'),
  'Cambio de año reordena el año anterior');
select pg_temp.verificar((select array_agg(r->'tipo'->>'codigo' order by (r->>'imprevisto_id')::bigint)=array['43','98']
  from public.rpc_licencias_historial(2027) r where r->>'imprevisto_id' is not null), 'Cambio de año reordena el destino');
reset role;
delete from public.usuario_roles where rol_id=(select id from public.roles where codigo='FICHA_LECTURA');
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles where codigo='LICENCIAS_LECTURA';
set local role authenticated;
select pg_temp.verificar((select count(*)=3 from public.rpc_licencias_historial(2027)), 'Licencias también consulta el origen');
reset role;
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles where codigo in('LICENCIAS_CARGA','LICENCIAS_ADM');
set local role authenticated;
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,143::smallint,'2026-12-01','2026-12-01')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(-3,12345678,101::smallint,'2026-12-01','2026-12-01')$q$,'P0001');
reset role;
delete from public.usuario_roles where rol_id in (select id from public.roles where codigo in('LICENCIAS_LECTURA','LICENCIAS_CARGA','LICENCIAS_ADM'));
set local role authenticated;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()');
reset role;
select pg_temp.verificar((select count(*)=2 and bool_and(origen_datos->>'B'='PRUEBA LICENCIAS')
  from public.licencias_registros where origen_archivo='prueba-imprevistos-ficha'), 'Originales del Excel preservados');
rollback;
select 'OK: Imprevistos en Ficha, orden, códigos, modificaciones, anulaciones y permisos' as resultado;
