begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Mantener intactas las modalidades anteriores y sus cupos.
alter table public.horas_registros drop constraint horas_registros_tipo_check;
alter table public.horas_registros add constraint horas_registros_tipo_check
  check (tipo in ('PARTICULAR','ENFERMEDAD','OFICIAL','GREMIAL'));
alter table public.horas_registros drop constraint ck_tipo_minutos;
alter table public.horas_registros add constraint ck_tipo_minutos check (
  (tipo='PARTICULAR' and minutos is not null and minutos between 30 and 180 and minutos%30=0)
  or (tipo in ('OFICIAL','GREMIAL') and minutos is not null and minutos between 30 and 600 and minutos%30=0)
  or (tipo='ENFERMEDAD' and minutos is null));
alter table public.horas_registros drop constraint ck_carrera_valida;
alter table public.horas_registros add constraint ck_carrera_valida
  check (tipo in ('OFICIAL','GREMIAL') or carrera_id=any(array[1,2,3]));

-- Ampliar la rama existente sin reemplazar el resto del cálculo histórico.
-- El bloqueo transaccional también evita carreras al calcular cupos mensuales.
do $migration$
declare definition text;
begin
  definition := replace(pg_get_functiondef('public.horas_before_insert_update()'::regprocedure), E'\r', '');
  if position('if new.tipo = ''OFICIAL'' then' in definition)=0 then
    raise exception 'El cálculo de horas cambió; revisar antes de ampliar Gremiales.';
  end if;
  definition := replace(definition, 'if new.tipo = ''OFICIAL'' then',
    'if new.tipo in (''OFICIAL'',''GREMIAL'') then');
  definition := regexp_replace(definition, E'begin\n',
    E'begin\n  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.dni::text || ''/'' || new.carrera_id::text || ''/'' || pg_catalog.date_trunc(''month'',new.fecha)::date::text, 0));\n');
  execute definition;
end;
$migration$;

-- Registro de solicitudes confirmado en la misma transacción que la hora.
create table private.horas_operaciones (
  usuario_id uuid not null references auth.users(id) on delete cascade,
  operacion_id uuid not null,
  datos jsonb not null,
  resultado jsonb not null,
  created_at timestamptz not null default now(),
  primary key(usuario_id,operacion_id)
);
alter table private.horas_operaciones enable row level security;
revoke all on private.horas_operaciones from public,anon,authenticated,service_role;

create function private.cargar_hora_segura(p_operacion_id uuid,p_dni bigint,
  p_carrera_id integer,p_fecha date,p_tipo text,p_minutos integer default null)
returns public.horas_registros language plpgsql security definer set search_path=''
as $function$
declare
  uid uuid := (select auth.uid());
  datos jsonb;
  anterior private.horas_operaciones;
  resultado public.horas_registros;
begin
  if uid is null or public.can_horas_write() is distinct from true then
    raise exception 'Sin permiso para cargar horas.' using errcode='42501';
  end if;
  perform private.exigir_mfa_si_activado();
  if p_operacion_id is null then
    raise exception 'Falta identificar la operación.' using errcode='22023';
  end if;
  datos := jsonb_build_array(p_dni,p_carrera_id,p_fecha,upper(p_tipo),p_minutos);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text||p_operacion_id::text,0));
  select * into anterior from private.horas_operaciones
    where usuario_id=uid and operacion_id=p_operacion_id;
  if found then
    if anterior.datos is distinct from datos then
      raise exception 'La operación ya corresponde a otros datos.' using errcode='22023';
    end if;
    select * into resultado from jsonb_populate_record(null::public.horas_registros,anterior.resultado);
    return resultado;
  end if;
  -- Revalidar una baja aunque el padrón del cliente siga vigente en caché.
  if upper(p_tipo) in ('OFICIAL','GREMIAL') and exists (
    select 1 from public.persona_inactivo pi where pi.dni=p_dni
  ) then
    raise exception 'La persona ya no está habilitada para esta carga.' using errcode='22023';
  end if;
  select * into resultado from public.rpc_cargar_hora(p_dni,p_carrera_id,p_fecha,p_tipo,p_minutos);
  insert into private.horas_operaciones(usuario_id,operacion_id,datos,resultado)
    values(uid,p_operacion_id,datos,to_jsonb(resultado));
  return resultado;
end;
$function$;
revoke all on function private.cargar_hora_segura(uuid,bigint,integer,date,text,integer)
  from public,anon;
grant execute on function private.cargar_hora_segura(uuid,bigint,integer,date,text,integer) to authenticated;
create function public.rpc_cargar_hora_segura(p_operacion_id uuid,p_dni bigint,
  p_carrera_id integer,p_fecha date,p_tipo text,p_minutos integer default null)
returns public.horas_registros language sql security invoker set search_path=''
as $$ select private.cargar_hora_segura(p_operacion_id,p_dni,p_carrera_id,p_fecha,p_tipo,p_minutos); $$;
revoke all on function public.rpc_cargar_hora_segura(uuid,bigint,integer,date,text,integer) from public,anon;
grant execute on function public.rpc_cargar_hora_segura(uuid,bigint,integer,date,text,integer) to authenticated;

create function private.horas_periodos() returns table(periodo date)
language plpgsql stable security definer set search_path=''
as $$ begin
  if (select auth.uid()) is null or public.can_horas_read() is distinct from true then
    raise exception 'Sin permiso para consultar horas.' using errcode='42501';
  end if;
  perform private.exigir_mfa_si_activado();
  return query select distinct hr.periodo from public.horas_registros hr order by hr.periodo desc;
end; $$;
revoke all on function private.horas_periodos() from public,anon;
grant execute on function private.horas_periodos() to authenticated;
create function public.rpc_horas_periodos() returns table(periodo date)
language sql stable security invoker set search_path='' as $$ select * from private.horas_periodos(); $$;
revoke all on function public.rpc_horas_periodos() from public,anon;
grant execute on function public.rpc_horas_periodos() to authenticated;
notify pgrst,'reload schema';
commit;
