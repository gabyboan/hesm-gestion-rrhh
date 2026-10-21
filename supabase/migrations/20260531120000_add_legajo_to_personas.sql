-- Normalize personas.legajo as the canonical legajo attribute.
--
-- Legajos is kept intact for compatibility while apps are updated.
-- Current inventory before this migration:
-- - public."Legajos" has 204 rows.
-- - 203 rows match an existing public.personas.dni.
-- - 1 row does not currently match public.personas.
-- - public.personas already has legajo integer not null default 0.
-- - 166 personas rows currently use legajo = 0 as "missing legajo".

alter table public.personas
alter column legajo drop default;
alter table public.personas
alter column legajo drop not null;
update public.personas
set legajo = null
where legajo = 0;
update public.personas p
set legajo = l.legajo
from public."Legajos" l
where l.dni = p.dni;
alter table public.personas
add constraint personas_legajo_unique unique (legajo);
alter table public.personas
add constraint personas_legajo_positive
check (legajo is null or legajo > 0);
comment on column public.personas.legajo is
  'Numero de legajo administrativo. Nullable while historical data is completed.';
