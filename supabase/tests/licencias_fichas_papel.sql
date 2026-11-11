\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end; $$;
\ir ../migrations/20261105120442_fichas_papel_codigos_y_cantidades.sql
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
where codigo in('LICENCIAS_ADM','FICHA_LECTURA');
select pg_temp.verificar((select count(distinct categoria_excel_id)=30 from public.licencias_tipos_excel),'Solo categorías Excel');
select pg_temp.verificar((select array_agg(codigo order by codigo)=array['04','07']::text[]
  from public.licencias_tipos_excel where categoria_excel_id=8),'A.R.T. tiene 04 y 07');
select pg_temp.rechazar($q$insert into public.licencias_tipos(id,nombre,codigo,categoria_excel_id)
  values(900,'Código imprevisto duplicado','43',5)$q$,'23505');
select pg_temp.rechazar($q$insert into public.licencias_tipos(id,nombre,codigo,categoria_excel_id)
  values(901,'A.R.T. duplicada','04',8)$q$,'23505');
select pg_temp.rechazar($q$insert into public.licencias_tipos(id,nombre,codigo,categoria_excel_id)
  values(902,'04 sin categoría','04',null)$q$,'23514');
insert into public.licencias_registros(dni,persona_dni,apellido_nombre,tipo_id,desde,hasta,
  origen_archivo,origen_fila,origen_datos,cantidad_ficha,cantidad_dias_ficha,anio_cupo)
values(12345678,12345678,'PRUEBA LICENCIAS',101,'2026-01-01','2026-01-19',
  'pdf:prueba',304,'{"pagina":3}', '15/25',15,2025);
select pg_temp.verificar((select not importacion_confirmada from public.licencias_registros where origen_archivo='pdf:prueba'),
  'PDF requiere confirmación explícita');
update public.licencias_registros set importacion_confirmada=true where origen_archivo='pdf:prueba';
set local role authenticated;
select pg_temp.verificar((select r->>'dias'='15' and r->>'dias_calendario'='19' and r->>'anio_cupo'='2025'
  and r->'dias_por_anio'->>'2026'='15' and r->>'origen_documento'='PDF' and r->>'origen_pagina'='3'
  from public.rpc_licencias_historial(2026,12345678) r where r->>'origen_fila'='304'),
  'Historial respeta cantidad explícita, calendario, cupo y fuente PDF');
select public.rpc_licencias_guardar(null,12345678,204::smallint,'2026-10-01','2026-10-01','Accidente');
select public.rpc_licencias_guardar(null,12345678,207::smallint,'2026-10-02','2026-10-02','A.R.T.');
select public.rpc_licencias_guardar(null,12345678,104::smallint,'2026-10-03','2026-10-03','Enfermedad');
select pg_temp.verificar((select count(*)=2 from public.rpc_licencias_historial(2026,12345678) r
  where r->>'categoria_excel_id'='8' and r->>'observacion' like '%A.R.T.%'), 'A.R.T. se distingue por categoría y leyenda');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,143::smallint,'2026-10-04','2026-10-04')$q$,'22023');
select pg_temp.rechazar($q$select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-10-05','2026-10-05')$q$,'22023');
reset role;
update public.licencias_registros set observacion='Revisión de metadatos' where origen_archivo='pdf:prueba';
select pg_temp.verificar((select cantidad_dias_ficha=15 and anio_cupo=2025 from public.licencias_registros
  where origen_archivo='pdf:prueba'),'Una nota no cambia el cómputo');
update public.licencias_registros set hasta='2026-01-20' where origen_archivo='pdf:prueba';
select pg_temp.verificar((select cantidad_dias_ficha is null and anio_cupo is null and cantidad_ficha is null
  from public.licencias_registros where origen_archivo='pdf:prueba'),'Editar período invalida cantidades antiguas');
set local role authenticated;
select pg_temp.verificar((select r->>'dias'='20' from public.rpc_licencias_historial(2026,12345678) r
  where r->>'origen_fila'='304'),'El nuevo período usa su duración actual');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()','42501');
select pg_temp.verificar((select count(*)=0 from public.licencias_tipos_excel),'Sin permisos no ve catálogo');
reset role;
set local role anon;
select pg_temp.rechazar('select * from public.rpc_licencias_historial()','42501');
rollback;
select 'OK: equivalencias de papel, A.R.T., cantidades y permisos';
