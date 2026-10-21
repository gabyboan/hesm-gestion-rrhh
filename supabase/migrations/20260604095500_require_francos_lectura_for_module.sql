-- Require FRANCOS_LECTURA as the base permission for the francos module.
--
-- Matrix:
-- - FRANCOS_LECTURA: read/list movements only.
-- - FRANCOS_LECTURA + FRANCOS_CARGA: read and subtract/use francos.
-- - FRANCOS_LECTURA + FRANCOS_ADM: read and add positive bank movements.
-- - FRANCOS_CARGA and/or FRANCOS_ADM without FRANCOS_LECTURA: no module access.

create or replace function public.can_francos_read()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('FRANCOS_LECTURA');
$function$;
create or replace function public.can_francos_write()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('FRANCOS_LECTURA')
      and public.has_role_code('FRANCOS_CARGA');
$function$;
create or replace function public.can_francos_manage()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('FRANCOS_LECTURA')
      and public.has_role_code('FRANCOS_ADM');
$function$;
create or replace function public.can_francos_use_bank()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('FRANCOS_LECTURA')
      and public.has_role_code('FRANCOS_CARGA');
$function$;
create or replace function public.can_francos_admin_bank()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('FRANCOS_LECTURA')
      and public.has_role_code('FRANCOS_ADM');
$function$;
revoke execute on function public.can_francos_read() from public, anon;
revoke execute on function public.can_francos_write() from public, anon;
revoke execute on function public.can_francos_manage() from public, anon;
revoke execute on function public.can_francos_use_bank() from public, anon;
revoke execute on function public.can_francos_admin_bank() from public, anon;
grant execute on function public.can_francos_read() to authenticated;
grant execute on function public.can_francos_write() to authenticated;
grant execute on function public.can_francos_manage() to authenticated;
grant execute on function public.can_francos_use_bank() to authenticated;
grant execute on function public.can_francos_admin_bank() to authenticated;
notify pgrst, 'reload schema';
