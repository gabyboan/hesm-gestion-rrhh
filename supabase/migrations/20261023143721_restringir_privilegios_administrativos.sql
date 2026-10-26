-- Aplicar despues de contrastar el esquema real y validar en staging.
-- La app necesita DML/RPC; nunca crear objetos ni vaciar tablas con TRUNCATE.
-- TRUNCATE no aplica RLS. No se cambian SELECT/INSERT/UPDATE/DELETE existentes.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

revoke create on schema public, private from public, anon, authenticated;

do $$
declare v_tabla record;
begin
  for v_tabla in
    select n.nspname, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private')
      and c.relkind in ('r', 'p')
      -- Los objetos de extensiones se administran con su propia extension.
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_class'::regclass and d.objid = c.oid
          and d.deptype = 'e'
      )
  loop
    execute format(
      'revoke truncate, references, trigger on table %I.%I from public, anon, authenticated',
      v_tabla.nspname, v_tabla.relname
    );
  end loop;
end;
$$;

-- Los defaults pertenecen al creador, no al esquema ni al ejecutor futuro.
-- Las migraciones/SQL Editor deben crear objetos como postgres. Otros
-- creadores requieren su propia configuracion, que se detecta en la auditoria.
-- Un REVOKE IN SCHEMA no anula el EXECUTE global de PUBLIC: hay que quitar
-- tanto el default global como las concesiones adicionales por esquema.
alter default privileges for role postgres
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public, private
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres
  revoke truncate, references, trigger on tables from public, anon, authenticated;
alter default privileges for role postgres in schema public, private
  revoke truncate, references, trigger on tables from public, anon, authenticated;

-- Cada RPC nueva debe conceder EXECUTE explicitamente a su destinatario.
-- Las funciones ya existentes conservan sus ACL, incluido el Worker service_role.
commit;
