-- Deprecate unused legacy views by renaming them instead of dropping them.
--
-- Evidence before this migration:
-- - public.cocina only appeared in pg_stat_statements as postgres/dashboard
--   count queries, not authenticated PostgREST app traffic.
-- - public.vw_suplencias_detalle_old only appeared as postgres/dashboard count
--   queries.
-- - No SQL objects depended on either view.

alter view if exists public.cocina
rename to deprecated_cocina;
alter view if exists public.vw_suplencias_detalle_old
rename to deprecated_vw_suplencias_detalle_old;
