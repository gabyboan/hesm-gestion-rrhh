begin;

-- El filtro se aplica antes de devolver filas: consultar un día antiguo
-- no depende de los últimos 500 registros del listado general.
create function private.medicos_registros_dia(p_fecha date, p_buscar text)
returns setof public.partes_medicos
language plpgsql stable security definer set search_path = ''
as $$
declare v_terminos text[] := public.busqueda_terminos(p_buscar);
begin
  if (select auth.uid()) is null then raise exception 'No autenticado.'; end if;
  if public.can_medicos_read() is not true then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;
  if p_fecha is null then raise exception 'Indica la fecha de emision.'; end if;
  return query select pm.* from public.partes_medicos pm
  where pm.fecha = p_fecha and pm.anulado_at is null
    and public.busqueda_coincide(array[
      pm.dni::text, pm.empleado_legajo::text, pm.empleado_apellido,
      pm.empleado_nombre, pm.familiar_apellido_nombre, pm.familiar_dni::text,
      pm.aclaracion_fecha_turno, pm.id::text, pm.codigo_qr,
      'PM-' || regexp_replace(pm.codigo_qr, '(.{4})(?=.)', '\1-', 'g')
    ], v_terminos)
  order by pm.id;
end;
$$;
revoke all on function private.medicos_registros_dia(date,text) from public, anon, authenticated;
grant execute on function private.medicos_registros_dia(date,text) to authenticated;

create function public.rpc_medicos_registros_dia(p_fecha date, p_buscar text default null)
returns setof public.partes_medicos
language sql stable security invoker set search_path = ''
as $$ select * from private.medicos_registros_dia(p_fecha, p_buscar); $$;
revoke all on function public.rpc_medicos_registros_dia(date,text) from public, anon;
grant execute on function public.rpc_medicos_registros_dia(date,text) to authenticated;

notify pgrst, 'reload schema';
commit;
