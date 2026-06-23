-- Restrict the public hours consultation RPC from direct anonymous access.
--
-- The public page should go through the Cloudflare Worker, which validates
-- Turnstile before querying Supabase. Leaving anon EXECUTE on this SECURITY
-- DEFINER function allows bypassing that Worker and querying by DNI directly
-- through the Supabase REST RPC endpoint.

revoke execute on function public.rpc_consulta_horas_public(bigint)
from anon;
grant execute on function public.rpc_consulta_horas_public(bigint)
to authenticated;
