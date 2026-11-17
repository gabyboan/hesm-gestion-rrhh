begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- Regla confirmada: Anual (01 y categoría histórica 6) computa hábiles.
-- Comparte el calendario con Estudio; no se agrega un cupo anual ni por solicitud.
create function private.licencias_anual_hasta(p_desde date, p_dias integer)
returns date language plpgsql stable security definer set search_path = '' as $$
declare
  v_hasta date;
begin
  if (select auth.uid()) is null or not public.can_licencias_read() then
    raise exception 'Sin permiso para consultar licencias.' using errcode = '42501';
  end if;
  perform private.exigir_mfa_si_activado();
  perform private.gestion_sesion_exigir();
  -- Mismo límite técnico de cantidad que el formulario, sin establecer un cupo.
  if p_desde is null or p_desde < date '2026-01-01' or
      p_dias is null or p_dias < 1 or p_dias > 36500 then
    raise exception 'Ingresá una fecha desde 2026 y de 1 a 36500 días hábiles.' using errcode = '22023';
  end if;
  select p_desde + n into v_hasta
  from generate_series(0, p_dias * 2 + 366) n
  where public.es_dia_laborable(p_desde + n)
  order by n offset p_dias - 1 limit 1;
  if v_hasta is null then
    raise exception 'Revisá el calendario: no se encontraron suficientes días hábiles.' using errcode = '22023';
  end if;
  return v_hasta;
end;
$$;

create function public.rpc_licencias_anual_hasta(p_desde date, p_dias integer)
returns date language sql stable security invoker set search_path = '' as $$
  select private.licencias_anual_hasta(p_desde, p_dias);
$$;

-- Se conserva el nombre del adaptador usado por las RPC y el orden de la ficha.
-- Las cantidades verificadas del papel prevalecen para Anual.
create or replace function private.licencias_estudio_datos(p_registro jsonb)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  v_desde date;
  v_hasta date;
  v_anios jsonb;
  v_anual boolean := coalesce(p_registro->'tipo'->>'codigo' = '01', false)
    or coalesce(p_registro->>'categoria_excel_id' = '6', false);
begin
  if p_registro->'tipo'->>'codigo' is distinct from '29' and not v_anual then
    return p_registro;
  end if;
  if v_anual and p_registro->>'cantidad_dias_ficha' is not null then
    return p_registro;
  end if;
  v_desde := (p_registro->>'desde')::date;
  v_hasta := (p_registro->>'hasta')::date;
  select jsonb_object_agg(y::text, private.licencias_contar_habiles(
    greatest(v_desde, make_date(y,1,1)), least(v_hasta, make_date(y,12,31))))
  into v_anios
  from generate_series(extract(year from v_desde)::integer, extract(year from v_hasta)::integer) y;
  return p_registro || jsonb_build_object(
    'dias_calendario', coalesce(p_registro->>'dias_calendario', (v_hasta - v_desde + 1)::text)::integer,
    'dias', private.licencias_contar_habiles(v_desde, v_hasta), 'dias_por_anio', v_anios);
end;
$$;

create function private.licencias_validar_anual() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if not new.importacion_confirmada or new.anulado_at is not null or
      new.cantidad_dias_ficha is not null or not exists (
        select 1 from public.licencias_tipos t
        where t.id = new.tipo_id and (t.codigo = '01' or t.categoria_excel_id = 6)
      ) then
    return new;
  end if;
  if tg_op = 'UPDATE' and
      (new.dni, new.tipo_id, new.desde, new.hasta, new.importacion_confirmada, new.anulado_at)
      is not distinct from
      (old.dni, old.tipo_id, old.desde, old.hasta, old.importacion_confirmada, old.anulado_at) then
    return new;
  end if;
  if private.licencias_contar_habiles(new.desde, new.hasta) < 1 then
    raise exception 'La licencia anual debe incluir al menos un día hábil.' using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke all on function private.licencias_anual_hasta(date,integer),
  public.rpc_licencias_anual_hasta(date,integer), private.licencias_estudio_datos(jsonb),
  private.licencias_validar_anual() from public, anon, authenticated;
grant execute on function private.licencias_anual_hasta(date,integer),
  public.rpc_licencias_anual_hasta(date,integer), private.licencias_estudio_datos(jsonb) to authenticated;
create trigger licencias_validar_anual
  before insert or update of dni, tipo_id, desde, hasta, importacion_confirmada, anulado_at, cantidad_dias_ficha
  on public.licencias_registros for each row execute function private.licencias_validar_anual();

notify pgrst, 'reload schema';
commit;
