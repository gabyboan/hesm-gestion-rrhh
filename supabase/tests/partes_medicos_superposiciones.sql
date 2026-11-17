\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database() <> 'publication_test' then raise exception 'Solo publication_test.'; end if;
end; $$;

-- Contratos de guardas probadas por sus suites independientes.
create or replace function private.exigir_mfa_si_activado() returns void language sql as $$ select; $$;
create or replace function private.gestion_sesion_exigir() returns void language sql as $$ select; $$;
\ir ../migrations/20261117001707_partes_medicos_advertir_superposiciones.sql

create function pg_temp.verificar(ok boolean, mensaje text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló: %', mensaje; end if; end; $$;
create function pg_temp.conflictos(consulta text) returns jsonb language plpgsql as $$
declare detalle text;
begin
  begin execute consulta;
  exception when sqlstate 'PMP01' then
    get stacked diagnostics detalle = pg_exception_detail;
    return detalle::jsonb;
  end;
  raise exception 'Se permitió guardar un parte duplicado o superpuesto: %', consulta;
end; $$;
create function pg_temp.rechazar(consulta text, estado text default '42501') returns void language plpgsql as $$
begin
  begin execute consulta;
  exception when others then if sqlstate = estado then return; end if; raise; end;
  raise exception 'Operación indebidamente permitida: %', consulta;
end; $$;
grant execute on function pg_temp.verificar(boolean,text), pg_temp.conflictos(text),
  pg_temp.rechazar(text,text) to authenticated, anon;

begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
insert into public.personas(dni,apellido,nombre,legajo) values
  (45678901,'PRUEBA','SUPERPOSICIÓN',71), (56789012,'PRUEBA','ANULACIÓN',72);
insert into public.usuario_roles
select '00000000-0000-4000-8000-000000000001', id from public.roles r
where codigo = 'MEDICOS_CONTROL' and not exists (
  select 1 from public.usuario_roles ur where ur.usuario_id = '00000000-0000-4000-8000-000000000001' and ur.rol_id = r.id);
-- Parte previo de la misma persona, emitido en una fecha que no se superpone.
insert into public.partes_medicos(dni,fecha,tipo,empleado_apellido,empleado_nombre,empleado_legajo)
values(45678901,timezone('America/Argentina/Buenos_Aires',now())::date-6,
  'CONSULTORIO','PRUEBA','SUPERPOSICIÓN',71);
set local role authenticated;
do $$
declare
  hoy date := timezone('America/Argentina/Buenos_Aires',now())::date;
  primero bigint;
  segundo bigint;
  otro bigint;
  codigo text;
  codigo_segundo text;
  vistos jsonb;
  control jsonb;
begin
  primero := public.rpc_medicos_crear(45678901,'CONSULTORIO');
  codigo := public.rpc_medicos_documento(p_id => primero)->'parte'->>'codigo_qr';
  control := public.rpc_medicos_control_guardar(codigo,hoy-5,6,'Médico prueba','MAT-1',0);
  perform pg_temp.verificar(control->>'fecha_hasta' = hoy::text, 'El último día es inclusivo');

  vistos := pg_temp.conflictos($q$select public.rpc_medicos_crear(45678901,'DOMICILIO')$q$);
  perform pg_temp.verificar(jsonb_array_length(vistos) = 1 and vistos->0->>'id' = primero::text
    and vistos->0->>'fecha_desde' = (hoy-5)::text and vistos->0->>'fecha_hasta' = hoy::text,
    'Bloquea la emisión en el último día de otro parte');
  vistos := pg_temp.conflictos($q$select public.rpc_medicos_crear(45678901,'CONSULTORIO')$q$);
  perform pg_temp.verificar(vistos->0->>'duplicado'='true', 'Bloquea también la emisión duplicada');
  perform pg_temp.verificar((select count(*)=2 from public.rpc_medicos_registros() where dni=45678901),
    'Los intentos rechazados no crearon partes');
  -- No existe un parámetro para saltar la validación, ni para administradores.
  perform pg_temp.rechazar(format(
    'select public.rpc_medicos_crear(45678901,''CONSULTORIO'',p_conflictos_confirmados => %L::jsonb)',vistos), '42883');

  select id into segundo from public.rpc_medicos_registros() where dni=45678901 and fecha=hoy-6;
  codigo_segundo := public.rpc_medicos_documento(p_id => segundo)->'parte'->>'codigo_qr';
  vistos := pg_temp.conflictos(format(
    'select public.rpc_medicos_control_guardar(%L,%L,2,''Médico prueba'',''MAT-2'',0)',codigo_segundo,hoy));
  perform pg_temp.verificar(exists(select 1 from jsonb_array_elements(vistos) c where c->>'id'=primero::text),
    'Bloquea una devolución parcialmente superpuesta por su último día');
  vistos := pg_temp.conflictos(format(
    'select public.rpc_medicos_control_guardar(%L,%L,6,''Médico prueba'',''MAT-2'',0)',codigo_segundo,hoy-5));
  perform pg_temp.verificar(vistos->0->>'duplicado'='true', 'Bloquea un período ya registrado');
  vistos := pg_temp.conflictos(format(
    'select public.rpc_medicos_control_guardar(%L,%L,8,''Médico prueba'',''MAT-2'',0)',codigo_segundo,hoy-6));
  perform pg_temp.verificar(jsonb_array_length(vistos)>0, 'Bloquea un período que contiene al existente');
  perform pg_temp.verificar(jsonb_array_length(public.rpc_medicos_documento(p_id => segundo)->'controles')=0,
    'Las devoluciones rechazadas no dejaron versiones registradas');
  perform pg_temp.rechazar(format(
    'select public.rpc_medicos_control_guardar(%L,%L,6,''Médico'',''MAT'',0,p_conflictos_confirmados => %L::jsonb)',
    codigo_segundo,hoy-5,vistos), '42883');

  control := public.rpc_medicos_control_guardar(codigo_segundo,hoy+1,1,'Médico prueba','MAT-2',0);
  perform pg_temp.verificar(control->>'version'='1', 'El día siguiente al fin admite una devolución');
  vistos := pg_temp.conflictos(format(
    'select public.rpc_medicos_control_guardar(%L,%L,1,''Médico prueba'',''MAT-2'',1,''Corrige fechas'')',
    codigo_segundo,hoy-1));
  perform pg_temp.verificar(jsonb_array_length(public.rpc_medicos_documento(p_id => segundo)->'controles')=1,
    'Una rectificación superpuesta también se bloquea sin modificar el historial');

  -- Solo se usa la última versión; cero días no conserva cobertura anterior.
  control := public.rpc_medicos_control_guardar(codigo,hoy-5,0,'Médico prueba','MAT-1',1,'Sin días aprobados');
  perform pg_temp.verificar(control->>'fecha_hasta' is null and control->>'version'='2',
    'Cero días no genera un período de cobertura');
  control := public.rpc_medicos_control_guardar(codigo_segundo,hoy-1,1,'Médico prueba','MAT-2',1,'Corrige fechas');
  perform pg_temp.verificar(control->>'version'='2',
    'Ignora controles anteriores y excluye el propio parte al rectificar');
  perform pg_temp.rechazar(format(
    'select public.rpc_medicos_control_guardar(%L,%L,1,''Médico prueba'',''MAT-2'',1,''Reenvío'')',codigo_segundo,hoy-1), 'P0001');

  otro := public.rpc_medicos_crear(56789012,'CONSULTORIO');
  vistos := pg_temp.conflictos($q$select public.rpc_medicos_crear(56789012,'CONSULTORIO')$q$);
  perform pg_temp.verificar(vistos->0->>'duplicado'='true' and vistos->0->>'version'='0',
    'Bloquea duplicados incluso sin devolución registrada');
  perform pg_temp.verificar((select count(*)=1 from public.rpc_medicos_registros() where dni=56789012),
    'Las coincidencias de otra persona no bloquean su primera emisión');
  perform public.rpc_medicos_anular(otro);
  otro := public.rpc_medicos_crear(56789012,'CONSULTORIO');
  perform pg_temp.verificar((select count(*)=1 from public.rpc_medicos_registros() where dni=56789012),
    'Un parte anulado no bloquea una nueva emisión');

  perform pg_temp.rechazar($q$select private.medicos_crear_base(45678901,'CONSULTORIO')$q$);
  perform pg_temp.rechazar(format(
    'select private.medicos_control_guardar_base(%L,%L,1,''Médico'',''MAT'',2,''Cambio'')',codigo,hoy));
end; $$;
reset role;
set local role anon;
select pg_temp.rechazar($q$select public.rpc_medicos_crear(45678901,'CONSULTORIO')$q$);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.rechazar($q$select public.rpc_medicos_crear(45678901,'CONSULTORIO')$q$);
select pg_temp.rechazar($q$select public.rpc_medicos_control_guardar('00000422','2026-11-11',6,'Médico','MAT',0)$q$);
reset role;
rollback;
select 'OK: bloqueo de duplicados y superposiciones sin excepción, extremos inclusivos, rectificaciones, anulación y permisos';
