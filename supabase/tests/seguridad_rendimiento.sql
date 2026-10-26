\set ON_ERROR_STOP on
\encoding UTF8
-- Solo sobre los fixtures ficticios de publicacion_contratos.sql.
do $$
begin
  if current_database() <> 'publication_test'
    or to_regprocedure('public.busqueda_coincide(text[],text[])') is null then
    raise exception 'Se requiere publication_test con los contratos sinteticos cargados.';
  end if;
end;
$$;

-- Guardar la implementacion anterior para comparar resultados y tiempos.
create function pg_temp.busqueda_anterior(p_campos text[], p_terminos text[])
returns boolean language sql immutable parallel safe set search_path = '' as $$
  select not exists (
    select 1 from unnest(p_terminos) as t(termino)
    where strpos(public.busqueda_normalizar(array_to_string(p_campos, ' ')), t.termino) = 0
  );
$$;

-- Simular concesiones amplias de una instalacion anterior de Supabase.
grant create on schema public, private to public, anon, authenticated;
create table public._seguridad_existente (usuario_id uuid primary key, valor text);
alter table public._seguridad_existente enable row level security;
create policy propia on public._seguridad_existente to authenticated
  using (usuario_id = (select auth.uid()))
  with check (usuario_id = (select auth.uid()));
grant all on table public._seguridad_existente to public, anon, authenticated;
alter default privileges for role postgres
  grant execute on functions to public, anon, authenticated;
alter default privileges for role postgres in schema public, private
  grant execute on functions to authenticated;
alter default privileges for role postgres
  grant all on tables to anon, authenticated;
alter default privileges for role postgres in schema public, private
  grant all on tables to anon, authenticated;

\ir ../migrations/20261023143721_restringir_privilegios_administrativos.sql
\ir ../migrations/20261023143727_optimizar_normalizacion_busquedas.sql
-- Las dos migraciones son repetibles sin ampliar privilegios.
\ir ../migrations/20261023143721_restringir_privilegios_administrativos.sql
\ir ../migrations/20261023143727_optimizar_normalizacion_busquedas.sql

create table public._seguridad_nueva (id integer);
create function public._seguridad_rpc_nueva() returns integer language sql as $$ select 1; $$;
create function private._seguridad_rpc_nueva() returns integer language sql as $$ select 1; $$;

do $$
declare v_rol text; v_priv text; v_tabla text; v_esquema text;
begin
  foreach v_rol in array array['anon', 'authenticated'] loop
    foreach v_esquema in array array['public', 'private'] loop
      if has_schema_privilege(v_rol, v_esquema, 'CREATE') then
        raise exception 'El rol % conserva CREATE en %.', v_rol, v_esquema;
      end if;
      if has_function_privilege(v_rol, v_esquema || '._seguridad_rpc_nueva()', 'EXECUTE') then
        raise exception 'La nueva funcion de % es accesible por % sin GRANT.', v_esquema, v_rol;
      end if;
    end loop;
    foreach v_tabla in array array['public._seguridad_existente', 'public._seguridad_nueva'] loop
      foreach v_priv in array array['TRUNCATE', 'REFERENCES', 'TRIGGER'] loop
        if has_table_privilege(v_rol, v_tabla, v_priv) then
          raise exception '% conserva % en %.', v_rol, v_priv, v_tabla;
        end if;
      end loop;
    end loop;
  end loop;
  if not has_table_privilege('authenticated', 'public._seguridad_existente', 'SELECT')
    or not has_table_privilege('authenticated', 'public._seguridad_existente', 'INSERT')
    or not has_table_privilege('authenticated', 'public._seguridad_existente', 'UPDATE')
    or not has_table_privilege('authenticated', 'public._seguridad_existente', 'DELETE') then
    raise exception 'Se perdieron permisos DML existentes.';
  end if;
  if not has_function_privilege('service_role', 'public.rpc_consulta_horas_beneficios_public(integer)', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.rpc_consulta_horas_beneficios_public(integer)', 'EXECUTE')
    or has_function_privilege('anon', 'public.rpc_consulta_horas_beneficios_public(integer)', 'EXECUTE') then
    raise exception 'Cambio el contrato del Worker service_role.';
  end if;
end;
$$;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
insert into public._seguridad_existente values (auth.uid(), 'propio');
update public._seguridad_existente set valor = 'editado' where usuario_id = auth.uid();
do $$
begin
  if (select valor from public._seguridad_existente) <> 'editado' then
    raise exception 'El DML autorizado dejo de funcionar.';
  end if;
  begin
    truncate public._seguridad_existente;
    raise exception 'TRUNCATE eludio RLS.';
  exception when insufficient_privilege then null;
  end;
  begin
    create table public._objeto_intruso (id integer);
    raise exception 'Se permitio crear objetos como authenticated.';
  exception when insufficient_privilege then null;
  end;
  begin
    update public._seguridad_existente set usuario_id = '00000000-0000-4000-8000-000000000002';
    raise exception 'Se permitio reasignar una fila ajena.';
  exception when insufficient_privilege then null;
  end;
  if not exists (select 1 from public.rpc_francos_listado('garcia ana'))
    or (select torre from public.rpc_medicos_domicilio(12345678)) <> 'DEMO' then
    raise exception 'Las RPC autorizadas dejaron de funcionar.';
  end if;
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
do $$
begin
  if exists (select 1 from public._seguridad_existente) then
    raise exception 'RLS permitio leer la fila ajena.';
  end if;
  begin
    perform public.rpc_medicos_domicilio(12345678);
    raise exception 'Se permitio consultar domicilio sin rol medico.';
  exception when raise_exception then
    if sqlerrm <> 'Sin permiso para ver partes medicos.' then raise; end if;
  end;
end;
$$;
rollback;

-- Comparacion diferencial con nulos, arrays vacios, acentos, documentos,
-- simbolos literales y arrays multidimensionales (FOREACH recorre sus elementos).
do $$
declare v_errores integer;
begin
  select count(*) into v_errores from (
    values (null::text[]), (array[]::text[]), (array[null::text]),
      (array['Ana', 'García', '12.345.678']), (array['100%', 'a_b']),
      (array[['Ana', 'García'], ['DEMO', null]])
  ) c(campos) cross join (
    values (null::text[]), (array[]::text[]), (array[null::text]),
      (array['']), (array['ana', 'garcia', '12345678']), (array['%']),
      (array['_']), (array['ausente']), (array[null, 'ana']),
      (array[['ana', 'garcia'], ['', null]])
  ) t(terminos)
  where public.busqueda_coincide(c.campos, t.terminos)
    is distinct from pg_temp.busqueda_anterior(c.campos, t.terminos);
  if v_errores <> 0 then raise exception 'Hay % diferencias de busqueda.', v_errores; end if;
end;
$$;

-- Medicion orientativa con datos sinteticos, no una meta de tiempo para CI.
\timing on
select count(*) as coincidencias_antes from generate_series(1, 10000) g
where pg_temp.busqueda_anterior(array['García', 'Ana', g::text, '20-12345678-0'],
  array['garcia', 'ana', '20123456780']);
select count(*) as coincidencias_despues from generate_series(1, 10000) g
where public.busqueda_coincide(array['García', 'Ana', g::text, '20-12345678-0'],
  array['garcia', 'ana', '20123456780']);
\timing off

drop table public._seguridad_existente, public._seguridad_nueva;
drop function public._seguridad_rpc_nueva(), private._seguridad_rpc_nueva();
select 'OK: privilegios, defaults, RLS, Worker, RPC y 60 casos de busqueda' as resultado;
