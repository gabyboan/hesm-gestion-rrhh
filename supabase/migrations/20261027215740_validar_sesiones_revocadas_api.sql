-- Valida la sesion de Auth antes de aplicar el MFA voluntario en la Data API.
begin isolation level repeatable read;set local search_path=pg_catalog;set local lock_timeout='3s';set local statement_timeout='45s';
do $$ begin
 if (select count(*) from pg_db_role_setting s join pg_roles r on r.oid=s.setrole cross join lateral unnest(s.setconfig) c
  where r.rolname='authenticator' and c like 'pgrst.db_pre_request=%')<>1 or not exists(
 select 1 from pg_db_role_setting s join pg_roles r on r.oid=s.setrole cross join lateral unnest(s.setconfig) c
 where r.rolname='authenticator' and s.setdatabase=0 and c='pgrst.db_pre_request=public.verificar_mfa_opcional') then
 raise exception 'El hook actual no coincide con el revisado.';end if;
end;$$;
do $guard$ declare f jsonb; acl jsonb; p record; begin
 for f in select value from jsonb_array_elements('[{"identidad": "private.exigir_mfa_si_activado()", "propietario": "postgres", "permisos": [{"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "postgres"}, {"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "authenticated"}], "hash": "434bb96dd911bd95f0c61d2ae9628443"}]'::jsonb) loop
  select * into p from pg_proc where oid=to_regprocedure(f->>'identidad');
  if not found or md5(pg_get_functiondef(p.oid))<>f->>'hash'
    or pg_get_userbyid(p.proowner)<>f->>'propietario' then
    raise exception 'Definicion/owner no esperado: %',f->>'identidad';end if;
  select jsonb_agg(jsonb_build_object('rol',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
   'grantor',pg_get_userbyid(a.grantor),'privilegio',a.privilege_type,'grantable',a.is_grantable)) into acl
   from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a;
  if not(acl @> (f->'permisos') and (f->'permisos') @> acl) then raise exception 'ACL no esperada: %',f->>'identidad';end if;
 end loop;
end;$guard$;
CREATE OR REPLACE FUNCTION private.exigir_mfa_si_activado()
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid := (select auth.uid());
  sid uuid;
begin
  if uid is null then
    raise exception 'No autenticado.' using errcode='42501';
  end if;
  begin
    sid := nullif((select auth.jwt()->>'session_id'),'')::uuid;
  exception when invalid_text_representation then
    raise sqlstate 'PT401' using message='La sesión ya no es válida. Volvé a iniciar sesión.';
  end;
  if sid is null or not exists(
    select 1 from auth.sessions s join auth.users u on u.id=s.user_id
    where s.id=sid and s.user_id=uid
      and (s.not_after is null or s.not_after>statement_timestamp())
      and (u.banned_until is null or u.banned_until<=statement_timestamp())
  ) then
    raise sqlstate 'PT401' using message='La sesión ya no es válida. Volvé a iniciar sesión.';
  end if;
  if coalesce((select auth.jwt()->>'aal'),'aal1')<>'aal2' and exists(
    select 1 from auth.mfa_factors f
    where f.user_id=uid and f.status='verified'
  ) then
    raise exception 'Verificá el código de tu autenticadora para continuar.' using errcode='42501';
  end if;
end; $function$
;
do $guard$ declare f jsonb; acl jsonb; p record; begin
 for f in select value from jsonb_array_elements('[{"identidad": "private.exigir_mfa_si_activado()", "propietario": "postgres", "permisos": [{"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "postgres"}, {"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "authenticated"}], "hash": "b6ae7c74fd85e0b5092bb8c6a174e4d6"}]'::jsonb) loop
  select * into p from pg_proc where oid=to_regprocedure(f->>'identidad');
  if not found or md5(pg_get_functiondef(p.oid))<>f->>'hash'
    or pg_get_userbyid(p.proowner)<>f->>'propietario' then
    raise exception 'Definicion/owner no esperado: %',f->>'identidad';end if;
  select jsonb_agg(jsonb_build_object('rol',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
   'grantor',pg_get_userbyid(a.grantor),'privilegio',a.privilege_type,'grantable',a.is_grantable)) into acl
   from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a;
  if not(acl @> (f->'permisos') and (f->'permisos') @> acl) then raise exception 'ACL no esperada: %',f->>'identidad';end if;
 end loop;
end;$guard$;
commit;
