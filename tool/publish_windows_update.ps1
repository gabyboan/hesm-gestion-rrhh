[CmdletBinding(DefaultParameterSetName='Red')]
param(
    [Parameter(Mandatory=$true)][string]$Paquete,
    [Parameter(Mandatory=$true,ParameterSetName='Red')][string]$CarpetaRed,
    [Parameter(Mandatory=$true,ParameterSetName='Local')][string]$CarpetaLocal
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'windows_release_common.ps1')
if ($PSCmdlet.ParameterSetName -eq 'Local') {
    $CarpetaRed = [IO.Path]::GetFullPath($CarpetaLocal).TrimEnd('\')
    $projectPath = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
    if ($CarpetaRed.Length -le 3 -or $CarpetaRed.StartsWith('\\') -or
        $CarpetaRed -eq $projectPath -or $CarpetaRed.StartsWith($projectPath + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $projectPath.StartsWith($CarpetaRed + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'La distribucion local debe usar una carpeta dedicada fuera del proyecto.'
    }
} else {
    $CarpetaRed = $CarpetaRed.TrimEnd('\')
    if ($CarpetaRed -notmatch '^\\\\[^\\]+\\[^\\]+') { throw 'Usa una ruta UNC: \\PC-RRHH\Actualizaciones.' }
    foreach ($part in $CarpetaRed.Substring(2).Split('\')) {
        if (-not $part -or $part -in @('.', '..') -or $part -match '[<>:"|?*\x00-\x1f$]' -or $part.EndsWith('.') -or $part.EndsWith(' ')) {
            throw 'Ruta de red no permitida.'
        }
    }
}
if (-not (Test-Path -LiteralPath $CarpetaRed -PathType Container)) { throw 'La carpeta de distribucion no esta disponible. No se modificaron permisos.' }
if ((Get-Item -LiteralPath $CarpetaRed).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'La carpeta de distribucion no puede ser un enlace.' }
$Paquete = (Resolve-Path -LiteralPath $Paquete).Path
$tool = Get-WinSparkle -CacheRoot (Join-Path $repoRoot '.private/release-tools')
$header = Get-Content -LiteralPath (Join-Path $repoRoot 'windows/runner/update_public_key.h') -Raw
$publicKey = [regex]::Match($header, '"([A-Za-z0-9+/]{43}=)"').Groups[1].Value
$manifest = Join-Path $Paquete 'release.json'
$release = Get-LanSignedRelease -Path $manifest -PublicKey $publicKey -Tool $tool
$installer = Join-Path $Paquete $release.file
if ((Get-Item -LiteralPath $installer).Length -ne $release.length -or
    (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant() -cne $release.sha256) { throw 'El instalador no coincide con el manifiesto.' }
& $tool verify --public-key $publicKey --signature $release.signature $installer
if ($LASTEXITCODE -ne 0) { throw 'Firma de instalador invalida.' }

# Serialize publishers. The empty lock file remains; its OS lock is released.
$lock = [IO.File]::Open((Join-Path $CarpetaRed '.publish.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
$latestTemporary = $null
try {
    $latest = Join-Path $CarpetaRed 'latest.json'
    if (Test-Path -LiteralPath $latest) {
        $current = Get-LanSignedRelease -Path $latest -PublicKey $publicKey -Tool $tool
        if ([version]$release.version -le [version]$current.version) { throw 'La version publicada debe aumentar. No se reemplaza una version existente.' }
    }
    $versionRoot = Join-Path $CarpetaRed ('versions/' + $release.version)
    if (Test-Path -LiteralPath $versionRoot) { throw 'La carpeta de esa version ya existe. Revisa la publicacion anterior o genera otra version.' }
    New-Item -ItemType Directory -Path $versionRoot | Out-Null
    $copy = Join-Path $versionRoot $release.file
    Copy-Item -LiteralPath $installer -Destination $copy
    if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash.ToLowerInvariant() -cne $release.sha256) { throw 'La copia en red no supero la verificacion. latest.json no cambio.' }
    Copy-Item -LiteralPath $manifest -Destination (Join-Path $versionRoot 'release.json')
    $latestTemporary = Join-Path $CarpetaRed ('latest-' + [guid]::NewGuid().ToString('N') + '.tmp')
    Copy-Item -LiteralPath $manifest -Destination $latestTemporary
    # A single signed envelope is promoted only after the full installer exists.
    # Windows PowerShell 5.1 converts $null to an empty string for this overload.
    # Pass an actual null string: no backup filename is requested.
    if (Test-Path -LiteralPath $latest) { [IO.File]::Replace($latestTemporary, $latest, [System.Management.Automation.Language.NullString]::Value) }
    else { [IO.File]::Move($latestTemporary, $latest) }
    if ($PSCmdlet.ParameterSetName -eq 'Local') {
        Write-Output "Version $($release.version) preparada en la carpeta local de distribucion."
    } else {
        Write-Output "Version $($release.version) publicada en la red del hospital."
    }
} finally {
    $lock.Dispose()
    if ($latestTemporary -and (Test-Path -LiteralPath $latestTemporary)) { Remove-Item -LiteralPath $latestTemporary }
}
