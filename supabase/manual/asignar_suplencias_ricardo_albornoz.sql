-- Asignacion puntual e idempotente del modulo Suplencias.
-- Ejecutar en Supabase SQL Editor con una cuenta administradora.

do $$
declare
  v_usuario_id uuid;
  v_rol_id bigint;
begin
  select u.id
  into strict v_usuario_id
  from public.usuarios u
  where lower(trim(coalesce(u.nombre, ''))) like 'ricardo%'
    and lower(trim(coalesce(u.apellido, ''))) = 'albornoz';

  select r.id
  into strict v_rol_id
  from public.roles r
  where r.id = 31
    and r.codigo = 'SUPLENCIAS_LECTURA';

  insert into public.usuario_roles (usuario_id, rol_id)
  values (v_usuario_id, v_rol_id)
  on conflict do nothing;
end;
$$;

-- Verificacion: debe devolver una unica fila para Ricardo Albornoz.
select
  u.id as usuario_id,
  u.auth_user_id,
  u.dni,
  concat_ws(' ', u.nombre, u.apellido) as usuario,
  r.id as rol_id,
  r.codigo as rol_codigo,
  r.nombre as rol_nombre
from public.usuario_roles ur
join public.usuarios u on u.id = ur.usuario_id
join public.roles r on r.id = ur.rol_id
where lower(trim(coalesce(u.nombre, ''))) like 'ricardo%'
  and lower(trim(coalesce(u.apellido, ''))) = 'albornoz'
  and r.id = 31
  and r.codigo = 'SUPLENCIAS_LECTURA';
