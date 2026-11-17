begin;

-- Mantener el cupo informativo de 180 minutos y admitir todas las cargas.
-- No modifica registros históricos ni los permisos de las RPC existentes.
create or replace function public.horas_before_insert_update()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  usados integer;
  disponible integer;
  cupo constant integer := 180;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    new.dni::text || '/' || new.carrera_id::text || '/' ||
    pg_catalog.date_trunc('month', new.fecha)::date::text, 0));
  new.periodo := pg_catalog.date_trunc('month', new.fecha)::date;

  if new.tipo = 'ENFERMEDAD' then
    if exists (
      select 1 from public.horas_registros hr
      where hr.dni = new.dni
        and hr.carrera_id = new.carrera_id
        and hr.periodo = new.periodo
        and hr.tipo = 'ENFERMEDAD'
        and (tg_op = 'INSERT' or hr.id <> new.id)
    ) then
      raise exception 'ENFERMEDAD: solo 1 registro por mes (DNI %, carrera %, %).',
        new.dni, new.carrera_id, new.periodo;
    end if;
    new.minutos_aplicados := 0;
    new.minutos_excedidos := 0;
    new.excedido := false;
    return new;
  end if;

  if new.tipo in ('OFICIAL', 'GREMIAL') then
    if new.minutos is null then
      raise exception '% requiere minutos', new.tipo;
    end if;
    new.minutos_aplicados := 0;
    new.minutos_excedidos := 0;
    new.excedido := false;
    return new;
  end if;

  if new.tipo = 'PARTICULAR' then
    if new.minutos is null then
      raise exception 'PARTICULAR requiere minutos';
    end if;
    -- Usar la duración real también después de borrar registros anteriores.
    select coalesce(sum(hr.minutos), 0)::integer into usados
    from public.horas_registros hr
    where hr.dni = new.dni
      and hr.carrera_id = new.carrera_id
      and hr.periodo = new.periodo
      and hr.tipo = 'PARTICULAR'
      and (tg_op = 'INSERT' or hr.id <> new.id);

    disponible := greatest(cupo - usados, 0);
    new.minutos_aplicados := least(new.minutos, disponible);
    new.minutos_excedidos := greatest(new.minutos - disponible, 0);
    new.excedido := new.minutos_excedidos > 0;
    return new;
  end if;

  raise exception 'Tipo invalido: %', new.tipo;
end;
$function$;

commit;
