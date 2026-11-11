<#
.SYNOPSIS
Programa el backup HESM para los viernes, con la cuenta Windows actual.
.DESCRIPTION
Necesita una sesion iniciada: DPAPI, login Supabase y Docker pertenecen a este usuario.
No almacena contrasenas, cambia de plan ni elimina respaldos anteriores.
#>
[CmdletBinding()]
param(
  [ValidatePattern('^([01][0-9]|2[0-3]):[0-5][0-9]$')]
  [string]$At = '09:00',
  [string]$BackupRoot,
  [switch]$RunNow
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoPath = Split-Path -Parent $PSScriptRoot
$taskName = 'HESM-Supabase-Backup-Semanal'
$pythonPath = Join-Path $repoPath '.private/backup-tools/Scripts/python.exe'
$runnerPath = Join-Path $repoPath 'tool/run_database_backup.py'
if (-not $BackupRoot) { $BackupRoot = Join-Path $repoPath '.private/database-backups/weekly' }
$BackupRoot = [System.IO.Path]::GetFullPath($BackupRoot)
if ((Get-TimeZone).Id -ne 'Argentina Standard Time') {
  throw 'Configurar la zona horaria de Windows en Argentina antes de registrar la tarea.'
}
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
  throw 'Preparar .private/backup-tools con tool/backup_requirements.txt antes de registrar la tarea.'
}
& $pythonPath $runnerPath --backup-root $BackupRoot --check
if ($LASTEXITCODE -ne 0) { throw 'No se verificaron los requisitos locales del respaldo.' }

$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing -and $existing.Description -notlike 'Respaldo cifrado y verificado de HESM-SUPLENCIAS.*') {
  throw 'Ya existe una tarea con ese nombre que no pertenece a este procedimiento.'
}
$arguments = '"{0}" --backup-root "{1}"' -f $runnerPath, $BackupRoot
$action = New-ScheduledTaskAction -Execute $pythonPath -Argument $arguments -WorkingDirectory $repoPath
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At ([datetime]::ParseExact($At, 'HH:mm', $null))
$principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
  -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 30) `
  -ExecutionTimeLimit (New-TimeSpan -Hours 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$description = 'Respaldo cifrado y verificado de HESM-SUPLENCIAS. Viernes {0}, Argentina. Requiere sesion iniciada, Internet y Docker Desktop; no elimina copias.' -f $At
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal `
  -Settings $settings -Description $description
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
$info = Get-ScheduledTaskInfo -TaskName $taskName
[pscustomobject]@{
  Tarea = $taskName
  Usuario = $identity.Name
  Frecuencia = 'Viernes ' + $At + ' (Argentina)'
  ProximaEjecucion = $info.NextRunTime
  Carpeta = $BackupRoot
  Reintentos = '3, cada 30 minutos'
} | Format-List
if ($RunNow) { Start-ScheduledTask -TaskName $taskName }
