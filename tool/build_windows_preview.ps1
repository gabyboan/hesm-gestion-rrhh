param(
    [ValidateSet('Ambas', 'Aplicacion', 'Demo')]
    [string]$Variante = 'Ambas',
    [string]$Destino
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $Destino) {
    $Destino = Join-Path $repoRoot ('dist/windows-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$artifactRoot = [IO.Path]::GetFullPath($Destino)
if (Test-Path -LiteralPath $artifactRoot) {
    throw 'Destination already exists. Choose a new directory to avoid stale or private files.'
}
New-Item -ItemType Directory -Path $artifactRoot | Out-Null

Push-Location $repoRoot
try {
    & flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw 'Dependency validation failed.' }
    $commit = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not identify the source commit.' }
    $sourceDirty = [bool](& git status --porcelain --untracked-files=all)
    $sdk = (& flutter --version --machine | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Could not identify the Flutter version.' }
    $variants = if ($Variante -eq 'Ambas') { @('Aplicacion', 'Demo') } else { @($Variante) }
    $zipHashes = @()
    foreach ($variantName in $variants) {
        $target = if ($variantName -eq 'Demo') { 'tool/demo/main.dart' } else { 'lib/main.dart' }
        & flutter build windows --release --no-pub --target $target
        if ($LASTEXITCODE -ne 0) { throw "Windows build failed: $variantName" }

        $buildDir = Join-Path $repoRoot 'build/windows/x64/runner/Release'
        $sourceFiles = @(Get-ChildItem -LiteralPath $buildDir -Recurse -File)
        foreach ($file in $sourceFiles) {
            if ($file.Name -match '(?i)(^credenciales\.env$|^\.env($|\.)|\.pem$|\.key$|\.pfx$|\.dump$|\.backup$)') {
                throw 'A private configuration or backup was found in the Windows bundle.'
            }
            if ($file.Extension -in @('.exe', '.dll', '.so', '.json')) {
                $bytes = [IO.File]::ReadAllBytes($file.FullName)
                $profilePath = [Environment]::GetFolderPath('UserProfile')
                $utf8 = [Text.Encoding]::UTF8.GetString($bytes)
                $utf16 = [Text.Encoding]::Unicode.GetString($bytes)
                foreach ($profileVariant in @($profilePath, $profilePath.Replace('\', '/'))) {
                    if ($utf8.IndexOf($profileVariant, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                        $utf16.IndexOf($profileVariant, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        throw 'A local profile path was embedded in the build. Rebuild from a neutral directory outside the user profile.'
                    }
                }
            }
        }
        $name = 'HESM-Gestion-RRHH-' + $variantName + '-Windows-x64'
        $bundleDir = Join-Path $artifactRoot $name
        New-Item -ItemType Directory -Path $bundleDir | Out-Null
        foreach ($child in Get-ChildItem -LiteralPath $buildDir) {
            if ($child.Extension -eq '.pdb') { continue }
            Copy-Item -LiteralPath $child.FullName -Destination $bundleDir -Recurse
        }
        Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/WINDOWS.md') -Destination (Join-Path $bundleDir 'LEEME.md')
        if ($variantName -eq 'Aplicacion') {
            Copy-Item -LiteralPath (Join-Path $repoRoot 'credenciales.env.example') -Destination $bundleDir
        }
        $fileHashes = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath $bundleDir -Recurse -File | Sort-Object FullName) {
            $relative = $file.FullName.Substring($bundleDir.Length + 1).Replace('\', '/')
            $fileHashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        [ordered]@{
            variant = $variantName
            source_commit = $commit
            source_dirty = $sourceDirty
            flutter = $sdk.frameworkVersion
            dart = $sdk.dartSdkVersion
            architecture = 'windows-x64'
            includes_credentials = $false
            files_sha256 = $fileHashes
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $bundleDir 'build-manifest.json') -Encoding UTF8
        $zipPath = Join-Path $artifactRoot ($name + '.zip')
        Compress-Archive -LiteralPath $bundleDir -DestinationPath $zipPath -CompressionLevel Optimal
        $zipHashes += (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($zipPath)
        Write-Output "Created $zipPath"
    }
    $zipHashes | Set-Content -LiteralPath (Join-Path $artifactRoot 'SHA256SUMS.txt') -Encoding ASCII
} finally {
    Pop-Location
}
