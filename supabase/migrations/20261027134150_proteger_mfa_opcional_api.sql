-- MFA opt-in: solo exige AAL2 a quien tenga un factor verificado.
-- El hook de PostgREST cubre tablas, vistas y RPC de la Data API.
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';
set local search_path=pg_catalog;

do $check$ begin
  if to_regprocedure('private.exigir_mfa_si_activado()') is not null
    or to_regprocedure('public.verificar_mfa_opcional()') is not null then
    raise exception 'Las funciones MFA ya existen: revisar antes de modificar.';
  end if;
  if exists(select 1 from pg_db_role_setting s join pg_roles r on r.oid=s.setrole
    cross join lateral unnest(s.setconfig) c where r.rolname='authenticator'
    and c like 'pgrst.db_pre_request=%' and c<>'pgrst.db_pre_request=') then
    raise exception 'Ya hay un hook de Data API: integrar sin reemplazarlo.';
  end if;
end; $check$;

create function private.exigir_mfa_si_activado()
returns void language plpgsql stable security definer set search_path='' as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.' using errcode='42501';
  end if;
  if coalesce((select auth.jwt()->>'aal'),'aal1')<>'aal2' and exists(
    select 1 from auth.mfa_factors f
    where f.user_id=(select auth.uid()) and f.status='verified'
  ) then
    raise exception 'Verificá el código de tu autenticadora para continuar.' using errcode='42501';
  end if;
end; $function$;
alter function private.exigir_mfa_si_activado() owner to postgres;
revoke all on function private.exigir_mfa_si_activado() from public,anon,authenticated,service_role;
grant execute on function private.exigir_mfa_si_activado() to authenticated;

-- INVOKER: anon y los servicios no reciben acceso al esquema privado.
create function public.verificar_mfa_opcional()
returns void language plpgsql stable security invoker set search_path='' as $function$
begin
  if current_user='authenticated' then
    perform private.exigir_mfa_si_activado();
  end if;
end; $function$;
alter function public.verificar_mfa_opcional() owner to postgres;
revoke all on function public.verificar_mfa_opcional() from public,anon,authenticated,service_role;
grant execute on function public.verificar_mfa_opcional() to anon,authenticated,service_role;

alter role authenticator set pgrst.db_pre_request='public.verificar_mfa_opcional';
notify pgrst,'reload config';
notify pgrst,'reload schema';
commit;
