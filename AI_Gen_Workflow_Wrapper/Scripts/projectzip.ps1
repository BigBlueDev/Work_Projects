$projectFolder = "$env:TEMP\VcenterTagPermissionsProject"
New-Item -ItemType Directory -Path $projectFolder -Force | Out-Null

# Write VcenterTagPermissions.pssproj
@"
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <ProjectName>VcenterTagPermissions</ProjectName>
    <Author>YourName</Author>
    <Version>1.0</Version>
    <Description>vCenter Tag &amp; Permission Manager</Description>
    <StartupForm>MainForm</StartupForm>
    <OutputType>WinExe</OutputType>
  </PropertyGroup>

  <ItemGroup>
    <Form Include="MainForm.psf">
      <Name>MainForm</Name>
      <ScriptFile>MainForm.ps1</ScriptFile>
    </Form>
  </ItemGroup>
</Project>
"@ | Set-Content -Path (Join-Path $projectFolder "VcenterTagPermissions.pssproj") -Encoding UTF8

# Write MainForm.psf
@"
<?xml version="1.0" encoding="utf-8"?>
<Form xmlns="http://schemas.microsoft.com/developer/msbuild/2003" 
      Name="MainForm" 
      Text="vCenter Tag &amp; Permission Manager" 
      Size="800,700" 
      Font="Segoe UI,9" 
      StartPosition="CenterScreen">

  <Controls>
    <GroupBox Name="grpConnection" Text="vCenter Connection" Location="10,10" Size="760,130" Padding="15">
      <Controls>
        <Label Name="lblVCenter" Text="vCenter Server:" Location="10,25" Size="130,22" />
        <TextBox Name="txtVCenter" Location="150,25" Size="300,25" />
        <Button Name="btnGetCredential" Text="Get Credentials" Location="150,60" Size="140,30" />
        <Label Name="lblCredStatus" Text="Credentials: Not set" Location="310,65" Size="250,22" />
        <Button Name="btnConnect" Text="Connect" Location="150,95" Size="140,30" />
        <Button Name="btnDisconnect" Text="Disconnect" Location="310,95" Size="140,30" Enabled="False" />
      </Controls>
    </GroupBox>

    <GroupBox Name="grpRole" Text="Role Assignment" Location="10,150" Size="760,160" Padding="15">
      <Controls>
        <Label Name="lblPrincipal" Text="Principal (user/group):" Location="10,25" Size="130,22" />
        <TextBox Name="txtPrincipal" Location="150,25" Size="300,25" />
        <Label Name="lblRole" Text="Select Role:" Location="10,60" Size="130,22" />
        <ComboBox Name="comboRoles" Location="150,60" Size="300,25" DropDownStyle="DropDownList" />
        <Button Name="btnAssignPermission" Text="Assign Permission" Location="150,100" Size="180,35" Enabled="False" />
      </Controls>
    </GroupBox>

    <TextBox Name="txtLog" Location="15,330" Size="760,330" Multiline="True" ReadOnly="True" ScrollBars="Vertical" Font="Consolas,9" />
  </Controls>

</Form>
"@ | Set-Content -Path (Join-Path $projectFolder "MainForm.psf") -Encoding UTF8

# Write MainForm.ps1
@"
# Import your required modules here
# Example:
# Import-Module ..\Modules\Logging.psm1
# Import-Module ..\Modules\PermissionManagement.psm1
# Import-Module ..\Modules\RoleManagement.psm1
# Import-Module ..\Modules\SsoGroupManagement.psm1
# Import-Module ..\Modules\VMProcessing.psm1

# Variables to hold state
\$global:vCenterConnection = \$null
\$global:VCenterCredential = \$null

# Helper function to append logs to txtLog control
function Append-LogToTextBox {
    param([string]\$Message)
    if (\$form.txtLog.InvokeRequired) {
        \$form.txtLog.Invoke([action] { param(\$msg) \$form.txtLog.AppendText(\$msg + [Environment]::NewLine) }, \$Message)
    }
    else {
        \$form.txtLog.AppendText(\$Message + [Environment]::NewLine)
    }
}

function Write-Log {
    param(
        [string]\$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]\$Level = "INFO"
    )
    \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    \$logEntry = "\$timestamp [\$Level] \$Message"
    Append-LogToTextBox -Message \$logEntry
}

# Credential dialog function
function Show-CredentialDialog {
    \$credForm = New-Object System.Windows.Forms.Form
    \$credForm.Text = "Enter vCenter Credentials"
    \$credForm.Size = New-Object System.Drawing.Size(350, 180)
    \$credForm.StartPosition = "CenterParent"
    \$credForm.FormBorderStyle = 'FixedDialog'
    \$credForm.MaximizeBox = \$false
    \$credForm.MinimizeBox = \$false
    \$credForm.Topmost = \$true
    \$credForm.ShowInTaskbar = \$false

    \$lblUser = New-Object System.Windows.Forms.Label
    \$lblUser.Text = "Username:"
    \$lblUser.Location = New-Object System.Drawing.Point(10, 20)
    \$lblUser.Size = New-Object System.Drawing.Size(80, 20)
    \$credForm.Controls.Add(\$lblUser)

    \$txtUser = New-Object System.Windows.Forms.TextBox
    \$txtUser.Location = New-Object System.Drawing.Point(100, 18)
    \$txtUser.Size = New-Object System.Drawing.Size(220, 22)
    \$credForm.Controls.Add(\$txtUser)

    \$lblPass = New-Object System.Windows.Forms.Label
    \$lblPass.Text = "Password:"
    \$lblPass.Location = New-Object System.Drawing.Point(10, 60)
    \$lblPass.Size = New-Object System.Drawing.Size(80, 20)
    \$credForm.Controls.Add(\$lblPass)

    \$txtPass = New-Object System.Windows.Forms.TextBox
    \$txtPass.Location = New-Object System.Drawing.Point(100, 58)
    \$txtPass.Size = New-Object System.Drawing.Size(220, 22)
    \$txtPass.UseSystemPasswordChar = \$true
    \$credForm.Controls.Add(\$txtPass)

    \$btnOK = New-Object System.Windows.Forms.Button
    \$btnOK.Text = "OK"
    \$btnOK.Location = New-Object System.Drawing.Point(100, 100)
    \$btnOK.Size = New-Object System.Drawing.Size(80, 30)
    \$btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    \$credForm.Controls.Add(\$btnOK)

    \$btnCancel = New-Object System.Windows.Forms.Button
    \$btnCancel.Text = "Cancel"
    \$btnCancel.Location = New-Object System.Drawing.Point(200, 100)
    \$btnCancel.Size = New-Object System.Drawing.Size(80, 30)
    \$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    \$credForm.Controls.Add(\$btnCancel)

    \$credForm.AcceptButton = \$btnOK
    \$credForm.CancelButton = \$btnCancel

    \$dialogResult = \$credForm.ShowDialog(\$form)

    if (\$dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        \$username = \$txtUser.Text.Trim()
        \$password = \$txtPass.Text

        if ([string]::IsNullOrEmpty(\$username) -or [string]::IsNullOrEmpty(\$password)) {
            [System.Windows.Forms.MessageBox]::Show("Username and password cannot be empty.","Input Required","OK","Warning")
            return \$null
        }

        \$securePass = ConvertTo-SecureString \$password -AsPlainText -Force
        return New-Object System.Management.Automation.PSCredential (\$username, \$securePass)
    }
    else {
        return \$null
    }
}

# Event handlers
\$form.btnGetCredential.Add_Click({
    \$cred = Show-CredentialDialog
    if (\$cred) {
        \$global:VCenterCredential = \$cred
        \$form.lblCredStatus.Text = "Credentials: Set for \$($cred.UserName)"
        Write-Log -Message "Credentials obtained for user \$($cred.UserName)." -Level "INFO"
    }
    else {
        Write-Log -Message "Credential input cancelled." -Level "WARN"
    }
})

\$form.btnConnect.Add_Click({
    \$server = \$form.txtVCenter.Text.Trim()

    if ([string]::IsNullOrEmpty(\$server)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter vCenter server.","Input Required","OK","Warning")
        return
    }

    if (-not \$global:VCenterCredential) {
        [System.Windows.Forms.MessageBox]::Show("Please get credentials first.","Input Required","OK","Warning")
        return
    }

    try {
        Write-Log -Message "Connecting to vCenter \$server as \$($global:VCenterCredential.UserName)..." -Level "INFO"
        \$global:vCenterConnection = Connect-VIServer -Server \$server -Credential \$global:VCenterCredential -ErrorAction Stop
        Write-Log -Message "Connected to vCenter \$server." -Level "INFO"

        # Populate roles dropdown
        \$roles = Get-VIRole | Sort-Object Name
        \$form.comboRoles.Items.Clear()
        foreach (\$role in \$roles) {
            \$form.comboRoles.Items.Add(\$role.Name) | Out-Null
        }

        \$form.btnAssignPermission.Enabled = \$true
        \$form.btnDisconnect.Enabled = \$true
        \$form.btnConnect.Enabled = \$false
    }
    catch {
        Write-Log -Message "Failed to connect to vCenter: \$_" -Level "ERROR"
    }
})

\$form.btnDisconnect.Add_Click({
    if (\$global:vCenterConnection) {
        try {
            Disconnect-VIServer -Server \$global:vCenterConnection -Confirm:\$false -ErrorAction Stop
            Write-Log -Message "Disconnected from vCenter." -Level "INFO"
        }
        catch {
            Write-Log -Message "Error during disconnect: \$_" -Level "WARN"
        }
        finally {
            \$global:vCenterConnection = \$null
            \$form.btnDisconnect.Enabled = \$false
            \$form.btnAssignPermission.Enabled = \$false
            \$form.btnConnect.Enabled = \$true
        }
    }
})

\$form.btnAssignPermission.Add_Click({
    if (-not \$global:vCenterConnection) {
        Write-Log -Message "Not connected to vCenter." -Level "ERROR"
        return
    }

    \$principal = \$form.txtPrincipal.Text.Trim()
    \$roleName = \$form.comboRoles.SelectedItem

    if ([string]::IsNullOrEmpty(\$principal)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter the principal (user or group).","Input Required","OK","Warning")
        return
    }
    if ([string]::IsNullOrEmpty(\$roleName)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a role.","Input Required","OK","Warning")
        return
    }

    try {
        \$vms = Get-VM -ErrorAction Stop

        # For demo, assign permission on all VMs
        foreach (\$vm in \$vms) {
            Assign-PermissionIfNeeded -VM \$vm -Principal \$principal -RoleName \$roleName | Out-Null
        }
        Write-Log -Message "Finished assigning role '\$roleName' to principal '\$principal' on all VMs." -Level "INFO"
    }
    catch {
        Write-Log -Message "Error assigning permissions: \$_" -Level "ERROR"
    }
})

# Show the form
\$form.ShowDialog() | Out-Null
"@ | Set-Content -Path (Join-Path $projectFolder "MainForm.ps1") -Encoding UTF8

# Create zip
$zipPath = Join-Path $env:TEMP "VcenterTagPermissionsProject.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($projectFolder, $zipPath)

Write-Host "Project zip created at: $zipPath"
