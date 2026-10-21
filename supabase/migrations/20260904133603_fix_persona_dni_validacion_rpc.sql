create or replace function public.confirmar_persona_dni_validacion(p_dni bigint)
returns table (
  persona_dni bigint,
  validado_at timestamp with time zone
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_persona_dni bigint;
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
    or p_dni > 99999999
    or not exists (select 1 from public.personas where dni = p_dni) then
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
  returning validacion.persona_dni, validacion.validado_at
    into v_persona_dni, v_validado_at;

  if not found then
    select validacion.persona_dni, validacion.validado_at
      into v_persona_dni, v_validado_at
    from public.persona_dni_validaciones as validacion
    where validacion.persona_dni = p_dni;
  end if;

  return query select v_persona_dni, v_validado_at;
end;
$function$;
revoke all on function public.confirmar_persona_dni_validacion(bigint) from public, anon;
grant execute on function public.confirmar_persona_dni_validacion(bigint) to authenticated;
notify pgrst, 'reload schema';
