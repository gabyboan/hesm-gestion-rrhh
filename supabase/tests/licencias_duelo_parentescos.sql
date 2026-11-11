\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end; $$;
\ir ../migrations/20261105143403_fichas_duelo_parentescos_confirmados.sql
create function pg_temp.verificar(ok boolean,mensaje text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló: %',mensaje; end if; end; $$;
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo in('LICENCIAS_CARGA','FICHA_LECTURA');
set local role authenticated;
select pg_temp.verificar((select count(distinct categoria_excel_id)=30 from public.licencias_tipos_excel),
  'Se conservan las treinta categorías Excel');
select pg_temp.verificar((select count(*)=3 from public.licencias_tipos_excel where codigo in('19','21','22')
  and categoria_excel_id=11 and columna_ficha is null and habilitado_para_carga),
  'Duelo 19, 21 y 22 habilitados sin columna Estudio');
select public.rpc_licencias_guardar(null,12345678,119::smallint,'2026-11-02','2026-11-02','Duelo por padre');
select public.rpc_licencias_guardar(null,12345678,122::smallint,'2026-11-03','2026-11-03','Duelo por tío');
select public.rpc_licencias_guardar(null,12345678,121::smallint,'2026-11-04','2026-11-04','Duelo por abuelo');
select pg_temp.verificar((select count(*)=3 from public.rpc_licencias_historial(2026,12345678) r
  where r->>'categoria_excel_id'='11' and r->'tipo'->>'codigo' in('19','21','22')
  and r->'tipo'->>'nombre'=(select nombre from public.licencias_tipos where id=11)),
  'La ficha conserva código, parentesco y categoría Duelo');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.verificar((select count(*)=0 from public.licencias_tipos_excel),
  'Los nuevos códigos no abren permisos de lectura');
reset role;
rollback;
select 'OK: Duelo por padre 19, abuelo/abuela 21 y tío 22; permisos preservados';
