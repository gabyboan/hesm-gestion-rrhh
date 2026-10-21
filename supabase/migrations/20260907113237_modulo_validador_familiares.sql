create or replace function public.confirmar_persona_dni_validacion_con_cuit(
  p_dni bigint,
  p_cuit bigint
)
returns table (
  persona_dni bigint,
  cuil bigint,
  validado_at timestamp with time zone
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_persona_dni bigint;
  v_cuil bigint;
  v_validado_at timestamp with time zone;
  v_cuit_text text;
  v_suma integer;
  v_digito_verificador integer;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not (select private.has_legajo_edit_role()) then
    raise exception 'Sin permiso para validar DNIs.';
  end if;

  if p_dni is null
    or p_dni < 1000000
    or p_dni > 99999999
    or not exists (select 1 from public.personas where dni = p_dni) then
    raise exception 'Persona invalida.';
  end if;

  if p_cuit is null
    or p_cuit < 10000000000
    or p_cuit > 99999999999 then
    raise exception 'CUIT/CUIL invalido: debe contener 11 digitos.';
  end if;

  v_cuit_text := p_cuit::text;

  if substring(v_cuit_text from 3 for 8) <> lpad(p_dni::text, 8, '0') then
    raise exception 'El CUIT/CUIL no corresponde al DNI.';
  end if;

  v_suma :=
    substring(v_cuit_text from 1 for 1)::integer * 5 +
    substring(v_cuit_text from 2 for 1)::integer * 4 +
    substring(v_cuit_text from 3 for 1)::integer * 3 +
    substring(v_cuit_text from 4 for 1)::integer * 2 +
    substring(v_cuit_text from 5 for 1)::integer * 7 +
    substring(v_cuit_text from 6 for 1)::integer * 6 +
    substring(v_cuit_text from 7 for 1)::integer * 5 +
    substring(v_cuit_text from 8 for 1)::integer * 4 +
    substring(v_cuit_text from 9 for 1)::integer * 3 +
    substring(v_cuit_text from 10 for 1)::integer * 2;

  v_digito_verificador := 11 - mod(v_suma, 11);

  if v_digito_verificador = 11 then
    v_digito_verificador := 0;
  elsif v_digito_verificador = 10 then
    v_digito_verificador := 9;
  end if;

  if v_digito_verificador <> substring(v_cuit_text from 11 for 1)::integer then
    raise exception 'CUIT/CUIL invalido.';
  end if;

  select persona.cuil into v_cuil from public.personas as persona where persona.dni = p_dni for update;
  if v_cuil is not null and v_cuil <> p_cuit then
    raise exception 'El CUIT/CUIL obtenido es distinto del cargado. Revis? la inconsistencia antes de validar.';
  end if;

  insert into public.persona_dni_validaciones as validacion (
    persona_dni,
    validado_at,
    validado_by
  )
  values (
    p_dni,
    now(),
    (select auth.uid())
  )
  on conflict on constraint persona_dni_validaciones_pkey do nothing
  returning validacion.persona_dni, validacion.validado_at
    into v_persona_dni, v_validado_at;

  if not found then
    select validacion.persona_dni, persona.cuil, validacion.validado_at
      into v_persona_dni, v_cuil, v_validado_at
    from public.persona_dni_validaciones as validacion
    join public.personas as persona on persona.dni = validacion.persona_dni
    where validacion.persona_dni = p_dni;

    return query select v_persona_dni, v_cuil, v_validado_at;
    return;
  end if;

  update public.personas as persona
  set
    cuil = p_cuit,
    updated_at = now(),
    updated_by = (select auth.uid())
  where persona.dni = p_dni
  returning persona.cuil into v_cuil;

  return query select v_persona_dni, v_cuil, v_validado_at;
end;
$function$;
revoke all on function public.confirmar_persona_dni_validacion_con_cuit(bigint, bigint)
  from public, anon;
grant execute on function public.confirmar_persona_dni_validacion_con_cuit(bigint, bigint)
  to authenticated;
notify pgrst, 'reload schema';
alter table public.persona_familiares
  add column if not exists cuil bigint,
  add column if not exists dni_validado_at timestamptz;
create or replace function private.invalidar_dni_familiar_modificado()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.dni is distinct from old.dni or new.apellido is distinct from old.apellido or new.nombre is distinct from old.nombre then
    new.dni_validado_at := null;
    if new.dni is distinct from old.dni then new.cuil := null; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists invalidar_dni_familiar_modificado on public.persona_familiares;
create trigger invalidar_dni_familiar_modificado before update on public.persona_familiares
for each row execute function private.invalidar_dni_familiar_modificado();
notify pgrst, 'reload schema';
