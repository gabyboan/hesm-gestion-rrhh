-- La consulta pública se atiende desde Cloudflare Worker.
-- El navegador nunca debe ejecutar esta función directamente.
revoke execute on function public.rpc_consulta_horas_public(bigint)
  from public, anon, authenticated;
grant execute on function public.rpc_consulta_horas_public(bigint)
  to service_role;
