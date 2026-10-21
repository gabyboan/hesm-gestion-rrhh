-- Crear los permisos visibles del modulo de imprevistos.

insert into public.roles (codigo, nombre)
values
  ('IMPREVISTOS_LECTURA', 'Imprevistos - Lectura'),
  ('IMPREVISTOS_ESCRITURA', 'Imprevistos - Escritura'),
  ('IMPREVISTOS_ADM', 'Imprevistos - Modificacion y eliminacion')
on conflict (codigo) do update
set nombre = excluded.nombre;
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
      and (
        public.has_role_code('IMPREVISTOS_ESCRITURA')
        or public.has_role_code('IMPREVISTOS_CARGA')
      );
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
notify pgrst, 'reload schema';
