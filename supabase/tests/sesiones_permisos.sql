\set ON_ERROR_STOP on
do $$ begin
 if current_database()<>'hesm_restore_test' or inet_server_addr() is not null then
  raise exception 'Solo restauracion local hesm_restore_test por socket.';
 end if;
end;$$;
begin;
set local search_path=pg_catalog;
do $fixture$ declare uid uuid;pid uuid;sid constant uuid:='00000000-0000-4000-8000-000000000091';begin
 select u.auth_user_id,u.id into uid,pid from public.usuarios u
 join public.usuario_roles ur on ur.usuario_id=u.id
 join public.roles r on r.id=ur.rol_id
 where r.codigo in('HORAS_CARGA','HORAS_CARGA_ADM') order by u.auth_user_id limit 1;
 if uid is null or exists(select 1 from auth.mfa_factors where user_id=uid and status='verified')
  or exists(select 1 from auth.sessions where id=sid) then
  raise exception 'No se cumplen precondiciones del fixture de permisos.';
 end if;
 insert into auth.sessions(id,user_id,created_at,updated_at,aal)
 values(sid,uid,now(),now(),'aal1');
 perform set_config('hesm.fixture_permisos_pid',pid::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'session_id',sid,
  'role','authenticated','aal','aal1')::text,true);
end;$fixture$;
set local role authenticated;
do $$begin
 perform public.verificar_mfa_opcional();
 if not public.can_horas_read() then raise exception 'El perfil autorizado no conserva acceso.';end if;
 perform 1 from public.rpc_horas_registros_periodo(date_trunc('month',current_date)::date);
end;$$;
reset role;
-- Modificacion exclusivamente en esta transaccion local; el mismo JWT sigue vigente.
delete from public.usuario_roles where usuario_id=current_setting('hesm.fixture_permisos_pid')::uuid;
set local role authenticated;
do $$begin
 perform public.verificar_mfa_opcional();
 if public.can_horas_read() then raise exception 'El mismo JWT conservo permisos retirados.';end if;
 begin
  perform 1 from public.rpc_horas_registros_periodo(date_trunc('month',current_date)::date);
  raise exception using errcode='ZX001',message='RPC permitida despues de retirar los roles.';
 exception when insufficient_privilege then null;end;
 begin
  perform 1 from public.rpc_listado_horas_oficiales();
  raise exception using errcode='ZX001',message='Listado permitido despues de retirar los roles.';
 exception when insufficient_privilege then null;end;
end;$$;
reset role;
rollback;
