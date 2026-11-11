begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- Ficha y Licencias consultan el módulo de Imprevistos en tiempo real.
-- No se copian registros ni se conceden permisos de carga entre módulos.
create function private.licencias_historial(
  p_anio integer default null, p_persona_dni bigint default null,
  p_offset integer default 0, p_limite integer default 500
) returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
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
      'tipo_id',l.tipo_id,'tipo',jsonb_build_object('nombre',t.nombre,'codigo',t.codigo,'columna_ficha',t.columna_ficha),
      'desde',l.desde,'hasta',l.hasta,'dias',l.dias,'observacion',l.observacion,
      'anulado_at',l.anulado_at,'origen_fila',l.origen_fila,'dni_familiar',l.dni_familiar,
      'numero_orden',l.numero_orden,'cantidad_ficha',l.cantidad_ficha,'imprevisto_id',null
    ) as registro
    from public.licencias_registros l join public.licencias_tipos t on t.id=l.tipo_id
    where l.importacion_confirmada and l.desde>=date '2026-01-01'
      and (p_persona_dni is null or l.persona_dni=p_persona_dni)
      and (p_anio is null or (l.desde<=make_date(p_anio,12,31) and l.hasta>=make_date(p_anio,1,1)))
      -- El módulo es la fuente de los imprevistos. El Excel original se conserva.
      and not (l.origen_archivo is not null and
        (coalesce(t.codigo,'') in('43','98') or t.nombre='Imprevisto'))
  ), imprevistos_ordenados as (
    select i.*,p.apellido,p.nombre,
      row_number() over(partition by i.dni,i.anio order by i.id) as orden_carga
    from public.imprevistos_registros i join public.personas p on p.dni=i.dni
    where i.deleted_at is null and i.fecha>=date '2026-01-01'
      and (p_persona_dni is null or i.dni=p_persona_dni)
      and (p_anio is null or i.anio=p_anio)
  ), imprevistos as (
    -- ID negativo para que nunca pueda confundirse con una licencia editable.
    select -i.id as id,i.fecha as desde,jsonb_build_object(
      'id',-i.id,'dni',i.dni,'persona_dni',i.dni,
      'apellido_nombre',btrim(i.apellido||' '||i.nombre),
      'carrera',coalesce(c.nombre,''),
      'situacion_revista',coalesce((select string_agg(distinct s.nombre,', ' order by s.nombre)
        from public.persona_situacion_revista ps join public.situacion_revista s on s.id=ps.situacion_id
        where ps.dni=i.dni),''),
      'funcion',coalesce((select string_agg(distinct f.nombre,', ' order by f.nombre)
        from public.persona_funciones pf join public.funciones f on f.id=pf.funcion_id
        where pf.dni=i.dni),''),
      'tipo_id',t.id,'tipo',jsonb_build_object('nombre',t.nombre,'codigo',t.codigo,'columna_ficha',t.columna_ficha),
      'desde',i.fecha,'hasta',i.fecha,'dias',1,'observacion',i.observacion,
      'anulado_at',null,'origen_fila',null,'dni_familiar',null,
      'numero_orden',i.numero_orden,'cantidad_ficha',null,'imprevisto_id',i.id
    ) as registro
    from imprevistos_ordenados i left join public.carreras c on c.id=i.carrera_id
    join public.licencias_tipos t on t.codigo=case when i.orden_carga=1 then '43' else '98' end
  )
  select h.registro from (
    select * from licencias union all select * from imprevistos
  ) h order by h.desde desc,h.id desc limit p_limite offset p_offset;
end;
$$;

create function public.rpc_licencias_historial(
  p_anio integer default null, p_persona_dni bigint default null,
  p_offset integer default 0, p_limite integer default 500
) returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select * from private.licencias_historial(p_anio,p_persona_dni,p_offset,p_limite);
$$;
revoke all on function private.licencias_historial(integer,bigint,integer,integer),
  public.rpc_licencias_historial(integer,bigint,integer,integer) from public,anon,authenticated;
grant execute on function private.licencias_historial(integer,bigint,integer,integer),
  public.rpc_licencias_historial(integer,bigint,integer,integer) to authenticated;

-- Las cargas nuevas de Art. 8 se realizan en su módulo de origen.
-- Los registros históricos del Excel y las ediciones anteriores se conservan.
create function private.licencias_validar_origen_imprevisto() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if new.origen_archivo is null and exists(
    select 1 from public.licencias_tipos where id=new.tipo_id and codigo in('43','98')
  ) and (tg_op='INSERT' or not exists(
    select 1 from public.licencias_tipos where id=old.tipo_id and codigo in('43','98')
  )) then
    raise exception 'Los imprevistos se cargan desde el módulo Imprevistos.' using errcode='22023';
  end if;
  return new;
end;
$$;
revoke all on function private.licencias_validar_origen_imprevisto() from public,anon,authenticated;
create trigger licencias_validar_origen_imprevisto before insert or update of tipo_id
  on public.licencias_registros for each row execute function private.licencias_validar_origen_imprevisto();

notify pgrst,'reload schema';
commit;
