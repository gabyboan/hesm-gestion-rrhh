begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- NULL identifica partes anteriores sin una copia histórica verificable.
-- {} identifica partes nuevos emitidos sin domicilio (o de consultorio).
-- No completar los anteriores con la ficha actual: podría ser otro domicilio.
alter table public.partes_medicos
  add column domicilio_emision jsonb,
  add constraint partes_medicos_domicilio_emision_objeto_chk
    check (domicilio_emision is null or jsonb_typeof(domicilio_emision) = 'object');

comment on column public.partes_medicos.domicilio_emision is
  'Copia inmutable del domicilio al emitir. NULL: parte anterior sin copia histórica; {}: sin domicilio o consultorio.';

-- Las RPC de creación ejecutan el INSERT con sus permisos ya comprobados.
-- La consulta privada existente valida además la sesión y la lectura médica.
-- No se necesita otra función SECURITY DEFINER ni nuevos permisos de tabla.
create function private.partes_medicos_fijar_domicilio()
returns trigger
language plpgsql security invoker set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.domicilio_emision is distinct from old.domicilio_emision then
      raise exception 'El domicilio de un parte emitido no se puede modificar.';
    end if;
    return new;
  end if;

  -- Ignorar cualquier copia enviada por el cliente: manda el dato del servidor.
  new.domicilio_emision := '{}'::jsonb;
  if new.tipo <> 'CONSULTORIO' then
    select coalesce((
      select to_jsonb(d) from private.medicos_domicilio_actual(new.dni) d
    ), '{}'::jsonb) into new.domicilio_emision;
  end if;
  return new;
end;
$$;
revoke all on function private.partes_medicos_fijar_domicilio()
  from public, anon, authenticated;

create trigger partes_medicos_fijar_domicilio
before insert or update on public.partes_medicos
for each row execute function private.partes_medicos_fijar_domicilio();

-- Los listados devuelven SETOF partes_medicos y el documento usa to_jsonb:
-- incorporan la copia automáticamente sin cambiar las firmas de las RPC.
notify pgrst, 'reload schema';
commit;
