-- Deprecate the legacy public."Legajos" table.
--
-- personas.legajo is now the canonical legajo attribute. This keeps the legacy
-- rows available under a deprecated name while surfacing any hidden dependency
-- on the old table name before a future drop.

alter table if exists public."Legajos"
rename to "deprecated_Legajos";
comment on table public."deprecated_Legajos" is
  'Deprecated legacy import table. Use public.personas.legajo as the canonical legajo source.';
