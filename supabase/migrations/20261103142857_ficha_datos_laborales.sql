begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';
-- Se conserva el nombre y argumento de la RPC. Solo se amplía el JSON de salida.
drop function public.rpc_ficha_personas(text);
drop function private.ficha_personas(text);

create function private.ficha_personas(p_buscar text default null)
returns table(dni bigint, apellido_nombre text, legajo integer, carrera text,
  situacion_revista text, funcion text, activo boolean, reloj integer, fecha_ingreso date, fecha_nacimiento date, telefono text, domicilio text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not public.can_ficha_read() then
    raise exception 'Sin permiso para consultar fichas.' using errcode = '42501';
  end if;
  return query
  select p.dni, btrim(p.apellido || ' ' || p.nombre), p.legajo,
    coalesce((select string_agg(c.nombre, ', ' order by c.nombre)
      from public.persona_carreras pc join public.carreras c on c.id = pc.carrera_id
      where pc.dni = p.dni), ''),
    coalesce((select string_agg(s.nombre, ', ' order by s.nombre)
      from public.persona_situacion_revista ps join public.situacion_revista s on s.id = ps.situacion_id
      where ps.dni = p.dni), ''),
    coalesce((select string_agg(f.nombre, ', ' order by f.nombre)
      from public.persona_funciones pf join public.funciones f on f.id = pf.funcion_id
      where pf.dni = p.dni), ''),
    not exists(select 1 from public.persona_inactivo pi where pi.dni = p.dni),
    p.reloj, p.fecha_ingreso, p.fecha_nacimiento, p.telefono,
    coalesce((select concat_ws(', ',
      nullif(btrim(concat_ws(' ',d.calle,d.numero)),''),
      case when nullif(btrim(d.barrio),'') is not null then 'Barrio '||d.barrio end,
      case when nullif(btrim(d.manzana),'') is not null then 'Mza. '||d.manzana end,
      case when nullif(btrim(d.lote),'') is not null then 'Lote '||d.lote end,
      case when nullif(btrim(d.casa),'') is not null then 'Casa '||d.casa end,
      case when nullif(btrim(d.monoblock),'') is not null then 'Monoblock '||d.monoblock end,
      case when nullif(btrim(d.torre),'') is not null then 'Torre '||d.torre end,
      case when nullif(btrim(d.piso),'') is not null then 'Piso '||d.piso end,
      case when nullif(btrim(d.departamento),'') is not null then 'Dto. '||d.departamento end,
      nullif(btrim(d.localidad_nombre),''),nullif(btrim(d.provincia_nombre),''))
      from public.persona_domicilios d where d.persona_dni=p.dni and d.vigente_hasta is null
      order by d.vigente_desde desc,d.id desc limit 1),'')
  from public.personas p
  where public.busqueda_coincide(array[p.apellido, p.nombre, p.dni::text, p.legajo::text],
    public.busqueda_terminos(p_buscar))
  order by p.apellido, p.nombre, p.dni limit 100;
end;
$$;
create function public.rpc_ficha_personas(p_buscar text default null)
returns table(dni bigint, apellido_nombre text, legajo integer, carrera text,
  situacion_revista text, funcion text, activo boolean, reloj integer, fecha_ingreso date, fecha_nacimiento date, telefono text, domicilio text)
language sql stable security invoker set search_path = '' as $$
  select * from private.ficha_personas(p_buscar);
$$;
revoke all on function public.rpc_ficha_personas(text), private.ficha_personas(text)
  from public, anon, authenticated;
grant execute on function public.rpc_ficha_personas(text), private.ficha_personas(text)
  to authenticated;
notify pgrst, 'reload schema';
commit;
