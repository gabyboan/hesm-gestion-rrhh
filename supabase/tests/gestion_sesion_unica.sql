\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database() <> 'gestion_session_test' then
    raise exception 'Solo la base aislada gestion_session_test.';
  end if;
end; $$;

create schema auth;
create schema private;
grant usage on schema auth, private to authenticated;
create role authenticator nologin;
create table auth.users(id uuid primary key, banned_until timestamptz);
create table auth.sessions(
  id uuid primary key, user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(), not_after timestamptz
);
create table auth.mfa_factors(id uuid primary key, user_id uuid, status text);
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb);
$$;
create function auth.uid() returns uuid language sql stable as $$ select (auth.jwt()->>'sub')::uuid; $$;
\ir ../migrations/20261027134150_proteger_mfa_opcional_api.sql
\ir ../migrations/20261102141024_sesion_unica_gestion_por_usuario.sql

insert into auth.users(id) values
  ('00000000-0000-4000-8000-000000000001'), ('00000000-0000-4000-8000-000000000002');
insert into auth.sessions(id,user_id) values
  ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000013','00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000002');

begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000011","aal":"aal1"}', true);
select set_config('request.path', '/rpc/rpc_gestion_sesion_adquirir', true);
set local role authenticated;
do $$ begin
  perform public.verificar_mfa_opcional();
  if not public.rpc_gestion_sesion_adquirir() or not public.rpc_gestion_sesion_adquirir()
      or not public.rpc_gestion_sesion_renovar() then
    raise exception 'No permitió adquirir, repetir o renovar la misma sesión.';
  end if;
  perform set_config('request.path', '/personas', true);
  perform public.verificar_mfa_opcional();
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000012","aal":"aal1"}', true);
  if public.rpc_gestion_sesion_adquirir() or public.rpc_gestion_sesion_renovar()
      or public.rpc_gestion_sesion_liberar() then
    raise exception 'La segunda sesión robó, renovó o liberó la reserva de la primera.';
  end if;
  begin
    perform public.verificar_mfa_opcional();
    raise exception 'La segunda Gestión accedió a datos pese al rechazo.';
  exception when sqlstate 'PT409' then null; end;
  -- El mismo rechazo también cubre RPC y peticiones sin cabecera de aplicación.
  perform set_config('request.path', '/rpc/rpc_medicos_registros', true);
  begin
    perform public.verificar_mfa_opcional();
    raise exception 'Una RPC de datos omitió la reserva.';
  exception when sqlstate 'PT409' then null; end;
  perform set_config('request.path', '/rpc/rpc_gestion_sesion_adquirir', true);
  perform public.verificar_mfa_opcional();
  -- Una sesión propia de otra app no se registra como Gestión.
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000013","aal":"aal1"}', true);
  perform set_config('request.path', '/personas', true);
  perform public.verificar_mfa_opcional();
  -- Un usuario diferente puede trabajar a la vez.
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000002","session_id":"00000000-0000-4000-8000-000000000021","aal":"aal1"}', true);
  if not public.rpc_gestion_sesion_adquirir() then raise exception 'Bloqueó otra cuenta.'; end if;
end; $$;
reset role;

-- La caída del primer equipo permite recuperar sin dejar una cuenta trabada.
update private.gestion_sesiones set vence_at = statement_timestamp() - interval '1 second'
where user_id = '00000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000012","aal":"aal1"}', true);
set local role authenticated;
do $$ begin
  if not public.rpc_gestion_sesion_adquirir() then raise exception 'No recuperó la reserva vencida.'; end if;
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000011","aal":"aal1"}', true);
  if public.rpc_gestion_sesion_renovar() or public.rpc_gestion_sesion_liberar() then
    raise exception 'Una ventana vieja quitó el acceso a la nueva.';
  end if;
  begin
    perform public.verificar_mfa_opcional();
    raise exception 'El JWT anterior siguió accediendo a datos.';
  exception when sqlstate 'PT409' then null; end;
end; $$;
reset role;
-- Un logout real elimina la sesión de Auth y su reserva por FK.
delete from auth.sessions where id = '00000000-0000-4000-8000-000000000012';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000011","aal":"aal1"}', true);
set local role authenticated;
do $$ begin
  if not public.rpc_gestion_sesion_adquirir() or not public.rpc_gestion_sesion_liberar() then
    raise exception 'Cerrar sesión no liberó la cuenta inmediatamente.';
  end if;
  if not public.rpc_gestion_sesion_adquirir() then raise exception 'No permitió adquirir tras liberar.'; end if;
  -- No se puede reclamar la sesión de otro usuario con un sid ajeno.
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000021","aal":"aal1"}', true);
  begin
    perform public.rpc_gestion_sesion_adquirir();
    raise exception 'Aceptó un session_id de otro usuario.';
  exception when sqlstate 'PT401' then null; end;
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"invalido"}', true);
  begin
    perform public.rpc_gestion_sesion_adquirir();
    raise exception 'Aceptó un session_id inválido.';
  exception when sqlstate 'PT401' then null; end;
end; $$;
reset role;

-- Se conserva la obligación MFA previa a la reserva.
insert into auth.mfa_factors values ('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000001','verified');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-000000000011","aal":"aal1"}', true);
set local role authenticated;
do $$ begin
  begin
    perform public.rpc_gestion_sesion_adquirir();
    raise exception 'Adquirió la reserva sin resolver MFA.';
  exception when insufficient_privilege then null; end;
end; $$;
reset role;
do $$ begin
  if has_table_privilege('authenticated','private.gestion_sesiones','SELECT,INSERT,UPDATE,DELETE')
      or has_table_privilege('anon','private.gestion_clientes','SELECT,INSERT,UPDATE,DELETE')
      or has_function_privilege('anon','public.rpc_gestion_sesion_adquirir()','EXECUTE')
      or has_function_privilege('authenticated','private.gestion_sesion_actual()','EXECUTE')
      or exists(select 1 from pg_class where oid in ('private.gestion_sesiones'::regclass,
        'private.gestion_clientes'::regclass) and not relrowsecurity) then
    raise exception 'La reserva expone datos o permisos innecesarios.';
  end if;
end; $$;
rollback;
select 'OK: sesión única, recuperación, logout, alcance por app, API, identidad, MFA y permisos' as resultado;
