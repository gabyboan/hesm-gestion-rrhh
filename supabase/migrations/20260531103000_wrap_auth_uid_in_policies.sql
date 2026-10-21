-- Wrap auth.uid() calls in RLS policies with `(select auth.uid())`.
--
-- Supabase recommends this form so the value can be evaluated once per
-- statement instead of once per row. This migration preserves the existing
-- policy names, commands, roles, and permission logic.

alter policy carreras_select_legajo_19_20_21
on public.carreras
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint, 21::bigint])
  )
);
alter policy p_francos_horarios_insert
on public.francos_horarios_persona
with check (
  public.can_asistencia_manage()
  and usuario_carga = (select auth.uid())
);
alter policy p_francos_insert
on public.francos_movimientos
with check (
  public.can_francos_write()
  and usuario_carga = (select auth.uid())
);
alter policy p_hr_insert
on public.horas_registros
with check (
  public.can_horas_write()
  and usuario_carga = (select auth.uid())
);
alter policy persona_carreras_delete_legajo_19_20
on public.persona_carreras
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy persona_carreras_insert_legajo_19_20
on public.persona_carreras
with check (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy persona_carreras_select_legajo_19_20_21
on public.persona_carreras
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint, 21::bigint])
  )
);
alter policy persona_carreras_update_legajo_19_20
on public.persona_carreras
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy persona_situacion_revista_delete_legajo_19_20
on public.persona_situacion_revista
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy persona_situacion_revista_insert_legajo_19_20
on public.persona_situacion_revista
with check (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy persona_situacion_revista_select_legajo_19_20_21
on public.persona_situacion_revista
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint, 21::bigint])
  )
);
alter policy persona_situacion_revista_update_legajo_19_20
on public.persona_situacion_revista
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy personas_insert_legajo_roles_19_20
on public.personas
with check (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy personas_select_legajo_roles_19_20_21
on public.personas
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint, 21::bigint])
  )
);
alter policy visor_select_personas_en_suplencias
on public.personas
using (
  exists (
    select 1
    from public.usuario_roles ur
    join public.roles r on r.id = ur.rol_id
    where ur.usuario_id = (select auth.uid())
      and r.nombre = 'VISOR'
  )
  and (
    exists (
      select 1
      from public.suplencias s
      where s.titular_dni = personas.dni
    )
    or exists (
      select 1
      from public.suplencias s
      where s.suplente_dni = personas.dni
    )
  )
);
alter policy personas_update_legajo_roles_19_20
on public.personas
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
)
with check (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint])
  )
);
alter policy situacion_revista_select_legajo_19_20_21
on public.situacion_revista
using (
  exists (
    select 1
    from public.usuarios u
    join public.usuario_roles ur on ur.usuario_id = u.id
    where u.auth_user_id = (select auth.uid())
      and ur.rol_id = any (array[19::bigint, 20::bigint, 21::bigint])
  )
);
alter policy usuarios_select_own
on public.usuarios
using (
  (select auth.uid()) = auth_user_id
);
