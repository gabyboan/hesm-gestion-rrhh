begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

alter table public.licencias_registros
  add column importacion_confirmada boolean not null default true;
comment on column public.licencias_registros.importacion_confirmada is
  'El historial del Excel requiere selección y confirmación antes de incorporarse a las vistas de trabajo.';

-- Apartar exactamente el lote ya importado, sin borrar ni alterar sus datos.
update public.licencias_registros set importacion_confirmada = false
where origen_archivo = 'a164de3f55f1d1de5bffd8b6d43f87087850a87b14f2a8b212e9abe881b8905e';

create function private.licencias_marcar_importacion() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.origen_archivo is not null then new.importacion_confirmada := false; end if;
  return new;
end;
$$;
revoke all on function private.licencias_marcar_importacion() from public, anon, authenticated;
create trigger licencias_importacion_requiere_revision
  before insert on public.licencias_registros for each row
  execute function private.licencias_marcar_importacion();

drop policy licencias_registros_lectura on public.licencias_registros;
create policy licencias_registros_lectura on public.licencias_registros
  for select to authenticated
  using (importacion_confirmada and (select public.can_licencias_read()));
drop policy licencias_pendientes_lectura on public.licencias_importacion_pendientes;
create policy licencias_pendientes_lectura on public.licencias_importacion_pendientes
  for select to authenticated using ((select public.can_licencias_admin()));

create function private.licencias_importadas_resumen()
returns table(origen_archivo text, tipo text, registros bigint, dias bigint, desde date, hasta date)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not public.can_licencias_admin() then
    raise exception 'Sin permiso para revisar el historial del Excel.' using errcode = '42501';
  end if;
  return query select l.origen_archivo, t.nombre, count(*), sum(l.dias), min(l.desde), max(l.hasta)
  from public.licencias_registros l join public.licencias_tipos t on t.id = l.tipo_id
  where not l.importacion_confirmada and l.desde >= date '2026-01-01'
  group by l.origen_archivo, t.nombre order by t.nombre;
end;
$$;
create function public.rpc_licencias_importadas_resumen()
returns table(origen_archivo text, tipo text, registros bigint, dias bigint, desde date, hasta date)
language sql stable security invoker set search_path = '' as $$
  select * from private.licencias_importadas_resumen();
$$;
revoke all on function public.rpc_licencias_importadas_resumen(),
  private.licencias_importadas_resumen() from public, anon, authenticated;
grant execute on function public.rpc_licencias_importadas_resumen(),
  private.licencias_importadas_resumen() to authenticated;

create or replace function private.licencias_guardar(p_id bigint, p_dni bigint, p_tipo_id smallint,
  p_desde date, p_hasta date, p_observacion text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_persona record;
  v_id bigint;
  v_anterior public.licencias_registros;
begin
  if (select auth.uid()) is null or
    (p_id is null and not public.can_licencias_create()) or
    (p_id is not null and not public.can_licencias_admin()) then
    raise exception 'Sin permiso para guardar licencias.' using errcode = '42501';
  end if;
  if p_desde is null or p_hasta is null or p_hasta < p_desde or p_desde < date '2026-01-01' then
    raise exception 'El período de la licencia es inválido.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.licencias_tipos where id = p_tipo_id) then
    raise exception 'Tipo de licencia inválido.' using errcode = '22023';
  end if;
  if p_id is not null then
    select * into v_anterior from public.licencias_registros
      where id = p_id and anulado_at is null and importacion_confirmada for update;
    if not found then raise exception 'La licencia no existe o fue anulada.'; end if;
    if v_anterior.dni <> p_dni then raise exception 'No se puede cambiar la persona de una licencia.'; end if;
  end if;
  -- Serializa la comprobación de duplicados para cargas de la misma persona.
  perform 1 from public.personas where dni = p_dni for update;
  select * into v_persona from private.licencias_personas(null, p_dni);
  if not found then
    if p_id is null then raise exception 'La persona no tiene ficha. Revisá su DNI.'; end if;
  end if;
  if exists (select 1 from public.persona_inactividad_periodos pip
    where pip.persona_dni = p_dni and pip.fecha_desde <= p_hasta
      and (pip.fecha_hasta is null or pip.fecha_hasta >= p_desde))
    or exists (select 1 from public.persona_inactivo pi
      where pi.dni = p_dni and coalesce(pi.fecha, p_desde) <= p_hasta) then
    raise exception 'La persona estuvo inactiva durante el período indicado.';
  end if;
  if (p_id is null or (v_anterior.tipo_id,v_anterior.desde,v_anterior.hasta)
      is distinct from (p_tipo_id,p_desde,p_hasta)) and exists (
    select 1 from public.licencias_registros l where l.dni = p_dni
    and l.tipo_id = p_tipo_id and l.desde = p_desde and l.hasta = p_hasta
    and l.importacion_confirmada and l.anulado_at is null and (p_id is null or l.id <> p_id)) then
    raise exception 'Ya existe una licencia del mismo tipo y período para esta persona.';
  end if;
  if p_id is null then
    insert into public.licencias_registros(dni, persona_dni, apellido_nombre, carrera,
      situacion_revista, funcion, tipo_id, desde, hasta, observacion, created_by, updated_by)
    values (p_dni, p_dni, v_persona.apellido_nombre, v_persona.carrera,
      v_persona.situacion_revista, v_persona.funcion, p_tipo_id, p_desde, p_hasta,
      nullif(btrim(p_observacion), ''), (select auth.uid()), (select auth.uid()))
    returning id into v_id;
  else
    update public.licencias_registros set tipo_id = p_tipo_id, desde = p_desde,
      hasta = p_hasta, observacion = nullif(btrim(p_observacion), ''),
      updated_at = now(), updated_by = (select auth.uid()) where id = p_id returning id into v_id;
  end if;
  return v_id;
end;
$$;
create or replace function private.licencias_anular(p_id bigint) returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_filas integer;
begin
  if (select auth.uid()) is null or not public.can_licencias_admin() then
    raise exception 'Sin permiso para anular licencias.' using errcode = '42501';
  end if;
  update public.licencias_registros set anulado_at = now(), anulado_by = (select auth.uid()),
    updated_at = now(), updated_by = (select auth.uid()) where id = p_id and anulado_at is null and importacion_confirmada;
  get diagnostics v_filas = row_count;
  return v_filas = 1;
end;
$$;
notify pgrst, 'reload schema';
commit;
