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
