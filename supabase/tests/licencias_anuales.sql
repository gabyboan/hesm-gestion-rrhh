\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database() <> 'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end; $$;

-- Contratos de las guardas ya probadas en las suites de sesión y MFA.
create or replace function private.exigir_mfa_si_activado() returns void language plpgsql as $$
begin
  if current_setting('test.mfa_ok', true) = 'false' then
    raise exception 'MFA pendiente.' using errcode = '42501';
  end if;
end; $$;
create or replace function private.gestion_sesion_exigir() returns void language plpgsql as $$
begin
  if current_setting('test.sesion_ok', true) = 'false' then
    raise exception 'Sesión revocada.' using errcode = '42501';
  end if;
end; $$;
select to_regclass('private.licencias_ficha_orden') is null as requiere_orden \gset
\if :requiere_orden
\ir ../migrations/20261116153646_ficha_insertar_filas.sql
\endif
\ir ../migrations/20261117000619_licencias_anuales_dias_habiles.sql

create function pg_temp.verificar(ok boolean, mensaje text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló: %', mensaje; end if; end; $$;
create function pg_temp.rechazar(consulta text, estado text default '42501') returns void language plpgsql as $$
begin
  begin execute consulta;
  exception when others then if sqlstate = estado then return; end if; raise; end;
  raise exception 'Operación indebidamente permitida: %', consulta;
end; $$;

begin;
-- La prueba concurrente de Estudio deja roles asignados en este fixture.
delete from public.usuario_roles where usuario_id = '00000000-0000-4000-8000-000000000001';
set local role anon;
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',5)$q$);
reset role;
set local role authenticated;
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',5)$q$);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',5)$q$);
reset role;
insert into public.usuario_roles
select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo in ('LICENCIAS_LECTURA','LICENCIAS_CARGA','LICENCIAS_ADM','FICHA_LECTURA');
set local role authenticated;
set local test.mfa_ok = 'false';
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',5)$q$);
set local test.mfa_ok = 'true';
set local test.sesion_ok = 'false';
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',5)$q$);
set local test.sesion_ok = 'true';

select pg_temp.verificar(public.rpc_licencias_anual_hasta('2026-01-01',5) = '2026-01-08',
  'Anual excluye feriados y fines de semana');
select pg_temp.verificar(public.rpc_licencias_anual_hasta('2026-01-03',1) = '2026-01-05',
  'Inicio en sábado avanza al primer hábil');
select pg_temp.verificar(public.rpc_licencias_anual_hasta('2026-12-30',5) = '2027-01-06',
  'Cruce de año utiliza los feriados del siguiente año');
select pg_temp.verificar(public.rpc_licencias_anual_hasta('2028-02-28',3) = '2028-03-01',
  'Incluye el día hábil del febrero bisiesto');
select pg_temp.verificar(private.licencias_contar_habiles('2026-01-01',
  public.rpc_licencias_anual_hasta('2026-01-01',21)) = 21,
  'Anual admite más de cinco por solicitud y veinte por año');
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',0)$q$, '22023');
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',36501)$q$, '22023');
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',null)$q$, '22023');
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta(null,1)$q$, '22023');
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2025-12-31',1)$q$, '22023');

select public.rpc_licencias_guardar_con_datos(null,12345678,101::smallint,
  '2026-01-01','2026-01-08','Anual cinco',null,null,null);
select pg_temp.verificar((select dias = 8 from public.licencias_registros where observacion = 'Anual cinco'),
  'Conserva la duración calendario original');
select pg_temp.verificar((select r->>'dias' = '5' and r->>'dias_calendario' = '8'
  and r->'dias_por_anio'->>'2026' = '5'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'observacion' = 'Anual cinco'),
  'Historial y ficha reciben hábiles y calendario separados');
select public.rpc_licencias_guardar_con_datos(null,12345678,101::smallint,
  '2026-12-30','2027-01-06','Anual cruce',null,null,null);
select pg_temp.verificar((select r->>'dias' = '5' and r->'dias_por_anio'->>'2026' = '2'
  and r->'dias_por_anio'->>'2027' = '3'
  from public.rpc_licencias_historial(null,12345678) r where r->>'observacion' = 'Anual cruce'),
  'Reparte los hábiles entre los años del período');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,101::smallint,
  '2026-01-03','2026-01-04','Solo fin de semana')$q$, '22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,101::smallint,
  '2026-01-01','2026-01-01','Solo feriado')$q$, '22023');
-- No traslada los topes de Estudio ni cambia otras licencias.
select public.rpc_licencias_guardar(null,12345678,101::smallint,'2026-02-01',
  public.rpc_licencias_anual_hasta('2026-02-01',21),'Anual veintiuno');
select public.rpc_licencias_guardar(null,12345678,103::smallint,'2026-01-01','2026-01-08','Profiláctica calendario');
select pg_temp.verificar((select r->>'dias' = '8'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'observacion' = 'Profiláctica calendario'),
  'Las demás licencias conservan días corridos');
select pg_temp.verificar(public.rpc_licencias_estudio_hasta('2026-01-01',5) = '2026-01-08',
  'Estudio conserva su cálculo');
select pg_temp.rechazar($q$select public.rpc_licencias_estudio_hasta('2026-01-01',6)$q$, '22023');

reset role;
-- Original Excel sin código, con el mismo significado de Anual.
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila)
values(12345678,12345678,'PRUEBA LICENCIAS',6,'2026-01-01','2026-01-08','anual-historica',1);
update public.licencias_registros set importacion_confirmada = true where origen_archivo = 'anual-historica';
-- Cantidad ya verificada del papel: no se sustituye por un cálculo nuevo.
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila,cantidad_dias_ficha,cantidad_ficha,anio_cupo)
values(12345678,12345678,'PRUEBA LICENCIAS',101,'2026-01-01','2026-01-19',
  'pdf:anual-verificada',1,15,'15/25',2025);
update public.licencias_registros set importacion_confirmada = true where origen_archivo = 'pdf:anual-verificada';
set local role authenticated;
select pg_temp.verificar((select r->>'dias' = '5' and r->>'dias_calendario' = '8'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'origen_documento' = 'Excel'
    and r->>'tipo_id' = '6' and r->>'origen_fila' = '1'), 'Anual histórica también computa hábiles');
select pg_temp.verificar((select r->>'dias' = '15' and r->>'dias_calendario' = '19'
  and r->>'anio_cupo' = '2025' and r->>'cantidad_ficha' = '15/25'
  and r->'dias_por_anio'->>'2026' = '15'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'origen_documento' = 'PDF'
    and r->>'origen_fila' = '1'), 'Mantiene las cantidades verificadas del papel');
-- Insertar en Ficha conserva su orden al aplicar el cómputo de hábiles.
select public.rpc_licencias_insertar_en_ficha(
  '{"p_dni":12345678,"p_tipo_id":101,"p_desde":"2026-03-02","p_hasta":"2026-03-10","p_observacion":"Anual insertada"}',
  2026, (select id from public.licencias_registros where observacion = 'Anual cinco'), 'arriba');
select pg_temp.verificar((select r->>'dias' = '7' and r->'orden_ficha_por_anio'->>'2026' is not null
  from public.rpc_licencias_historial(2026,12345678) r where r->>'observacion' = 'Anual insertada'),
  'La inserción en ficha conserva su orden y utiliza hábiles');
reset role;
delete from public.usuario_roles where rol_id in (select id from public.roles where codigo like 'LICENCIAS_%');
set local role authenticated;
select pg_temp.verificar((select r->>'dias' = '5' from public.rpc_licencias_historial(2026,12345678) r
  where r->>'observacion' = 'Anual cinco'), 'Ficha sola consulta los hábiles');
select pg_temp.rechazar($q$select public.rpc_licencias_anual_hasta('2026-01-01',5)$q$);
reset role;
rollback;
select 'OK: Anual hábil, feriados, años, papel, ficha, permisos y Estudio conservado' as resultado;
