-- Prune redundant/no-op permissive SELECT policies.
--
-- This migration does not tighten the current effective permissions:
-- - On carreras and persona_carreras, authenticated_select_* already grants
--   SELECT using true for authenticated users.
-- - v2_select_* policies using false never grant access.
-- - On personas and persona_situacion_revista, the broad ver_* policies already
--   cover the narrower legajo/visor SELECT policies under current rules.

drop policy if exists carreras_select_legajo_19_20_21
on public.carreras;
drop policy if exists persona_carreras_select_legajo_19_20_21
on public.persona_carreras;
drop policy if exists v2_select_persona_funciones
on public.persona_funciones;
drop policy if exists persona_situacion_revista_select_legajo_19_20_21
on public.persona_situacion_revista;
drop policy if exists v2_select_persona_situacion
on public.persona_situacion_revista;
drop policy if exists personas_select_legajo_roles_19_20_21
on public.personas;
drop policy if exists v2_select_personas
on public.personas;
drop policy if exists visor_select_personas_en_suplencias
on public.personas;
