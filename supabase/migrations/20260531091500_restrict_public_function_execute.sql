-- Restrict public schema functions from unauthenticated direct execution.
--
-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. In Supabase,
-- that means anon and authenticated can call RPC-exposed functions unless we
-- explicitly tighten grants.
--
-- This migration keeps authenticated users working, including app RPCs and
-- functions used by RLS policies, but removes inherited anon access.
--
-- The only anon RPC intentionally preserved is rpc_consulta_horas_public(bigint),
-- which already had an explicit anon grant and is named as a public endpoint.

revoke execute on all functions in schema public from public;
revoke execute on all functions in schema public from anon;
grant execute on all functions in schema public to authenticated;
grant execute on function public.rpc_consulta_horas_public(bigint) to anon;
alter default privileges in schema public
revoke execute on functions from public;
alter default privileges in schema public
revoke execute on functions from anon;
alter default privileges in schema public
grant execute on functions to authenticated;
