$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$reportPath = Join-Path $repoRoot '.private/project-relocation.json'
$report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $report.sha256_verified -or -not $report.git_status_identical -or
    [IO.Path]::GetFullPath($report.target).TrimEnd('\') -ne $repoRoot) {
    throw 'El informe de copia no corresponde a esta ubicacion o no fue verificado.'
}
$source = [IO.Path]::GetFullPath($report.source).TrimEnd('\')
if ($source.Length -le 10 -or $source -eq $repoRoot -or
    $source.StartsWith($repoRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $repoRoot.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Las rutas de origen y destino no son independientes.'
}
if (-not (Test-Path -LiteralPath $source)) { throw 'La ubicacion anterior no existe. Revisar el estado antes de continuar.' }
$entry = Get-Item -LiteralPath $source -Force
if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    Write-Output 'La ubicacion anterior ya es un enlace. No se movio nada.'
    exit 0
}
if (-not (Test-Path -LiteralPath (Join-Path $source '.git')) -or
    -not (Test-Path -LiteralPath (Join-Path $source 'pubspec.yaml'))) {
    throw 'El origen no contiene el proyecto esperado.'
}
$head = (& git -C $source rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne $report.original_head) { throw 'El historial del origen cambio despues de copiarlo. Revisar antes de archivarlo.' }
$cutoff = [DateTime]::Parse($report.verified_at_utc).ToUniversalTime()
$queue = New-Object 'Collections.Generic.Queue[string]'
$queue.Enqueue($source)
$excluded = @((Join-Path $source '.git'),(Join-Path $source '.private'),(Join-Path $source '.dart_tool'),
    (Join-Path $source 'build'),(Join-Path $source '.history-backups'),(Join-Path $source 'windows/flutter/ephemeral'))
while ($queue.Count -gt 0) {
    foreach ($file in Get-ChildItem -LiteralPath $queue.Dequeue() -Force) {
        if ($file.PSIsContainer) {
            if ($file.FullName -notin $excluded -and -not ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $queue.Enqueue($file.FullName) }
        } elseif ($file.Name -ne '.flutter-plugins-dependencies' -and $file.LastWriteTimeUtc -gt $cutoff) {
            throw 'Hay archivos modificados en la carpeta anterior despues de la copia. Revisarlos antes de archivar.'
        }
    }
}
foreach ($relative in @('credenciales.env','.private/windows-updates.key')) {
    if ((Get-FileHash -LiteralPath (Join-Path $source $relative)).Hash -ne
        (Get-FileHash -LiteralPath (Join-Path $repoRoot $relative)).Hash) { throw 'La configuracion o la clave de firma no coincide entre ubicaciones.' }
}
$backupRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.history-backups'))
$backup = [IO.Path]::GetFullPath((Join-Path $backupRoot ('ubicacion-anterior-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))))
if (-not $backup.StartsWith($backupRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $backup)) {
    throw 'Destino de respaldo no valido.'
}
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
if ((Get-Item -LiteralPath $backupRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'La carpeta de respaldo no puede ser un enlace.'
}
try { Move-Item -LiteralPath $source -Destination $backup -ErrorAction Stop }
catch { throw 'Windows mantiene la carpeta abierta. Cierra VS Code y terminales de la ubicacion anterior y ejecuta nuevamente desde la carpeta nueva. El original se conservo.' }
$report.source_preserved_due_to_open_handles = $false
$report | Add-Member -NotePropertyName archived_original -NotePropertyValue $backup -Force
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
try { New-Item -ItemType Junction -Path $source -Target $repoRoot | Out-Null }
catch { Write-Warning 'El respaldo se guardo, pero no se pudo crear el enlace de compatibilidad. Usa la carpeta nueva.' }
Write-Output "Ubicacion anterior archivada en $backup"
Write-Output "Proyecto activo: $repoRoot"
