#!/usr/bin/env bash
set -euo pipefail

# Exclusivamente el servicio desechable de GitHub Actions; nunca toma URLs ni
# credenciales de Supabase ni elimina bases existentes.
if [[ "${GITHUB_ACTIONS:-}" != true || "${PGHOST:-}" != 127.0.0.1 ]]; then
  echo 'Este runner requiere el servicio local de GitHub Actions.' >&2
  exit 1
fi
cd "$(dirname "$0")/.."
mkdir -p build/sql-ci
sql() {
  local database="$1" file="$2" label="$3"
  if ! psql -X --dbname="$database" --set=ON_ERROR_STOP=1 --file="$file" >"build/sql-ci/$label.log" 2>&1; then
    tail -n 30 "build/sql-ci/$label.log"
    return 1
  fi
  echo "OK: $label"
}

createdb publication_test
sql publication_test supabase/tests/publicacion_contratos.sql contracts
for migration in \
  20261023093056_partes_medicos_qr_control.sql \
  20261023102714_partes_medicos_por_fecha.sql \
  20261023111125_medicos_carrera_enfermeria.sql; do
  sql publication_test "supabase/migrations/$migration" "$migration"
done
sql publication_test supabase/tests/partes_medicos_domicilio_emision.sql issued-address
sql publication_test supabase/tests/partes_medicos_condicion.sql issued-condition
sql publication_test supabase/tests/seguridad_rendimiento.sql security
psql -X -A -t --dbname=publication_test --set=ON_ERROR_STOP=1 \
  --file=supabase/audits/seguridad_rendimiento.sql >build/sql-ci/audit.json
python3 - <<'PY'
import json
from pathlib import Path
audit = json.loads(Path('build/sql-ci/audit.json').read_text())
assert audit['solo_metadatos'] is True
for finding in audit['hallazgos']:
    assert finding['codigo'] not in {'PRIVILEGIO_ADMINISTRATIVO', 'ESQUEMA_MODIFICABLE', 'DEFAULT_PERMISIVO'}, finding
PY

createdb horas_security_test
sql horas_security_test supabase/tests/horas_seguridad.sql hours-security
createdb gestion_session_test
sql gestion_session_test supabase/tests/gestion_sesion_unica.sql single-session

# Dos transacciones y conexiones distintas compiten realmente por el mismo usuario.
declare -a contenders=()
for suffix in 11 12; do
  psql -X -A -t -q --dbname=gestion_session_test --set=ON_ERROR_STOP=1 \
    >"build/sql-ci/concurrent-$suffix.log" 2>"build/sql-ci/concurrent-$suffix.err" <<SQL &
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-0000000000$suffix","aal":"aal1"}';
select 'RESERVA:' || public.rpc_gestion_sesion_adquirir()::text;
select pg_sleep(0.5);
commit;
SQL
  contenders+=("$!")
done
for contender in "${contenders[@]}"; do wait "$contender"; done
python3 - <<'PY'
from pathlib import Path
results = [Path(f'build/sql-ci/concurrent-{suffix}.log').read_text() for suffix in (11, 12)]
assert all('RESERVA:true' in result or 'RESERVA:false' in result for result in results), results
assert sum('RESERVA:true' in result for result in results) == 1, results
print('OK: dos ingresos concurrentes, una sola Gestión admitida.')
PY

# Los contratos comparten una base ficticia y aplican las migraciones en orden.
createdb licencias_test
for contract in \
  licencias \
  ficha_licencias \
  ficha_formulario_codigos \
  ficha_imprevistos \
  licencias_estudio; do
  sql licencias_test "supabase/tests/$contract.sql" "$contract"
done

# El catálogo también comprueba el cupo consumido por este ensayo concurrente.
psql -X --dbname=licencias_test --set=ON_ERROR_STOP=1 \
  >build/sql-ci/study-prepare.log 2>&1 <<'SQL'
begin;
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo in('LICENCIAS_LECTURA','LICENCIAS_CARGA');
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
select public.rpc_licencias_guardar(null,12345678,129::smallint,d,h,'Cupo concurrente')
from (values('2026-06-01'::date,'2026-06-05'::date),('2026-06-08','2026-06-12'),
('2026-06-15','2026-06-19'),('2026-06-22','2026-06-25')) x(d,h);
commit;
SQL

contenders=()
for day in 29 30; do
  psql -X -A -t -q --dbname=licencias_test --set=ON_ERROR_STOP=1 \
    >"build/sql-ci/study-$day.log" 2>"build/sql-ci/study-$day.err" <<SQL &
begin;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
select public.rpc_licencias_guardar(null,12345678,129::smallint,'2026-06-$day','2026-06-$day','Cupo concurrente');
select pg_sleep(0.5);
commit;
SQL
  contenders+=("$!")
done
study_winners=0
for contender in "${contenders[@]}"; do
  if wait "$contender"; then study_winners=$((study_winners + 1)); fi
done
if [[ "$study_winners" != 1 ]]; then
  echo "El último día de Estudio fue consumido por $study_winners solicitudes." >&2
  exit 1
fi
echo 'OK: cupo de Estudio protegido ante dos solicitudes simultáneas.'

for contract in \
  licencias_catalogo_excel \
  licencias_fichas_papel \
  licencias_duelo_parentescos \
  licencias_francos_cantidad_papel \
  licencias_documentacion_pendiente; do
  sql licencias_test "supabase/tests/$contract.sql" "$contract"
done

createdb horas_next_test
sql horas_next_test supabase/tests/horas_gremiales.sql gremiales

contenders=()
for attempt in 1 2; do
  psql -X -A -t -q --dbname=horas_next_test --set=ON_ERROR_STOP=1 \
    --file=supabase/tests/horas_operacion_concurrente.sql >"build/sql-ci/hours-$attempt.log" 2>"build/sql-ci/hours-$attempt.err" &
  contenders+=("$!")
done
for contender in "${contenders[@]}"; do wait "$contender"; done
python3 - <<'PY'
import re
from pathlib import Path
ids = [re.search(r'OPERACION:(\d+)', Path(f'build/sql-ci/hours-{i}.log').read_text()).group(1) for i in (1, 2)]
assert len(set(ids)) == 1, ids
print('OK: reenvios concurrentes de horas sin duplicados.')
PY
