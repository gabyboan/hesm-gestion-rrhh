param(
    [string]$Version,
    [string]$Configuracion,
    [string]$SigningKey,
    [string]$Iscc,
    [string]$Destino
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'windows_release_common.ps1')
if (-not $Version) {
    $Version = [regex]::Match((Get-Content (Join-Path $repoRoot 'pubspec.yaml') -Raw), '(?m)^version:\s*(\S+)').Groups[1].Value
}
if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') { throw 'Usa una version estable MAJOR.MINOR.PATCH+BUILD.' }
$versionParts = @($Matches[1], $Matches[2], $Matches[3], $Matches[4])
foreach ($part in $versionParts) { if ([long]$part -gt 65535) { throw 'Cada componente de version debe estar entre 0 y 65535.' } }
$fileVersion = $versionParts -join '.'
$displayVersion = $versionParts[0..2] -join '.'
if (-not $Configuracion) { $Configuracion = Join-Path $repoRoot 'credenciales.env' }
$clientConfig = Get-WindowsClientConfig -Path $Configuracion
if (-not $SigningKey) { $SigningKey = Join-Path $repoRoot '.private/windows-updates.key' }
$SigningKey = (Resolve-Path -LiteralPath $SigningKey).Path
$signTool = Get-WinSparkle -CacheRoot (Join-Path $repoRoot '.private/release-tools')
$publicKey = Get-UpdatePublicKey -Tool $signTool -PrivateKey $SigningKey
$publicHeader = Join-Path $repoRoot 'windows/runner/update_public_key.h'
if (-not (Get-Content -LiteralPath $publicHeader -Raw).Contains($publicKey)) { throw 'La clave de firma no coincide con la incorporada en la aplicacion.' }
if (-not $Iscc) {
    $candidates = @(
        'C:/Program Files (x86)/Inno Setup 6/ISCC.exe',
        'C:/Program Files/Inno Setup 6/ISCC.exe',
        'C:/Program Files/Inno Setup 7/ISCC.exe'
    )
    $Iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Iscc -or -not (Test-Path -LiteralPath $Iscc)) { throw 'Instala Inno Setup 6.5 o posterior, o indica -Iscc ruta/ISCC.exe.' }
if (-not $Destino) { $Destino = Join-Path $repoRoot ("dist/installer-$fileVersion-" + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$Destino = [IO.Path]::GetFullPath($Destino)
if (Test-Path -LiteralPath $Destino) { throw 'El destino ya existe; usa una carpeta nueva.' }
New-Item -ItemType Directory -Path $Destino | Out-Null

# Build outside the user profile to avoid embedding personal paths in Flutter AOT.
$stage = Join-Path ([IO.Path]::GetPathRoot($repoRoot)) ('Temp/HESM-build-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach ($directory in @('lib', 'assets', 'windows')) {
    & robocopy (Join-Path $repoRoot $directory) (Join-Path $stage $directory) /E /NFL /NDL /NJH /NJS /NP /XD ephemeral .plugin_symlinks /XF generated_plugin_registrant.cc generated_plugin_registrant.h generated_plugins.cmake | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "No se pudo copiar $directory a la compilacion aislada." }
}
Copy-Item -LiteralPath (Join-Path $repoRoot 'pubspec.yaml'), (Join-Path $repoRoot 'pubspec.lock') -Destination $stage
$configPath = Join-Path $stage 'client-config.json'
$clientConfig | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding ASCII
Push-Location $stage
try {
    & flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la validacion de dependencias.' }
    & flutter build windows --release --no-pub --target lib/main.dart `
        "--build-name=$displayVersion" "--build-number=$($versionParts[3])" `
        "--dart-define-from-file=$configPath" '--dart-define=WINDOWS_UPDATES_ENABLED=true' "--dart-define=WINDOWS_UPDATE_PUBLIC_KEY=$publicKey" "--dart-define=WINDOWS_APP_VERSION=$fileVersion"
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion de Windows.' }
    $bundle = Join-Path $stage 'build/windows/x64/runner/Release'
    # App-local MSVC runtime avoids requiring administrator access on a clean PC.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $vsPath = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
    $crt = Get-ChildItem -Path (Join-Path $vsPath 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT') -Directory | Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $crt) { throw 'No se encontro el runtime redistribuible de Visual C++.' }
    Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $bundle
    Get-ChildItem -LiteralPath $bundle -Filter '*.pdb' | Remove-Item
    foreach ($file in Get-ChildItem -LiteralPath $bundle -Recurse -File) {
        if ($file.Name -match '(?i)(\.env($|\.)|\.key$|\.pem$|\.pfx$|\.dump$|\.backup$|client-config)') { throw 'Se encontro un archivo privado en el bundle.' }
        if ($file.Extension -in @('.exe', '.dll', '.so', '.json')) {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            $profilePath = [Environment]::GetFolderPath('UserProfile')
            $utf8 = [Text.Encoding]::UTF8.GetString($bytes)
            $utf16 = [Text.Encoding]::Unicode.GetString($bytes)
            foreach ($profileVariant in @($profilePath, $profilePath.Replace('\', '/'))) {
                if ($utf8.IndexOf($profileVariant, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                    $utf16.IndexOf($profileVariant, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    throw 'Se encontro una ruta del perfil local en el bundle.'
                }
            }
        }
    }
    & $Iscc "/DAppVersion=$displayVersion" "/DAppFileVersion=$fileVersion" "/DBundleDir=$bundle" "/DOutputDir=$Destino" (Join-Path $repoRoot 'installer/windows/hesm.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la generacion del instalador.' }
} finally {
    Pop-Location
    if (Test-Path -LiteralPath $configPath) { Remove-Item -LiteralPath $configPath }
}
$installer = Join-Path $Destino "HESM-Gestion-RRHH-$fileVersion-Setup.exe"
$signature = (& $signTool sign --private-key-file $SigningKey $installer | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $signature -notmatch '^[A-Za-z0-9+/]{86}==$') { throw 'No se pudo firmar el instalador con Ed25519.' }
& $signTool verify --public-key $publicKey --signature $signature $installer
if ($LASTEXITCODE -ne 0) { throw 'La firma del instalador no es valida.' }
$length = (Get-Item -LiteralPath $installer).Length
$payloadPath = Join-Path $Destino 'release-payload.json'
$utf8NoBom = New-Object Text.UTF8Encoding($false)
$payload = [ordered]@{schema=1; version=$fileVersion; file=[IO.Path]::GetFileName($installer); length=$length;
    sha256=(Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant(); signature=$signature} | ConvertTo-Json -Compress
[IO.File]::WriteAllText($payloadPath, $payload, $utf8NoBom)
try {
    $manifestSignature = (& $signTool sign --private-key-file $SigningKey $payloadPath | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo firmar el manifiesto.' }
    & $signTool verify --public-key $publicKey --signature $manifestSignature $payloadPath
    if ($LASTEXITCODE -ne 0) { throw 'La firma del manifiesto no es valida.' }
    $envelope = @{payload=[Convert]::ToBase64String([IO.File]::ReadAllBytes($payloadPath)); signature=$manifestSignature} | ConvertTo-Json -Compress
    [IO.File]::WriteAllText((Join-Path $Destino 'release.json'), $envelope, $utf8NoBom)
} finally { Remove-Item -LiteralPath $payloadPath -ErrorAction SilentlyContinue }
((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($installer)) | Set-Content -LiteralPath (Join-Path $Destino 'SHA256SUMS.txt') -Encoding ASCII
Write-Output "Instalador firmado y feed listos: $Destino"
Write-Output 'Publicar con tool/publish_windows_update.ps1 en la carpeta compartida privada del hospital.'
