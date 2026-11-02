\set ON_ERROR_STOP on
do $$ begin
 if current_database()<>'hesm_restore_test' or inet_server_addr() is not null then
  raise exception 'Solo restauracion local hesm_restore_test por socket.';
 end if;
end;$$;
begin;
set local search_path=pg_catalog;
do $fixture$ declare uid uuid;sid constant uuid:='00000000-0000-4000-8000-000000000097';begin
 select id into uid from auth.users order by id limit 1;
 if uid is null or exists(select 1 from auth.mfa_factors where user_id=uid) then
   raise exception 'Se requiere un usuario del fixture sin factores.';end if;
 perform set_config('hesm.mfa_uid',uid::text,true);
 if exists(select 1 from auth.sessions where id=sid) then raise exception 'Session fixture ya existe.';end if;
 insert into auth.sessions(id,user_id,created_at,updated_at,aal) values(sid,uid,now(),now(),'aal1');
 insert into auth.mfa_amr_claims(id,session_id,authentication_method,created_at,updated_at)
 values('00000000-0000-4000-8000-000000000096',sid,'totp',now(),now());
 perform set_config('hesm.mfa_sid',sid::text,true);
 perform set_config('request.jwt.claim.sub',uid::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'session_id',sid,'role','authenticated','aal','aal1')::text,true);
end;$fixture$;
set local role authenticated;
select public.verificar_mfa_opcional(); -- sin factor: contraseña permitida.
reset role;
insert into auth.mfa_factors(id,user_id,friendly_name,factor_type,status,created_at,updated_at,secret)
values('00000000-0000-4000-8000-000000000098',current_setting('hesm.mfa_uid')::uuid,
 'FIXTURE MFA','totp','unverified',now(),now(),'FIXTURE_ONLY_NOT_A_REAL_SECRET');
set local role authenticated;
select public.verificar_mfa_opcional(); -- alta incompleta no obliga MFA.
reset role;
update auth.mfa_factors set status='verified' where id='00000000-0000-4000-8000-000000000098';
set local role authenticated;
do $$ begin
 begin
  perform public.verificar_mfa_opcional();
  raise exception using errcode='ZX001',message='MFA verificado acepto AAL1.';
 exception when insufficient_privilege then null;end;
end;$$;
reset role;
do $$ begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('hesm.mfa_uid'),
   'role','authenticated','aal','aal2','session_id',current_setting('hesm.mfa_sid'),
   'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',floor(extract(epoch from now()))::bigint)))::text,true);
end;$$;
set local role authenticated;
select public.verificar_mfa_opcional(); -- factor verificado + AAL2 permitido.
reset role;
do $$ begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('hesm.mfa_uid'),
   'role','authenticated','session_id',current_setting('hesm.mfa_sid'))::text,true);
end;$$;
set local role authenticated;
do $$ begin
 begin
  perform public.verificar_mfa_opcional();
  raise exception using errcode='ZX001',message='MFA verificado acepto AAL ausente.';
 exception when insufficient_privilege then null;end;
end;$$;
reset role;
set local role service_role;
select public.verificar_mfa_opcional(); -- un servicio no es un login interactivo.
reset role;
do $$ begin
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{}',true);
end;$$;
set local role anon;
select public.verificar_mfa_opcional();
do $$ begin
 begin
  perform private.exigir_mfa_si_activado();
  raise exception using errcode='ZX001',message='Anon accedio al helper privado.';
 exception when insufficient_privilege then null;end;
end;$$;
reset role;
set local role authenticated;
do $$ begin
 begin
  perform public.verificar_mfa_opcional();
  raise exception using errcode='ZX001',message='Authenticated sin identidad aceptado.';
 exception when insufficient_privilege then null;end;
end;$$;
reset role;
delete from auth.mfa_factors where id='00000000-0000-4000-8000-000000000098';
do $$ begin
 perform set_config('request.jwt.claim.sub',current_setting('hesm.mfa_uid'),true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('hesm.mfa_uid'),
   'role','authenticated','aal','aal1','session_id',current_setting('hesm.mfa_sid'))::text,true);
end;$$;
set local role authenticated;
select public.verificar_mfa_opcional(); -- desactivar restaura el acceso sin TOTP.
reset role;
rollback;
