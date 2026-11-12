begin;
create function public.rpc_gestion_capacidades() returns jsonb
language plpgsql stable security invoker set search_path=''
as $$ begin
  if (select auth.uid()) is null then raise exception 'No autenticado.' using errcode='42501'; end if;
  return jsonb_build_object('schema',2,'horas_gremiales',true,'horas_idempotencia',true,'horas_periodos',true);
end; $$;
revoke all on function public.rpc_gestion_capacidades() from public,anon;
grant execute on function public.rpc_gestion_capacidades() to authenticated;
notify pgrst,'reload schema';
commit;
