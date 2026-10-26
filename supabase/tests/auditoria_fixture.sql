\set ON_ERROR_STOP on
-- Fixture adversarial: SOLO en el cluster sintetico creado por test_database.ps1.
do $$
begin
  if current_database() <> 'publication_test' then
    raise exception 'Se requiere la base aislada publication_test.';
  end if;
end;
$$;
create table public._auditoria_padre (a integer, b integer, secreto text, primary key (a, b));
insert into public._auditoria_padre values (1, 2, 'SENTINELA_PRIVADA_NO_EXPORTAR');
create table public._auditoria_hija (
  id integer, a integer, b integer, c integer, d integer,
  constraint auditoria_fk_sin_indice foreign key (a, b) references public._auditoria_padre(a, b),
  constraint auditoria_fk_con_indice foreign key (c, d) references public._auditoria_padre(a, b)
);
-- INCLUDE no cubre un prefijo de busqueda. El orden de igualdad compuesto si.
create index on public._auditoria_hija (id) include (a, b);
create index on public._auditoria_hija (d, c);
alter table public._auditoria_hija enable row level security;
create policy auditoria_abierta on public._auditoria_hija to authenticated using (((true)));
create policy auditoria_metadata on public._auditoria_hija to authenticated
  using ((current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'admin') = 'true');
create function public._auditoria_definer() returns boolean
  language sql security definer as $$ select true; $$;
grant execute on function public._auditoria_definer() to public;
create view public._auditoria_vista as select a, b from public._auditoria_padre;
grant select on public._auditoria_vista to authenticated;
-- PostgreSQL conserva tanto "on" como "true" en reloptions.
create view public._auditoria_vista_invoker with (security_invoker=on)
  as select a, b from public._auditoria_padre;
grant select on public._auditoria_vista_invoker to authenticated;
grant create on schema public to authenticated;
grant truncate on public._auditoria_padre to authenticated;
