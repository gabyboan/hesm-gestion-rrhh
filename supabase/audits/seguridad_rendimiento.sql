-- SOLO LECTURA. Ejecutar en SQL Editor como postgres (PostgreSQL 15+).
-- Devuelve metadatos y estadisticas agregadas; nunca filas de RRHH, JWT,
-- cuerpos de funciones, textos de consultas ni definiciones de politicas.
-- public se considera expuesto. Confirmar los esquemas de la Data API en Dashboard.
-- Los resultados son candidatos a revisar, no autorizacion para borrar indices.
with
tablas as (
  select c.*, n.nspname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'private') and c.relkind in ('r', 'p')
    and not exists (
      select 1 from pg_depend d where d.classid = 'pg_class'::regclass
        and d.objid = c.oid and d.deptype = 'e'
    )
),
funciones as (
  select p.*, n.nspname,
    pg_get_function_identity_arguments(p.oid) as argumentos,
    (select substr(v, 13) from unnest(p.proconfig) as s(v)
      where v like 'search_path=%' limit 1) as ruta,
    exists (
      select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where a.grantee = 0 and a.privilege_type = 'EXECUTE'
    ) as ejecutable_public
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private') and p.prokind = 'f'
    and not exists (
      select 1 from pg_depend d where d.classid = 'pg_proc'::regclass
        and d.objid = p.oid and d.deptype = 'e'
    )
),
hallazgos as (
  select 'RLS_DESACTIVADO' as codigo, 'alta' as prioridad,
    t.nspname as esquema, t.relname::text as objeto,
    jsonb_build_object('acceso_anon', has_table_privilege('anon', t.oid, 'SELECT,INSERT,UPDATE,DELETE'),
      'acceso_authenticated', has_table_privilege('authenticated', t.oid, 'SELECT,INSERT,UPDATE,DELETE')) as detalle
  from tablas t where t.nspname = 'public' and not t.relrowsecurity

  union all
  select 'RLS_SIN_POLITICAS', 'revisar', t.nspname, t.relname::text,
    jsonb_build_object('nota', 'Puede ser intencional si el acceso es exclusivamente por RPC.')
  from tablas t where t.relrowsecurity
    and not exists (select 1 from pg_policy p where p.polrelid = t.oid)
    and has_table_privilege('authenticated', t.oid, 'SELECT,INSERT,UPDATE,DELETE')

  union all
  select 'PRIVILEGIO_ADMINISTRATIVO', 'alta', t.nspname, t.relname::text,
    jsonb_build_object('rol', r.rol, 'privilegio', v.privilegio)
  from tablas t cross join (values ('anon'), ('authenticated')) r(rol)
    cross join (values ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) v(privilegio)
  where has_table_privilege(r.rol, t.oid, v.privilegio)

  union all
  select 'ESQUEMA_MODIFICABLE', 'alta', n.nspname, n.nspname::text,
    jsonb_build_object('rol', r.rol, 'privilegio', 'CREATE')
  from pg_namespace n cross join (values ('anon'), ('authenticated')) r(rol)
  where n.nspname in ('public', 'private') and has_schema_privilege(r.rol, n.oid, 'CREATE')

  union all
  select 'DEFINER_ANON_PUBLIC', 'alta', f.nspname, f.proname || '(' || f.argumentos || ')',
    jsonb_build_object('execute_public', f.ejecutable_public,
      'execute_anon', has_function_privilege('anon', f.oid, 'EXECUTE'))
  from funciones f where f.prosecdef and
    (f.ejecutable_public or has_function_privilege('anon', f.oid, 'EXECUTE'))

  union all
  select 'DEFINER_EN_API', 'revisar', f.nspname, f.proname || '(' || f.argumentos || ')',
    jsonb_build_object('nota', 'Revisar autenticacion y permiso de modulo dentro de la funcion.')
  from funciones f where f.nspname = 'public' and f.prosecdef
    and has_function_privilege('authenticated', f.oid, 'EXECUTE')

  union all
  select 'DEFINER_SEARCH_PATH', 'alta', f.nspname, f.proname || '(' || f.argumentos || ')',
    jsonb_build_object('search_path', f.ruta,
      'nota', 'Usar nombres calificados y search_path vacio; o esquemas confiables y pg_temp al final.')
  from funciones f where f.prosecdef and (
    f.ruta is null or (f.ruta not in ('', '""') and f.ruta !~ '(^|,)[[:space:]]*pg_temp[[:space:]]*$')
  )

  union all
  select 'VISTA_OMITE_RLS', 'alta', n.nspname, c.relname::text,
    jsonb_build_object('tipo', c.relkind, 'nota', 'Revisar security_invoker y acceso a las tablas base.')
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('v', 'm')
    and (has_table_privilege('anon', c.oid, 'SELECT') or has_table_privilege('authenticated', c.oid, 'SELECT'))
    and (c.relkind = 'm' or not exists (
      select 1 from pg_options_to_table(c.reloptions) o
      where o.option_name = 'security_invoker' and o.option_value::boolean
    ))

  union all
  select 'POLITICA_ABIERTA', 'revisar', p.schemaname, p.tablename || '.' || p.policyname,
    jsonb_build_object('roles', p.roles, 'operacion', p.cmd,
      'nota', 'Comprobar si es un catalogo compartido o una tabla sensible.')
  from pg_policies p where p.schemaname in ('public', 'private')
    and p.roles && array['anon', 'authenticated', 'public']::name[]
    and (regexp_replace(coalesce(p.qual, ''), '[()[:space:]]', '', 'g') = 'true'
      or regexp_replace(coalesce(p.with_check, ''), '[()[:space:]]', '', 'g') = 'true')

  union all
  select 'AUTORIZACION_USER_METADATA', 'alta', p.schemaname, p.tablename || '.' || p.policyname,
    jsonb_build_object('nota', 'user_metadata es editable por el usuario; revisar la autorizacion.')
  from pg_policies p where p.schemaname in ('public', 'private')
    and (coalesce(p.qual, '') || coalesce(p.with_check, '')) ~* '(raw_user_meta_data|user_metadata)'

  union all
  select 'DEFAULT_PERMISIVO', 'alta', coalesce(n.nspname, '*'),
    pg_get_userbyid(d.defaclrole) || ':' || d.defaclobjtype::text,
    jsonb_build_object('destinatario', case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
      'privilegio', a.privilege_type)
  from pg_default_acl d left join pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral aclexplode(d.defaclacl) a
  where (d.defaclnamespace = 0 or n.nspname in ('public', 'private'))
    and (a.grantee = 0 or a.grantee in (select oid from pg_roles where rolname in ('anon', 'authenticated')))
    and ((d.defaclobjtype = 'f' and a.privilege_type = 'EXECUTE')
      or (d.defaclobjtype = 'r' and a.privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER')))

  union all
  select 'FK_SIN_INDICE', 'rendimiento', t.nspname, t.relname || '.' || c.conname,
    jsonb_build_object('columnas', (select jsonb_agg(a.attname order by k.orden)
      from unnest(c.conkey) with ordinality k(num, orden)
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.num),
      'nota', 'Medir joins y borrados de padres antes de crear un indice.')
  from pg_constraint c join tablas t on t.oid = c.conrelid
  where c.contype = 'f' and not exists (
    select 1 from pg_index i join pg_class ix on ix.oid = i.indexrelid
      join pg_am am on am.oid = ix.relam
    where i.indrelid = c.conrelid and i.indisvalid and i.indisready
      and i.indpred is null and am.amname = 'btree'
      and i.indnkeyatts >= cardinality(c.conkey)
      -- Se acepta cualquier orden dentro del prefijo de la FK compuesta.
      and (select array_agg(i.indkey[k] order by i.indkey[k])
        from generate_series(0, cardinality(c.conkey) - 1) k)
        = (select array_agg(num order by num) from unnest(c.conkey) num)
  )

  union all
  select 'INDICE_INVALIDO', 'alta', t.nspname, ix.relname::text,
    jsonb_build_object('tabla', t.relname, 'valido', i.indisvalid, 'listo', i.indisready)
  from pg_index i join tablas t on t.oid = i.indrelid
    join pg_class ix on ix.oid = i.indexrelid
  where not i.indisvalid or not i.indisready
)
select jsonb_build_object(
  'version_auditoria', 1,
  'generado_en', current_timestamp,
  'postgres_version', current_setting('server_version'),
  'solo_metadatos', true,
  'resumen', coalesce((select jsonb_object_agg(codigo, cantidad) from (
    select codigo, count(*) as cantidad from hallazgos group by codigo
  ) x), '{}'::jsonb),
  'hallazgos', coalesce((select jsonb_agg(to_jsonb(h) order by prioridad, codigo, esquema, objeto) from hallazgos h), '[]'::jsonb),
  'tablas', coalesce((select jsonb_agg(jsonb_build_object(
    'esquema', t.nspname, 'tabla', t.relname, 'rls', t.relrowsecurity,
    'filas_estimadas', s.n_live_tup, 'filas_muertas_estimadas', s.n_dead_tup,
    'bytes_totales', pg_total_relation_size(t.oid),
    'last_analyze', s.last_analyze, 'last_autoanalyze', s.last_autoanalyze,
    'last_autovacuum', s.last_autovacuum
  ) order by t.nspname, t.relname) from tablas t
    left join pg_stat_user_tables s on s.relid = t.oid), '[]'::jsonb),
  'limites', jsonb_build_array(
    'No valida Auth, copias de seguridad, red, TLS, Storage ni configuracion de la Data API.',
    'No demuestra que los permisos internos de cada RPC sean correctos.',
    'La ausencia de pg_default_acl no elimina el EXECUTE por defecto de PUBLIC para otros creadores.',
    'Las estadisticas son estimaciones acumuladas; no justifican por si solas crear o borrar indices.'
  )
) as auditoria;
