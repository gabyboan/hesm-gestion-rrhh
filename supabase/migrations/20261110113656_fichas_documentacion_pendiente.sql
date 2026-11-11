begin;
set local lock_timeout='3s';
alter table public.licencias_registros add column documentacion_pendiente boolean not null default false;
comment on column public.licencias_registros.documentacion_pendiente is 'Anotación visible en gris, pendiente de recibir documentación. Independiente de la confirmación de importaciones y de la ausencia de orden.';

CREATE OR REPLACE FUNCTION private.licencias_historial(p_anio integer DEFAULT NULL::integer, p_persona_dni bigint DEFAULT NULL::bigint, p_offset integer DEFAULT 0, p_limite integer DEFAULT 500)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select auth.uid()) is null or
    not (public.can_ficha_read() or public.can_licencias_read()) then
    raise exception 'Sin permiso para consultar el historial de licencias.' using errcode='42501';
  end if;
  if (p_anio is not null and (p_anio<2026 or p_anio>9998)) or
    p_offset is null or p_offset<0 or p_limite is null or p_limite<1 or p_limite>500 then
    raise exception 'Período o paginación inválidos.' using errcode='22023';
  end if;
  return query
  with licencias as (
    select l.id,l.desde,jsonb_build_object(
      'id',l.id,'dni',l.dni,'persona_dni',l.persona_dni,'apellido_nombre',l.apellido_nombre,
      'carrera',l.carrera,'situacion_revista',l.situacion_revista,'funcion',l.funcion,
      'tipo_id',l.tipo_id,'categoria_excel_id',t.categoria_excel_id,
      'tipo',jsonb_build_object('nombre',coalesce(cat.nombre,t.nombre),'codigo',t.codigo,'columna_ficha',t.columna_ficha),
      'desde',l.desde,'hasta',l.hasta,'dias',coalesce(l.cantidad_dias_ficha,l.dias),
      'dias_calendario',l.dias,'dias_por_anio',case when l.cantidad_dias_ficha is not null then
        jsonb_build_object(extract(year from l.desde)::integer::text,l.cantidad_dias_ficha) end,
      'observacion',case when t.categoria_excel_id=8 and coalesce(l.observacion,'') not ilike '%A.R.T.%'
        then concat_ws('; ',nullif(l.observacion,''),'A.R.T.') else l.observacion end,
      'anulado_at',l.anulado_at,'origen_fila',l.origen_fila,'dni_familiar',l.dni_familiar,
      'documentacion_pendiente',l.documentacion_pendiente,
      'numero_orden',l.numero_orden,'cantidad_ficha',l.cantidad_ficha,'imprevisto_id',null,
      'cantidad_dias_ficha',l.cantidad_dias_ficha,'anio_cupo',l.anio_cupo,
      'origen_documento',case when l.origen_archivo like 'pdf:%' then 'PDF' when l.origen_archivo is not null then 'Excel' end,
      'origen_pagina',case when l.origen_archivo like 'pdf:%' then (l.origen_datos->>'pagina')::integer end
    ) as registro
    from public.licencias_registros l join public.licencias_tipos t on t.id=l.tipo_id
    left join public.licencias_tipos cat on cat.id=t.categoria_excel_id
    where l.importacion_confirmada and l.desde>=date '2026-01-01'
      and (p_persona_dni is null or l.persona_dni=p_persona_dni)
      and (p_anio is null or (l.desde<=make_date(p_anio,12,31) and l.hasta>=make_date(p_anio,1,1)))
      and not(l.origen_archivo is not null and
        (coalesce(t.codigo,'') in('43','98') or t.nombre='Imprevisto'))
  ), imprevistos_ordenados as (
    select i.*,p.apellido,p.nombre,
      row_number() over(partition by i.dni,i.anio order by i.id) as orden_carga
    from public.imprevistos_registros i join public.personas p on p.dni=i.dni
    where i.deleted_at is null and i.fecha>=date '2026-01-01'
      and (p_persona_dni is null or i.dni=p_persona_dni)
      and (p_anio is null or i.anio=p_anio)
  ), imprevistos as (
    select -i.id as id,i.fecha as desde,jsonb_build_object(
      'id',-i.id,'dni',i.dni,'persona_dni',i.dni,
      'apellido_nombre',btrim(i.apellido||' '||i.nombre),'carrera',coalesce(c.nombre,''),
      'situacion_revista',coalesce((select string_agg(distinct s.nombre,', ' order by s.nombre)
        from public.persona_situacion_revista ps join public.situacion_revista s on s.id=ps.situacion_id
        where ps.dni=i.dni),''),
      'funcion',coalesce((select string_agg(distinct f.nombre,', ' order by f.nombre)
        from public.persona_funciones pf join public.funciones f on f.id=pf.funcion_id
        where pf.dni=i.dni),''),
      'tipo_id',t.id,'categoria_excel_id',t.categoria_excel_id,
      'tipo',jsonb_build_object('nombre',cat.nombre,'codigo',t.codigo,'columna_ficha',t.columna_ficha),
      'desde',i.fecha,'hasta',i.fecha,'dias',1,'observacion',i.observacion,
      'anulado_at',null,'origen_fila',null,'dni_familiar',null,
      'numero_orden',i.numero_orden,'cantidad_ficha',null,'imprevisto_id',i.id
    ) as registro
    from imprevistos_ordenados i left join public.carreras c on c.id=i.carrera_id
    join public.licencias_tipos t on t.codigo=case when i.orden_carga=1 then '43' else '98' end
    join public.licencias_tipos cat on cat.id=t.categoria_excel_id
  )
  select h.registro from(select * from licencias union all select * from imprevistos) h
  order by h.desde desc,h.id desc limit p_limite offset p_offset;
end;
$function$;

notify pgrst,'reload schema';
commit;
