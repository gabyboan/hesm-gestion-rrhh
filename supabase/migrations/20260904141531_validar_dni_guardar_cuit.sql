create function public.confirmar_persona_dni_validacion_con_cuit(
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
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not (select private.has_legajo_edit_role()) then
    raise exception 'Sin permiso para validar DNIs.';
  end if;

  if p_dni is null
    or p_dni < 1000000
    or p_dni > 99999999 then
    raise exception 'DNI invalido.';
  end if;

  if p_cuit is null
    or p_cuit < 10000000000
    or p_cuit > 99999999999 then
    raise exception 'CUIT/CUIL invalido: debe contener 11 digitos.';
  end if;

  if substring(p_cuit::text from 3 for 8) <> lpad(p_dni::text, 8, '0') then
    raise exception 'El CUIT/CUIL no corresponde al DNI.';
  end if;

  update public.personas as persona
  set
    cuil = p_cuit,
    updated_at = now(),
    updated_by = (select auth.uid())
  where persona.dni = p_dni
  returning persona.dni, persona.cuil
    into v_persona_dni, v_cuil;

  if not found then
    raise exception 'Persona invalida.';
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
  returning validacion.validado_at into v_validado_at;

  if not found then
    select validacion.validado_at
      into v_validado_at
    from public.persona_dni_validaciones as validacion
    where validacion.persona_dni = p_dni;
  end if;

  return query select v_persona_dni, v_cuil, v_validado_at;
end;
$function$;
revoke all on function public.confirmar_persona_dni_validacion_con_cuit(bigint, bigint)
  from public, anon;
grant execute on function public.confirmar_persona_dni_validacion_con_cuit(bigint, bigint)
  to authenticated;
notify pgrst, 'reload schema';
