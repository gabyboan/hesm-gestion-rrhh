begin;
set local lock_timeout = '3s';
set local statement_timeout = '45s';

-- Integrar el control sin cambiar la política existente de MFA/revocación.
do $$
begin
  if (select md5(pg_get_functiondef(p.oid)) from pg_proc p
      where p.oid = 'public.verificar_mfa_opcional()'::regprocedure)
      is distinct from '28198940213d7f016ea8c9f192aa2bed' then
    raise exception 'El hook de acceso cambió: revisar antes de integrar sesión única.';
  end if;
end;
$$;

-- Se identifica la aplicación al registrar su sesión, no por una cabecera
-- modificable en cada consulta. Otras apps con sesiones propias no se reservan.
create table private.gestion_clientes (
  session_id uuid primary key references auth.sessions(id) on delete cascade
);
create table private.gestion_sesiones (
  user_id uuid primary key references auth.users(id) on delete cascade,
  session_id uuid not null unique references auth.sessions(id) on delete cascade,
  vence_at timestamptz not null
);
alter table private.gestion_clientes enable row level security;
alter table private.gestion_sesiones enable row level security;
revoke all on private.gestion_clientes, private.gestion_sesiones
  from public, anon, authenticated, service_role;

create function private.gestion_sesion_actual()
returns uuid language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_sid uuid;
begin
  if v_uid is null then
    raise exception 'No autenticado.' using errcode = '42501';
  end if;
  perform private.exigir_mfa_si_activado();
  begin
    v_sid := nullif((select auth.jwt()->>'session_id'), '')::uuid;
  exception when invalid_text_representation then
    raise sqlstate 'PT401' using message = 'La sesión ya no es válida. Volvé a iniciar sesión.';
  end;
  if v_sid is null or not exists (
    select 1 from auth.sessions s join auth.users u on u.id = s.user_id
    where s.id = v_sid and s.user_id = v_uid
      and (s.not_after is null or s.not_after > statement_timestamp())
      and (u.banned_until is null or u.banned_until <= statement_timestamp())
  ) then
    raise sqlstate 'PT401' using message = 'La sesión ya no es válida. Volvé a iniciar sesión.';
  end if;
  return v_sid;
end;
$$;
revoke all on function private.gestion_sesion_actual() from public, anon, authenticated, service_role;

create function private.gestion_sesion_operar(p_accion text)
returns boolean language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_sid uuid := private.gestion_sesion_actual();
  v_uid uuid := (select auth.uid());
  v_filas integer;
begin
  case p_accion
    when 'adquirir' then
      -- Registrar también intentos rechazados: ese JWT tampoco podrá usar
      -- tablas, vistas ni RPC de datos mientras la otra Gestión sea dueña.
      insert into private.gestion_clientes(session_id) values (v_sid)
        on conflict do nothing;
      insert into private.gestion_sesiones(user_id, session_id, vence_at)
        values (v_uid, v_sid, statement_timestamp() + interval '2 minutes')
      on conflict (user_id) do update
        set session_id = excluded.session_id, vence_at = excluded.vence_at
      where gestion_sesiones.session_id = v_sid
        or gestion_sesiones.vence_at <= statement_timestamp()
        or not exists (
          select 1 from auth.sessions s
          where s.id = gestion_sesiones.session_id
            and (s.not_after is null or s.not_after > statement_timestamp())
        );
    when 'renovar' then
      update private.gestion_sesiones set vence_at = statement_timestamp() + interval '2 minutes'
      where user_id = v_uid and session_id = v_sid and vence_at > statement_timestamp();
    when 'liberar' then
      delete from private.gestion_sesiones where user_id = v_uid and session_id = v_sid;
    else
      raise exception 'Operación de sesión no válida.';
  end case;
  get diagnostics v_filas = row_count;
  return v_filas = 1;
end;
$$;
revoke all on function private.gestion_sesion_operar(text) from public, anon, authenticated, service_role;
grant execute on function private.gestion_sesion_operar(text) to authenticated;

create function public.rpc_gestion_sesion_adquirir()
returns boolean language sql volatile security invoker set search_path = ''
as $$ select private.gestion_sesion_operar('adquirir'); $$;
create function public.rpc_gestion_sesion_renovar()
returns boolean language sql volatile security invoker set search_path = ''
as $$ select private.gestion_sesion_operar('renovar'); $$;
create function public.rpc_gestion_sesion_liberar()
returns boolean language sql volatile security invoker set search_path = ''
as $$ select private.gestion_sesion_operar('liberar'); $$;
revoke all on function public.rpc_gestion_sesion_adquirir(),
  public.rpc_gestion_sesion_renovar(), public.rpc_gestion_sesion_liberar()
  from public, anon, authenticated, service_role;
grant execute on function public.rpc_gestion_sesion_adquirir(),
  public.rpc_gestion_sesion_renovar(), public.rpc_gestion_sesion_liberar()
  to authenticated;

create function private.gestion_sesion_exigir()
returns void language plpgsql stable security definer set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_sid uuid;
  v_path text := current_setting('request.path', true);
begin
  if v_uid is null then
    raise exception 'No autenticado.' using errcode = '42501';
  end if;
  -- Son RPC sin datos de negocio que permiten adquirir, recuperar o soltar
  -- la reserva. MFA y revocación ya se comprobaron en el hook exterior.
  if v_path in ('/rpc/rpc_gestion_sesion_adquirir', '/rpc/rpc_gestion_sesion_renovar',
      '/rpc/rpc_gestion_sesion_liberar', '/rpc/verificar_mfa_opcional') then
    return;
  end if;
  v_sid := nullif((select auth.jwt()->>'session_id'), '')::uuid;
  if exists (select 1 from private.gestion_clientes where session_id = v_sid)
      and not exists (
        select 1 from private.gestion_sesiones
        where user_id = v_uid and session_id = v_sid and vence_at > statement_timestamp()
      ) then
    raise sqlstate 'PT409' using message = 'Esta cuenta ya tiene una Gestión abierta. Volvé a comprobar la sesión.';
  end if;
end;
$$;
revoke all on function private.gestion_sesion_exigir() from public, anon, authenticated, service_role;
grant execute on function private.gestion_sesion_exigir() to authenticated;

create or replace function public.verificar_mfa_opcional()
returns void language plpgsql stable security invoker set search_path = ''
as $function$
begin
  if current_user = 'authenticated' then
    perform private.exigir_mfa_si_activado();
    perform private.gestion_sesion_exigir();
  end if;
end;
$function$;

comment on table private.gestion_sesiones is
  'Una Gestión por usuario. Renovación cada 30 s; recuperación tras cierre abrupto en 2 min. Auth logout elimina la reserva por FK.';
notify pgrst, 'reload schema';
commit;
