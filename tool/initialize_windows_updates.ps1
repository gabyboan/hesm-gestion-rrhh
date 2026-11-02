param([string]$PrivateKey)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'windows_release_common.ps1')
if (-not $PrivateKey) { $PrivateKey = Join-Path $repoRoot '.private/windows-updates.key' }
$PrivateKey = [IO.Path]::GetFullPath($PrivateKey)
$header = Join-Path $repoRoot 'windows/runner/update_public_key.h'
$tool = Get-WinSparkle -CacheRoot (Join-Path $repoRoot '.private/release-tools')
if (-not (Test-Path -LiteralPath $PrivateKey)) {
    if (Test-Path -LiteralPath $header) {
        throw 'Ya existe una clave publica. Recupera la clave privada original; no se genera otra que rompa las actualizaciones instaladas.'
    }
    New-Item -ItemType Directory -Path (Split-Path $PrivateKey -Parent) -Force | Out-Null
    & $tool generate-key --file $PrivateKey
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo generar la clave de actualizaciones.' }
}
$publicKey = Get-UpdatePublicKey -Tool $tool -PrivateKey $PrivateKey
if (Test-Path -LiteralPath $header) {
    if (-not (Get-Content -LiteralPath $header -Raw).Contains($publicKey)) {
        throw 'La clave privada no corresponde a la publica existente.'
    }
} else {
    @"
// Public Ed25519 verification key. The private key must never enter source control.
#ifndef RUNNER_UPDATE_PUBLIC_KEY_H_
#define RUNNER_UPDATE_PUBLIC_KEY_H_
constexpr char kUpdatePublicKey[] = "$publicKey";
#endif
"@ | Set-Content -LiteralPath $header -Encoding ASCII
}
Write-Output "Firma de actualizaciones preparada. Respalda fuera de este equipo: $PrivateKey"
