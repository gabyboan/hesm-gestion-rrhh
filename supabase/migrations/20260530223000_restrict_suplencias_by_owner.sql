-- Restrict suplencias by owner.
--
-- Normal users can see/delete only their own rows.
-- Admin/RRHH users can see/delete all rows.
-- Inserts must always be attributed to the current auth user.

drop policy if exists "insert suplencias" on public.suplencias;
drop policy if exists "select suplencias" on public.suplencias;
drop policy if exists visor_select_suplencias on public.suplencias;
drop policy if exists suplencias_insert_own on public.suplencias;
drop policy if exists suplencias_select_own_or_admin on public.suplencias;
drop policy if exists suplencias_delete_own_or_admin on public.suplencias;
create policy suplencias_insert_own
on public.suplencias
for insert
to authenticated
with check (
  usuario_carga = (select auth.uid())
);
create policy suplencias_select_own_or_admin
on public.suplencias
for select
to authenticated
using (
  usuario_carga = (select auth.uid())
  or public.is_rrhh()
  or public.has_role('ADMIN')
);
create policy suplencias_delete_own_or_admin
on public.suplencias
for delete
to authenticated
using (
  usuario_carga = (select auth.uid())
  or public.is_rrhh()
  or public.has_role('ADMIN')
);
