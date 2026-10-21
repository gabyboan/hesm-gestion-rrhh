-- Preferencias personales de la aplicación.
--
-- Cada fila pertenece a un único usuario autenticado. Los límites también se
-- validan en la base para que no puedan evitarse desde un cliente modificado.

create table if not exists public.usuario_preferencias (
  usuario_id uuid primary key references auth.users (id) on delete cascade,
  tema text not null default 'oscuro'
    constraint usuario_preferencias_tema_chk check (tema in ('claro', 'oscuro')),
  inactividad_minutos smallint not null default 5
    constraint usuario_preferencias_inactividad_minutos_chk
      check (inactividad_minutos between 1 and 10)
);
alter table public.usuario_preferencias enable row level security;
-- Las nuevas tablas pueden no exponerse automáticamente a la Data API;
-- estos permisos permiten que el cliente autenticado use la tabla, y RLS
-- restringe cada operación a la fila propia.
grant select, insert, update on table public.usuario_preferencias
  to authenticated;
drop policy if exists usuario_preferencias_select_propias
  on public.usuario_preferencias;
create policy usuario_preferencias_select_propias
on public.usuario_preferencias
for select
to authenticated
using ((select auth.uid()) = usuario_id);
drop policy if exists usuario_preferencias_insert_propias
  on public.usuario_preferencias;
create policy usuario_preferencias_insert_propias
on public.usuario_preferencias
for insert
to authenticated
with check ((select auth.uid()) = usuario_id);
drop policy if exists usuario_preferencias_update_propias
  on public.usuario_preferencias;
create policy usuario_preferencias_update_propias
on public.usuario_preferencias
for update
to authenticated
using ((select auth.uid()) = usuario_id)
with check ((select auth.uid()) = usuario_id);
-- El perfil no se consulta directamente desde el cliente. Esta función interna
-- devuelve únicamente el perfil del usuario autenticado; el RPC público es un
-- envoltorio SECURITY INVOKER para mantener la función con privilegios fuera
-- del esquema expuesto.
create schema if not exists private;
grant usage on schema private to authenticated;
create or replace function private.mi_perfil_actual()
returns table (
  apellido text,
  nombre text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    nullif(trim(u.apellido), '')::text as apellido,
    nullif(trim(u.nombre), '')::text as nombre
  from public.usuarios u
  where u.auth_user_id = (select auth.uid());
$$;
revoke all on function private.mi_perfil_actual() from public;
grant execute on function private.mi_perfil_actual() to authenticated;
create or replace function public.rpc_mi_perfil()
returns table (
  apellido text,
  nombre text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select perfil.apellido, perfil.nombre
  from private.mi_perfil_actual() as perfil;
$$;
revoke all on function public.rpc_mi_perfil() from public;
grant execute on function public.rpc_mi_perfil() to authenticated;
