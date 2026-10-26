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
