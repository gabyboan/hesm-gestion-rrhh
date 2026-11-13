begin;
set local lock_timeout='5s';
set local statement_timeout='45s';

alter table public.partes_medicos add column empleado_condicion text;
comment on column public.partes_medicos.empleado_condicion is
 'Condición de revista al emitir. NULL: desconocida, ambigua o parte anterior sin copia histórica. No reconstruir usando la ficha vigente.';

create function private.medicos_condicion_actual(p_dni bigint) returns text
language sql stable security invoker set search_path='' as $$
 select case when count(distinct s.id)=1 then min(btrim(s.nombre)) end
 from public.persona_situacion_revista ps join public.situacion_revista s on s.id=ps.situacion_id
 where ps.dni=p_dni;
$$;
revoke all on function private.medicos_condicion_actual(bigint) from public,anon,authenticated;

create function private.medicos_condiciones(p_dnis bigint[])
returns table(dni bigint,condicion text)
language plpgsql stable security definer set search_path='' as $$ begin
 if (select auth.uid()) is null or public.can_medicos_read() is distinct from true then
  raise exception 'Sin permiso para consultar la condición.' using errcode='42501';
 end if;
 perform private.exigir_mfa_si_activado();
 perform private.gestion_sesion_exigir();
 if p_dnis is null or cardinality(p_dnis)>2000 then
  raise exception 'La consulta de condiciones es inválida.' using errcode='22023';
 end if;
 return query select p.dni,private.medicos_condicion_actual(p.dni)
 from public.personas p where p.dni=any(p_dnis);
end; $$;
revoke all on function private.medicos_condiciones(bigint[]) from public,anon;
grant execute on function private.medicos_condiciones(bigint[]) to authenticated;

create function public.rpc_medicos_condiciones(p_dnis bigint[])
returns table(dni bigint,condicion text)
language sql stable security invoker set search_path='' as $$ select * from private.medicos_condiciones(p_dnis); $$;
revoke all on function public.rpc_medicos_condiciones(bigint[]) from public,anon;
grant execute on function public.rpc_medicos_condiciones(bigint[]) to authenticated;

create function private.partes_medicos_fijar_condicion() returns trigger
language plpgsql security invoker set search_path='' as $$ begin
 if tg_op='UPDATE' then
  if new.empleado_condicion is distinct from old.empleado_condicion then
   raise exception 'La condición de un parte emitido no se puede modificar.' using errcode='22023';
  end if;
  return new;
 end if;
 -- La RPC ya comprobó la autorización: solo cuenta la condición del servidor.
 new.empleado_condicion:=private.medicos_condicion_actual(new.dni);
 return new;
end; $$;
revoke all on function private.partes_medicos_fijar_condicion() from public,anon,authenticated;
create trigger partes_medicos_fijar_condicion before insert or update on public.partes_medicos
for each row execute function private.partes_medicos_fijar_condicion();

create or replace function public.rpc_gestion_capacidades() returns jsonb
language plpgsql stable security invoker set search_path='' as $$ begin
 if (select auth.uid()) is null then raise exception 'No autenticado.' using errcode='42501'; end if;
 return jsonb_build_object('schema',3,'horas_gremiales',true,'horas_idempotencia',true,
 'horas_periodos',true,'medicos_condicion',true);
end; $$;
revoke all on function public.rpc_gestion_capacidades() from public,anon;
grant execute on function public.rpc_gestion_capacidades() to authenticated;
notify pgrst,'reload schema';
commit;
