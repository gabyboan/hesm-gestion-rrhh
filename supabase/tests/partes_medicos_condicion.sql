\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
 if current_database()<>'publication_test' then raise exception 'Se requiere el fixture aislado publication_test.'; end if;
end; $$;
-- Helpers de sesión ficticios: no se conectan a Auth ni a la base compartida.
create function private.exigir_mfa_si_activado() returns void language plpgsql as $$ begin
 if current_setting('test.mfa',true)='pendiente' then raise exception 'MFA pendiente' using errcode='42501'; end if;
end; $$;
create function private.gestion_sesion_exigir() returns void language plpgsql as $$ begin
 if current_setting('test.sesion',true)='vencida' then raise exception 'Sesión vencida' using errcode='42501'; end if;
end; $$;
\ir ../migrations/20261113114028_medicos_condicion_legajo.sql
begin;
insert into public.situacion_revista(nombre) values ('Titular'),('Suplente Ordinario - Cargo Vacante') on conflict(nombre) do nothing;
delete from public.persona_situacion_revista where dni=12345678;
insert into public.persona_situacion_revista select 12345678,id from public.situacion_revista where nombre='Titular';
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ declare parte bigint; condicion text; begin
 select c.condicion into condicion from public.rpc_medicos_condiciones(array[12345678,12345678]::bigint[]) c;
 if condicion is distinct from 'Titular' then raise exception 'No consulta la condición de la ficha'; end if;
 parte:=public.rpc_medicos_crear(12345678,'CONSULTORIO');
 if (public.rpc_medicos_documento(p_id=>parte)->'parte'->>'empleado_condicion') is distinct from 'Titular' then raise exception 'No conservó la condición al emitir'; end if;
 perform set_config('test.condicion_parte',parte::text,true);
 perform set_config('test.mfa','pendiente',true);
 begin perform public.rpc_medicos_condiciones(array[12345678]::bigint[]); raise exception 'Omitió MFA'; exception when insufficient_privilege then null; end;
 perform set_config('test.mfa','',true);
 perform set_config('test.sesion','vencida',true);
 begin perform public.rpc_medicos_condiciones(array[12345678]::bigint[]); raise exception 'Aceptó sesión vencida'; exception when insufficient_privilege then null; end;
 perform set_config('test.sesion','',true);
end; $$;
reset role;
update public.persona_situacion_revista set situacion_id=(select id from public.situacion_revista where nombre='Suplente Ordinario - Cargo Vacante') where dni=12345678;
do $$ begin
 begin
  update public.partes_medicos set empleado_condicion='Suplente' where id=current_setting('test.condicion_parte')::bigint;
  raise exception 'Permitió reescribir la condición histórica';
 exception when invalid_parameter_value then null;
 end;
 if exists(select 1 from public.partes_medicos where id<>current_setting('test.condicion_parte')::bigint and empleado_condicion is not null) then raise exception 'Reconstruyó condiciones anteriores'; end if;
end; $$;
set local role authenticated;
do $$ declare parte bigint; begin
 if (public.rpc_medicos_documento(p_id=>current_setting('test.condicion_parte')::bigint)->'parte'->>'empleado_condicion') is distinct from 'Titular' then raise exception 'Una edición cambió un parte emitido'; end if;
 parte:=public.rpc_medicos_crear(12345678,'CONSULTORIO');
 if (public.rpc_medicos_documento(p_id=>parte)->'parte'->>'empleado_condicion') is distinct from 'Suplente Ordinario - Cargo Vacante' then raise exception 'No tomó la nueva condición al emitir'; end if;
end; $$;
reset role;
insert into public.persona_situacion_revista select 12345678,id from public.situacion_revista where nombre='Titular';
do $$ begin
 if private.medicos_condicion_actual(12345678) is not null then raise exception 'Una condición ambigua se dio por cierta'; end if;
 if has_function_privilege('anon','public.rpc_medicos_condiciones(bigint[])','execute') or has_function_privilege('authenticated','private.medicos_condicion_actual(bigint)','execute') then raise exception 'Permisos demasiado amplios'; end if;
end; $$;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000002';
set local role authenticated;
do $$ begin
 begin perform public.rpc_medicos_condiciones(array[12345678]::bigint[]); raise exception 'Acceso sin rol'; exception when insufficient_privilege then null; end;
end; $$;
rollback;
select 'OK: condición real, captura inmutable, permisos, MFA, sesión y ambigüedad' resultado;
