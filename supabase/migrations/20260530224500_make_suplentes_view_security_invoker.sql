-- Make the general substitutes view respect the querying user's RLS.
-- Also align the broad person-read policies with the current role mapping so
-- existing role-based titulares/suplentes views keep returning data.

drop policy if exists ver_enfermeria on public.personas;
create policy ver_enfermeria
on public.personas
for select
to authenticated
using (
  exists (
    select 1
    from public.usuario_roles ur
    left join public.usuarios u on u.id = ur.usuario_id
    where ur.usuario_id = (select auth.uid())
       or u.auth_user_id = (select auth.uid())
  )
);
drop policy if exists ver_funciones_enfermeria on public.persona_funciones;
create policy ver_funciones_enfermeria
on public.persona_funciones
for select
to authenticated
using (
  exists (
    select 1
    from public.usuario_roles ur
    left join public.usuarios u on u.id = ur.usuario_id
    where ur.usuario_id = (select auth.uid())
       or u.auth_user_id = (select auth.uid())
  )
);
drop policy if exists ver_situacion_enfermeria on public.persona_situacion_revista;
create policy ver_situacion_enfermeria
on public.persona_situacion_revista
for select
to authenticated
using (
  exists (
    select 1
    from public.usuario_roles ur
    left join public.usuarios u on u.id = ur.usuario_id
    where ur.usuario_id = (select auth.uid())
       or u.auth_user_id = (select auth.uid())
  )
);
create or replace view public.vw_escalafon_general_suplentes
with (security_invoker = true) as
select
  p.dni,
  p.apellido,
  p.nombre,
  coalesce(
    string_agg(distinct s.nombre, ' | ' order by s.nombre)
      filter (where s.nombre is not null),
    'Escalafón General'
  ) as servicio,
  coalesce(
    string_agg(distinct f.nombre, ' | ' order by f.nombre)
      filter (where f.nombre is not null),
    'Sin función'
  ) as funcion,
  coalesce(
    string_agg(distinct sr.nombre, ' | ' order by sr.nombre)
      filter (where sr.nombre is not null),
    'Sin situación'
  ) as situacion,
  'Suplente'::text as condicion
from public.personas p
join public.persona_carreras pc
  on pc.dni = p.dni
 and pc.carrera_id = 1
left join public.persona_funciones pf
  on pf.dni = p.dni
left join public.funciones f
  on f.id = pf.funcion_id
left join public.persona_servicios psv
  on psv.dni = p.dni
left join public.servicios s
  on s.id = psv.servicio_id
join public.persona_situacion_revista psr
  on psr.dni = p.dni
 and psr.situacion_id is not null
 and psr.situacion_id <> 1
left join public.situacion_revista sr
  on sr.id = psr.situacion_id
group by p.dni, p.apellido, p.nombre;
