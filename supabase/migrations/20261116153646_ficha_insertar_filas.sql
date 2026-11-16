begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- Solo orden de presentación. Los datos y las anulaciones siguen en su origen.
create table private.licencias_ficha_orden (
  dni bigint not null references public.personas(dni),
  anio integer not null check (anio between 2026 and 9998),
  registros bigint[] not null check (cardinality(registros) <= 10000),
  updated_at timestamptz not null default now(),
  updated_by uuid not null,
  primary key (dni, anio)
);
alter table private.licencias_ficha_orden enable row level security;
revoke all on private.licencias_ficha_orden from public, anon, authenticated;

create function private.licencias_historial_ficha(p_anio integer, p_persona_dni bigint,
  p_offset integer, p_limite integer) returns setof jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not (public.can_ficha_read() or public.can_licencias_read()) then
    raise exception 'Sin permiso para consultar fichas.' using errcode = '42501';
  end if;
  perform private.exigir_mfa_si_activado();
  perform private.gestion_sesion_exigir();
  return query
    select private.licencias_estudio_datos(h.registro) || jsonb_build_object(
      'orden_ficha_por_anio', coalesce((
        select jsonb_object_agg(o.anio::text, array_position(o.registros, (h.registro->>'id')::bigint))
        from private.licencias_ficha_orden o
        where o.dni = (h.registro->>'dni')::bigint and (p_anio is null or o.anio = p_anio)
          and (h.registro->>'id')::bigint = any(o.registros)
      ), '{}'::jsonb))
    from private.licencias_historial(p_anio, p_persona_dni, p_offset, p_limite) h(registro);
end;
$$;

create or replace function public.rpc_licencias_historial(p_anio integer default null,
  p_persona_dni bigint default null, p_offset integer default 0, p_limite integer default 500)
returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select * from private.licencias_historial_ficha(p_anio, p_persona_dni, p_offset, p_limite);
$$;

create function private.licencias_insertar_en_ficha(p_datos jsonb, p_anio integer,
  p_referencia_id bigint, p_lado text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_dni bigint;
  v_id bigint;
  v_previos bigint[];
  v_ids bigint[];
  v_historial jsonb := '[]'::jsonb;
  v_pagina jsonb;
  v_offset integer := 0;
  v_indice integer;
begin
  if (select auth.uid()) is null or not public.can_ficha_read() or not public.can_licencias_create() then
    raise exception 'Sin permiso para añadir licencias en la ficha.' using errcode = '42501';
  end if;
  perform private.exigir_mfa_si_activado();
  perform private.gestion_sesion_exigir();
  if p_datos is null or jsonb_typeof(p_datos) <> 'object' or
    p_datos - array['p_dni','p_tipo_id','p_desde','p_hasta','p_observacion','p_dni_familiar','p_numero_orden','p_cantidad_ficha'] <> '{}'::jsonb or
    p_anio is null or p_anio not between 2026 and 9998 or p_lado is null or p_lado not in ('arriba','abajo') then
    raise exception 'La fila indicada es inválida.' using errcode = '22023';
  end if;
  v_dni := (p_datos->>'p_dni')::bigint;
  if (p_datos->>'p_desde')::date is null or (p_datos->>'p_hasta')::date is null or
    (p_datos->>'p_desde')::date > make_date(p_anio,12,31) or (p_datos->>'p_hasta')::date < make_date(p_anio,1,1) then
    raise exception 'El período debe incluir días del año de la ficha.' using errcode = '22023';
  end if;
  -- Mismo orden de bloqueo que las cargas de Estudio y las correcciones.
  perform 1 from public.personas where dni = v_dni for update;
  if not found then raise exception 'La persona no existe.' using errcode = '22023'; end if;
  select registros into v_previos from private.licencias_ficha_orden
    where dni = v_dni and anio = p_anio for update;
  loop
    select coalesce(jsonb_agg(r), '[]'::jsonb) into v_pagina
      from private.licencias_historial(p_anio, v_dni, v_offset, 500) r;
    v_historial := v_historial || v_pagina;
    exit when jsonb_array_length(v_pagina) < 500;
    v_offset := v_offset + 500;
  end loop;
  select coalesce(array_agg((r->>'id')::bigint order by
    array_position(v_previos,(r->>'id')::bigint) nulls last, r->>'desde', (r->>'id')::bigint), '{}'::bigint[])
    into v_ids from jsonb_array_elements(v_historial) r where r->>'anulado_at' is null;
  if cardinality(v_ids) >= 10000 then raise exception 'La ficha alcanzó el máximo de filas.' using errcode = '22023'; end if;
  if p_referencia_id is not null then
    v_indice := array_position(v_ids, p_referencia_id);
    if v_indice is null then
      raise exception 'La licencia de referencia cambió. Actualizá la ficha.' using errcode = '40001';
    end if;
    if p_lado = 'abajo' then v_indice := v_indice + 1; end if;
  else
    v_indice := cardinality(v_ids) + 1;
  end if;
  v_id := private.licencias_guardar_con_datos(null, v_dni, (p_datos->>'p_tipo_id')::smallint,
    (p_datos->>'p_desde')::date, (p_datos->>'p_hasta')::date, p_datos->>'p_observacion',
    (p_datos->>'p_dni_familiar')::bigint, (p_datos->>'p_numero_orden')::integer, p_datos->>'p_cantidad_ficha');
  v_ids := coalesce(v_ids[1:v_indice-1], '{}'::bigint[]) || array[v_id] || coalesce(v_ids[v_indice:cardinality(v_ids)], '{}'::bigint[]);
  insert into private.licencias_ficha_orden(dni, anio, registros, updated_by)
    values(v_dni, p_anio, v_ids, (select auth.uid()))
    on conflict(dni, anio) do update set registros = excluded.registros,
      updated_at = clock_timestamp(), updated_by = excluded.updated_by;
  return v_id;
end;
$$;

create function public.rpc_licencias_insertar_en_ficha(p_datos jsonb, p_anio integer,
  p_referencia_id bigint default null, p_lado text default 'abajo') returns bigint
language sql security invoker set search_path = '' as $$
  select private.licencias_insertar_en_ficha(p_datos, p_anio, p_referencia_id, p_lado);
$$;

revoke all on function private.licencias_historial_ficha(integer,bigint,integer,integer),
  private.licencias_insertar_en_ficha(jsonb,integer,bigint,text),
  public.rpc_licencias_insertar_en_ficha(jsonb,integer,bigint,text) from public, anon, authenticated;
grant execute on function private.licencias_historial_ficha(integer,bigint,integer,integer),
  private.licencias_insertar_en_ficha(jsonb,integer,bigint,text),
  public.rpc_licencias_insertar_en_ficha(jsonb,integer,bigint,text) to authenticated;
notify pgrst, 'reload schema';
commit;
