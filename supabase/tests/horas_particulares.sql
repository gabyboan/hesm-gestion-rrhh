\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'horas_next_test' then
    raise exception 'Solo la base aislada horas_next_test.';
  end if;
end; $$;
\ir ../migrations/20261117001144_horas_particulares_sin_bloqueo_por_cantidad.sql

begin;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
do $$
declare
  registro public.horas_registros;
  operacion uuid;
begin
  -- La séptima y siguientes cargas se conservan completas como excedidas.
  for i in 1..8 loop
    operacion := ('00000000-0000-4000-8000-' || lpad((100+i)::text,12,'0'))::uuid;
    select * into registro from public.rpc_cargar_hora_segura(
      operacion,1001,1,'2027-01-10','PARTICULAR',30);
    if registro.minutos<>30
      or registro.minutos_aplicados<>(case when i<=6 then 30 else 0 end)
      or registro.minutos_excedidos<>(case when i<=6 then 0 else 30 end)
      or registro.excedido<>(i>6) then
      raise exception 'Cálculo incorrecto en carga particular %.',i;
    end if;
  end loop;
  -- Reintentar una carga excedida conserva la misma operación.
  perform public.rpc_cargar_hora_segura(operacion,1001,1,'2027-01-10','PARTICULAR',30);
  -- Mes independiente y registro que cruza parcialmente el cupo.
  perform public.rpc_cargar_hora_segura(
    '00000000-0000-4000-8000-000000000201',1001,1,'2027-02-01','PARTICULAR',120);
  select * into registro from public.rpc_cargar_hora_segura(
    '00000000-0000-4000-8000-000000000202',1001,1,'2027-02-02','PARTICULAR',120);
  if registro.minutos<>120 or registro.minutos_aplicados<>60
    or registro.minutos_excedidos<>60 or not registro.excedido then
    raise exception 'Se perdió duración al cruzar el cupo.';
  end if;
  -- Los otros tipos conservan sus reglas después de reemplazar el trigger.
  perform public.rpc_cargar_hora_segura(
    '00000000-0000-4000-8000-000000000301',1001,1,'2027-01-10','OFICIAL',600);
  select * into registro from public.rpc_cargar_hora_segura(
    '00000000-0000-4000-8000-000000000302',1001,17,'2027-01-10','GREMIAL',600);
  if registro.minutos_aplicados<>0 or registro.minutos_excedidos<>0 or registro.excedido then
    raise exception 'Gremiales consumió el cupo particular.';
  end if;
  perform public.rpc_cargar_hora_segura(
    '00000000-0000-4000-8000-000000000303',1001,1,'2027-01-10','ENFERMEDAD',null);
  begin
    perform public.rpc_cargar_hora_segura(
      '00000000-0000-4000-8000-000000000304',1001,1,'2027-01-11','ENFERMEDAD',null);
    raise exception using errcode='ZX001',message='Se permitió una segunda enfermedad.';
  exception when raise_exception then null; end;
  begin
    perform public.rpc_cargar_hora_segura(
      '00000000-0000-4000-8000-000000000305',1001,1,'2027-01-10','PARTICULAR',31);
    raise exception using errcode='ZX001',message='Se permitió una duración inválida.';
  exception when check_violation then null; end;
end; $$;
reset role;
select pg_temp.assertion((select count(*)=8 and sum(minutos)=240
  and sum(minutos_aplicados)=180 and sum(minutos_excedidos)=60
  from public.horas_registros where periodo='2027-01-01' and tipo='PARTICULAR'));

-- Tras borrar una hora, las duraciones restantes siguen consumiendo cupo.
delete from public.horas_registros
where periodo='2027-02-01' and fecha='2027-02-01';
set local role authenticated;
do $$ declare registro public.horas_registros; begin
  select * into registro from public.rpc_cargar_hora_segura(
    '00000000-0000-4000-8000-000000000203',1001,1,'2027-02-03','PARTICULAR',90);
  if registro.minutos_aplicados<>60 or registro.minutos_excedidos<>30 then
    raise exception 'Cupo incorrecto después de borrar.';
  end if;
end; $$;
reset role;
rollback;
select 'OK: Particulares sin bloqueo, duración completa, reintento y cupo por mes.' as resultado;
