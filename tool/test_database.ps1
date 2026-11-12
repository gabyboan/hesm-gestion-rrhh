param(
  [string]$PostgresBin = 'C:/Program Files/PostgreSQL/16/bin'
)
$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$runPath = Join-Path $repoPath ('build/database-validation/' + [guid]::NewGuid().ToString('N'))
$clusterPath = Join-Path $runPath 'cluster'
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$pgCtl = Join-Path $PostgresBin 'pg_ctl.exe'
$started = $false

function Invoke-CheckedNative {
  param([string]$Executable, [string[]]$Arguments, [string]$LogName)
  $logPath = Join-Path $runPath $LogName
  $savedPreference = $ErrorActionPreference
  try {
    # Windows PowerShell representa NOTICE de psql como NativeCommandError.
    # La comprobacion correcta es ON_ERROR_STOP junto con el codigo de salida.
    $ErrorActionPreference = 'Continue'
    & $Executable @Arguments *> $logPath
    $nativeExitCode = $LASTEXITCODE
  }
  finally { $ErrorActionPreference = $savedPreference }
  if ($nativeExitCode -ne 0) {
    Get-Content -LiteralPath $logPath -Tail 20 | Write-Host
    throw "Fallo $Executable. Registro: $logPath"
  }
}

try {
  # Siempre un cluster nuevo con datos ficticios, accesible solo en loopback.
  # No lee credenciales.env ni acepta URLs de bases compartidas.
  Invoke-CheckedNative (Join-Path $PostgresBin 'initdb.exe') @(
    '-D', $clusterPath, '-U', 'postgres', '--auth=trust', '--encoding=UTF8', '--locale=C'
  ) 'initdb.log'
  $serverLog = Join-Path $runPath 'server.log'
  $pgArgs = @('-D', ('"{0}"' -f $clusterPath), '-l', ('"{0}"' -f $serverLog),
    '-o', ('"-h 127.0.0.1 -p {0}"' -f $port), '-w', 'start')
  # Start-Process -Wait espera tambien a postgres en Windows. Esperar solo pg_ctl.
  $process = Start-Process -FilePath $pgCtl -ArgumentList $pgArgs -WindowStyle Hidden -PassThru
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) { throw "No se pudo iniciar PostgreSQL. Revisar $serverLog" }
  $started = $true
  Invoke-CheckedNative (Join-Path $PostgresBin 'createdb.exe') @(
    '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', 'publication_test'
  ) 'createdb.log'
  $psql = Join-Path $PostgresBin 'psql.exe'
  $connectionArgs = @('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'publication_test', '-v', 'ON_ERROR_STOP=1')
  Invoke-CheckedNative $psql ($connectionArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/publicacion_contratos.sql'))) 'contratos.log'
  # Integrar tambien las tres migraciones medicas posteriores a esos contratos.
  foreach ($migrationName in @('20261023093056_partes_medicos_qr_control.sql',
    '20261023102714_partes_medicos_por_fecha.sql', '20261023111125_medicos_carrera_enfermeria.sql')) {
    Invoke-CheckedNative $psql ($connectionArgs + @('-f',
      (Join-Path $repoPath "supabase/migrations/$migrationName"))) "$migrationName.log"
  }
  # El contrato emite un parte anterior, aplica la migración y prueba
  # cambios de ficha, consultas, ausencia de domicilio e inmutabilidad.
  Invoke-CheckedNative $psql ($connectionArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/partes_medicos_domicilio_emision.sql'))) 'domicilio-emision.log'
  Invoke-CheckedNative $psql ($connectionArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/seguridad_rendimiento.sql'))) 'seguridad-rendimiento.log'
  Invoke-CheckedNative $psql ($connectionArgs + @('-A', '-t', '-f',
    (Join-Path $repoPath 'supabase/audits/seguridad_rendimiento.sql'))) 'auditoria.json'
  $audit = Get-Content -LiteralPath (Join-Path $runPath 'auditoria.json') -Raw | ConvertFrom-Json
  if ($audit.solo_metadatos -ne $true) { throw 'La auditoria no devolvio su contrato esperado.' }
  foreach ($code in @('PRIVILEGIO_ADMINISTRATIVO', 'ESQUEMA_MODIFICABLE', 'DEFAULT_PERMISIVO')) {
    if (@($audit.hallazgos | Where-Object { $_.codigo -eq $code }).Count -gt 0) {
      throw "La auditoria detecto $code despues del endurecimiento."
    }
  }
  Invoke-CheckedNative $psql ($connectionArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/auditoria_fixture.sql'))) 'auditoria-fixture.log'
  Invoke-CheckedNative $psql ($connectionArgs + @('-A', '-t', '-f',
    (Join-Path $repoPath 'supabase/audits/seguridad_rendimiento.sql'))) 'auditoria-adversarial.json'
  $adversarialText = Get-Content -LiteralPath (Join-Path $runPath 'auditoria-adversarial.json') -Raw
  if ($adversarialText.Contains('SENTINELA_PRIVADA_NO_EXPORTAR')) { throw 'La auditoria exporto datos de una fila.' }
  $adversarial = $adversarialText | ConvertFrom-Json
  foreach ($code in @('RLS_DESACTIVADO', 'PRIVILEGIO_ADMINISTRATIVO', 'ESQUEMA_MODIFICABLE',
    'DEFINER_ANON_PUBLIC', 'DEFINER_SEARCH_PATH', 'VISTA_OMITE_RLS', 'POLITICA_ABIERTA',
    'AUTORIZACION_USER_METADATA', 'FK_SIN_INDICE')) {
    if (@($adversarial.hallazgos | Where-Object { $_.codigo -eq $code -and $_.objeto -like '*auditoria*' }).Count -eq 0 -and
      $code -ne 'ESQUEMA_MODIFICABLE') { throw "La auditoria no detecto el fixture $code." }
    if ($code -eq 'ESQUEMA_MODIFICABLE' -and @($adversarial.hallazgos | Where-Object { $_.codigo -eq $code }).Count -eq 0) {
      throw 'La auditoria no detecto CREATE en el esquema.'
    }
  }
  if (@($adversarial.hallazgos | Where-Object {
    $_.codigo -eq 'FK_SIN_INDICE' -and $_.objeto -like '*auditoria_fk_con_indice'
  }).Count -gt 0) { throw 'La auditoria no reconocio el indice compuesto existente.' }
  if (@($adversarial.hallazgos | Where-Object {
    $_.codigo -eq 'VISTA_OMITE_RLS' -and $_.objeto -eq '_auditoria_vista_invoker'
  }).Count -gt 0) { throw 'La auditoria no reconocio security_invoker=on.' }
  Invoke-CheckedNative (Join-Path $PostgresBin 'createdb.exe') @(
    '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', 'horas_security_test'
  ) 'createdb-horas.log'
  $horasArgs = @('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'horas_security_test', '-v', 'ON_ERROR_STOP=1', '-f',
    (Join-Path $repoPath 'supabase/tests/horas_seguridad.sql'))
  Invoke-CheckedNative $psql $horasArgs 'horas-seguridad.log'
  Invoke-CheckedNative (Join-Path $PostgresBin 'createdb.exe') @(
    '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', 'gestion_session_test'
  ) 'createdb-gestion.log'
  $gestionArgs = @('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'gestion_session_test', '-v', 'ON_ERROR_STOP=1')
  Invoke-CheckedNative $psql ($gestionArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/gestion_sesion_unica.sql'))) 'gestion-sesion-unica.log'
  # Dos conexiones reales compiten por la misma cuenta: solo una debe ganar.
  $contenders = @()
  foreach ($suffix in @('11', '12')) {
    $sqlPath = Join-Path $runPath "gestion-concurrente-$suffix.sql"
    $outPath = Join-Path $runPath "gestion-concurrente-$suffix.log"
    $errPath = Join-Path $runPath "gestion-concurrente-$suffix.err"
    @"
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-000000000001","session_id":"00000000-0000-4000-8000-0000000000$suffix","aal":"aal1"}';
select 'RESERVA:' || public.rpc_gestion_sesion_adquirir()::text;
select pg_sleep(0.5);
commit;
"@ | Set-Content -LiteralPath $sqlPath -Encoding UTF8
    $process = Start-Process -FilePath $psql -ArgumentList ($gestionArgs + @('-A', '-t', '-q', '-f',
      ('"{0}"' -f $sqlPath))) -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    # Mantener el handle: PowerShell 5 puede perder ExitCode si termina antes del Wait.
    $null = $process.Handle
    $contenders += @{ Process = $process; Output = $outPath; Error = $errPath }
  }
  $winners = 0
  foreach ($contender in $contenders) {
    $contender.Process.WaitForExit()
    if ($contender.Process.ExitCode -ne 0) {
      Get-Content -LiteralPath $contender.Error | Write-Host
      throw 'Falló la prueba concurrente de sesión única.'
    }
    $resultText = Get-Content -LiteralPath $contender.Output -Raw
    if ($resultText -notmatch 'RESERVA:(true|false)') { throw 'Falta el resultado del ingreso concurrente.' }
    if ($resultText.Contains('RESERVA:true')) { $winners++ }
  }
  if ($winners -ne 1) { throw "La misma cuenta obtuvo $winners reservas concurrentes." }
  Invoke-CheckedNative (Join-Path $PostgresBin 'createdb.exe') @(
    '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', 'licencias_test'
  ) 'createdb-licencias.log'
  Invoke-CheckedNative $psql (@('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'licencias_test', '-v', 'ON_ERROR_STOP=1', '-f',
    (Join-Path $repoPath 'supabase/tests/licencias.sql'))) 'licencias.log'
  Invoke-CheckedNative $psql (@('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'licencias_test', '-v', 'ON_ERROR_STOP=1', '-f',
    (Join-Path $repoPath 'supabase/tests/ficha_licencias.sql'))) 'ficha-licencias.log'
  Invoke-CheckedNative $psql (@('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'licencias_test', '-v', 'ON_ERROR_STOP=1', '-f',
    (Join-Path $repoPath 'supabase/tests/ficha_formulario_codigos.sql'))) 'ficha-formulario-codigos.log'
  Invoke-CheckedNative $psql (@('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'licencias_test', '-v', 'ON_ERROR_STOP=1', '-f',
    (Join-Path $repoPath 'supabase/tests/ficha_imprevistos.sql'))) 'ficha-imprevistos.log'
  $licenciasArgs = @('-X', '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres',
    '-d', 'licencias_test', '-v', 'ON_ERROR_STOP=1')
  Invoke-CheckedNative $psql ($licenciasArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/licencias_estudio.sql'))) 'licencias-estudio.log'
  # Con un solo día disponible, dos solicitudes simultáneas no pueden usarlo ambas.
  $studySetup = Join-Path $runPath 'estudio-concurrente-preparar.sql'
  @'
begin;
insert into public.usuario_roles select '00000000-0000-4000-8000-000000000001',id from public.roles
where codigo in('LICENCIAS_LECTURA','LICENCIAS_CARGA');
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
select public.rpc_licencias_guardar(null,12345678,129::smallint,d,h,'Cupo concurrente')
from (values('2026-06-01'::date,'2026-06-05'::date),('2026-06-08','2026-06-12'),
('2026-06-15','2026-06-19'),('2026-06-22','2026-06-25')) x(d,h);
commit;
'@ | Set-Content -LiteralPath $studySetup -Encoding UTF8
  Invoke-CheckedNative $psql ($licenciasArgs + @('-f', $studySetup)) 'estudio-concurrente-preparar.log'
  $studyContenders = @()
  foreach ($studyDay in @('29', '30')) {
    $sqlPath = Join-Path $runPath "estudio-concurrente-$studyDay.sql"
    $outPath = Join-Path $runPath "estudio-concurrente-$studyDay.log"
    $errPath = Join-Path $runPath "estudio-concurrente-$studyDay.err"
    $sqlTemplate = @'
create function pg_temp.intentar_estudio(p_fecha date) returns boolean language plpgsql as
'begin perform public.rpc_licencias_guardar(null,12345678,129::smallint,p_fecha,p_fecha,''Último día'');
return true; exception when sqlstate ''22023'' then return false; end;';
begin;
set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
set local role authenticated;
select 'ESTUDIO:'||pg_temp.intentar_estudio('2026-06-{dia}')::text;
select pg_sleep(0.5);
commit;
'@
    $sqlTemplate.Replace('{dia}', $studyDay) | Set-Content -LiteralPath $sqlPath -Encoding UTF8
    $process = Start-Process -FilePath $psql -ArgumentList ($licenciasArgs + @('-A', '-t', '-q', '-f',
      ('"{0}"' -f $sqlPath))) -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $null = $process.Handle
    $studyContenders += @{ Process = $process; Output = $outPath; Error = $errPath }
  }
  $studyWinners = 0
  foreach ($contender in $studyContenders) {
    $contender.Process.WaitForExit()
    if ($contender.Process.ExitCode -ne 0) {
      Get-Content -LiteralPath $contender.Error | Write-Host
      throw 'Falló la prueba concurrente del cupo de Estudio.'
    }
    $resultText = Get-Content -LiteralPath $contender.Output -Raw
    if ($resultText -notmatch 'ESTUDIO:(true|false)') { throw 'Falta el resultado de Estudio.' }
    if ($resultText.Contains('ESTUDIO:true')) { $studyWinners++ }
  }
  if ($studyWinners -ne 1) { throw "El último día de Estudio admitió $studyWinners solicitudes." }
  Invoke-CheckedNative $psql ($licenciasArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/licencias_catalogo_excel.sql'))) 'licencias-catalogo-excel.log'
  Invoke-CheckedNative $psql ($licenciasArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/licencias_fichas_papel.sql'))) 'licencias-fichas-papel.log'
  Invoke-CheckedNative $psql ($licenciasArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/licencias_duelo_parentescos.sql'))) 'licencias-duelo-parentescos.log'
  Invoke-CheckedNative $psql ($licenciasArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/licencias_francos_cantidad_papel.sql'))) 'licencias-francos-cantidad-papel.log'
  Invoke-CheckedNative $psql ($licenciasArgs + @('-f',
    (Join-Path $repoPath 'supabase/tests/licencias_documentacion_pendiente.sql'))) 'licencias-documentacion-pendiente.log'
  Invoke-CheckedNative (Join-Path $PostgresBin 'createdb.exe') @(
    '-h', '127.0.0.1', '-p', "$port", '-U', 'postgres', 'horas_next_test'
  ) 'createdb-horas-next.log'
  Invoke-CheckedNative $psql (@('-X','-h','127.0.0.1','-p',"$port",'-U','postgres',
    '-d','horas_next_test','-v','ON_ERROR_STOP=1','-f',
    (Join-Path $repoPath 'supabase/tests/horas_gremiales.sql'))) 'horas-gremiales.log'
  $hourContenders = @()
  foreach ($hourIndex in @(1,2)) {
    $hourOut = Join-Path $runPath "horas-concurrente-$hourIndex.log"
    $hourErr = Join-Path $runPath "horas-concurrente-$hourIndex.err"
    $hourProcess = Start-Process -FilePath $psql -ArgumentList @('-X','-A','-t','-q',
      '-h','127.0.0.1','-p',"$port",'-U','postgres','-d','horas_next_test',
      '-v','ON_ERROR_STOP=1','-f',('"{0}"' -f (Join-Path $repoPath 'supabase/tests/horas_operacion_concurrente.sql'))) `
      -WindowStyle Hidden -PassThru -RedirectStandardOutput $hourOut -RedirectStandardError $hourErr
    $null = $hourProcess.Handle
    $hourContenders += @{Process=$hourProcess;Output=$hourOut;Error=$hourErr}
  }
  $hourIds = @()
  foreach ($hourAttempt in $hourContenders) {
    $hourAttempt.Process.WaitForExit()
    if ($hourAttempt.Process.ExitCode -ne 0) {
      Get-Content -LiteralPath $hourAttempt.Error | Write-Host
      throw 'Fallo del reenvio concurrente de horas.'
    }
    $hourText = Get-Content -LiteralPath $hourAttempt.Output -Raw
    if ($hourText -notmatch 'OPERACION:(\d+)') { throw 'Falta resultado de operacion de horas.' }
    $hourIds += $Matches[1]
  }
  if (@($hourIds | Select-Object -Unique).Count -ne 1) { throw 'El reenvio duplico la hora.' }
  Write-Host 'OK: dos reenvios simultaneos devolvieron la misma hora.'
  Write-Host 'OK: cupo de Estudio protegido ante dos solicitudes simultáneas.'
  Write-Host 'OK: dos ingresos simultáneos, una sola Gestión admitida.'
  Get-Content -LiteralPath (Join-Path $runPath 'horas-seguridad.log') -Tail 5 | Write-Host
  Get-Content -LiteralPath (Join-Path $runPath 'seguridad-rendimiento.log') -Tail 22 | Write-Host
  Write-Host "OK: contratos, migraciones, seguridad y auditoria. Registros: $runPath"
}
finally {
  if ($started) {
    $process = Start-Process -FilePath $pgCtl -ArgumentList @('-D',
      ('"{0}"' -f $clusterPath), '-m', 'fast', '-w', 'stop') -WindowStyle Hidden -PassThru
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "No se pudo detener el cluster aislado en $clusterPath" }
  }
}
