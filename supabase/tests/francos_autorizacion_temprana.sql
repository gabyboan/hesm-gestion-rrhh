\set ON_ERROR_STOP on
do $$ begin
 if current_database()<>'hesm_restore_test' or inet_server_addr() is not null then
   raise exception 'Solo copia local aislada.';end if;
end;$$;
begin;
set local search_path=pg_catalog;
do $$ begin
 perform set_config('hesm.fixture_uid',(select id::text from auth.users order by id limit 1),true);
end;$$;
insert into public.personas(dni,apellido,nombre) values(99999995,'FIXTURE','NO FILTRAR TOTAL');
insert into public.persona_carreras(dni,carrera_id) values(99999995,1);
insert into public.francos_movimientos(dni,carrera_id,fecha,periodo,minutos,motivo,usuario_carga)
 values(99999995,1,'2099-07-01','2099-07-01',30,'fixture',current_setting('hesm.fixture_uid')::uuid);
do $$ begin
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
 perform set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000099","role":"authenticated","aal":"aal1"}',true);
end;$$;
set local role authenticated;
do $probe$ declare msg text;begin
 begin
  perform public.rpc_francos_crear(99999995,1,'2099-07-01',360,'fixture',null);
  raise exception using errcode='ZX001',message='Se acepto operacion sin permiso.';
 exception when raise_exception then get stacked diagnostics msg=message_text;end;
 if current_setting('hesm.expect_early_francos',true)='true' then
   if msg not ilike 'Sin permiso%' then raise exception 'Se consulto el tope antes de denegar el permiso.';end if;
 else
   if msg not ilike 'El maximo permitido por dia%' then raise exception 'El fixture no reproduce el orden previo.';end if;
 end if;
end;$probe$;
reset role;
rollback;
