-- Verifica los permisos existentes antes de consultar el total diario.
begin;set local search_path=pg_catalog;set local lock_timeout='3s';set local statement_timeout='45s';
do $guard$ declare f jsonb; acl jsonb; p record; begin
 for f in select value from jsonb_array_elements('[{"identidad": "public.rpc_francos_crear(bigint,bigint,date,integer,text,text)", "propietario": "postgres", "permisos": [{"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "postgres"}, {"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "authenticated"}], "hash": "5e610912ca397725f9f37cfa2d0ed1cc"}]'::jsonb) loop
  select * into p from pg_proc where oid=to_regprocedure(f->>'identidad');
  if not found or md5(pg_get_functiondef(p.oid))<>f->>'hash'
    or pg_get_userbyid(p.proowner)<>f->>'propietario' then
    raise exception 'Definicion/owner no esperado: %',f->>'identidad';end if;
  select jsonb_agg(jsonb_build_object('rol',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
   'grantor',pg_get_userbyid(a.grantor),'privilegio',a.privilege_type,'grantable',a.is_grantable)) into acl
   from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a;
  if not(acl @> (f->'permisos') and (f->'permisos') @> acl) then raise exception 'ACL no esperada: %',f->>'identidad';end if;
 end loop;
end;$guard$;
CREATE OR REPLACE FUNCTION public.rpc_francos_crear(p_dni bigint, p_carrera_id bigint, p_fecha date, p_minutos integer, p_motivo text, p_observacion text DEFAULT NULL::text)
 RETURNS public.francos_movimientos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_row public.francos_movimientos;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;

  if not (public.can_francos_admin_bank() or public.can_francos_use_bank()) then
    raise exception 'Sin permiso para cargar movimientos de francos.';
  end if;

  if p_minutos > 0 and not public.can_francos_admin_bank() then
    raise exception 'Sin permiso para sumar banco de francos.';
  end if;

  if p_minutos < 0 and not public.can_francos_use_bank() then
    raise exception 'Sin permiso para usar francos.';
  end if;

  if not (
    public.can_francos_admin_bank()
    or public.can_access_person(p_dni)
  ) then
    raise exception 'Sin permiso para acceder a la persona.';
  end if;



  if p_fecha is null then
    raise exception 'Debe indicar la fecha.';
  end if;

  perform public.validar_francos_minutos(p_minutos);
  perform public.validar_francos_tope_dia(
    p_dni,
    p_carrera_id,
    p_fecha,
    p_minutos
  );

  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'Debe indicar un motivo.';
  end if;

  insert into public.francos_movimientos (
    dni,
    carrera_id,
    fecha,
    periodo,
    minutos,
    motivo,
    observacion,
    usuario_carga
  )
  values (
    p_dni,
    p_carrera_id,
    p_fecha,
    date_trunc('month', p_fecha)::date,
    p_minutos,
    trim(p_motivo),
    null,
    (select auth.uid())
  )
  returning * into v_row;

  return v_row;
end;
$function$
;
do $guard$ declare f jsonb; acl jsonb; p record; begin
 for f in select value from jsonb_array_elements('[{"identidad": "public.rpc_francos_crear(bigint,bigint,date,integer,text,text)", "propietario": "postgres", "permisos": [{"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "postgres"}, {"grantable": false, "grantor": "postgres", "privilegio": "EXECUTE", "rol": "authenticated"}], "hash": "1eb4dd2b1b1da4d22f70984b86c8e1a1"}]'::jsonb) loop
  select * into p from pg_proc where oid=to_regprocedure(f->>'identidad');
  if not found or md5(pg_get_functiondef(p.oid))<>f->>'hash'
    or pg_get_userbyid(p.proowner)<>f->>'propietario' then
    raise exception 'Definicion/owner no esperado: %',f->>'identidad';end if;
  select jsonb_agg(jsonb_build_object('rol',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
   'grantor',pg_get_userbyid(a.grantor),'privilegio',a.privilege_type,'grantable',a.is_grantable)) into acl
   from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a;
  if not(acl @> (f->'permisos') and (f->'permisos') @> acl) then raise exception 'ACL no esperada: %',f->>'identidad';end if;
 end loop;
end;$guard$;
commit;
