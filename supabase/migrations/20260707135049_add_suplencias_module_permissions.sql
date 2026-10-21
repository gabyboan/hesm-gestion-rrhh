insert into public.roles (codigo, nombre)
values ('SUPLENCIAS_LECTURA', 'Suplencias - Lectura')
on conflict (codigo) do update set nombre = excluded.nombre;
create or replace function public.can_suplencias_read()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_role_code('SUPLENCIAS_LECTURA');
$$;
revoke execute on function public.can_suplencias_read() from public, anon;
grant execute on function public.can_suplencias_read() to authenticated;
drop policy if exists suplencias_select_own_or_admin on public.suplencias;
drop policy if exists suplencias_select_authorized on public.suplencias;
create policy suplencias_select_authorized on public.suplencias
for select to authenticated
using (
  usuario_carga = (select auth.uid())
  or public.is_rrhh()
  or public.has_role('ADMIN')
  or public.has_role_code('SUPLENCIAS_LECTURA')
);
alter view if exists public.vw_suplencias_detalle_servicio
set (security_invoker = true);
revoke all on public.vw_suplencias_detalle_servicio from anon;
grant select on public.vw_suplencias_detalle_servicio to authenticated;
notify pgrst, 'reload schema';
