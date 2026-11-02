$ErrorActionPreference = 'Stop'

function Get-WinSparkle {
    param([string]$CacheRoot)
    $root = Join-Path $CacheRoot 'WinSparkle-0.9.4'
    $tool = Join-Path $root 'bin/winsparkle-tool.exe'
    if (-not (Test-Path -LiteralPath $tool)) {
        New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
        $zip = Join-Path $CacheRoot 'WinSparkle-0.9.4.zip'
        & curl.exe --fail --location --silent --show-error --max-time 180 `
            'https://github.com/vslavik/winsparkle/releases/download/v0.9.4/WinSparkle-0.9.4.zip' --output $zip
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar WinSparkle.' }
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne '6037DF37FC263BD1650A1C4949681A9D40FFE991D01F35892A406CB5D103C976') {
            throw 'El checksum de WinSparkle no coincide.'
        }
        Expand-Archive -LiteralPath $zip -DestinationPath $CacheRoot -Force
    }
    return $tool
}

function Get-WindowsClientConfig {
    param([string]$Path)
    $values = @{}
    if ([IO.Path]::GetExtension($Path) -eq '.json') {
        $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($property in $json.PSObject.Properties) { $values[$property.Name] = [string]$property.Value }
    } else {
        foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
            if ($line -match '^\s*(SUPABASE_URL|SUPABASE_ANON_KEY)\s*=\s*(.*?)\s*$') {
                $values[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
            }
        }
    }
    $url = $null
    if (-not [Uri]::TryCreate($values['SUPABASE_URL'], [UriKind]::Absolute, [ref]$url) -or $url.Scheme -ne 'https') {
        throw 'La configuracion requiere una SUPABASE_URL HTTPS.'
    }
    $key = $values['SUPABASE_ANON_KEY']
    if (-not $key) { throw 'Falta la clave de cliente SUPABASE_ANON_KEY.' }
    if (-not $key.StartsWith('sb_publishable_')) {
        try {
            $payload = $key.Split('.')[1].Replace('-', '+').Replace('_', '/')
            $payload = $payload.PadRight($payload.Length + (4 - $payload.Length % 4) % 4, '=')
            $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
        } catch { throw 'La clave no es publishable ni un JWT anon valido.' }
        if ($claims.role -ne 'anon') { throw 'Solo se permiten claves de cliente publishable o anon. Nunca service_role/secret.' }
    }
    # Whitelist: never pass other environment values into the executable.
    return @{ SUPABASE_URL = $url.AbsoluteUri.TrimEnd('/'); SUPABASE_ANON_KEY = $key }
}

function Get-UpdatePublicKey {
    param([string]$Tool, [string]$PrivateKey)
    $output = (& $Tool public-key --private-key-file $PrivateKey | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer la clave de firma.' }
    $match = [regex]::Match($output, '(?m)(?:Public key:\s*)?([A-Za-z0-9+/]{43}=)')
    if (-not $match.Success) { throw 'No se encontro la clave publica Ed25519.' }
    return $match.Groups[1].Value
}

function Get-LanSignedRelease {
    param([string]$Path, [string]$PublicKey, [string]$Tool)
    if ((Get-Item -LiteralPath $Path).Length -gt 16384) { throw 'Manifiesto demasiado grande.' }
    $envelope = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $payload = [Convert]::FromBase64String($envelope.payload)
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('hesm-release-verify-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        [IO.File]::WriteAllBytes($temporary, $payload)
        & $Tool verify --public-key $PublicKey --signature $envelope.signature $temporary | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'La firma del manifiesto no es valida.' }
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary } }
    $release = [Text.Encoding]::UTF8.GetString($payload) | ConvertFrom-Json
    if ($release.schema -ne 1 -or $release.version -notmatch '^\d+\.\d+\.\d+\.\d+$' -or
        $release.file -cne "HESM-Gestion-RRHH-$($release.version)-Setup.exe" -or
        $release.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $release.length -le 0 -or $release.length -gt 157286400) {
        throw 'El manifiesto firmado contiene campos no permitidos.'
    }
    foreach ($part in $release.version.Split('.')) { if ([long]$part -gt 65535) { throw 'Version fuera de rango.' } }
    return $release
}
