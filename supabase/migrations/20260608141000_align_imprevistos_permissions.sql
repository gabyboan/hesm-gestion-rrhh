-- Alinear permisos de imprevistos con el helper de roles usado por el resto
-- del sistema.

create or replace function public.can_imprevistos_read()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('IMPREVISTOS_LECTURA');
$function$;
create or replace function public.can_imprevistos_create()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('IMPREVISTOS_LECTURA')
      and public.has_role_code('IMPREVISTOS_CARGA');
$function$;
create or replace function public.can_imprevistos_admin()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('IMPREVISTOS_LECTURA')
      and public.has_role_code('IMPREVISTOS_ADM');
$function$;
revoke execute on function public.can_imprevistos_read() from public, anon;
revoke execute on function public.can_imprevistos_create() from public, anon;
revoke execute on function public.can_imprevistos_admin() from public, anon;
grant execute on function public.can_imprevistos_read() to authenticated;
grant execute on function public.can_imprevistos_create() to authenticated;
grant execute on function public.can_imprevistos_admin() to authenticated;
grant execute on function public.rpc_imprevistos_listado(integer, text)
to authenticated;
grant execute on function public.rpc_imprevistos_registros(integer, integer, integer)
to authenticated;
grant execute on function public.rpc_imprevistos_crear(integer, integer, date, text, integer)
to authenticated;
grant execute on function public.rpc_imprevistos_modificar(bigint, date, text, integer)
to authenticated;
grant execute on function public.rpc_imprevistos_eliminar(bigint)
to authenticated;
notify pgrst, 'reload schema';
