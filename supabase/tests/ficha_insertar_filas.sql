\set ON_ERROR_STOP on
\encoding UTF8
do $$ begin
  if current_database()<>'licencias_test' then raise exception 'Solo licencias_test.'; end if;
end $$;
-- La sesión y MFA tienen contratos propios; esta base mínima no instala Auth.
create function private.exigir_mfa_si_activado() returns void language plpgsql as $$ begin return; end $$;
create function private.gestion_sesion_exigir() returns void language plpgsql as $$ begin return; end $$;
\ir ../migrations/20261116153646_ficha_insertar_filas.sql
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo in ('FICHA_LECTURA','LICENCIAS_LECTURA','LICENCIAS_CARGA','LICENCIAS_ADM') on conflict do nothing;
set local role authenticated;
select public.rpc_licencias_guardar_con_datos(null,12345678,101::smallint,'2026-11-16','2026-11-16','Referencia sintética',null,null,null) as referencia \gset
select public.rpc_licencias_insertar_en_ficha('{"p_dni":12345678,"p_tipo_id":101,"p_desde":"2026-11-30","p_hasta":"2026-11-30"}',2026,:referencia,'arriba') as nueva \gset
select 1 / ((select (a.r->'orden_ficha_por_anio'->>'2026')::int + 1 = (b.r->'orden_ficha_por_anio'->>'2026')::int
  from public.rpc_licencias_historial(2026,12345678) a(r),public.rpc_licencias_historial(2026,12345678) b(r)
  where a.r->>'id'=:'nueva' and b.r->>'id'=:'referencia')::int);
select 1 / ((select r->>'desde'='2026-11-30' from public.rpc_licencias_historial(2026,12345678) r where r->>'id'=:'nueva')::int);
reset role;
rollback;
select 'OK: inserta una licencia real en posición indicada sin cambiar sus fechas.';
