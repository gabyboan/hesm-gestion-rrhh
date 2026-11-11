begin;
set local lock_timeout='3s';
set local statement_timeout='45s';

-- Regla operativa confirmada por el usuario: 29, 20 hábiles/año, 5 por solicitud.
insert into public.licencias_tipos(id,codigo,nombre,columna_ficha,habilitado_para_carga)
values(129,'29','Licencia por Estudio','ESTUDIO',true);

create function private.licencias_contar_habiles(p_desde date,p_hasta date)
returns integer language sql stable security invoker set search_path='' as $$
  select count(*)::integer from generate_series(0,p_hasta-p_desde) n
  where public.es_dia_laborable(p_desde+n);
$$;

create function private.licencias_estudio_hasta(p_desde date,p_dias integer)
returns date language plpgsql stable security definer set search_path='' as $$
declare v_hasta date;
begin
  if (select auth.uid()) is null or not public.can_licencias_read() then
    raise exception 'Sin permiso para consultar licencias.' using errcode='42501';
  end if;
  if p_desde is null or p_desde<date '2026-01-01' or p_dias is null or p_dias<1 or p_dias>5 then
    raise exception 'Estudio admite de 1 a 5 días hábiles por solicitud.' using errcode='22023';
  end if;
  select p_desde+n into v_hasta from generate_series(0,366) n
    where public.es_dia_laborable(p_desde+n) order by n offset p_dias-1 limit 1;
  if v_hasta is null then
    raise exception 'Revisá el calendario: no se encontraron suficientes días hábiles.' using errcode='22023';
  end if;
  return v_hasta;
end;
$$;
create function public.rpc_licencias_estudio_hasta(p_desde date,p_dias integer)
returns date language sql stable security invoker set search_path='' as $$
  select private.licencias_estudio_hasta(p_desde,p_dias);
$$;

create function private.licencias_estudio_datos(p_registro jsonb)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare v_desde date;v_hasta date;v_anios jsonb;
begin
  if p_registro->'tipo'->>'codigo' is distinct from '29' then return p_registro; end if;
  v_desde:=(p_registro->>'desde')::date;v_hasta:=(p_registro->>'hasta')::date;
  select jsonb_object_agg(y::text,private.licencias_contar_habiles(
    greatest(v_desde,make_date(y,1,1)),least(v_hasta,make_date(y,12,31)))) into v_anios
    from generate_series(extract(year from v_desde)::integer,extract(year from v_hasta)::integer) y;
  return p_registro||jsonb_build_object('dias_calendario',p_registro->'dias',
    'dias',private.licencias_contar_habiles(v_desde,v_hasta),'dias_por_anio',v_anios);
end;
$$;

-- Conserva el filtro de permisos, la paginación y la fuente de Imprevistos.
create or replace function public.rpc_licencias_historial(
  p_anio integer default null,p_persona_dni bigint default null,
  p_offset integer default 0,p_limite integer default 500
) returns setof jsonb language sql stable security invoker set search_path='' as $$
  select private.licencias_estudio_datos(r) from private.licencias_historial(p_anio,p_persona_dni,p_offset,p_limite) r;
$$;
revoke all on function private.licencias_contar_habiles(date,date),
  private.licencias_estudio_datos(jsonb),private.licencias_estudio_hasta(date,integer),
  public.rpc_licencias_estudio_hasta(date,integer),
  public.rpc_licencias_historial(integer,bigint,integer,integer) from public,anon,authenticated;
grant execute on function private.licencias_contar_habiles(date,date),
  private.licencias_estudio_datos(jsonb),private.licencias_estudio_hasta(date,integer),
  public.rpc_licencias_estudio_hasta(date,integer),
  public.rpc_licencias_historial(integer,bigint,integer,integer) to authenticated;

create function private.licencias_validar_estudio() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_dias integer;v_anio integer;v_usados integer;v_solicitados integer;
begin
  if not new.importacion_confirmada or new.anulado_at is not null or not exists(
    select 1 from public.licencias_tipos where id=new.tipo_id and codigo='29'
  ) then return new; end if;
  if tg_op='UPDATE' and (new.dni,new.tipo_id,new.desde,new.hasta,new.importacion_confirmada,new.anulado_at)
    is not distinct from (old.dni,old.tipo_id,old.desde,old.hasta,old.importacion_confirmada,old.anulado_at) then
    return new;
  end if;
  -- El mismo bloqueo que utilizan carga, edición y anulación de licencias.
  perform 1 from public.personas where dni=new.dni for update;
  v_dias:=private.licencias_contar_habiles(new.desde,new.hasta);
  if v_dias<1 or v_dias>5 then
    raise exception 'Estudio admite de 1 a 5 días hábiles por solicitud.' using errcode='22023';
  end if;
  for v_anio in extract(year from new.desde)::integer..extract(year from new.hasta)::integer loop
    v_solicitados:=private.licencias_contar_habiles(greatest(new.desde,make_date(v_anio,1,1)),least(new.hasta,make_date(v_anio,12,31)));
    select coalesce(sum(private.licencias_contar_habiles(greatest(l.desde,make_date(v_anio,1,1)),
      least(l.hasta,make_date(v_anio,12,31)))),0)::integer into v_usados
    from public.licencias_registros l join public.licencias_tipos t on t.id=l.tipo_id
    where l.dni=new.dni and l.importacion_confirmada and l.anulado_at is null and t.codigo='29'
      and l.id is distinct from new.id and l.desde<=make_date(v_anio,12,31) and l.hasta>=make_date(v_anio,1,1);
    if v_usados+v_solicitados>20 then
      raise exception 'Estudio: en % quedan % días hábiles del cupo anual de 20.',v_anio,greatest(20-v_usados,0)
        using errcode='22023';
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function private.licencias_validar_estudio() from public,anon,authenticated;
create trigger licencias_validar_estudio before insert or update of tipo_id,desde,hasta,importacion_confirmada,anulado_at
  on public.licencias_registros for each row execute function private.licencias_validar_estudio();

notify pgrst,'reload schema';
commit;
