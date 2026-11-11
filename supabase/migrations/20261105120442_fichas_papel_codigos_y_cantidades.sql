begin;
set local lock_timeout='3s';
set local statement_timeout='45s';

-- Equivalencias operativas confirmadas en las fichas; no recodifica históricos.
do $$ begin
  if exists(select 1 from public.licencias_registros where tipo_id in(120,121,127)) then
    raise exception 'Revisar históricos antes de cambiar las descripciones 20, 21 y 27.';
  end if;
end; $$;
alter table public.licencias_tipos drop constraint licencias_tipos_codigo_key;
-- Solo A.R.T. comparte 04/07 con Enfermedad; los demás códigos siguen siendo únicos.
create unique index licencias_tipos_codigo_unico_idx on public.licencias_tipos(codigo)
  where codigo not in('04','07');
create unique index licencias_tipos_codigo_categoria_idx on public.licencias_tipos(codigo,categoria_excel_id)
  where codigo in('04','07');
alter table public.licencias_tipos add constraint licencias_tipos_codigos_compartidos_check
  check(codigo not in('04','07') or (categoria_excel_id is not null and
    ((codigo='04' and categoria_excel_id in(1,8)) or (codigo='07' and categoria_excel_id in(2,8))))) not valid;
update public.licencias_tipos set categoria_excel_id=2,habilitado_para_carga=true where id=107;
alter table public.licencias_tipos validate constraint licencias_tipos_codigos_compartidos_check;
update public.licencias_tipos set nombre='Duelo por hermana (código 20)',
  categoria_excel_id=11,habilitado_para_carga=true where id=120;
update public.licencias_tipos set nombre='Duelo por abuela (código 21)',
  categoria_excel_id=11,habilitado_para_carga=true where id=121;
update public.licencias_tipos set nombre='Matrimonio del agente (código 27)',
  categoria_excel_id=14,habilitado_para_carga=true where id=127;
update public.licencias_tipos set habilitado_para_carga=false where id in(2,10,14,112,170);
insert into public.licencias_tipos(id,codigo,nombre,columna_ficha,habilitado_para_carga,categoria_excel_id)
values(132,'32','Curso de perfeccionamiento (código 32)',null,true,10),
  (150,'50','Gremial (código 50)',null,true,16),
  (204,'04','A.R.T. (código 04)','ENFERMEDAD',true,8),
  (207,'07','A.R.T. (código 07)','ENFERMEDAD',true,8);

-- Cantidad explícita del papel, separada de la duración calendario y del año del cupo.
alter table public.licencias_registros
  add column cantidad_dias_ficha integer check(cantidad_dias_ficha>0),
  add column anio_cupo integer check(anio_cupo between 1900 and 9998),
  add constraint licencias_cantidad_ficha_un_anio_check check(cantidad_dias_ficha is null or
    (extract(year from desde)=extract(year from hasta) and cantidad_dias_ficha<=dias)),
  add constraint licencias_anio_cupo_cantidad_check check(anio_cupo is null or cantidad_dias_ficha is not null);
comment on column public.licencias_registros.cantidad_dias_ficha is
  'Días explícitos de una ficha verificada; no se deducen automáticamente de cantidad_ficha.';

create function private.licencias_invalidar_cantidad_papel() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if (new.dni,new.tipo_id,new.desde,new.hasta) is distinct from (old.dni,old.tipo_id,old.desde,old.hasta) then
    new.cantidad_dias_ficha:=null;new.anio_cupo:=null;new.cantidad_ficha:=null;
  elsif new.cantidad_ficha is distinct from old.cantidad_ficha then
    new.cantidad_dias_ficha:=null;new.anio_cupo:=null;
  end if;
  return new;
end; $$;
revoke all on function private.licencias_invalidar_cantidad_papel() from public,anon,authenticated;
create trigger licencias_invalidar_cantidad_papel before update on public.licencias_registros
  for each row execute function private.licencias_invalidar_cantidad_papel();

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
      'desde',l.desde,'hasta',l.hasta,'dias',coalesce(l.cantidad_dias_ficha,l.dias),
      'dias_calendario',l.dias,'dias_por_anio',case when l.cantidad_dias_ficha is not null then
        jsonb_build_object(extract(year from l.desde)::integer::text,l.cantidad_dias_ficha) end,
      'observacion',case when t.categoria_excel_id=8 and coalesce(l.observacion,'') not ilike '%A.R.T.%'
        then concat_ws('; ',nullif(l.observacion,''),'A.R.T.') else l.observacion end,
      'anulado_at',l.anulado_at,'origen_fila',l.origen_fila,'dni_familiar',l.dni_familiar,
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
$$;


notify pgrst,'reload schema';
commit;
