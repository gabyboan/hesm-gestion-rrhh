-- Drop redundant persona_carreras indexes/constraints.
--
-- Business rule preserved:
-- - persona_carreras_dni_unique keeps one carrera per persona.
--
-- Referential integrity preserved:
-- - persona_carreras_pkey on (dni, carrera_id) stays in place and is the
--   referenced key for horas/francos foreign keys.

drop index if exists public.idx_pc_dni_carrera;
alter table public.persona_carreras
drop constraint if exists persona_carreras_dni_carrera_unique;
