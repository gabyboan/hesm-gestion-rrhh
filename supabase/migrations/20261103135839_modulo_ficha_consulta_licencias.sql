begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

insert into public.roles(codigo, nombre) values
  ('FICHA_LECTURA', 'Ficha: consultar datos e historial de licencias')
on conflict (codigo) do nothing;

create function public.can_ficha_read() returns boolean
language sql stable security invoker set search_path = '' as $$
  select (select auth.uid()) is not null and public.has_role_code('FICHA_LECTURA');
$$;
revoke all on function public.can_ficha_read() from public, anon, authenticated;
grant execute on function public.can_ficha_read() to authenticated;

-- La consulta de Ficha no concede permisos de carga ni administración.
drop policy licencias_registros_lectura on public.licencias_registros;
create policy licencias_registros_lectura on public.licencias_registros
  for select to authenticated using (importacion_confirmada and
    ((select public.can_licencias_read()) or (select public.can_ficha_read())));
drop policy licencias_tipos_lectura on public.licencias_tipos;
create policy licencias_tipos_lectura on public.licencias_tipos
  for select to authenticated using
    ((select public.can_licencias_read()) or (select public.can_ficha_read()));

create function private.ficha_personas(p_buscar text default null)
returns table(dni bigint, apellido_nombre text, legajo integer, carrera text,
  situacion_revista text, funcion text, activo boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not public.can_ficha_read() then
    raise exception 'Sin permiso para consultar fichas.' using errcode = '42501';
  end if;
  return query
  select p.dni, btrim(p.apellido || ' ' || p.nombre), p.legajo,
    coalesce((select string_agg(c.nombre, ', ' order by c.nombre)
      from public.persona_carreras pc join public.carreras c on c.id = pc.carrera_id
      where pc.dni = p.dni), ''),
    coalesce((select string_agg(s.nombre, ', ' order by s.nombre)
      from public.persona_situacion_revista ps join public.situacion_revista s on s.id = ps.situacion_id
      where ps.dni = p.dni), ''),
    coalesce((select string_agg(f.nombre, ', ' order by f.nombre)
      from public.persona_funciones pf join public.funciones f on f.id = pf.funcion_id
      where pf.dni = p.dni), ''),
    not exists(select 1 from public.persona_inactivo pi where pi.dni = p.dni)
  from public.personas p
  where public.busqueda_coincide(array[p.apellido, p.nombre, p.dni::text, p.legajo::text],
    public.busqueda_terminos(p_buscar))
  order by p.apellido, p.nombre, p.dni limit 100;
end;
$$;
create function public.rpc_ficha_personas(p_buscar text default null)
returns table(dni bigint, apellido_nombre text, legajo integer, carrera text,
  situacion_revista text, funcion text, activo boolean)
language sql stable security invoker set search_path = '' as $$
  select * from private.ficha_personas(p_buscar);
$$;
revoke all on function public.rpc_ficha_personas(text), private.ficha_personas(text)
  from public, anon, authenticated;
grant execute on function public.rpc_ficha_personas(text), private.ficha_personas(text)
  to authenticated;
notify pgrst, 'reload schema';
commit;
