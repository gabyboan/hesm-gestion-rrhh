-- Step 1: align role lookup with the current user/profile model.
--
-- usuarios.id is the local profile id.
-- usuarios.auth_user_id is auth.uid().
-- usuario_roles.usuario_id may contain either value in existing data, so all
-- checks support both shapes.

create or replace view public.vw_usuario_roles
with (security_invoker = true) as
select
  coalesce(u.auth_user_id, ur.usuario_id) as usuario_id,
  r.codigo as rol,
  ur.usuario_id as perfil_usuario_id,
  r.nombre as rol_nombre,
  r.ver_todo
from public.usuario_roles ur
left join public.usuarios u on u.id = ur.usuario_id
join public.roles r on r.id = ur.rol_id;
drop policy if exists usuario_roles_select_own on public.usuario_roles;
create policy usuario_roles_select_own
on public.usuario_roles
for select
to authenticated
using (
  usuario_id = (select auth.uid())
  or exists (
    select 1
    from public.usuarios u
    where u.id = usuario_roles.usuario_id
      and u.auth_user_id = (select auth.uid())
  )
);
create or replace function public.is_rrhh()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuario_roles ur
    left join public.usuarios u on u.id = ur.usuario_id
    join public.roles r on r.id = ur.rol_id
    where (
        ur.usuario_id = auth.uid()
        or u.auth_user_id = auth.uid()
      )
      and r.ver_todo = true
  );
$$;
create or replace function public.can_access_person(_dni bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_rrhh()
    or exists (
      select 1
      from public.usuario_roles ur
      left join public.usuarios u on u.id = ur.usuario_id
      join public.rol_permisos rp on rp.rol_id = ur.rol_id
      where (
          ur.usuario_id = auth.uid()
          or u.auth_user_id = auth.uid()
        )
        and (
          (
            rp.tipo = 'SERVICIO'
            and exists (
              select 1
              from public.persona_servicios psv
              where psv.dni = _dni
                and psv.servicio_id = rp.target_id
            )
            and public._condicion_ok(_dni, rp.condicion)
          )
          or
          (
            rp.tipo = 'FUNCION'
            and exists (
              select 1
              from public.persona_funciones pf
              where pf.dni = _dni
                and pf.funcion_id = rp.target_id
            )
            and public._condicion_ok(_dni, rp.condicion)
          )
          or
          (
            rp.tipo = 'CARRERA'
            and exists (
              select 1
              from public.persona_carreras pc
              where pc.dni = _dni
                and pc.carrera_id = rp.target_id
            )
            and public._condicion_ok(_dni, rp.condicion)
          )
        )
    );
$$;
