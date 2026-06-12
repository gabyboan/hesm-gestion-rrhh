-- Modulo de partes medicos para imprimir sobre formularios preimpresos.

insert into public.roles (codigo, nombre)
values
  ('MEDICOS_LECTURA', 'Partes medicos - Lectura'),
  ('MEDICOS_ESCRITURA', 'Partes medicos - Emision'),
  ('MEDICOS_ADM', 'Partes medicos - Anulacion')
on conflict (codigo) do update
set nombre = excluded.nombre;

create or replace function public.can_medicos_read()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('MEDICOS_LECTURA');
$function$;

create or replace function public.can_medicos_create()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('MEDICOS_LECTURA')
      and public.has_role_code('MEDICOS_ESCRITURA');
$function$;

create or replace function public.can_medicos_admin()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.has_role_code('MEDICOS_LECTURA')
      and public.has_role_code('MEDICOS_ADM');
$function$;

create table if not exists public.partes_medicos (
  id bigserial primary key,
  dni bigint not null references public.personas(dni),
  fecha date not null
    default timezone('America/Argentina/Buenos_Aires', now())::date,
  tipo text not null,
  empleado_apellido text not null,
  empleado_nombre text not null,
  empleado_legajo integer not null,
  familiar_apellido_nombre text,
  familiar_edad integer,
  familiar_parentesco text,
  usuario_carga uuid not null default auth.uid(),
  usuario_anula uuid,
  created_at timestamptz not null default now(),
  anulado_at timestamptz,
  constraint partes_medicos_tipo_chk check (
    tipo in (
      'DOMICILIO',
      'CONSULTORIO',
      'CANJE',
      'DOMICILIO_FAMILIAR'
    )
  ),
  constraint partes_medicos_legajo_chk check (empleado_legajo > 0),
  constraint partes_medicos_familiar_edad_chk check (
    familiar_edad is null or familiar_edad between 0 and 120
  ),
  constraint partes_medicos_familiar_chk check (
    (
      tipo = 'DOMICILIO_FAMILIAR'
      and nullif(trim(familiar_apellido_nombre), '') is not null
      and familiar_edad is not null
      and nullif(trim(familiar_parentesco), '') is not null
    )
    or (
      tipo <> 'DOMICILIO_FAMILIAR'
      and familiar_apellido_nombre is null
      and familiar_edad is null
      and familiar_parentesco is null
    )
  )
);

create index if not exists partes_medicos_fecha_idx
  on public.partes_medicos (fecha desc)
  where anulado_at is null;

create index if not exists partes_medicos_dni_fecha_idx
  on public.partes_medicos (dni, fecha desc)
  where anulado_at is null;

create index if not exists partes_medicos_dni_idx
  on public.partes_medicos (dni);

alter table public.partes_medicos enable row level security;

create or replace function public.rpc_medicos_personas(p_buscar text default null)
returns table (
  dni bigint,
  apellido text,
  nombre text,
  legajo integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;

  return query
  select p.dni, p.apellido, p.nombre, p.legajo
  from public.personas p
  where p.legajo is not null
    and (
      p_buscar is null
      or trim(p_buscar) = ''
      or p.dni::text ilike '%' || trim(p_buscar) || '%'
      or p.legajo::text ilike '%' || trim(p_buscar) || '%'
      or p.apellido ilike '%' || trim(p_buscar) || '%'
      or p.nombre ilike '%' || trim(p_buscar) || '%'
    )
  order by p.apellido, p.nombre, p.dni;
end;
$function$;

create or replace function public.rpc_medicos_registros(p_buscar text default null)
returns table (
  id bigint,
  dni bigint,
  fecha date,
  tipo text,
  empleado_apellido text,
  empleado_nombre text,
  empleado_legajo integer,
  familiar_apellido_nombre text,
  familiar_edad integer,
  familiar_parentesco text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_read() then
    raise exception 'Sin permiso para ver partes medicos.';
  end if;

  return query
  select
    pm.id,
    pm.dni,
    pm.fecha,
    pm.tipo,
    pm.empleado_apellido,
    pm.empleado_nombre,
    pm.empleado_legajo,
    pm.familiar_apellido_nombre,
    pm.familiar_edad,
    pm.familiar_parentesco,
    pm.created_at
  from public.partes_medicos pm
  where pm.anulado_at is null
    and (
      p_buscar is null
      or trim(p_buscar) = ''
      or pm.dni::text ilike '%' || trim(p_buscar) || '%'
      or pm.empleado_legajo::text ilike '%' || trim(p_buscar) || '%'
      or pm.empleado_apellido ilike '%' || trim(p_buscar) || '%'
      or pm.empleado_nombre ilike '%' || trim(p_buscar) || '%'
      or coalesce(pm.familiar_apellido_nombre, '') ilike
        '%' || trim(p_buscar) || '%'
    )
  order by pm.fecha desc, pm.id desc
  limit 500;
end;
$function$;

create or replace function public.rpc_medicos_crear(
  p_dni bigint,
  p_tipo text,
  p_familiar_apellido_nombre text default null,
  p_familiar_edad integer default null,
  p_familiar_parentesco text default null
)
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_persona public.personas%rowtype;
  v_tipo text := upper(trim(coalesce(p_tipo, '')));
  v_id bigint;
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_create() then
    raise exception 'Sin permiso para emitir partes medicos.';
  end if;

  select *
  into v_persona
  from public.personas p
  where p.dni = p_dni;

  if not found then
    raise exception 'La persona no existe.';
  end if;
  if v_persona.legajo is null or v_persona.legajo <= 0 then
    raise exception 'La persona debe tener numero de legajo.';
  end if;
  if v_tipo not in ('DOMICILIO', 'CONSULTORIO', 'CANJE', 'DOMICILIO_FAMILIAR') then
    raise exception 'Tipo de parte medico invalido.';
  end if;
  if v_tipo = 'DOMICILIO_FAMILIAR' and (
    nullif(trim(coalesce(p_familiar_apellido_nombre, '')), '') is null
    or p_familiar_edad is null
    or nullif(trim(coalesce(p_familiar_parentesco, '')), '') is null
  ) then
    raise exception 'Completa nombre, edad y parentesco del familiar.';
  end if;

  insert into public.partes_medicos (
    dni,
    tipo,
    empleado_apellido,
    empleado_nombre,
    empleado_legajo,
    familiar_apellido_nombre,
    familiar_edad,
    familiar_parentesco
  )
  values (
    v_persona.dni,
    v_tipo,
    trim(v_persona.apellido),
    trim(v_persona.nombre),
    v_persona.legajo,
    case when v_tipo = 'DOMICILIO_FAMILIAR'
      then trim(p_familiar_apellido_nombre) end,
    case when v_tipo = 'DOMICILIO_FAMILIAR' then p_familiar_edad end,
    case when v_tipo = 'DOMICILIO_FAMILIAR'
      then trim(p_familiar_parentesco) end
  )
  returning id into v_id;

  return v_id;
end;
$function$;

create or replace function public.rpc_medicos_anular(p_id bigint)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'No autenticado.';
  end if;
  if not public.can_medicos_admin() then
    raise exception 'Sin permiso para anular partes medicos.';
  end if;

  update public.partes_medicos
  set anulado_at = now(),
      usuario_anula = auth.uid()
  where id = p_id
    and anulado_at is null;

  return found;
end;
$function$;

revoke all on table public.partes_medicos from anon, authenticated;
revoke execute on function public.can_medicos_read() from public, anon;
revoke execute on function public.can_medicos_create() from public, anon;
revoke execute on function public.can_medicos_admin() from public, anon;
revoke execute on function public.rpc_medicos_personas(text) from public, anon;
revoke execute on function public.rpc_medicos_registros(text) from public, anon;
revoke execute on function public.rpc_medicos_crear(bigint, text, text, integer, text)
from public, anon;
revoke execute on function public.rpc_medicos_anular(bigint) from public, anon;

grant execute on function public.can_medicos_read() to authenticated;
grant execute on function public.can_medicos_create() to authenticated;
grant execute on function public.can_medicos_admin() to authenticated;
grant execute on function public.rpc_medicos_personas(text) to authenticated;
grant execute on function public.rpc_medicos_registros(text) to authenticated;
grant execute on function public.rpc_medicos_crear(bigint, text, text, integer, text)
to authenticated;
grant execute on function public.rpc_medicos_anular(bigint) to authenticated;

notify pgrst, 'reload schema';
