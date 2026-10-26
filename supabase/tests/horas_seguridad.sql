\set ON_ERROR_STOP on
\encoding UTF8
-- Contratos y tipos de Horas reproducidos en una base nueva, sin datos reales.
do $$
begin
  if current_database() <> 'horas_security_test' or to_regclass('public.horas_registros') is not null then
    raise exception 'Se requiere la base aislada horas_security_test vacia.';
  end if;
end;
$$;
set timezone = 'America/Argentina/Buenos_Aires';
create schema auth;
create schema private;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
grant usage on schema public, auth to anon, authenticated, service_role;
create table public.usuarios (id uuid primary key, auth_user_id uuid unique, nombre text, apellido text);
create table public.roles (id bigint primary key, codigo text);
create table public.usuario_roles (usuario_id uuid, rol_id bigint);
create function public.has_role(p_codigo text) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.usuarios u join public.usuario_roles ur on ur.usuario_id=u.id
    join public.roles r on r.id=ur.rol_id where u.auth_user_id=auth.uid() and r.codigo=p_codigo);
$$;
create function public.can_horas_read() returns boolean language sql stable as $$
  select public.has_role('HORAS_CARGA') or public.has_role('HORAS_CARGA_ADM');
$$;
create table public.horas_registros (
  id bigint primary key, dni bigint, carrera_id integer, fecha date, periodo date,
  tipo text, minutos integer, minutos_aplicados integer, minutos_excedidos integer,
  excedido boolean, usuario_carga uuid, created_at timestamp
);
alter table public.horas_registros enable row level security;
create view public.vw_listado_horas_oficiales as
  select 12345678::bigint as dni, 'Persona'::text as apellido, 'Ficticia'::text as nombre, 1::bigint as carrera_id;
insert into public.usuarios values
 ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001','Demo','Uno'),
 ('00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000002','Demo','Dos');
insert into public.roles values (1,'HORAS_CARGA'),(2,'HORAS_CARGA_ADM');
insert into public.usuario_roles values
 ('00000000-0000-4000-8000-000000000011',1),('00000000-0000-4000-8000-000000000012',2);
insert into public.horas_registros values
 (1,12345678,1,'2026-10-01','2026-10-01','COMUN',60,null,null,null,'00000000-0000-4000-8000-000000000001','2026-10-01 09:00'),
 (2,23456789,1,'2026-10-02','2026-10-01','COMUN',30,20,10,true,'00000000-0000-4000-8000-000000000012','2026-10-02 10:00'),
 (3,34567890,1,'2026-09-01','2026-09-01','COMUN',15,15,0,false,null,'2026-09-01 11:00');

-- Firmas y consulta anteriores: SQL permite coerciones que PL/pgSQL requiere explicitar.
create function public.rpc_horas_registros_periodo(p_periodo date)
returns table(id bigint,dni integer,carrera_id integer,fecha date,periodo date,tipo text,minutos integer,
 minutos_aplicados integer,minutos_excedidos integer,excedido boolean,created_at timestamptz,
 usuario_carga uuid,usuario_carga_nombre text,usuario_carga_apellido text)
language sql security definer set search_path = public as $$
 select hr.id,hr.dni,hr.carrera_id,hr.fecha,hr.periodo,hr.tipo,hr.minutos,
 coalesce(hr.minutos_aplicados,0)::integer,coalesce(hr.minutos_excedidos,0)::integer,
 coalesce(hr.excedido,false),hr.created_at,hr.usuario_carga,u.nombre,u.apellido
 from public.horas_registros hr left join public.usuarios u on u.auth_user_id=hr.usuario_carga or u.id=hr.usuario_carga
 where hr.periodo=p_periodo order by hr.fecha desc,hr.id desc;
$$;
create function public.rpc_listado_horas_oficiales()
returns table(dni bigint,apellido text,nombre text,carrera_id bigint)
language sql security definer set search_path = public as $$
 select v.dni,v.apellido,v.nombre,v.carrera_id from public.vw_listado_horas_oficiales v
 order by v.apellido,v.nombre,v.dni,v.carrera_id;
$$;
create temp table horas_esperadas as select * from public.rpc_horas_registros_periodo('2026-10-01');
grant select on horas_esperadas to authenticated;
begin;
set local role anon;
do $$ begin
 if not exists(select 1 from public.rpc_horas_registros_periodo('2026-10-01')) then
   raise exception 'El fixture no reproduce el acceso anonimo anterior.';
 end if;
end; $$;
rollback;

\ir ../migrations/20261026113006_proteger_consultas_horas.sql
\ir ../migrations/20261026113006_proteger_consultas_horas.sql

begin;
set local role anon;
do $$ begin
 begin
  perform * from public.rpc_horas_registros_periodo('2026-10-01');
  raise exception 'Anon accedio a Horas.';
 exception when insufficient_privilege then null; end;
 begin
  perform * from public.rpc_listado_horas_oficiales();
  raise exception 'Anon accedio al listado.';
 exception when insufficient_privilege then null; end;
end; $$;
rollback;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 begin
  perform * from public.rpc_horas_registros_periodo('2026-10-01');
  raise exception 'Authenticated sin identidad accedio a Horas.';
 exception when insufficient_privilege then null; end;
end; $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000099',true);
do $$ begin
 begin
  perform * from public.rpc_horas_registros_periodo('2026-10-01');
  raise exception 'Un usuario sin rol accedio a Horas.';
 exception when insufficient_privilege then null; end;
 begin
  perform * from private.horas_registros_periodo('2026-10-01');
  raise exception 'Se eludio el permiso mediante la funcion privada.';
 exception when insufficient_privilege then null; end;
 begin
  perform * from public.rpc_listado_horas_oficiales();
  raise exception 'Un usuario sin rol accedio al listado.';
 exception when insufficient_privilege then null; end;
end; $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin
 if exists((select * from horas_esperadas except all select * from public.rpc_horas_registros_periodo('2026-10-01'))
   union all (select * from public.rpc_horas_registros_periodo('2026-10-01') except all select * from horas_esperadas)) then
   raise exception 'Cambiaron resultados, tipos, autoria, nulos o conversion horaria.';
 end if;
 if (select array_agg(r.id) from public.rpc_horas_registros_periodo('2026-10-01') r) <> array[2,1]::bigint[]
   or (select count(*) from public.rpc_listado_horas_oficiales()) <> 1 then
   raise exception 'Se perdio el orden o el listado autorizado.';
 end if;
end; $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
do $$ begin
 if (select count(*) from public.rpc_horas_registros_periodo('2026-10-01')) <> 2 then
   raise exception 'El administrador de Horas perdio acceso.';
 end if;
end; $$;
rollback;
do $$ begin
 if (select prosecdef from pg_proc where oid='public.rpc_horas_registros_periodo(date)'::regprocedure)
   or (select prosecdef from pg_proc where oid='public.rpc_listado_horas_oficiales()'::regprocedure)
   or not (select prosecdef from pg_proc where oid='private.horas_registros_periodo(date)'::regprocedure) then
   raise exception 'La implementacion elevada no quedo en el esquema privado.';
 end if;
end; $$;
select 'OK: reproduccion anonima anterior, denegacion anon/sin identidad/sin rol, dos roles autorizados y contrato de datos' as resultado;
