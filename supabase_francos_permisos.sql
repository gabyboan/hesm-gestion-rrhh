-- Reglas recomendadas para reforzar Francos del lado de Supabase.
-- Revisar antes de ejecutar: si ya existen helpers equivalentes, reutilizarlos.

create or replace function public.usuario_tiene_rol(p_codigo text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuario_roles ur
    join public.roles r on r.id = ur.rol_id
    where ur.usuario_id = auth.uid()
      and r.codigo = p_codigo
  );
$$;

-- Dentro de rpc_francos_crear, aplicar esta regla antes de insertar:
--
-- if p_minutos > 0 and not public.usuario_tiene_rol('FRANCOS_ADM') then
--   raise exception 'Sin permiso para sumar banco de francos';
-- end if;
--
-- if p_minutos < 0
--    and not (
--      public.usuario_tiene_rol('FRANCOS_CARGA')
--      or public.usuario_tiene_rol('FRANCOS_ADM')
--    ) then
--   raise exception 'Sin permiso para cargar uso de francos';
-- end if;

-- Dentro de rpc_francos_modificar y rpc_francos_eliminar, aplicar:
--
-- if not public.usuario_tiene_rol('FRANCOS_ADM') then
--   raise exception 'Sin permiso para administrar movimientos de francos';
-- end if;

-- Roles esperados:
-- FRANCOS_CARGA: puede restar/usar francos.
-- FRANCOS_ADM: puede sumar banco inicial, modificar y anular movimientos.
