\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'horas_next_test' then raise exception 'Solo horas_next_test.'; end if;
end; $$;
begin;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
select 'OPERACION:' || id::text from public.rpc_cargar_hora_segura(
  '00000000-0000-4000-8000-000000000042',1001,17,'2026-12-01','GREMIAL',30);
select pg_sleep(0.5);
commit;
