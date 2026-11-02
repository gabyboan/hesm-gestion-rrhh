#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory=$true)][string]$Publicador,
    [string]$Carpeta = 'C:\HESM-Actualizaciones',
    [string]$NombreRecurso = 'HESM-Actualizaciones',
    [string]$GrupoLectores = 'HESM-Lectores',
    [string[]]$LectoresWindows = @()
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)).TrimEnd('\')
$Carpeta = [IO.Path]::GetFullPath($Carpeta).TrimEnd('\')
if ($Carpeta.Length -le 3 -or $Carpeta.StartsWith('\\') -or
    $Carpeta -eq $repoRoot -or $Carpeta.StartsWith($repoRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $repoRoot.StartsWith($Carpeta + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $Carpeta.StartsWith($env:WINDIR, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'La carpeta de distribucion debe ser local, dedicada y estar separada del proyecto y de Windows.'
}
if ($NombreRecurso -notmatch '^[A-Za-z0-9_-]{1,60}$' -or $GrupoLectores -notmatch '^[A-Za-z0-9_-]{1,40}$') {
    throw 'Nombre de recurso o grupo no permitido.'
}
$publisherAccount = New-Object Security.Principal.NTAccount($Publicador)
$publisherSid = $publisherAccount.Translate([Security.Principal.SecurityIdentifier])
# Resolve all explicitly requested reader accounts before changing anything.
$readerSids = foreach ($reader in $LectoresWindows) {
    (New-Object Security.Principal.NTAccount($reader)).Translate([Security.Principal.SecurityIdentifier])
}
$existing = Get-SmbShare -Name $NombreRecurso -ErrorAction SilentlyContinue
if ($existing -and [IO.Path]::GetFullPath($existing.Path).TrimEnd('\') -ne $Carpeta) {
    throw 'Ese nombre de recurso ya apunta a otra carpeta. No se modifico.'
}
$readersAccount = $env:COMPUTERNAME + '\' + $GrupoLectores
if ($existing) {
    $allowed = @($Publicador, $readersAccount)
    $unexpected = @(Get-SmbShareAccess -Name $NombreRecurso | Where-Object { $_.AccountName -notin $allowed -or $_.AccessControlType -ne 'Allow' })
    if ($unexpected) { throw 'El recurso tiene permisos diferentes. Revisalos antes de continuar.' }
}
$existingGroup = Get-LocalGroup -Name $GrupoLectores -ErrorAction SilentlyContinue
if ($existingGroup -and $existingGroup.Description -ne 'Lectura de actualizaciones firmadas HESM') {
    throw 'El grupo ya existe y no fue creado para esta distribucion. Elegi otro nombre.'
}
if (Test-Path -LiteralPath $Carpeta) {
    if ((Get-Item -LiteralPath $Carpeta -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'La carpeta no puede ser un enlace o junction.'
    }
    foreach ($entry in Get-ChildItem -LiteralPath $Carpeta -Force -Recurse) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Se encontro un enlace dentro de la distribucion.' }
        $relative = $entry.FullName.Substring($Carpeta.Length + 1)
        if ($entry.PSIsContainer) {
            if ($relative -notmatch '^versions(?:\\\d+\.\d+\.\d+\.\d+)?$') { throw 'La carpeta contiene directorios ajenos a la distribucion.' }
        } elseif ($relative -notmatch '^(latest\.json|\.publish\.lock|versions\\\d+\.\d+\.\d+\.\d+\\(?:release\.json|HESM-Gestion-RRHH-\d+\.\d+\.\d+\.\d+-Setup\.exe))$') {
            throw 'La carpeta contiene archivos ajenos a la distribucion. No se compartira.'
        }
    }
} else { New-Item -ItemType Directory -Path $Carpeta | Out-Null }

if (-not $existingGroup) {
    $existingGroup = New-LocalGroup -Name $GrupoLectores -Description 'Lectura de actualizaciones firmadas HESM'
}
foreach ($readerSid in $readerSids) {
    $members = @(Get-LocalGroupMember -Name $GrupoLectores)
    if ($readerSid.Value -notin @($members | ForEach-Object { $_.SID.Value })) {
        Add-LocalGroupMember -Group $GrupoLectores -Member $readerSid.Value
    }
}
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
$propagation = [Security.AccessControl.PropagationFlags]::None
$allow = [Security.AccessControl.AccessControlType]::Allow
foreach ($sid in @($publisherSid, (New-Object Security.Principal.SecurityIdentifier('S-1-5-18')), (New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))) {
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid, [Security.AccessControl.FileSystemRights]::FullControl, $inheritance, $propagation, $allow)))
}
$acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($existingGroup.SID, [Security.AccessControl.FileSystemRights]::ReadAndExecute, $inheritance, $propagation, $allow)))
Set-Acl -LiteralPath $Carpeta -AclObject $acl

if (-not $existing) {
    New-SmbShare -Name $NombreRecurso -Path $Carpeta -FullAccess $Publicador -ReadAccess $readersAccount `
        -EncryptData $true -FolderEnumerationMode AccessBased -CachingMode None | Out-Null
} else {
    Grant-SmbShareAccess -Name $NombreRecurso -AccountName $Publicador -AccessRight Full -Force | Out-Null
    Grant-SmbShareAccess -Name $NombreRecurso -AccountName $readersAccount -AccessRight Read -Force | Out-Null
    Set-SmbShare -Name $NombreRecurso -EncryptData $true -FolderEnumerationMode AccessBased -CachingMode None -Force
}

$ruleName = 'HESM-Updates-SMB-Private'
if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name $ruleName -DisplayName 'HESM actualizaciones SMB (red privada local)' `
        -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -RemoteAddress LocalSubnet -Profile Private | Out-Null
}
Write-Output ('Recurso listo: \\' + $env:COMPUTERNAME + '\' + $NombreRecurso)
Write-Output 'El grupo de lectores no incluye usuarios nuevos salvo los indicados en -LectoresWindows.'
Get-SmbShareAccess -Name $NombreRecurso | Select-Object AccountName,AccessRight,AccessControlType
