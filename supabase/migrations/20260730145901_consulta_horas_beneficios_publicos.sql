-- Saldo reducido para el portal público de consulta de horas.
-- La función sólo puede ejecutarla el service_role del Worker, después de
-- validar Turnstile; no otorga acceso directo a las tablas de origen.

create or replace function public.rpc_consulta_horas_beneficios_public(
  p_dni integer
)
returns table (
  francos_disponibles_hhmm text,
  imprevistos_disponibles integer
)
language sql
stable
security definer
set search_path = public
as $function$
  with carreras as (
    select distinct pc.carrera_id::integer as carrera_id
    from public.persona_carreras pc
    where pc.dni = p_dni
  ),
  saldo_francos as (
    select
      case
        when exists (
          select 1
          from public.francos_movimientos fm
          where fm.dni = p_dni
            and coalesce(fm.anulado, false) = false
        )
        then coalesce(
          sum(fm.minutos) filter (
            where coalesce(fm.anulado, false) = false
          ),
          0
        )::integer
        else null
      end as minutos
    from public.francos_movimientos fm
    where fm.dni = p_dni
  ),
  carrera_imprevisto as (
    select c.carrera_id
    from carreras c
    where c.carrera_id in (1, 3)
    order by c.carrera_id
    limit 1
  ),
  imprevistos as (
    select count(*)::integer as usados
    from public.imprevistos_registros ir
    join carrera_imprevisto ci on ci.carrera_id = ir.carrera_id
    where ir.dni = p_dni
      and ir.deleted_at is null
      and ir.anio = extract(
        year from now() at time zone 'America/Argentina/Buenos_Aires'
      )::integer
  )
  select
    case
      when sf.minutos is null then null
      else
        case when sf.minutos < 0 then '-' else '' end
        || (abs(sf.minutos) / 60)::text
        || ':'
        || lpad((abs(sf.minutos) % 60)::text, 2, '0')
    end as francos_disponibles_hhmm,
    case
      when ci.carrera_id is null then null
      else greatest(3 - coalesce(i.usados, 0), 0)
    end as imprevistos_disponibles
  from saldo_francos sf
  left join carrera_imprevisto ci on true
  left join imprevistos i on true;
$function$;
revoke all on function public.rpc_consulta_horas_beneficios_public(integer)
from public, anon, authenticated;
grant execute on function public.rpc_consulta_horas_beneficios_public(integer)
to service_role;
notify pgrst, 'reload schema';
