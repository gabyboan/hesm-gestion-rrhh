-- Auditoria de permisos para HESM Gestion RRHH.
-- SOLO LECTURA: puede ejecutarse completo en Supabase SQL Editor.

-- 1. Usuarios y roles efectivos. Verificar especialmente que cada usuario
-- tenga solamente los modulos que necesita.
select
  u.id as usuario_id,
  u.auth_user_id,
  u.dni,
  concat_ws(' ', u.nombre, u.apellido) as usuario,
  r.id as rol_id,
  r.codigo as rol_codigo,
  r.nombre as rol_nombre,
  r.ver_todo
from public.usuarios u
left join public.usuario_roles ur on ur.usuario_id = u.id
left join public.roles r on r.id = ur.rol_id
order by u.apellido nulls last, u.nombre nulls last, r.codigo;

-- 2. Resumen por usuario de permisos de modulos.
select
  u.id as usuario_id,
  u.auth_user_id,
  u.dni,
  concat_ws(' ', u.nombre, u.apellido) as usuario,
  bool_or(r.codigo = 'FRANCOS_LECTURA') as francos,
  bool_or(r.codigo = 'IMPREVISTOS_LECTURA') as imprevistos,
  bool_or(r.codigo = 'MEDICOS_LECTURA') as medicos,
  bool_or(r.codigo = 'SUPLENCIAS_LECTURA') as suplencias,
  array_remove(array_agg(distinct r.codigo order by r.codigo), null) as roles
from public.usuarios u
left join public.usuario_roles ur on ur.usuario_id = u.id
left join public.roles r on r.id = ur.rol_id
group by u.id, u.auth_user_id, u.dni, u.nombre, u.apellido
order by u.apellido nulls last, u.nombre nulls last;

-- 3. Roles de modulos existentes. Debe aparecer SUPLENCIAS_LECTURA.
select id, codigo, nombre, ver_todo
from public.roles
where codigo like any (array[
  'FRANCOS_%',
  'IMPREVISTOS_%',
  'MEDICOS_%',
  'SUPLENCIAS_%',
  'HORAS_%',
  'CAPACITACION_%'
])
order by codigo;

-- 4. Asignaciones duplicadas o que no enlazan con un perfil.
select ur.usuario_id, ur.rol_id, count(*) as repeticiones
from public.usuario_roles ur
group by ur.usuario_id, ur.rol_id
having count(*) > 1;

select ur.usuario_id, ur.rol_id
from public.usuario_roles ur
left join public.usuarios u on u.id = ur.usuario_id
left join public.roles r on r.id = ur.rol_id
where u.id is null or r.id is null;

-- 5. Estado RLS de todas las tablas expuestas en public.
-- ATENCION: cualquier fila con rls_activo = false requiere revision.
select
  c.relname as tabla,
  c.relrowsecurity as rls_activo,
  c.relforcerowsecurity as rls_forzado,
  count(p.policyname) as cantidad_politicas
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policies p
  on p.schemaname = n.nspname and p.tablename = c.relname
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
group by c.relname, c.relrowsecurity, c.relforcerowsecurity
order by c.relrowsecurity, c.relname;

-- 6. Definicion completa de las politicas de los modulos.
select
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual as using_expression,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'horas',
    'francos_movimientos',
    'imprevistos_registros',
    'partes_medicos',
    'suplencias'
  )
order by tablename, cmd, policyname;

-- 7. Politicas potencialmente abiertas: USING/WITH CHECK true para anon o
-- authenticated. Cada resultado debe justificarse manualmente.
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and (
    coalesce(qual, '') ~* '^\\s*\\(?\\s*true\\s*\\)?\\s*$'
    or coalesce(with_check, '') ~* '^\\s*\\(?\\s*true\\s*\\)?\\s*$'
  )
  and roles && array['anon', 'authenticated', 'public']::name[]
order by tablename, policyname;

-- 8. Vistas public que no declaran security_invoker.
-- Estas vistas pueden evadir el RLS de sus tablas base.
select
  n.nspname as esquema,
  c.relname as vista,
  coalesce(c.reloptions, array[]::text[]) as opciones
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'v'
  and not (
    coalesce(c.reloptions, array[]::text[])
    @> array['security_invoker=true']::text[]
  )
order by c.relname;

-- 9. Privilegios de anon/authenticated sobre tablas y vistas public.
select
  grantee,
  table_name,
  string_agg(distinct privilege_type, ', ' order by privilege_type) as privilegios
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee in ('anon', 'authenticated', 'PUBLIC')
group by grantee, table_name
order by table_name, grantee;

-- 10. Funciones SECURITY DEFINER en public ejecutables por PUBLIC o anon.
-- Cada resultado es una superficie privilegiada que debe revisarse.
select
  n.nspname as esquema,
  p.proname as funcion,
  pg_get_function_identity_arguments(p.oid) as argumentos,
  has_function_privilege('public', p.oid, 'EXECUTE') as ejecutable_por_public,
  has_function_privilege('anon', p.oid, 'EXECUTE') as ejecutable_por_anon,
  has_function_privilege('authenticated', p.oid, 'EXECUTE')
    as ejecutable_por_authenticated,
  p.proconfig as configuracion
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosecdef
  and (
    has_function_privilege('public', p.oid, 'EXECUTE')
    or has_function_privilege('anon', p.oid, 'EXECUTE')
  )
order by p.proname, argumentos;

-- 11. Comprobacion puntual del permiso de Suplencias por usuario.
select
  u.id as usuario_id,
  u.auth_user_id,
  u.dni,
  concat_ws(' ', u.nombre, u.apellido) as usuario,
  exists (
    select 1
    from public.usuario_roles ur
    join public.roles r on r.id = ur.rol_id
    where ur.usuario_id = u.id
      and r.codigo = 'SUPLENCIAS_LECTURA'
  ) as puede_ver_suplencias
from public.usuarios u
order by u.apellido nulls last, u.nombre nulls last;
