begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- Los 30 tipos originales conservan los nombres y el orden del Excel.
-- Un tipo puede tener variantes de código, sin duplicarse en el filtro.
alter table public.licencias_tipos add column categoria_excel_id smallint
  references public.licencias_tipos(id) check (categoria_excel_id between 1 and 30);
create index licencias_tipos_categoria_excel_idx on public.licencias_tipos(categoria_excel_id);
update public.licencias_tipos set categoria_excel_id=id where id between 1 and 30;
update public.licencias_tipos t set categoria_excel_id=m.categoria from (values
  (101,6),(103,7),(104,1),(110,3),(111,3),(112,8),(114,12),(115,13),
  (126,15),(129,9),(143,5),(160,4),(161,18),(162,27),(163,27),
  (164,28),(165,28),(170,16),(198,5)
) m(id,categoria) where t.id=m.id;

-- Confirmación del usuario: Profiláctica es 03. El 02 deja de ofrecerse.
update public.licencias_tipos set nombre='Licencia Profiláctica (código 03)',
  columna_ficha='PROFILACTICA' where codigo='03';
update public.licencias_tipos set habilitado_para_carga=id in (
  104,2,110,111,160,101,103,112,129,10,11,114,115,14,126,170,17,161,
  19,20,21,22,23,24,25,26,162,163,164,165,29,30
);

create view public.licencias_tipos_excel with (security_invoker=true) as
select t.id,c.nombre,t.nombre as descripcion,t.codigo,t.columna_ficha,
  t.habilitado_para_carga,t.categoria_excel_id
from public.licencias_tipos t join public.licencias_tipos c on c.id=t.categoria_excel_id
where t.habilitado_para_carga or t.codigo in('43','98');
revoke all on public.licencias_tipos_excel from public,anon,authenticated;
grant select on public.licencias_tipos_excel to authenticated;
comment on view public.licencias_tipos_excel is
  'Catálogo limitado a los 30 tipos del Excel; Imprevistos solo se consulta desde su módulo.';

-- Impide elegir tipos ajenos al Excel, incluso al editar una importación confirmada.
-- Los originales apartados y las ediciones sin cambio de tipo se conservan.
create or replace function private.licencias_validar_catalogo() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if (new.origen_archivo is null or new.importacion_confirmada) and
    (tg_op='INSERT' or new.tipo_id is distinct from old.tipo_id) and not exists(
      select 1 from public.licencias_tipos where id=new.tipo_id and habilitado_para_carga
    ) then
    -- La secuencia histórica de Art. 8 puede reordenarse por sus propios triggers.
    if tg_op='UPDATE' and pg_trigger_depth()>1 and exists(
      select 1 from public.licencias_tipos n,public.licencias_tipos o
      where n.id=new.tipo_id and o.id=old.tipo_id
        and n.codigo in('43','98') and o.codigo in('43','98')
    ) then return new; end if;
    raise exception 'Seleccioná un tipo de licencia habilitado del Excel.' using errcode='22023';
  end if;
  return new;
end;
$$;

-- Conserva el historial integrado y los permisos; agrega la categoría para filtrar.
-- La RPC pública mantiene su cálculo de días hábiles de Estudio.
create or replace function private.licencias_historial(
  p_anio integer default null,p_persona_dni bigint default null,
  p_offset integer default 0,p_limite integer default 500
) returns setof jsonb language plpgsql stable security definer set search_path='' as $$
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
      'desde',l.desde,'hasta',l.hasta,'dias',l.dias,'observacion',l.observacion,
      'anulado_at',l.anulado_at,'origen_fila',l.origen_fila,'dni_familiar',l.dni_familiar,
      'numero_orden',l.numero_orden,'cantidad_ficha',l.cantidad_ficha,'imprevisto_id',null
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
$$;

notify pgrst,'reload schema';
commit;
