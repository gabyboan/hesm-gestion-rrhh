\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'horas_next_test' or to_regclass('public.horas_registros') is not null then
    raise exception 'Solo la base aislada vacía horas_next_test.';
  end if;
end; $$;
create schema auth;
create schema private;
grant usage on schema auth,private to authenticated;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
create table auth.users(id uuid primary key);
insert into auth.users values('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
create function public.can_horas_write() returns boolean language sql stable as $$
  select auth.uid()='00000000-0000-4000-8000-000000000001'::uuid;
$$;
create function public.can_horas_read() returns boolean language sql stable as $$ select public.can_horas_write(); $$;
create function private.exigir_mfa_si_activado() returns void language sql as $$ select; $$;
create table public.personas(dni bigint primary key);
create table public.persona_carreras(dni bigint,carrera_id integer,primary key(dni,carrera_id));
create table public.persona_inactivo(dni bigint primary key);
insert into public.personas values(1001);
insert into public.persona_carreras values(1001,1),(1001,17);
create table public.horas_registros(
  id bigint generated always as identity primary key,
  dni bigint not null references public.personas(dni),carrera_id integer not null,
  fecha date not null,periodo date not null,tipo text not null,minutos integer,
  minutos_aplicados integer not null default 0,minutos_excedidos integer not null default 0,
  excedido boolean not null default false,usuario_carga uuid not null references auth.users(id),
  created_at timestamp not null default now(),
  foreign key(dni,carrera_id) references public.persona_carreras(dni,carrera_id),
  constraint horas_registros_tipo_check check(tipo in('PARTICULAR','OFICIAL','ENFERMEDAD')),
  constraint ck_carrera_valida check(tipo='OFICIAL' or carrera_id in(1,2,3)),
  constraint ck_tipo_minutos check((tipo='PARTICULAR' and minutos between 30 and 180 and minutos%30=0)
    or (tipo='OFICIAL' and minutos between 30 and 600 and minutos%30=0) or (tipo='ENFERMEDAD' and minutos is null))
);
alter table public.horas_registros enable row level security;
CREATE OR REPLACE FUNCTION public.horas_before_insert_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  usados int;
  cupo int := 180;

  cnt_particulares int;
  max_regs_particulares int := 6;

  disponible int;
begin
  -- periodo desde fecha
  new.periodo := date_trunc('month', new.fecha)::date;

  -- =========================
  -- ENFERMEDAD
  -- =========================
  if new.tipo = 'ENFERMEDAD' then
    if exists (
      select 1
      from public.horas_registros hr
      where hr.dni = new.dni
        and hr.carrera_id = new.carrera_id
        and hr.periodo = new.periodo
        and hr.tipo = 'ENFERMEDAD'
        and (tg_op = 'INSERT' or hr.id <> new.id)
    ) then
      raise exception
        'ENFERMEDAD: solo 1 registro por mes (DNI %, carrera %, %).',
        new.dni, new.carrera_id, new.periodo;
    end if;

    new.minutos_aplicados := 0;
    new.minutos_excedidos := 0;
    new.excedido := false;
    return new;
  end if;

  -- =========================
  -- OFICIAL (no consume cupo)
  -- =========================
  if new.tipo = 'OFICIAL' then
    if new.minutos is null then
      raise exception 'OFICIAL requiere minutos';
    end if;

    new.minutos_aplicados := 0;
    new.minutos_excedidos := 0;
    new.excedido := false;
    return new;
  end if;

  -- =========================
  -- PARTICULAR
  -- =========================
  if new.tipo = 'PARTICULAR' then
    if new.minutos is null then
      raise exception 'PARTICULAR requiere minutos';
    end if;

    select
      count(*)::int,
      coalesce(sum(hr.minutos_aplicados), 0)::int
    into cnt_particulares, usados
    from public.horas_registros hr
    where hr.dni = new.dni
      and hr.carrera_id = new.carrera_id
      and hr.periodo = new.periodo
      and hr.tipo = 'PARTICULAR'
      and (tg_op = 'INSERT' or hr.id <> new.id);

    if (cnt_particulares + 1) > max_regs_particulares then
      raise exception
        'PARTICULAR: maximo % registros por mes (DNI %, carrera %, %). Ya tiene %.',
        max_regs_particulares, new.dni, new.carrera_id, new.periodo, cnt_particulares;
    end if;

    disponible := greatest(cupo - usados, 0);

    new.minutos_aplicados := least(new.minutos, disponible);
    new.minutos_excedidos := greatest(new.minutos - disponible, 0);
    new.excedido := (new.minutos_excedidos > 0);

    return new;
  end if;

  raise exception 'Tipo invalido: %', new.tipo;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.rpc_cargar_hora(p_dni bigint, p_carrera_id integer, p_fecha date, p_tipo text, p_minutos integer DEFAULT NULL::integer)
 RETURNS horas_registros
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_row public.horas_registros;
begin
  if auth.uid() is null then
    raise exception 'No autenticado.';
  end if;

  if not public.can_horas_write() then
    raise exception 'Sin permiso para cargar horas.';
  end if;

  insert into public.horas_registros (
    dni, carrera_id, fecha, periodo, tipo, minutos, usuario_carga
  )
  values (
    p_dni,
    p_carrera_id,
    p_fecha,
    date_trunc('month', p_fecha)::date,
    upper(p_tipo),
    p_minutos,
    auth.uid()
  )
  returning * into v_row;

  return v_row;
end;
$function$
;
create trigger trg_horas_biu before insert or update of dni,carrera_id,fecha,tipo,minutos
  on public.horas_registros for each row execute function public.horas_before_insert_update();
revoke all on function public.rpc_cargar_hora(bigint,integer,date,text,integer) from public,anon;
grant execute on function public.rpc_cargar_hora(bigint,integer,date,text,integer) to authenticated;
\ir ../migrations/20261112122744_horas_gremiales_y_guardado_seguro.sql
\ir ../migrations/20261112123611_capacidades_gestion.sql
create function pg_temp.assertion(ok boolean) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Falló contrato de Horas.'; end if; end; $$;
set request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set role authenticated;
select public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000011',1001,1,'2026-11-12','PARTICULAR',180);
select public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000012',1001,17,'2026-11-12','GREMIAL',600);
select public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000012',1001,17,'2026-11-12','GREMIAL',600);
select public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000013',1001,17,'2026-11-12','GREMIAL',600);
select public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000014',1001,1,'2026-11-12','OFICIAL',30);
select public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000015',1001,1,'2026-11-12','ENFERMEDAD',null);
select pg_temp.assertion((select schema=2 from jsonb_to_record(public.rpc_gestion_capacidades()) as x(schema int)));
do $$ begin
  begin
    perform public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000012',1001,17,'2026-11-12','GREMIAL',30);
    raise exception 'No detectó reutilización con otros datos.';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000016',1001,17,'2026-11-12','GREMIAL',601);
    raise exception 'Aceptó duración inválida.';
  exception when check_violation then null; end;
end; $$;
reset role;
select pg_temp.assertion((select count(*)=5 from public.horas_registros));
select pg_temp.assertion((select sum(minutos_aplicados)=180 from public.horas_registros));
select pg_temp.assertion(not exists(select 1 from private.horas_operaciones where operacion_id='00000000-0000-4000-8000-000000000016'));
insert into public.horas_registros(dni,carrera_id,fecha,periodo,tipo,minutos,usuario_carga)
 select 1001,17,'2025-01-01','2025-01-01','GREMIAL',30,'00000000-0000-4000-8000-000000000001'
 from generate_series(1,1100);
set role authenticated;
select pg_temp.assertion((select count(*)=2 from public.rpc_horas_periodos()));
reset role;
set request.jwt.claim.sub='00000000-0000-4000-8000-000000000002';
set role authenticated;
do $$ begin
  begin
    perform * from public.rpc_horas_periodos();
    raise exception 'Permitió leer sin rol.';
  exception when insufficient_privilege then null; end;
  begin
    perform public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000012',1001,17,'2026-11-12','GREMIAL',600);
    raise exception 'Permitió escribir sin rol.';
  exception when insufficient_privilege then null; end;
end; $$;
reset role;
select pg_temp.assertion(not has_function_privilege('anon','public.rpc_cargar_hora_segura(uuid,bigint,integer,date,text,integer)','execute'));
select pg_temp.assertion(not has_table_privilege('authenticated','private.horas_operaciones','select'));
begin;
insert into public.persona_inactivo(dni) values(1001);
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$ begin
  begin
    perform public.rpc_cargar_hora_segura('00000000-0000-4000-8000-000000000019',1001,17,'2026-11-12','GREMIAL',30);
    raise exception 'Aceptó una baja desde un padrón en caché.';
  exception when sqlstate '22023' then null; end;
end; $$;
rollback;
select 'OK: Gremiales, carreras, cupos, reenvíos, períodos y permisos.' as resultado;
