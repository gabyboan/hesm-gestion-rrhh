#Requires -RunAsAdministrator
param(
    [string]$AccountName = 'HESM-Lector',
    [string]$GroupName = 'HESM-Lectores',
    [switch]$ResumePendingAccount,
    [switch]$ResetPassword
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$reportPath = Join-Path $repoRoot '.private\update-reader-result.json'
$description = 'Lectura autenticada de actualizaciones HESM'
try {
    if ($AccountName -notmatch '^HESM-[A-Za-z0-9_-]{1,14}$') {
        throw 'Nombre de cuenta no permitido.'
    }
    $group = Get-LocalGroup -Name $GroupName
    if ($group.Description -ne 'Lectura de actualizaciones firmadas HESM') {
        throw 'El grupo no corresponde a la distribucion HESM.'
    }
    $share = Get-SmbShare -Name 'HESM-Actualizaciones'
    if ($share.Path -ne 'C:\HESM-Actualizaciones') {
        throw 'La carpeta compartida no coincide con la configuracion esperada.'
    }
    $reader = Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
    if ($reader -and ($reader.Description -ne $description -or
        (-not $reader.Enabled -and -not $ResumePendingAccount))) {
        throw 'La cuenta ya existe con otra configuracion; no se modifico.'
    }
    if (-not $reader -or $ResetPassword) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object Windows.Forms.Form
        $form.Text = 'HESM - Acceso a las actualizaciones'
        $form.ClientSize = New-Object Drawing.Size(510, 280)
        $form.StartPosition = 'CenterScreen'
        $form.FormBorderStyle = 'FixedDialog'
        $form.MaximizeBox = $false
        $form.MinimizeBox = $false
        $form.TopMost = $true
        $label = New-Object Windows.Forms.Label
        $label.SetBounds(20, 18, 465, 66)
        $label.Text = "Elegi la contrasena de $env:COMPUTERNAME\$AccountName.`r`nEsta cuenta tendra lectura de las actualizaciones.`r`nUsa al menos 14 caracteres y guardala en un lugar seguro."
        $form.Controls.Add($label)
        $passwordLabel = New-Object Windows.Forms.Label
        $passwordLabel.Text = 'Contrasena:'
        $passwordLabel.SetBounds(20, 95, 140, 22)
        $form.Controls.Add($passwordLabel)
        $passwordBox = New-Object Windows.Forms.TextBox
        $passwordBox.SetBounds(165, 92, 320, 25)
        $passwordBox.UseSystemPasswordChar = $true
        $form.Controls.Add($passwordBox)
        $confirmLabel = New-Object Windows.Forms.Label
        $confirmLabel.Text = 'Repetir contrasena:'
        $confirmLabel.SetBounds(20, 137, 140, 22)
        $form.Controls.Add($confirmLabel)
        $confirmBox = New-Object Windows.Forms.TextBox
        $confirmBox.SetBounds(165, 134, 320, 25)
        $confirmBox.UseSystemPasswordChar = $true
        $form.Controls.Add($confirmBox)
        $hint = New-Object Windows.Forms.Label
        $hint.SetBounds(20, 175, 465, 33)
        $hint.ForeColor = [Drawing.Color]::Firebrick
        $form.Controls.Add($hint)
        $accept = New-Object Windows.Forms.Button
        $accept.Text = 'Guardar acceso'
        $accept.SetBounds(245, 225, 120, 32)
        $accept.Add_Click({
            if ($passwordBox.Text.Length -lt 14) {
                $hint.Text = 'La contrasena debe tener al menos 14 caracteres.'
            } elseif ($passwordBox.Text -cne $confirmBox.Text) {
                $hint.Text = 'Las contrasenas no coinciden.'
            } else {
                $form.DialogResult = [Windows.Forms.DialogResult]::OK
                $form.Close()
            }
        })
        $form.Controls.Add($accept)
        $cancel = New-Object Windows.Forms.Button
        $cancel.Text = 'Cancelar'
        $cancel.SetBounds(375, 225, 110, 32)
        $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
        $form.Controls.Add($cancel)
        $form.AcceptButton = $accept
        $form.CancelButton = $cancel
        try {
            if ($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {
                @{ Status = 'cancelled' } | ConvertTo-Json | Set-Content -LiteralPath $reportPath -Encoding UTF8
                exit 0
            }
            $securePassword = ConvertTo-SecureString -String $passwordBox.Text -AsPlainText -Force
            try {
                if ($reader) {
                    Set-LocalUser -SID $reader.SID -Password $securePassword
                } else {
                    $reader = New-LocalUser -Name $AccountName -Password $securePassword -Description $description
                }
            } finally {
                $securePassword.Dispose()
            }
        } finally {
            $passwordBox.Clear()
            $confirmBox.Clear()
            $form.Dispose()
        }
    }
    & net.exe user $AccountName /passwordreq:yes | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo confirmar el requisito de contrasena de la cuenta.' }
    if ($reader.SID.Value -notin @(Get-LocalGroupMember -Group $GroupName | ForEach-Object { $_.SID.Value })) {
        try {
            Add-LocalGroupMember -Group $GroupName -Member "$env:COMPUTERNAME\$AccountName"
        } catch {
            Disable-LocalUser -SID $reader.SID
            throw
        }
    }
    if (-not $reader.Enabled -and $ResumePendingAccount) {
        Enable-LocalUser -SID $reader.SID
    }
    # No password is written to disk, a command line, or the report.
    @{
        Status = 'authorized'
        Account = "$env:COMPUTERNAME\$AccountName"
        Group = $GroupName
        PasswordExpires = $reader.PasswordExpires
        CheckedAt = (Get-Date).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath $reportPath -Encoding UTF8
} catch {
    @{ Status = 'error'; Message = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath $reportPath -Encoding UTF8
    exit 1
}
