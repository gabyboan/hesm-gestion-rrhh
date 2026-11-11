\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end; $$;
\ir ../migrations/20261110102228_fichas_francos_doble_cantidad_un_dia.sql
create function pg_temp.verificar(ok boolean,mensaje text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló: %',mensaje; end if; end; $$;
create function pg_temp.rechazar(consulta text,estado text) returns void language plpgsql as $$
begin
  begin execute consulta;
  exception when others then if sqlstate=estado then return; end if; raise; end;
  raise exception 'Operación indebidamente permitida';
end; $$;
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo in('LICENCIAS_CARGA','FICHA_LECTURA');
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila,origen_datos,cantidad_ficha,cantidad_dias_ficha)
values(12345678,12345678,'PRUEBA LICENCIAS',160,'2026-03-23','2026-03-23',
  'pdf:francos-dobles',1303,'{"pagina":13,"confirmacion":"dos francos"}', '2',2);
update public.licencias_registros set importacion_confirmada=true where origen_archivo='pdf:francos-dobles';
set local role authenticated;
select pg_temp.verificar((select r->>'dias'='2' and r->>'dias_calendario'='1' and r->>'cantidad_ficha'='2'
  and r->'dias_por_anio'->>'2026'='2' and r->>'desde'=r->>'hasta'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'origen_fila'='1303'),
  'Ficha computa dos francos y conserva fecha única y un día calendario');
reset role;
select pg_temp.rechazar($q$insert into public.licencias_registros(dni,persona_dni,apellido_nombre,
  tipo_id,desde,hasta,cantidad_dias_ficha) values(12345678,12345678,'PRUEBA LICENCIAS',104,
  '2026-11-01','2026-11-01',2)$q$,'23514');
select pg_temp.rechazar($q$insert into public.licencias_registros(dni,persona_dni,apellido_nombre,
  tipo_id,desde,hasta,cantidad_dias_ficha) values(12345678,12345678,'PRUEBA LICENCIAS',160,
  '2026-11-01','2026-11-01',3)$q$,'23514');
select pg_temp.rechazar($q$insert into public.licencias_registros(dni,persona_dni,apellido_nombre,
  tipo_id,desde,hasta,cantidad_dias_ficha) values(12345678,12345678,'PRUEBA LICENCIAS',160,
  '2026-12-31','2027-01-01',2)$q$,'23514');
update public.licencias_registros set tipo_id=104 where origen_archivo='pdf:francos-dobles';
select pg_temp.verificar((select cantidad_dias_ficha is null and cantidad_ficha is null
  from public.licencias_registros where origen_archivo='pdf:francos-dobles'),
  'Cambiar el tipo invalida el cómputo de dos francos');
select pg_temp.rechazar($q$update public.licencias_registros set cantidad_dias_ficha=2
  where origen_archivo='pdf:francos-dobles'$q$,'23514');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()','42501');
reset role;
rollback;
select 'OK: dos francos en una fecha, duración calendario, invalidación y permisos';
