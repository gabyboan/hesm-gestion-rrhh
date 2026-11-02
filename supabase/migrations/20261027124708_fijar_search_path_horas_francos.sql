-- Endurecimiento de resolucion de nombres. Conserva cuerpos, firmas, owner y ACL.
-- Las ocho funciones son INVOKER; tablas y helpers propios ya estan calificados.
begin;
set local lock_timeout = '3s';
set local statement_timeout = '30s';

do $check$
declare firma text; funcion oid; ruta text;
begin
  foreach firma in array array[
    'public.can_horas_read()', 'public.can_horas_write()', 'public.can_horas_delete()',
    'public.francos_horario_minutos(time without time zone,time without time zone)',
    'public.francos_before_insert_update()', 'public.francos_horarios_before_insert_update()',
    'public.horas_before_insert_update()', 'public.horas_block_derived_updates()'
  ] loop
    funcion := pg_catalog.to_regprocedure(firma);
    if funcion is null then raise exception 'Falta la funcion esperada: %', firma; end if;
    if (select p.prosecdef from pg_catalog.pg_proc p where p.oid=funcion) then
      raise exception 'La funcion dejo de ser INVOKER: %', firma;
    end if;
    select pg_catalog.substr(v,13) into ruta
    from pg_catalog.pg_proc p cross join lateral pg_catalog.unnest(p.proconfig) v
    where p.oid=funcion and v like 'search_path=%';
    if ruta is not null and ruta not in ('','""') then
      raise exception 'La funcion tiene otra ruta: revisar antes de modificar %', firma;
    end if;
  end loop;
end;
$check$;

alter function public.can_horas_read() set search_path = '';
alter function public.can_horas_write() set search_path = '';
alter function public.can_horas_delete() set search_path = '';
alter function public.francos_horario_minutos(time without time zone,time without time zone) set search_path = '';
alter function public.francos_before_insert_update() set search_path = '';
alter function public.francos_horarios_before_insert_update() set search_path = '';
alter function public.horas_before_insert_update() set search_path = '';
alter function public.horas_block_derived_updates() set search_path = '';

commit;
