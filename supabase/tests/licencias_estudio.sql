\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end; $$;

create table public.feriados(fecha date primary key,nombre text);
insert into public.feriados values('2026-01-01','Prueba'),('2027-01-01','Prueba');
create function public.es_dia_laborable(p_fecha date) returns boolean
language sql stable security definer set search_path='' as $$
  select extract(isodow from p_fecha) between 1 and 5
    and not exists(select 1 from public.feriados f where f.fecha=p_fecha);
$$;
revoke all on function public.es_dia_laborable(date) from public,anon;
grant execute on function public.es_dia_laborable(date) to authenticated;
\ir ../migrations/20261104145008_licencia_estudio_codigo_29_y_cupos.sql

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
select pg_temp.verificar((select codigo='29' and columna_ficha='ESTUDIO' and habilitado_para_carga
  from public.licencias_tipos where id=129),'Código interno 129, operativo 29, columna Estudio');
set local role anon;
select pg_temp.rechazar($q$select public.rpc_licencias_estudio_hasta('2026-01-01',1)$q$);
reset role;
set local role authenticated;
select pg_temp.rechazar($q$select public.rpc_licencias_estudio_hasta('2026-01-01',1)$q$);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.rechazar($q$select public.rpc_licencias_estudio_hasta('2026-01-01',1)$q$);
reset role;
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
  where codigo in('LICENCIAS_LECTURA','LICENCIAS_CARGA','LICENCIAS_ADM','FICHA_LECTURA');
set local role authenticated;
select pg_temp.verificar(public.rpc_licencias_estudio_hasta('2026-01-01',5)='2026-01-08',
  'Fecha final excluye feriado y fin de semana');
select pg_temp.verificar(public.rpc_licencias_estudio_hasta('2026-01-03',1)='2026-01-05',
  'Inicio en fin de semana avanza al primer hábil');
select pg_temp.rechazar($q$select public.rpc_licencias_estudio_hasta('2026-01-01',6)$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_estudio_hasta('2026-01-01',0)$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_estudio_hasta('2025-01-01',1)$q$,'22023');
select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-01-01','2026-01-08','Estudio cinco');
select pg_temp.verificar((select dias=8 from public.licencias_registros where observacion='Estudio cinco'),
  'Período calendario permanece conservado');
select pg_temp.verificar((select r->>'dias'='5' and r->>'dias_calendario'='8' and r->'dias_por_anio'->>'2026'='5'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'observacion'='Estudio cinco'),
  'Ficha y Licencias computan hábiles y conservan calendario');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-02-02','2026-02-09','Seis hábiles')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-01-03','2026-01-04','Sin hábiles')$q$,'22023');
select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-02-02','2026-02-06','Segundo cinco');
select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-03-02','2026-03-06','Tercer cinco');
select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-04-06','2026-04-10','Cuarto cinco');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-05-04','2026-05-04','Sobre cupo')$q$,'22023');
-- Una edición se excluye de su propio consumo.
select public.rpc_licencias_guardar((select id from public.licencias_registros where observacion='Estudio cinco'),
  12345678,129::smallint,'2026-01-01','2026-01-08','Estudio editado');
-- Las importaciones sin confirmar no consumen cupo.
reset role;
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,origen_archivo,origen_fila)
values(12345678,12345678,'PRUEBA LICENCIAS',129,'2026-05-04','2026-05-08','estudio-apartado',6001);
select pg_temp.verificar((select not importacion_confirmada from public.licencias_registros where origen_archivo='estudio-apartado'),
  'Importación sigue apartada');
select pg_temp.rechazar($q$update public.licencias_registros set importacion_confirmada=true where origen_archivo='estudio-apartado'$q$,'22023');
set local role authenticated;
select public.rpc_licencias_anular((select id from public.licencias_registros where observacion='Cuarto cinco'));
select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-05-04','2026-05-08','Reposición tras anular');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-06-01','2026-06-01','Sobre cupo otra vez')$q$,'22023');
-- Otro año tiene su cupo; una licencia que cruza el año se reparte por días hábiles.
select public.rpc_licencias_guardar(null,12345678,129::smallint,'2027-02-01','2027-02-05','Otro año');
reset role;
insert into public.personas(dni,apellido,nombre,legajo) values(34567890,'ESTUDIO','OTRA PERSONA',99);
set local role authenticated;
select public.rpc_licencias_guardar(null,34567890,129::smallint,'2026-12-30','2027-01-06','Cruce de año');
select pg_temp.verificar((select r->>'dias'='5' and r->'dias_por_anio'->>'2026'='2' and r->'dias_por_anio'->>'2027'='3'
  from public.rpc_licencias_historial(null,34567890) r where r->>'observacion'='Cruce de año'),
  'Se excluye feriado del siguiente año y se reparte el cupo');
reset role;
-- Ficha sola sigue viendo el cómputo, sin permiso de carga.
delete from public.usuario_roles where rol_id in(select id from public.roles where codigo like 'LICENCIAS_%');
set local role authenticated;
select pg_temp.verificar((select r->>'dias'='5' from public.rpc_licencias_historial(null,34567890) r
  where r->>'observacion'='Cruce de año'), 'Ficha independiente puede consultar días hábiles');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,34567890,129::smallint,'2026-06-01','2026-06-01')$q$);
reset role;
rollback;
select 'OK: Estudio 29, feriados, cinco por solicitud, veinte anuales, edición y anulación' as resultado;
