-- Normalizar una sola vez por fila, independientemente del numero de terminos.
-- Conserva terminos literales, AND, arrays nulos/vacios y elementos NULL.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create or replace function public.busqueda_coincide(p_campos text[], p_terminos text[])
returns boolean
language plpgsql immutable parallel safe
security invoker
set search_path = ''
as $function$
declare
  v_texto text;
  v_termino text;
begin
  -- La consulta vacia no necesita concatenar ni normalizar la fila.
  if coalesce(cardinality(p_terminos), 0) = 0 then return true; end if;
  v_texto := public.busqueda_normalizar(array_to_string(p_campos, ' '));
  foreach v_termino in array p_terminos loop
    if strpos(v_texto, v_termino) = 0 then return false; end if;
  end loop;
  return true;
end;
$function$;

revoke all on function public.busqueda_coincide(text[], text[]) from public, anon;
grant execute on function public.busqueda_coincide(text[], text[]) to authenticated;
commit;
