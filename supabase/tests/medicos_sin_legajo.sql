-- Ejecutar sobre una base con personal y un usuario habilitado para emitir.
-- Los partes de prueba se revierten al finalizar la transaccion.
begin;

do $test$
declare
  v_usuario uuid;
  v_dni bigint;
  v_id bigint;
  v_total bigint;
  v_tipo text;
begin
  select coalesce(u.auth_user_id, u.id) into v_usuario
  from public.usuarios u
  where exists (
    select 1 from public.usuario_roles ur
    join public.roles r on r.id = ur.rol_id
    where ur.usuario_id in (u.id, u.auth_user_id)
      and r.codigo = 'MEDICOS_LECTURA'
  ) and exists (
    select 1 from public.usuario_roles ur
    join public.roles r on r.id = ur.rol_id
    where ur.usuario_id in (u.id, u.auth_user_id)
      and r.codigo = 'MEDICOS_ESCRITURA'
  ) limit 1;
  if v_usuario is null then
    raise exception 'La prueba requiere un usuario con permisos de medicos.';
  end if;
  perform set_config('request.jwt.claim.sub', v_usuario::text, true);

  select p.dni into v_dni from public.personas p
  where p.legajo is null
    and not exists (select 1 from public.persona_inactivo pi where pi.dni = p.dni)
  limit 1;
  if v_dni is null then
    raise exception 'La prueba requiere una persona activa sin legajo.';
  end if;

  select count(*) into v_total from public.personas p
  where not exists (select 1 from public.persona_inactivo pi where pi.dni = p.dni);
  if (select count(*) from public.rpc_medicos_personas()) <> v_total then
    raise exception 'El listado debe incluir a todo el personal activo.';
  end if;
  if not exists (
    select 1 from public.rpc_medicos_personas(v_dni::text) p
    where p.dni = v_dni and p.legajo is null
  ) then
    raise exception 'No se puede buscar por DNI a una persona sin legajo.';
  end if;

  foreach v_tipo in array array['DOMICILIO', 'CONSULTORIO', 'CANJE', 'DOMICILIO_FAMILIAR']
  loop
    v_id := public.rpc_medicos_crear(
      p_dni => v_dni,
      p_tipo => v_tipo,
      p_familiar_apellido_nombre => case when v_tipo = 'DOMICILIO_FAMILIAR' then 'Prueba, Familiar' end,
      p_familiar_edad => case when v_tipo = 'DOMICILIO_FAMILIAR' then 10 end,
      p_familiar_parentesco => case when v_tipo = 'DOMICILIO_FAMILIAR' then 'Hijo' end
    );
    if not exists (
      select 1 from public.rpc_medicos_registros(v_dni::text) pm
      where pm.id = v_id and pm.empleado_legajo is null and pm.tipo = v_tipo
    ) then
      raise exception 'No se guardo o recupero el parte sin legajo: %', v_tipo;
    end if;
  end loop;

  v_id := public.rpc_medicos_crear(
    p_dni => v_dni,
    p_tipo => 'DOMICILIO_FAMILIAR',
    p_familiar_apellido_nombre => 'Prueba, Familiar',
    p_familiar_edad => 0,
    p_familiar_parentesco => 'Hijo',
    p_familiar_edad_meses => 8
  );
  if not exists (
    select 1 from public.rpc_medicos_registros(v_dni::text) pm
    where pm.id = v_id and pm.familiar_edad = 0 and pm.familiar_edad_meses = 8
  ) then
    raise exception 'No se conservo la edad familiar en meses.';
  end if;

  if has_function_privilege('anon', 'public.rpc_medicos_personas(text)', 'EXECUTE')
    or has_function_privilege('anon',
      'public.rpc_medicos_crear(bigint,text,text,integer,text,boolean,bigint,text,integer)', 'EXECUTE') then
    raise exception 'Las RPC no deben permitir acceso anonimo.';
  end if;

  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.rpc_medicos_personas();
    raise exception 'El listado permitio acceso sin autenticacion.';
  exception when raise_exception then
    if sqlerrm <> 'No autenticado.' then raise; end if;
  end;
end;
$test$;

rollback;
select 'OK: listado, busqueda, cuatro tipos de parte sin legajo y permisos; datos revertidos' as resultado;
