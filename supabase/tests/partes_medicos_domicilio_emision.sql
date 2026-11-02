\set ON_ERROR_STOP on
\encoding UTF8
-- Exclusivamente los datos ficticios del runner tool/test_database.ps1.
do $$
begin
  if current_database() <> 'publication_test' then
    raise exception 'Se requiere la base aislada publication_test.';
  end if;
end;
$$;

-- Un parte realmente previo permite comprobar que la migración no inventa
-- su domicilio usando la ficha actual.
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
set role authenticated;
select public.rpc_medicos_crear(12345678, 'DOMICILIO') as id \gset anterior_
reset role;
\ir ../migrations/20261102135222_conservar_domicilio_emision_partes_medicos.sql

begin;
select set_config('domicilios_test.anterior_id', :'anterior_id', true);
update public.persona_domicilios set
  calle = 'Original', numero = '123', barrio = 'Centro', torre = 'B',
  manzana = 'M', lote = 'L', casa = '4', monoblock = 'A', piso = '2',
  departamento = 'C', referencias = 'Referencia original', otros_datos = 'Otros',
  localidad_nombre = 'Paraná', provincia_nombre = 'Entre Ríos'
where persona_dni = 12345678 and vigente_hasta is null;

set local role authenticated;
do $$
declare
  v_id bigint;
  v_tipo text;
  v_copia jsonb;
  v_esperado jsonb;
begin
  if (public.rpc_medicos_documento(
      p_id => current_setting('domicilios_test.anterior_id')::bigint)
      ->'parte'->'domicilio_emision') is distinct from 'null'::jsonb then
    raise exception 'La migración inventó el domicilio de un parte anterior.';
  end if;
  select to_jsonb(d) into v_esperado from public.rpc_medicos_domicilio(12345678) d;
  perform set_config('domicilios_test.esperado', v_esperado::text, true);
  foreach v_tipo in array array['DOMICILIO', 'CANJE', 'DOMICILIO_FAMILIAR'] loop
    v_id := public.rpc_medicos_crear(
      p_dni => 12345678, p_tipo => v_tipo,
      p_familiar_apellido_nombre => case when v_tipo = 'DOMICILIO_FAMILIAR' then 'Demo, Familiar' end,
      p_familiar_edad => case when v_tipo = 'DOMICILIO_FAMILIAR' then 10 end,
      p_familiar_parentesco => case when v_tipo = 'DOMICILIO_FAMILIAR' then 'Hijo' end
    );
    v_copia := public.rpc_medicos_documento(p_id => v_id)->'parte'->'domicilio_emision';
    if v_copia is distinct from v_esperado then
      raise exception 'No guardó todos los campos del domicilio: %.', v_tipo;
    end if;
    perform set_config('domicilios_test.' || lower(v_tipo), v_id::text, true);
  end loop;

  v_id := public.rpc_medicos_crear(12345678, 'CONSULTORIO');
  if (public.rpc_medicos_documento(p_id => v_id)->'parte'->'domicilio_emision')
      is distinct from '{}'::jsonb then
    raise exception 'Consultorio incluyó un domicilio.';
  end if;

  -- La segunda persona no tiene domicilio al emitir.
  v_id := public.rpc_medicos_crear(34567890, 'DOMICILIO');
  perform set_config('domicilios_test.sin_domicilio', v_id::text, true);
  if (public.rpc_medicos_documento(p_id => v_id)->'parte'->'domicilio_emision')
      is distinct from '{}'::jsonb then
    raise exception 'No dejó constancia de la emisión sin domicilio.';
  end if;
end;
$$;
reset role;

-- Editar la misma fila reproduce el problema original, sin depender de
-- versiones de domicilio que luego también podrían editarse o borrarse.
update public.persona_domicilios set calle = 'Actual', numero = '999', torre = 'Z'
where persona_dni = 12345678 and vigente_hasta is null;
insert into public.persona_domicilios(persona_dni, calle, numero)
values (34567890, 'Cargado después', '888');

set local role authenticated;
do $$
declare
  v_id bigint;
  v_tipo text;
  v_copia jsonb;
  v_esperado jsonb := current_setting('domicilios_test.esperado')::jsonb;
  v_codigo text;
  v_fecha date;
begin
  foreach v_tipo in array array['domicilio', 'canje', 'domicilio_familiar'] loop
    v_id := current_setting('domicilios_test.' || v_tipo)::bigint;
    v_codigo := public.rpc_medicos_documento(p_id => v_id)->'parte'->>'codigo_qr';
    v_fecha := (public.rpc_medicos_documento(p_id => v_id)->'parte'->>'fecha')::date;
    v_copia := public.rpc_medicos_documento(p_codigo => v_codigo)->'parte'->'domicilio_emision';
    if v_copia is distinct from v_esperado then
      raise exception 'La consulta QR cambió el domicilio del parte emitido.';
    end if;
    select domicilio_emision into v_copia from public.rpc_medicos_registros() where id = v_id;
    if v_copia is distinct from v_esperado then
      raise exception 'El listado general cambió el domicilio emitido.';
    end if;
    select domicilio_emision into v_copia
    from public.rpc_medicos_registros_dia(v_fecha) where id = v_id;
    if v_copia is distinct from v_esperado then
      raise exception 'El listado por fecha cambió el domicilio emitido.';
    end if;
  end loop;

  -- El próximo parte sí debe tomar el nuevo domicilio de la ficha.
  v_id := public.rpc_medicos_crear(12345678, 'DOMICILIO');
  if (public.rpc_medicos_documento(p_id => v_id)->'parte'->'domicilio_emision'->>'calle')
      is distinct from 'Actual' then
    raise exception 'Un parte nuevo no tomó el domicilio actual.';
  end if;
  v_id := current_setting('domicilios_test.sin_domicilio')::bigint;
  if (public.rpc_medicos_documento(p_id => v_id)->'parte'->'domicilio_emision')
      is distinct from '{}'::jsonb then
    raise exception 'Un domicilio cargado después modificó una emisión sin domicilio.';
  end if;

  -- Anular debe seguir funcionando y conservar el dato histórico.
  v_id := current_setting('domicilios_test.domicilio')::bigint;
  if not public.rpc_medicos_anular(v_id)
      or (public.rpc_medicos_documento(p_id => v_id)->'parte'->'domicilio_emision')
         is distinct from v_esperado then
    raise exception 'La anulación perdió el domicilio histórico.';
  end if;
end;
$$;
reset role;

-- Incluso una actualización privilegiada debe respetar la copia inmutable.
do $$
declare
  v_id bigint := current_setting('domicilios_test.canje')::bigint;
begin
  begin
    update public.partes_medicos set domicilio_emision = '{"calle":"Alterado"}' where id = v_id;
    raise exception 'Permitió modificar el domicilio emitido.';
  exception when raise_exception then
    if sqlerrm <> 'El domicilio de un parte emitido no se puede modificar.' then raise; end if;
  end;
  begin
    update public.partes_medicos set domicilio_emision = null where id = v_id;
    raise exception 'Permitió borrar el domicilio emitido.';
  exception when raise_exception then
    if sqlerrm <> 'El domicilio de un parte emitido no se puede modificar.' then raise; end if;
  end;
  if has_function_privilege('anon', 'private.partes_medicos_fijar_domicilio()', 'EXECUTE')
      or has_function_privilege('authenticated', 'private.partes_medicos_fijar_domicilio()', 'EXECUTE')
      or (select prosecdef from pg_proc
          where oid = 'private.partes_medicos_fijar_domicilio()'::regprocedure) then
    raise exception 'El trigger agregó permisos o acceso elevado innecesarios.';
  end if;
end;
$$;

-- Borrar la fuente tampoco debe borrar o alterar la copia del documento.
delete from public.persona_domicilios where persona_dni = 12345678;
set local role authenticated;
do $$
begin
  if (public.rpc_medicos_documento(
      p_id => current_setting('domicilios_test.canje')::bigint)->'parte'->'domicilio_emision')
      is distinct from current_setting('domicilios_test.esperado')::jsonb then
    raise exception 'La copia depende todavía del domicilio de la ficha.';
  end if;
end;
$$;
rollback;
select set_config('request.jwt.claim.sub', '', false);
select 'OK: domicilio de emisión, cambios de ficha, QR, listados, ausencia e inmutabilidad' as resultado;
