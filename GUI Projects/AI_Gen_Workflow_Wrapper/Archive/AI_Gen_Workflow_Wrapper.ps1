$btnExportLogs_Click = {
    try {
        # Implement log export logic
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
        $saveFileDialog.Title = "Export Logs"
        
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $logTextBox.Text | Out-File -FilePath $saveFileDialog.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Logs exported successfully!", "Export Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error exporting logs: $_", "Export Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnClearLogs_Click = {
    try {
        $logTextBox.Clear()
        # Optionally, clear the actual log file
        # Add-LogMessage "Logs cleared manually"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error clearing logs: $_", "Clear Logs Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnRefreshLogs_Click = {
        try {
        # Implement log refresh logic
        # This might involve reading the latest log file or reloading logs
        if (Test-Path $Global:LogFilePath) {
            $logTextBox.Text = Get-Content $Global:LogFilePath -Raw
        }
        else {
            $logTextBox.Text = "No log file found."
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error refreshing logs: $_", "Refresh Logs Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnStopExecution_Click = {
    try {
        # Implement script execution stop logic
        if ($Global:ExecutionJob) {
            Stop-Job $Global:ExecutionJob
            Remove-Job $Global:ExecutionJob
            $btnStopExecution.Enabled = $false
            $statusStripLabel.Text = "Execution stopped by user"
            # Add additional cleanup or reset logic
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error stopping execution: $_", "Stop Execution Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnRunSelected_Click = {
    try {
        # Implement run selected script logic
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to run.", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $selectedScript = $lvScripts.SelectedItems[0]
        # Add logic to run the selected script
        # This might involve creating a background job, updating progress, etc.
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error running selected script: $_", "Script Execution Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnRunAll_Click = {
    try {
        # Validate scripts exist and are enabled
        if ($lvScripts.Items.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No scripts available to run.", "Run All Scripts", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }

        # Confirm execution
        $confirmResult = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to run all scripts?", "Confirm Execution", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($confirmResult -eq [System.Windows.Forms.DialogResult]::No) {
            return
        }

        # Prepare for script execution
        $progressOverall.Value = 0
        $progressOverall.Maximum = ($lvScripts.Items | Where-Object { $_.SubItems[2].Text -eq 'True' }).Count
        $txtExecutionOutput.Clear()

        # Start background job to run scripts
        $Global:ExecutionJob = Start-Job -ScriptBlock {
            param($scripts, $stopOnError)
            
            $results = @()
            foreach ($script in $scripts) {
                try {
                    $result = Invoke-Expression $script.Path
                    $results += @{
                        ScriptPath = $script.Path
                        Success = $true
                        Output = $result
                    }
                }
                catch {
                    $results += @{
                        ScriptPath = $script.Path
                        Success = $false
                        Error = $_.Exception.Message
                    }
                    
                    if ($stopOnError) {
                        break
                    }
                }
            }
            return $results
        } -ArgumentList @(
            ($lvScripts.Items | Where-Object { $_.SubItems[2].Text -eq 'True' } | ForEach-Object { 
                @{ Path = $_.SubItems[1].Text }
            }),
            $chkStopOnError.Checked
        )

        # Monitor job progress
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $timer.Add_Tick({
            if ($Global:ExecutionJob.State -ne 'Running') {
                $timer.Stop()
                $results = Receive-Job $Global:ExecutionJob

                # Update UI with results
                $results | ForEach-Object {
                    if ($_.Success) {
                        $txtExecutionOutput.AppendText("Script: $($_.ScriptPath)`nSuccess`n")
                    }
                    else {
                        $txtExecutionOutput.AppendText("Script: $($_.ScriptPath)`nError: $($_.Error)`n")
                    }
                }

                $progressOverall.Value = $progressOverall.Maximum
                $statusStripLabel.Text = "Execution completed"
                $btnStopExecution.Enabled = $false
            }
            else {
                $progressOverall.Value++
            }
        })
        $timer.Start()

        $btnStopExecution.Enabled = $true
        $statusStripLabel.Text = "Running all scripts..."
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error running scripts: $_", "Execution Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnSaveScriptDetails_Click = {
    try {
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($txtScriptPath.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script file.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        # If a script is selected in the list, update its details
        if ($lvScripts.SelectedIndices.Count -gt 0) {
            $selectedIndex = $lvScripts.SelectedIndices[0]
            $lvScripts.Items[$selectedIndex].SubItems[1].Text = $txtScriptPath.Text
            $lvScripts.Items[$selectedIndex].SubItems[2].Text = $chkScriptEnabled.Checked.ToString()
        }
        else {
            # Add new script to the list
            $newItem = $lvScripts.Items.Add((($lvScripts.Items.Count + 1).ToString()))
            $newItem.SubItems.Add($txtScriptPath.Text)
            $newItem.SubItems.Add($chkScriptEnabled.Checked.ToString())
        }

        # Clear input fields
        $txtScriptPath.Clear()
        $txtScriptDescription.Clear()
        $chkScriptEnabled.Checked = $false
        $lvParameters.Items.Clear()

        [System.Windows.Forms.MessageBox]::Show("Script details saved successfully.", "Save Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error saving script details: $_", "Save Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnDetectParams_Click = {
    try {
        if ([string]::IsNullOrWhiteSpace($txtScriptPath.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script file first.", "Detection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        # Clear existing parameters
        $lvParameters.Items.Clear()

        # Use AST to parse script parameters
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($txtScriptPath.Text, [ref]$null, [ref]$null)
        $parameters = $ast.FindAll({ 
            param($node) 
            $node -is [System.Management.Automation.Language.ParameterAst] 
        }, $true)

        foreach ($param in $parameters) {
            $paramName = $param.Name.VariablePath.UserPath
            $paramType = $param.StaticType.Name
            
            $listItem = $lvParameters.Items.Add($paramName)
            $listItem.SubItems.Add("") # Value
            $listItem.SubItems.Add($paramType)
        }

        [System.Windows.Forms.MessageBox]::Show("Parameters detected successfully.", "Detection Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error detecting parameters: $_", "Detection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnRemoveParam_Click = {
    try {
        if ($lvParameters.SelectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a parameter to remove.", "Remove Parameter", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $lvParameters.Items.RemoveAt($lvParameters.SelectedIndices[0])
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error removing parameter: $_", "Remove Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnEditParam_Click = {
    try {
        if ($lvParameters.SelectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a parameter to edit.", "Edit Parameter", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $selectedItem = $lvParameters.SelectedItems[0]
        $paramName = $selectedItem.Text
        $paramType = $selectedItem.SubItems[2].Text

        # Create a dialog for editing parameter value
        $inputForm = New-Object System.Windows.Forms.Form
        $inputForm.Text = "Edit Parameter"
        $inputForm.Size = New-Object System.Drawing.Size(300,200)
        $inputForm.StartPosition = "CenterScreen"

        $labelName = New-Object System.Windows.Forms.Label
        $labelName.Text = "Parameter: $paramName (Type: $paramType)"
        $labelName.Location = New-Object System.Drawing.Point(10,20)
        $labelName.Size = New-Object System.Drawing.Size(280,20)
        $inputForm.Controls.Add($labelName)

        $textValue = New-Object System.Windows.Forms.TextBox
        $textValue.Location = New-Object System.Drawing.Point(10,50)
        $textValue.Size = New-Object System.Drawing.Size(260,20)
        $textValue.Text = $selectedItem.SubItems[1].Text
        $inputForm.Controls.Add($textValue)

        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Text = "OK"
        $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $btnOK.Location = New-Object System.Drawing.Point(100,100)
        $inputForm.Controls.Add($btnOK)
        $inputForm.AcceptButton = $btnOK

        $result = $inputForm.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $selectedItem.SubItems[1].Text = $textValue.Text
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error editing parameter: $_", "Edit Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnAddParam_Click = {
try {
        # Create a dialog for adding a new parameter
        $inputForm = New-Object System.Windows.Forms.Form
        $inputForm.Text = "Add Parameter"
        $inputForm.Size = New-Object System.Drawing.Size(300,250)
        $inputForm.StartPosition = "CenterScreen"

        $labelName = New-Object System.Windows.Forms.Label
        $labelName.Text = "Parameter Name:"
        $labelName.Location = New-Object System.Drawing.Point(10,20)
        $labelName.Size = New-Object System.Drawing.Size(100,20)
        $inputForm.Controls.Add($labelName)

        $textName = New-Object System.Windows.Forms.TextBox
        $textName.Location = New-Object System.Drawing.Point(120,20)
        $textName.Size = New-Object System.Drawing.Size(150,20)
        $inputForm.Controls.Add($textName)

        $labelType = New-Object System.Windows.Forms.Label
        $labelType.Text = "Parameter Type:"
        $labelType.Location = New-Object System.Drawing.Point(10,50)
        $labelType.Size = New-Object System.Drawing.Size(100,20)
        $inputForm.Controls.Add($labelType)

        $comboType = New-Object System.Windows.Forms.ComboBox
        $comboType.Location = New-Object System.Drawing.Point(120,50)
        $comboType.Size = New-Object System.Drawing.Size(150,20)
        $comboType.Items.AddRange(@("String", "Int32", "Boolean", "PSCredential", "Array"))
        $inputForm.Controls.Add($comboType)

        $labelValue = New-Object System.Windows.Forms.Label
        $labelValue.Text = "Parameter Value:"
        $labelValue.Location = New-Object System.Drawing.Point(10,80)
        $labelValue.Size = New-Object System.Drawing.Size(100,20)
        $inputForm.Controls.Add($labelValue)

        $textValue = New-Object System.Windows.Forms.TextBox
        $textValue.Location = New-Object System.Drawing.Point(120,80)
        $textValue.Size = New-Object System.Drawing.Size(150,20)
        $inputForm.Controls.Add($textValue)

        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Text = "Add"
        $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $btnOK.Location = New-Object System.Drawing.Point(100,150)
        $inputForm.Controls.Add($btnOK)
        $inputForm.AcceptButton = $btnOK

        $result = $inputForm.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            if ([string]::IsNullOrWhiteSpace($textName.Text) -or [string]::IsNullOrWhiteSpace($comboType.SelectedItem)) {
                [System.Windows.Forms.MessageBox]::Show("Please enter a parameter name and select a type.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            $newItem = $lvParameters.Items.Add($textName.Text)
            $newItem.SubItems.Add($textValue.Text)
            $newItem.SubItems.Add($comboType.SelectedItem)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error adding parameter: $_", "Add Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnMoveDown_Click = {
    try {
        if ($lvScripts.SelectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to move.", "Move Script", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $selectedIndex = $lvScripts.SelectedIndices[0]
        if ($selectedIndex -lt $lvScripts.Items.Count - 1) {
            $currentItem = $lvScripts.Items[$selectedIndex]
            $nextItem = $lvScripts.Items[$selectedIndex + 1]

            # Swap order numbers
            $tempOrder = $currentItem.SubItems[0].Text
            $currentItem.SubItems[0].Text = $nextItem.SubItems[0].Text
            $nextItem.SubItems[0].Text = $tempOrder

            # Remove and re-insert to change position
            $lvScripts.Items.Remove($currentItem)
            $lvScripts.Items.Insert($selectedIndex + 1, $currentItem)
            $lvScripts.Items[$selectedIndex + 1].Selected = $true
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error moving script down: $_", "Move Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnMoveUp_Click = {
    try {
        if ($lvScripts.SelectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to move.", "Move Script", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $selectedIndex = $lvScripts.SelectedIndices[0]
        if ($selectedIndex -gt 0) {
            $currentItem = $lvScripts.Items[$selectedIndex]
            $prevItem = $lvScripts.Items[$selectedIndex - 1]

            # Swap order numbers
            $tempOrder = $currentItem.SubItems[0].Text
            $currentItem.SubItems[0].Text = $prevItem.SubItems[0].Text
            $prevItem.SubItems[0].Text = $tempOrder

            # Remove and re-insert to change position
            $lvScripts.Items.Remove($currentItem)
            $lvScripts.Items.Insert($selectedIndex - 1, $currentItem)
            $lvScripts.Items[$selectedIndex - 1].Selected = $true
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error moving script up: $_", "Move Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnRemoveScript_Click = {
    try {
        if ($lvScripts.SelectedIndices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to remove.", "Remove Script", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        $confirmResult = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to remove the selected script?", "Confirm Removal", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($confirmResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            $lvScripts.Items.RemoveAt($lvScripts.SelectedIndices[0])

            # Reorder remaining scripts
            for ($i = 0; $i -lt $lvScripts.Items.Count; $i++) {
                $lvScripts.Items[$i].SubItems[0].Text = ($i + 1).ToString()
            }
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error removing script: $_", "Remove Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnAddScript_Click = {
    try {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $openFileDialog.Title = "Select PowerShell Script"

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $scriptPath = $openFileDialog.FileName

            # Add script to ListView
            $newItem = $lvScripts.Items.Add(($lvScripts.Items.Count + 1).ToString())
            $newItem.SubItems.Add($scriptPath)
            $newItem.SubItems.Add("True") # Default enabled

            # Populate script details
            $txtScriptPath.Text = $scriptPath
            $chkScriptEnabled.Checked = $true

            # Attempt to detect parameters
            $btnDetectParams_Click.Invoke()
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error adding script: $_", "Add Script Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnLoadConnection_Click = {
    try {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $openFileDialog.Title = "Load Connection Settings"

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $connectionSettings = Get-Content $openFileDialog.FileName | ConvertFrom-Json

            $txtSourceServer.Text = $connectionSettings.SourceServer
            $txtSourceUsername.Text = $connectionSettings.SourceUsername
            $txtTargetServer.Text = $connectionSettings.TargetServer
            $txtTargetUsername.Text = $connectionSettings.TargetUsername

            $chkUseCurrentCredentials.Checked = $connectionSettings.UseCurrentCredentials

            [System.Windows.Forms.MessageBox]::Show("Connection settings loaded successfully.", "Load Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error loading connection settings: $_", "Load Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnSaveConnection_Click = {
    try {
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $saveFileDialog.Title = "Save Connection Settings"

        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $connectionSettings = @{
                SourceServer = $txtSourceServer.Text
                SourceUsername = $txtSourceUsername.Text
                TargetServer = $txtTargetServer.Text
                TargetUsername = $txtTargetUsername.Text
                UseCurrentCredentials = $chkUseCurrentCredentials.Checked
            }

            $connectionSettings | ConvertTo-Json | Out-File $saveFileDialog.FileName

            [System.Windows.Forms.MessageBox]::Show("Connection settings saved successfully.", "Save Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error saving connection settings: $_", "Save Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnTestTargetConnection_Click = {
    try {
        # Validate input
        if ([string]::IsNullOrWhiteSpace($txtTargetServer.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a target server address.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        # Attempt connection
        $credential = $null
        if (-not $chkUseCurrentCredentials.Checked) {
            $credential = Get-Credential -UserName $txtTargetUsername.Text -Message "Enter credentials for Target vCenter"
        }

        $connection = Connect-VIServer -Server $txtTargetServer.Text -Credential $credential -ErrorAction Stop

        if ($connection) {
            Disconnect-VIServer -Server $connection -Confirm:$false
            [System.Windows.Forms.MessageBox]::Show("Successfully connected to target vCenter!", "Connection Test", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Connection failed: $_", "Connection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnTestSourceConnection_Click = {
    try {
        # Validate input
        if ([string]::IsNullOrWhiteSpace($txtSourceServer.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a source server address.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        # Attempt connection
        $credential = $null
        if (-not $chkUseCurrentCredentials.Checked) {
            $credential = Get-Credential -UserName $txtSourceUsername.Text -Message "Enter credentials for Source vCenter"
        }

        $connection = Connect-VIServer -Server $txtSourceServer.Text -Credential $credential -ErrorAction Stop

        if ($connection) {
            Disconnect-VIServer -Server $connection -Confirm:$false
            [System.Windows.Forms.MessageBox]::Show("Successfully connected to source vCenter!", "Connection Test", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Connection failed: $_", "Connection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# AI_Gen_Workflow_Wrapper.ps1
# Core functionality and action handlers for the vCenter Migration Workflow Manager

# Note: This file is loaded by Launch.ps1 and should not be run directly

#region Core Functions

function Initialize-Application {
    # Initialize application components that weren't handled in Globals.ps1
    Write-Log "Initializing application components"
    
    # Load saved settings into the UI
    Load-FormSettings
    
    # Check PowerCLI installation
    Check-PowerCLI
    
    # Load scripts list into the UI
    Load-ScriptsList
    
    # Set initial UI state
    Update-UIState -State "Ready"
    
    Write-Log "Application initialized successfully"
}

function Update-UIState {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Ready", "Running", "Stopped", "Error")]
        [string]$State
    )
    
    switch ($State) {
        "Ready" {
            $btnRunAll.Enabled = $true
            $btnRunSelected.Enabled = $true
            $btnStopExecution.Enabled = $false
            $statusStripLabel.Text = "Ready"
        }
        "Running" {
            $btnRunAll.Enabled = $false
            $btnRunSelected.Enabled = $false
            $btnStopExecution.Enabled = $true
            $statusStripLabel.Text = "Running..."
        }
        "Stopped" {
            $btnRunAll.Enabled = $true
            $btnRunSelected.Enabled = $true
            $btnStopExecution.Enabled = $false
            $statusStripLabel.Text = "Execution stopped"
        }
        "Error" {
            $btnRunAll.Enabled = $true
            $btnRunSelected.Enabled = $true
            $btnStopExecution.Enabled = $false
            $statusStripLabel.Text = "Error occurred"
        }
    }
}


#endregion

# Add this function to convert a TextBox's text to SecureString
function Convert-TextBoxToSecureString {
    param(
        [System.Windows.Forms.TextBox]$TextBox
    )

    if (-not $TextBox -or [string]::IsNullOrWhiteSpace($TextBox.Text)) {
        return $null
    }

    $secureString = New-Object System.Security.SecureString
    foreach ($char in $TextBox.Text.ToCharArray()) {
        $secureString.AppendChar($char)
    }
    $secureString.MakeReadOnly()
    return $secureString
}

function Test-vCenterConnection {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Button]$ConnectionButton,
        
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.TextBox]$ServerTextBox,
        
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.TextBox]$UsernameTextBox,
        
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.TextBox]$PasswordTextBox,
        
        [System.Windows.Forms.CheckBox]$UseCurrentCredentials = $null
    )

    function Write-DetailedLog {
        param(
            [string]$Message,
            [string]$LogLevel = 'INFO'
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$LogLevel] $Message"
        
        # Write to log textbox
        if ($mainForm.logTextBox) {
            $mainForm.logTextBox.Invoke([Action]{
                $mainForm.logTextBox.AppendText("$logEntry`r`n")
            })
        }
        
        # Write to file log
        Add-Content -Path "$PSScriptRoot\vcenter_connection.log" -Value $logEntry
        
        # Update status strip
        if ($mainForm.statusStripLabel) {
            $mainForm.statusStripLabel.Invoke([Action]{
                $mainForm.statusStripLabel.Text = $Message
            })
        }

        # Also write to console for debugging
        Write-Host $logEntry
    }

    try {
        # Explicitly extract text from TextBox controls
        $serverName = $ServerTextBox.Text
        $username = $UsernameTextBox.Text
        
        # Convert password to SecureString
        $securePassword = Convert-TextBoxToSecureString -TextBox $PasswordTextBox

        # Detailed diagnostic logging
        Write-DetailedLog "Connection Test Started" -LogLevel "INFO"
        
        # Log UI control values for debugging
        Write-DetailedLog "Server: $serverName" -LogLevel "DEBUG"
        Write-DetailedLog "Username: $username" -LogLevel "DEBUG"
        Write-DetailedLog "Password Length: $($securePassword?.Length -eq $null)" -LogLevel "DEBUG"

        # Validate input
        if ([string]::IsNullOrWhiteSpace($serverName)) {
            throw "Server address cannot be empty"
        }

        # Determine credentials
        $Credential = $null
        $useCurrentCreds = $false

        # Check if UseCurrentCredentials checkbox exists and is checked
        if ($UseCurrentCredentials -and $UseCurrentCredentials.Checked) {
            Write-DetailedLog "Using current Windows credentials" -LogLevel "INFO"
            $useCurrentCreds = $true
        }
        else {
            # Validate username and password
            if ([string]::IsNullOrWhiteSpace($username) -or ($securePassword -eq $null)) {
                throw "Username and Password are required when not using current credentials"
            }
            
            # Create credential object with SecureString
            $Credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
        }

        # Ensure PowerCLI is loaded
        if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
            Write-DetailedLog "Installing VMware PowerCLI module" -LogLevel "WARNING"
            Install-Module -Name VMware.PowerCLI -Force -Scope CurrentUser
        }

        # Import PowerCLI module
        #Import-Module VMware.PowerCLI
        
        # Suppress PowerCLI warnings
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

        # Attempt connection
        Write-DetailedLog "Connecting to vCenter Server: $serverName" -LogLevel "INFO"
        
        # Connection logic with different paths for current creds vs specific creds
        if ($useCurrentCreds) {
            $connection = Connect-VIServer -Server $serverName -ErrorAction Stop
        }
        else {
            $connection = Connect-VIServer -Server $serverName -Credential $Credential -ErrorAction Stop
        }

        if ($connection) {
            Write-DetailedLog "Successfully connected to vCenter Server" -LogLevel "SUCCESS"
            [System.Windows.Forms.MessageBox]::Show("Connection Successful!", "Connection Test", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            
            # Disconnect after successful test
            Disconnect-VIServer -Server $connection -Confirm:$false
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-DetailedLog "Connection Failed: $errorMessage" -LogLevel "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Connection Failed:`n$errorMessage", 
            "Connection Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    finally {
        # Ensure any lingering connections are closed
        try {
            Get-VIServer | Disconnect-VIServer -Confirm:$false
        }
        catch {}

        # Clear sensitive data
        if ($securePassword) {
            $securePassword.Dispose()
        }
        if ($Credential) {
            $Credential.Dispose()
        }
    }
}

# Password masking for TextBoxes
function Set-PasswordTextBoxProperties {
    param(
        [System.Windows.Forms.TextBox]$TextBox
    )

    $TextBox.PasswordChar = '*'
    $TextBox.MaxLength = 128  # Optional: set a reasonable max length
}

# Event handler for Source vCenter connection test

# Apply to your password TextBoxes
Set-PasswordTextBoxProperties -TextBox $mainForm.txtSourcePassword
Set-PasswordTextBoxProperties -TextBox $mainForm.txtTargetPassword

# Event handler for Source vCenter connection test
function btnTestSourceConnection_Click {
    Test-vCenterConnection `
        -ConnectionButton $mainForm.btnTestSourceConnection `
        -ServerTextBox $mainForm.txtSourceServer `
        -UsernameTextBox $mainForm.txtSourceUsername `
        -PasswordTextBox $mainForm.txtSourcePassword `
        -UseCurrentCredentials $mainForm.chkUseCurrentCredentials
}

# Event handler for Target vCenter connection test
function btnTestTargetConnection_Click {
    Test-vCenterConnection `
        -ConnectionButton $mainForm.btnTestTargetConnection `
        -ServerTextBox $mainForm.txtTargetServer `
        -UsernameTextBox $mainForm.txtTargetUsername `
        -PasswordTextBox $mainForm.txtTargetPassword `
        -UseCurrentCredentials $mainForm.chkUseCurrentCredentials
}

# Attach event handlers
$mainForm.btnTestSourceConnection.Add_Click({
    btnTestSourceConnection_Click
})

$mainForm.btnTestTargetConnection.Add_Click({
    btnTestTargetConnection_Click
})


function Save-ConnectionSettings {
    $script:vCenterConfig.SourcevCenter = $txtSourceServer.Text
    $script:vCenterConfig.SourceUsername = $txtSourceUsername.Text
    $script:vCenterConfig.SourcePassword = $txtSourcePassword.Text
    $script:vCenterConfig.TargetvCenter = $txtTargetServer.Text
    $script:vCenterConfig.TargetUsername = $txtTargetUsername.Text
    $script:vCenterConfig.TargetPassword = $txtTargetPassword.Text
    $script:vCenterConfig.UseCurrentCredentials = $chkUseCurrentCredentials.Checked
    
    $saved = Save-MigrationConfig
    if ($saved) {
        $statusStripLabel.Text = "Connection settings saved successfully"
        Write-Log "Connection settings saved successfully"
    } else {
        $statusStripLabel.Text = "Failed to save connection settings"
        Write-Log "Failed to save connection settings" -Level "ERROR"
    }
}

function Load-ConnectionSettings {
    $loaded = Load-MigrationConfig
    if ($loaded) {
        Load-FormSettings
        $statusStripLabel.Text = "Connection settings loaded successfully"
        Write-Log "Connection settings loaded successfully"
    } else {
        $statusStripLabel.Text = "Failed to load connection settings"
        Write-Log "Failed to load connection settings" -Level "WARNING"
    }
}

#endregion

#region Script Management Functions

function Load-ScriptsList {
    try {
        # Clear the ListView
        $lvScripts.Items.Clear()
        
        # Sort scripts by order
        $sortedScripts = $script:Scripts | Sort-Object -Property Order
        
        # Add each script to the ListView
        foreach ($script in $sortedScripts) {
            $item = New-Object System.Windows.Forms.ListViewItem
            $item.Text = $script.Order.ToString()
            $item.SubItems.Add($script.Name)
            $item.SubItems.Add($script.Enabled.ToString())
            $lvScripts.Items.Add($item)
        }
        
        Write-Log "Loaded scripts list"
    }
    catch {
        Write-Log "Error loading scripts list: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error loading scripts list: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Add-ScriptToList {
    param (
        [string]$scriptPath = "",
        [string]$description = "",
        [bool]$enabled = $true
    )

    try {
        Write-Log "Starting Add-ScriptToList function"
        
        # If scriptPath is empty, show file dialog
        if ([string]::IsNullOrEmpty($scriptPath)) {
            Write-Log "Opening file dialog to select script"
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All files (*.*)|*.*"
            $openFileDialog.Title = "Select a PowerShell Script"
            
            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $scriptPath = $openFileDialog.FileName
                Write-Log "Selected script: $scriptPath"
            } else {
                Write-Log "File dialog canceled"
                return $false
            }
        }

        # Get script name from path
        $scriptName = [System.IO.Path]::GetFileName($scriptPath)
        Write-Log "Script name: $scriptName"

        # Initialize Scripts collection if it doesn't exist
        if ($null -eq $script:Scripts) {
            Write-Log "Initializing Scripts collection"
            $script:Scripts = @()
        }

        # Get the next order number
        $nextOrder = 1
        if ($script:Scripts.Count -gt 0) {
            $nextOrder = ($script:Scripts | Measure-Object -Property Order -Maximum).Maximum + 1
        }
        Write-Log "Next order number: $nextOrder"

        # Add to scripts collection first
        Write-Log "Adding script to collection"
        $script:Scripts += @{
            Order = $nextOrder
            Name = $scriptName
            Path = $scriptPath
            Description = $description
            Enabled = $enabled
            Parameters = @()
        }

        # Now try to add to ListView
        Write-Log "Creating ListViewItem"
        $item = New-Object System.Windows.Forms.ListViewItem
        
        Write-Log "Setting ListViewItem properties"
        $item.Text = $nextOrder.ToString()
        
        Write-Log "Adding first subitem"
        $item.SubItems.Add($scriptName)
        
        Write-Log "Adding second subitem"
        $item.SubItems.Add($enabled.ToString())

        Write-Log "Adding item to ListView"
        $lvScripts.Items.Add($item)

        Write-Log "Successfully added script: $scriptPath"
        return $true
    }
    catch {
        Write-Log "Error adding script: $($_.Exception.Message)" -Level "Error"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error adding script: $($_.Exception.Message)`n`nStack trace: $($_.ScriptStackTrace)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Remove-ScriptFromList {
    try {
        # Check if a script is selected
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to remove.", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        # Get the selected script
        $selectedIndex = $lvScripts.SelectedIndices[0]
        $selectedOrder = [int]$lvScripts.Items[$selectedIndex].Text
        
        # Confirm deletion
        $scriptName = $lvScripts.Items[$selectedIndex].SubItems[1].Text
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to remove the script '$scriptName'?", "Confirm Removal", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Remove from ListView
            $lvScripts.Items.RemoveAt($selectedIndex)
            
            # Remove from scripts collection
            $script:Scripts = $script:Scripts | Where-Object { $_.Order -ne $selectedOrder }
            
            # Clear the details
            Clear-ScriptDetails
            
            Write-Log "Removed script: $scriptName"
        }
    }
    catch {
        Write-Log "Error removing script: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error removing script: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Move-ScriptUp {
    try {
        # Check if a script is selected
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to move.", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        # Get the selected script
        $selectedIndex = $lvScripts.SelectedIndices[0]
        
        # Check if it's already at the top
        if ($selectedIndex -eq 0) {
            return
        }
        
        # Get the current and previous script
        $currentScript = $script:Scripts | Where-Object { $_.Order -eq [int]$lvScripts.Items[$selectedIndex].Text }
        $previousScript = $script:Scripts | Where-Object { $_.Order -eq [int]$lvScripts.Items[$selectedIndex - 1].Text }
        
        # Swap their order
        $tempOrder = $currentScript.Order
        $currentScript.Order = $previousScript.Order
        $previousScript.Order = $tempOrder
        
        # Update the ListView
        $lvScripts.Items[$selectedIndex].Text = $currentScript.Order.ToString()
        $lvScripts.Items[$selectedIndex - 1].Text = $previousScript.Order.ToString()
        
        # Refresh the ListView to reflect the new order
        Load-ScriptsList
        
        # Select the moved item
        $lvScripts.Items[$selectedIndex - 1].Selected = $true
        
        Write-Log "Moved script up: $($currentScript.Name)"
    }
    catch {
        Write-Log "Error moving script up: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error moving script up: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Move-ScriptDown {
    try {
        # Check if a script is selected
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to move.", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        # Get the selected script
        $selectedIndex = $lvScripts.SelectedIndices[0]
        
        # Check if it's already at the bottom
        if ($selectedIndex -eq ($lvScripts.Items.Count - 1)) {
            return
        }
        
        # Get the current and next script
        $currentScript = $script:Scripts | Where-Object { $_.Order -eq [int]$lvScripts.Items[$selectedIndex].Text }
        $nextScript = $script:Scripts | Where-Object { $_.Order -eq [int]$lvScripts.Items[$selectedIndex + 1].Text }
        
        # Swap their order
        $tempOrder = $currentScript.Order
        $currentScript.Order = $nextScript.Order
        $nextScript.Order = $tempOrder
        
        # Update the ListView
        $lvScripts.Items[$selectedIndex].Text = $currentScript.Order.ToString()
        $lvScripts.Items[$selectedIndex + 1].Text = $nextScript.Order.ToString()
        
        # Refresh the ListView to reflect the new order
        Load-ScriptsList
        
        # Select the moved item
        $lvScripts.Items[$selectedIndex + 1].Selected = $true
        
        Write-Log "Moved script down: $($currentScript.Name)"
    }
    catch {
        Write-Log "Error moving script down: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error moving script down: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

#endregion

#region Script Details Functions

function Load-ScriptDetails {
    try {
        # Check if a script is selected
        if ($lvScripts.SelectedItems.Count -eq 0) {
            # Clear the details
            Clear-ScriptDetails
            return
        }
        
        # Get the selected script
        $selectedIndex = $lvScripts.SelectedIndices[0]
        $selectedOrder = [int]$lvScripts.Items[$selectedIndex].Text
        $selectedScript = $script:Scripts | Where-Object { $_.Order -eq $selectedOrder }
        
        if ($null -eq $selectedScript) {
            Clear-ScriptDetails
            return
        }
        
        # Fill in the details
        $txtScriptPath.Text = $selectedScript.Path
        $txtScriptDescription.Text = $selectedScript.Description
        $chkScriptEnabled.Checked = $selectedScript.Enabled
        
        # Clear and fill parameters
        $lvParameters.Items.Clear()
        foreach ($param in $selectedScript.Parameters) {
            $paramItem = New-Object System.Windows.Forms.ListViewItem
            $paramItem.Text = $param.Name
            $paramItem.SubItems.Add($param.Value)
            $paramItem.SubItems.Add($param.Type)
            $lvParameters.Items.Add($paramItem)
        }
        
        # Enable the details controls
        $grpScriptDetails.Enabled = $true
        
        Write-Log "Loaded details for script: $($selectedScript.Name)"
    }
    catch {
        Write-Log "Error loading script details: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error loading script details: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Clear-ScriptDetails {
    try {
        $txtScriptPath.Text = ""
        $txtScriptDescription.Text = ""
        $chkScriptEnabled.Checked = $true
        $lvParameters.Items.Clear()
        $grpScriptDetails.Enabled = $false
    }
    catch {
        Write-Log "Error clearing script details: $($_.Exception.Message)" -Level "Error"
    }
}

function Save-ScriptDetails {
    try {
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to save details for", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        $selectedIndex = $lvScripts.SelectedIndices[0]
        $selectedOrder = [int]$lvScripts.Items[$selectedIndex].Text
        $selectedScript = $script:Scripts | Where-Object { $_.Order -eq $selectedOrder }
        
        # Update script details
        $selectedScript.Path = $txtScriptPath.Text
        $selectedScript.Description = $txtScriptDescription.Text
        $selectedScript.Enabled = $chkScriptEnabled.Checked
        
        # Update ListView
        $lvScripts.Items[$selectedIndex].SubItems[1].Text = [System.IO.Path]::GetFileName($txtScriptPath.Text)
        $lvScripts.Items[$selectedIndex].SubItems[2].Text = $chkScriptEnabled.Checked.ToString()
        
        Write-Log "Saved details for script: $($selectedScript.Name)"
        $statusStripLabel.Text = "Saved script details"
        
        [System.Windows.Forms.MessageBox]::Show("Script details saved successfully", "Save Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        Write-Log "Error saving script details: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error saving script details: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Browse-ScriptFile {
    try {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All files (*.*)|*.*"
        $openFileDialog.Title = "Select PowerShell Script"
        
        if ($script:config.ScriptsFolder -and (Test-Path $script:config.ScriptsFolder)) {
            $openFileDialog.InitialDirectory = $script:config.ScriptsFolder
        }
        
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtScriptPath.Text = $openFileDialog.FileName
        }
    }
    catch {
        Write-Log "Error browsing for script file: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error browsing for script file: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

#endregion

#region Parameter Management Functions

function Detect-ScriptParameters {
    # Get the selected script
    $selectedIndex = $lvScripts.SelectedIndices[0]
    if ($selectedIndex -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Please select a script first.", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $scriptPath = $script:Scripts[$selectedIndex].Path
    if (-not (Test-Path $scriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Script file not found: $scriptPath", "File Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    try {
        # Clear existing parameters
        $lvParameters.Items.Clear()
        
        # Read the script content
        $scriptContent = Get-Content -Path $scriptPath -Raw -ErrorAction Stop
        
        Write-Log "Detecting parameters for script: $scriptPath"
        
        # Parse the script using AST
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
        
        # Find the param block
        $paramBlock = $ast.ParamBlock
        if ($null -eq $paramBlock -or $null -eq $paramBlock.Parameters -or $paramBlock.Parameters.Count -eq 0) {
            Write-Log "No parameters found in script: $scriptPath"
            [System.Windows.Forms.MessageBox]::Show("No parameters found in the script.", "No Parameters", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        # Extract comment-based help for parameter descriptions
        $helpContent = $null
        if ($ast.GetHelpContent()) {
            $helpContent = $ast.GetHelpContent()
        }
        
        # Process each parameter
        $detectedParams = @()
        
        foreach ($param in $paramBlock.Parameters) {
            $paramName = $param.Name.VariablePath.UserPath
            Write-Log "Found parameter: $paramName"
            
            # Get parameter type
            $paramType = "String"  # Default type
            if ($param.StaticType) {
                $paramType = $param.StaticType.Name
            }
            
            # Get default value if any
            $defaultValue = ""
            if ($param.DefaultValue) {
                $defaultValue = $param.DefaultValue.Extent.Text
            }
            
            # Get description from help content if available
            $description = ""
            if ($helpContent -and $helpContent.Parameters -and $helpContent.Parameters.ContainsKey($paramName)) {
                $description = $helpContent.Parameters[$paramName]
            }
            
            # Set default values for common parameters
            if ($paramName -eq "vCenterConnection") {
                $defaultValue = "SourceConnection"
            }
            elseif ($paramName -eq "LogOutputLocation") {
                $defaultValue = $script:config.LogPath
            }
            elseif ($paramName -eq "ReportOutputLocation") {
                $defaultValue = $script:config.ReportsPath
            }
            
            # Create parameter object
            $paramObject = [PSCustomObject]@{
                Name = $paramName
                Value = $defaultValue
                Type = $paramType
                Description = $description
            }
            
            $detectedParams += $paramObject
            
            # Add to ListView - with null checks
            $item = New-Object System.Windows.Forms.ListViewItem($paramName)
            if ($item -ne $null) {
                if ($defaultValue -ne $null) {
                    $item.SubItems.Add($defaultValue.ToString())
                } else {
                    $item.SubItems.Add("")
                }
                
                if ($paramType -ne $null) {
                    $item.SubItems.Add($paramType.ToString())
                } else {
                    $item.SubItems.Add("String")
                }
                
                $lvParameters.Items.Add($item)
            } else {
                Write-Log "Error: Failed to create ListView item for parameter $paramName" -Level "ERROR"
            }
        }
        
        # Update the script's parameters
        $script:Scripts[$selectedIndex].Parameters = $detectedParams
        
        Write-Log "Detected $($detectedParams.Count) parameters for script: $scriptPath"
        [System.Windows.Forms.MessageBox]::Show("Detected $($detectedParams.Count) parameters.", "Parameters Detected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        $errorMessage = "Error detecting script parameters: $($_.Exception.Message)"
        Write-Log $errorMessage -Level "ERROR"
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}


function Add-ScriptParameter {
    try {
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script first", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Create a parameter input form
        $paramForm = New-Object System.Windows.Forms.Form
        $paramForm.Text = "Add Parameter"
        $paramForm.Size = New-Object System.Drawing.Size(400, 250)
        $paramForm.StartPosition = "CenterParent"
        $paramForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
        $paramForm.MaximizeBox = $false
        $paramForm.MinimizeBox = $false
        $paramForm.autosize = $true
        
        # Parameter name label
        $lblParamName = New-Object System.Windows.Forms.Label
        $lblParamName.Text = "Parameter Name:"
        $lblParamName.Location = New-Object System.Drawing.Point(20, 20)
        $lblParamName.Size = New-Object System.Drawing.Size(120, 20)
        $paramForm.Controls.Add($lblParamName)
        
        # Parameter name textbox
        $txtParamName = New-Object System.Windows.Forms.TextBox
        $txtParamName.Location = New-Object System.Drawing.Point(150, 20)
        $txtParamName.Size = New-Object System.Drawing.Size(200, 20)
        $paramForm.Controls.Add($txtParamName)
        
        # Parameter value label
        $lblParamValue = New-Object System.Windows.Forms.Label
        $lblParamValue.Text = "Parameter Value:"
        $lblParamValue.Location = New-Object System.Drawing.Point(20, 50)
        $lblParamValue.Size = New-Object System.Drawing.Size(120, 20)
        $paramForm.Controls.Add($lblParamValue)
        
        # Parameter value textbox
        $txtParamValue = New-Object System.Windows.Forms.TextBox
        $txtParamValue.Location = New-Object System.Drawing.Point(150, 50)
        $txtParamValue.Size = New-Object System.Drawing.Size(200, 20)
        $paramForm.Controls.Add($txtParamValue)
        
        # Parameter type label
        $lblParamType = New-Object System.Windows.Forms.Label
        $lblParamType.Text = "Parameter Type:"
        $lblParamType.Location = New-Object System.Drawing.Point(20, 80)
        $lblParamType.Size = New-Object System.Drawing.Size(120, 20)
        $paramForm.Controls.Add($lblParamType)
        
        # Parameter type combobox
        $cmbParamType = New-Object System.Windows.Forms.ComboBox
        $cmbParamType.Location = New-Object System.Drawing.Point(150, 80)
        $cmbParamType.Size = New-Object System.Drawing.Size(200, 20)
        $cmbParamType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $paramTypes = @("String", "Int32", "Double", "Boolean", "DateTime", "PSCredential", "SecureString", "Object")
        foreach ($type in $paramTypes) {
            $cmbParamType.Items.Add($type)
        }
        $cmbParamType.SelectedIndex = 0
        $paramForm.Controls.Add($cmbParamType)
        
        # Use vCenter credentials checkbox
        $chkUseVCenterCreds = New-Object System.Windows.Forms.CheckBox
        $chkUseVCenterCreds.Text = "Use vCenter credentials"
        $chkUseVCenterCreds.Location = New-Object System.Drawing.Point(150, 110)
        $chkUseVCenterCreds.Size = New-Object System.Drawing.Size(200, 20)
        $paramForm.Controls.Add($chkUseVCenterCreds)
        
        # Source or Target radio buttons (only visible when using vCenter credentials)
        $pnlCredentialType = New-Object System.Windows.Forms.Panel
        $pnlCredentialType.Location = New-Object System.Drawing.Point(150, 130)
        $pnlCredentialType.Size = New-Object System.Drawing.Size(200, 30)
        $pnlCredentialType.Visible = $false
        $paramForm.Controls.Add($pnlCredentialType)
        
        $rbSource = New-Object System.Windows.Forms.RadioButton
        $rbSource.Text = "Source"
        $rbSource.Location = New-Object System.Drawing.Point(0, 0)
        $rbSource.Size = New-Object System.Drawing.Size(80, 20)
        $rbSource.Checked = $true
        $pnlCredentialType.Controls.Add($rbSource)
        
        $rbTarget = New-Object System.Windows.Forms.RadioButton
        $rbTarget.Text = "Target"
        $rbTarget.Location = New-Object System.Drawing.Point(90, 0)
        $rbTarget.Size = New-Object System.Drawing.Size(80, 20)
        $pnlCredentialType.Controls.Add($rbTarget)
        
        # Show/hide credential options based on checkbox
        $chkUseVCenterCreds.Add_CheckedChanged({
            $pnlCredentialType.Visible = $chkUseVCenterCreds.Checked
            if ($chkUseVCenterCreds.Checked) {
                $cmbParamType.SelectedItem = "PSCredential"
                $cmbParamType.Enabled = $false
                if ($rbSource.Checked) {
                    $txtParamValue.Text = "SourceCredential"
                } else {
                    $txtParamValue.Text = "TargetCredential"
                }
            } else {
                $cmbParamType.Enabled = $true
            }
        })
        
        $rbSource.Add_CheckedChanged({
            if ($rbSource.Checked) {
                $txtParamValue.Text = "SourceCredential"
            }
        })
        
        $rbTarget.Add_CheckedChanged({
            if ($rbTarget.Checked) {
                $txtParamValue.Text = "TargetCredential"
            }
        })
        
        # OK button
        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Text = "OK"
        $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $btnOK.Location = New-Object System.Drawing.Point(150, 170)
        $btnOK.Size = New-Object System.Drawing.Size(75, 23)
        $paramForm.Controls.Add($btnOK)
        
        # Cancel button
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = "Cancel"
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $btnCancel.Location = New-Object System.Drawing.Point(240, 170)
        $btnCancel.Size = New-Object System.Drawing.Size(75, 23)
        $paramForm.Controls.Add($btnCancel)
        
        $paramForm.AcceptButton = $btnOK
        $paramForm.CancelButton = $btnCancel
        
        # Show the form
        $result = $paramForm.ShowDialog()
        
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $paramName = $txtParamName.Text.Trim()
            $paramValue = $txtParamValue.Text
            $paramType = $cmbParamType.SelectedItem
            
            if ([string]::IsNullOrEmpty($paramName)) {
                [System.Windows.Forms.MessageBox]::Show("Parameter name cannot be empty", "Invalid Input", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }
            
            # Add to ListView
            $item = New-Object System.Windows.Forms.ListViewItem($paramName)
            $item.SubItems.Add($paramValue)
            $item.SubItems.Add($paramType)
            $lvParameters.Items.Add($item)
            
            # Add to script parameters
            $selectedIndex = $lvScripts.SelectedIndices[0]
            $selectedOrder = [int]$lvScripts.Items[$selectedIndex].Text
            $selectedScript = $script:Scripts | Where-Object { $_.Order -eq $selectedOrder }
            
            $selectedScript.Parameters += @{
                Name = $paramName
                Value = $paramValue
                Type = $paramType
            }
            
            Write-Log "Added parameter '$($paramName)' to script: $($selectedScript.Name)"
        }
    }
    catch {
        Write-Log "Error adding parameter: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error adding parameter: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Edit-ScriptParameter {
    # Get selected parameter
    if ($lvParameters.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a parameter to edit.", "No Parameter Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $selectedItem = $lvParameters.SelectedItems[0]
    $paramName = $selectedItem.Text
    $paramValue = $selectedItem.SubItems[1].Text
    $paramType = $selectedItem.SubItems[2].Text
    
    # Create a form for editing the parameter
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Edit Parameter"
    $form.Size = New-Object System.Drawing.Size(450, 400)  # Increased initial size
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Parameter Name (read-only)
    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Location = New-Object System.Drawing.Point(10, 20)
    $lblName.Size = New-Object System.Drawing.Size(100, 20)
    $lblName.Text = "Name:"
    $form.Controls.Add($lblName)
    
    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Location = New-Object System.Drawing.Point(120, 20)
    $txtName.Size = New-Object System.Drawing.Size(300, 20)  # Wider
    $txtName.Text = $paramName
    $txtName.ReadOnly = $true
    $form.Controls.Add($txtName)
    
    # Parameter Type
    $lblType = New-Object System.Windows.Forms.Label
    $lblType.Location = New-Object System.Drawing.Point(10, 50)
    $lblType.Size = New-Object System.Drawing.Size(100, 20)
    $lblType.Text = "Type:"
    $form.Controls.Add($lblType)
    
    $cboType = New-Object System.Windows.Forms.ComboBox
    $cboType.Location = New-Object System.Drawing.Point(120, 50)
    $cboType.Size = New-Object System.Drawing.Size(300, 20)  # Wider
    $cboType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    
    # Add common parameter types
    $paramTypes = @("String", "Int32", "Int64", "Double", "Boolean", "DateTime", "PSCredential", "Object", "Array", "Hashtable")
    foreach ($type in $paramTypes) {
        [void]$cboType.Items.Add($type)
    }
    
    # Set the current type
    if ($cboType.Items.Contains($paramType)) {
        $cboType.SelectedItem = $paramType
    } else {
        # If the type is not in the list, add it and select it
        [void]$cboType.Items.Add($paramType)
        $cboType.SelectedItem = $paramType
    }
    
    $form.Controls.Add($cboType)
    
    # Parameter Value
    $lblValue = New-Object System.Windows.Forms.Label
    $lblValue.Location = New-Object System.Drawing.Point(10, 80)
    $lblValue.Size = New-Object System.Drawing.Size(100, 20)
    $lblValue.Text = "Value:"
    $form.Controls.Add($lblValue)
    
    $txtValue = New-Object System.Windows.Forms.TextBox
    $txtValue.Location = New-Object System.Drawing.Point(120, 80)
    $txtValue.Size = New-Object System.Drawing.Size(300, 20)  # Wider
    $txtValue.Text = $paramValue
    $form.Controls.Add($txtValue)
    
    # Special options section
    $grpSpecialOptions = New-Object System.Windows.Forms.GroupBox
    $grpSpecialOptions.Location = New-Object System.Drawing.Point(10, 110)
    $grpSpecialOptions.Size = New-Object System.Drawing.Size(410, 200)  # Much taller and wider
    $grpSpecialOptions.Text = "Special Options"
    $form.Controls.Add($grpSpecialOptions)
    
    # OK and Cancel buttons - will be positioned later
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Size = New-Object System.Drawing.Size(75, 23)
    $btnOK.Text = "OK"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $btnOK
    $form.Controls.Add($btnOK)
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Size = New-Object System.Drawing.Size(75, 23)
    $btnCancel.Text = "Cancel"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $btnCancel
    $form.Controls.Add($btnCancel)
    
    # Add event handler for type change
    $cboType.Add_SelectedIndexChanged({
        # Update special options based on the selected type
        UpdateSpecialOptions
    })
    
    # Function to update special options based on parameter type
    function UpdateSpecialOptions {
        # Clear existing controls
        $grpSpecialOptions.Controls.Clear()
        
        $yPos = 25  # Start a bit lower for better spacing
        $optionSpacing = 35  # Increased spacing between options
        $hasSpecialOptions = $false
        $currentType = $cboType.SelectedItem.ToString()
        
        # Special handling for credential parameters
        if ($currentType -eq "PSCredential") {
            $rbSourceCred = New-Object System.Windows.Forms.RadioButton
            $rbSourceCred.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbSourceCred.Size = New-Object System.Drawing.Size(180, 40)  # Larger
            $rbSourceCred.Text = "Use Source Credentials"
            $rbSourceCred.Checked = ($txtValue.Text -eq "SourceCredential")
            $rbSourceCred.Add_Click({
                $txtValue.Text = "SourceCredential"
            })
            $grpSpecialOptions.Controls.Add($rbSourceCred)
            
            $rbTargetCred = New-Object System.Windows.Forms.RadioButton
            $rbTargetCred.Location = New-Object System.Drawing.Point(210, $yPos)
            $rbTargetCred.Size = New-Object System.Drawing.Size(180, 24)  # Larger
            $rbTargetCred.Text = "Use Target Credentials"
            $rbTargetCred.Checked = ($txtValue.Text -eq "TargetCredential")
            $rbTargetCred.Add_Click({
                $txtValue.Text = "TargetCredential"
            })
            $grpSpecialOptions.Controls.Add($rbTargetCred)
            
            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }
        
        # Special handling for vCenter connection
        if ($paramName -eq "vCenterConnection" -or $currentType -like "*VIServer*") {
            $rbSourceConn = New-Object System.Windows.Forms.RadioButton
            $rbSourceConn.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbSourceConn.Size = New-Object System.Drawing.Size(180, 24)  # Larger
            $rbSourceConn.Text = "Use Source Connection"
            $rbSourceConn.Checked = ($txtValue.Text -eq "SourceConnection")
            $rbSourceConn.Add_Click({
                $txtValue.Text = "SourceConnection"
            })
            $grpSpecialOptions.Controls.Add($rbSourceConn)
            
            $rbTargetConn = New-Object System.Windows.Forms.RadioButton
            $rbTargetConn.Location = New-Object System.Drawing.Point(210, $yPos)
            $rbTargetConn.Size = New-Object System.Drawing.Size(180, 24)  # Larger
            $rbTargetConn.Text = "Use Target Connection"
            $rbTargetConn.Checked = ($txtValue.Text -eq "TargetConnection")
            $rbTargetConn.Add_Click({
                $txtValue.Text = "TargetConnection"
            })
            $grpSpecialOptions.Controls.Add($rbTargetConn)
            
            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }
        
        # Special handling for vCenter server names or any string parameters that might use vCenter names
        if ($currentType -eq "String" -and 
            ($paramName -eq "vCenter" -or 
             $paramName -like "*vCenterServer*" -or 
             $paramName -like "*Server*" -or 
             $paramName -like "*vCenter*" -or 
             $paramName -like "*Host*")) {
            
            # Add a section label
            $lblServerSection = New-Object System.Windows.Forms.Label
            $lblServerSection.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblServerSection.Size = New-Object System.Drawing.Size(380, 20)
            $lblServerSection.Text = "vCenter Server Options:"
            $lblServerSection.Font = New-Object System.Drawing.Font($lblServerSection.Font, [System.Drawing.FontStyle]::Bold)
            $grpSpecialOptions.Controls.Add($lblServerSection)
            $yPos += 22
            
            # Source vCenter Server option
            $rbSourceServer = New-Object System.Windows.Forms.RadioButton
            $rbSourceServer.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbSourceServer.Size = New-Object System.Drawing.Size(180, 24)  # Larger
            $rbSourceServer.Text = "Use Source vCenter"
            $rbSourceServer.Checked = ($txtValue.Text -eq "SourcevCenter" -or $txtValue.Text -eq $txtSourceServer.Text)
            $rbSourceServer.Add_Click({
                if ($txtSourceServer.Text -ne "") {
                    $txtValue.Text = $txtSourceServer.Text
                } else {
                    $txtValue.Text = "SourcevCenter"
                }
            })
            $grpSpecialOptions.Controls.Add($rbSourceServer)
            
            # Target vCenter Server option
            $rbTargetServer = New-Object System.Windows.Forms.RadioButton
            $rbTargetServer.Location = New-Object System.Drawing.Point(210, $yPos)
            $rbTargetServer.Size = New-Object System.Drawing.Size(180, 24)  # Larger
            $rbTargetServer.Text = "Use Target vCenter"
            $rbTargetServer.Checked = ($txtValue.Text -eq "TargetvCenter" -or $txtValue.Text -eq $txtTargetServer.Text)
            $rbTargetServer.Add_Click({
                if ($txtTargetServer.Text -ne "") {
                    $txtValue.Text = $txtTargetServer.Text
                } else {
                    $txtValue.Text = "TargetvCenter"
                }
            })
            $grpSpecialOptions.Controls.Add($rbTargetServer)
            
            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }
        
        # Special handling for vCenter names (for parameters that might need the friendly name)
        if ($currentType -eq "String" -and 
            ($paramName -eq "vCenterName" -or 
             $paramName -like "*ServerName*" -or
             $paramName -like "*SourceVC*" -or 
             $paramName -like "*DestVC*" -or  
             $paramName -like "*HostName*" -or 
             ($paramName -like "*Name*" -and ($paramName -like "*vCenter*" -or $paramName -like "*Server*" -or $paramName -like "*Host*")))) {
            
            # Add a section label
            $lblNameSection = New-Object System.Windows.Forms.Label
            $lblNameSection.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblNameSection.Size = New-Object System.Drawing.Size(380, 20)
            $lblNameSection.Text = "vCenter Name Options:"
            $lblNameSection.Font = New-Object System.Drawing.Font($lblNameSection.Font, [System.Drawing.FontStyle]::Bold)
            $grpSpecialOptions.Controls.Add($lblNameSection)
            $yPos += 22
            
            # Source vCenter Name option
            $lblSourceName = New-Object System.Windows.Forms.Label
            $lblSourceName.Location = New-Object System.Drawing.Point(20, $yPos)
            $lblSourceName.Size = New-Object System.Drawing.Size(100, 24)
            $lblSourceName.Text = "Source Name:"
            $grpSpecialOptions.Controls.Add($lblSourceName)
            
            $btnUseSourceName = New-Object System.Windows.Forms.Button
            $btnUseSourceName.Location = New-Object System.Drawing.Point(130, $yPos)
            $btnUseSourceName.Size = New-Object System.Drawing.Size(75, 24)
            $btnUseSourceName.Text = "Use"
            $btnUseSourceName.Add_Click({
                # Extract server name without domain if possible
                $serverName = $txtSourceServer.Text -split '\.' | Select-Object -First 1
                $txtValue.Text = $serverName
            })
            $grpSpecialOptions.Controls.Add($btnUseSourceName)
            
            $yPos += $optionSpacing
            
            # Target vCenter Name option
            $lblTargetName = New-Object System.Windows.Forms.Label
            $lblTargetName.Location = New-Object System.Drawing.Point(20, $yPos)
            $lblTargetName.Size = New-Object System.Drawing.Size(100, 24)
            $lblTargetName.Text = "Target Name:"
            $grpSpecialOptions.Controls.Add($lblTargetName)
            
            $btnUseTargetName = New-Object System.Windows.Forms.Button
            $btnUseTargetName.Location = New-Object System.Drawing.Point(130, $yPos)
            $btnUseTargetName.Size = New-Object System.Drawing.Size(75, 24)
            $btnUseTargetName.Text = "Use"
            $btnUseTargetName.Add_Click({
                # Extract server name without domain if possible
                $serverName = $txtTargetServer.Text -split '\.' | Select-Object -First 1
                $txtValue.Text = $serverName
            })
            $grpSpecialOptions.Controls.Add($btnUseTargetName)
            
            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }
        
        # Special handling for LogOutputLocation and ReportOutputLocation
        if ($currentType -eq "String" -and 
            ($paramName -eq "LogOutputLocation" -or $paramName -like "*LogFile*" -or $paramName -like "*LogPath*")) {
            
            # Add a section label
            $lblLogSection = New-Object System.Windows.Forms.Label
            $lblLogSection.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblLogSection.Size = New-Object System.Drawing.Size(380, 20)
            $lblLogSection.Text = "Log Path Options:"
            $lblLogSection.Font = New-Object System.Drawing.Font($lblLogSection.Font, [System.Drawing.FontStyle]::Bold)
            $grpSpecialOptions.Controls.Add($lblLogSection)
            $yPos += 22
            
            $rbDefaultLogPath = New-Object System.Windows.Forms.RadioButton
            $rbDefaultLogPath.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbDefaultLogPath.Size = New-Object System.Drawing.Size(180, 24)  # Larger
            $rbDefaultLogPath.Text = "Use Default Log Path"
            $rbDefaultLogPath.Checked = ($txtValue.Text -eq $script:config.LogPath)
            $rbDefaultLogPath.Add_Click({
                $txtValue.Text = $script:config.LogPath
            })
            $grpSpecialOptions.Controls.Add($rbDefaultLogPath)
            
            $btnBrowseLogPath = New-Object System.Windows.Forms.Button
            $btnBrowseLogPath.Location = New-Object System.Drawing.Point(210, $yPos)
            $btnBrowseLogPath.Size = New-Object System.Drawing.Size(100, 24)
            $btnBrowseLogPath.Text = "Browse..."
            $btnBrowseLogPath.Add_Click({
                $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderBrowser.Description = "Select Log Folder"
                $folderBrowser.SelectedPath = $txtValue.Text
                
                if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $txtValue.Text = $folderBrowser.SelectedPath
                }
            })
            $grpSpecialOptions.Controls.Add($btnBrowseLogPath)
            
            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }
        
        if ($currentType -eq "String" -and 
            ($paramName -eq "ReportOutputLocation" -or $paramName -like "*ReportFile*" -or $paramName -like "*OutputFile*" -or $paramName -like "*ReportPath*")) {
            
            # Add a section label
            $lblReportSection = New-Object System.Windows.Forms.Label
            $lblReportSection.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblReportSection.Size = New-Object System.Drawing.Size(380, 20)
            $lblReportSection.Text = "Report Path Options:"
            $lblReportSection.Font = New-Object System.Drawing.Font($lblReportSection.Font, [System.Drawing.FontStyle]::Bold)
            $grpSpecialOptions.Controls.Add($lblReportSection)
            $yPos += 22
            
            $rbDefaultReportPath = New-Object System.Windows.Forms.RadioButton
            $rbDefaultReportPath.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbDefaultReportPath.Size = New-Object System.Drawing.Size(180, 24)  # Larger
            $rbDefaultReportPath.Text = "Use Default Report Path"
            $rbDefaultReportPath.Checked = ($txtValue.Text -eq $script:config.ReportsPath)
            $rbDefaultReportPath.Add_Click({
                $txtValue.Text = $script:config.ReportsPath
            })
            $grpSpecialOptions.Controls.Add($rbDefaultReportPath)
            
            $btnBrowseReportPath = New-Object System.Windows.Forms.Button
            $btnBrowseReportPath.Location = New-Object System.Drawing.Point(210, $yPos)
            $btnBrowseReportPath.Size = New-Object System.Drawing.Size(100, 24)
            $btnBrowseReportPath.Text = "Browse..."
            $btnBrowseReportPath.Add_Click({
                $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderBrowser.Description = "Select Report Folder"
                $folderBrowser.SelectedPath = $txtValue.Text
                
                if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $txtValue.Text = $folderBrowser.SelectedPath
                }
            })
            $grpSpecialOptions.Controls.Add($btnBrowseReportPath)
            
            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }
        
        # Add options for any string parameter that might be a filename or path
        if ($currentType -eq "String" -and 
            ($paramName -like "*File*" -or $paramName -like "*Path*" -or $paramName -like "*Directory*" -or $paramName -like "*Folder*")) {
            # Skip if already handled by log or report path handlers
            if ($paramName -ne "LogOutputLocation" -and 
                $paramName -ne "ReportOutputLocation" -and 
                -not ($paramName -like "*LogFile*" -or $paramName -like "*LogPath*") -and
                -not ($paramName -like "*ReportFile*" -or $paramName -like "*OutputFile*" -or $paramName -like "*ReportPath*")) {
                
                # Add a section label
                $lblFileSection = New-Object System.Windows.Forms.Label
                $lblFileSection.Location = New-Object System.Drawing.Point(10, $yPos)
                $lblFileSection.Size = New-Object System.Drawing.Size(380, 20)
                $lblFileSection.Text = "File/Folder Options:"
                $lblFileSection.Font = New-Object System.Drawing.Font($lblFileSection.Font, [System.Drawing.FontStyle]::Bold)
                $grpSpecialOptions.Controls.Add($lblFileSection)
                $yPos += 22
                
                $btnBrowseFile = New-Object System.Windows.Forms.Button
                $btnBrowseFile.Location = New-Object System.Drawing.Point(20, $yPos)
                $btnBrowseFile.Size = New-Object System.Drawing.Size(120, 28)  # Larger
                $btnBrowseFile.Text = "Browse File..."
                $btnBrowseFile.Add_Click({
                    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
                    $fileDialog.Title = "Select File"
                    $fileDialog.Filter = "All Files (*.*)|*.*"
                    
                    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $txtValue.Text = $fileDialog.FileName
                    }
                })
                $grpSpecialOptions.Controls.Add($btnBrowseFile)
                
                $btnBrowseFolder = New-Object System.Windows.Forms.Button
                $btnBrowseFolder.Location = New-Object System.Drawing.Point(150, $yPos)
                $btnBrowseFolder.Size = New-Object System.Drawing.Size(120, 28)  # Larger
                $btnBrowseFolder.Text = "Browse Folder..."
                $btnBrowseFolder.Add_Click({
                    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
                    $folderBrowser.Description = "Select Folder"
                    
                    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $txtValue.Text = $folderBrowser.SelectedPath
                    }
                })
                $grpSpecialOptions.Controls.Add($btnBrowseFolder)
                
                $yPos += $optionSpacing
                $hasSpecialOptions = $true
            }
        }
        
        # Special handling for Boolean type
        if ($currentType -eq "Boolean") {
            # Add a section label
            $lblBoolSection = New-Object System.Windows.Forms.Label
            $lblBoolSection.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblBoolSection.Size = New-Object System.Drawing.Size(380, 20)
            $lblBoolSection.Text = "Boolean Options:"
            $lblBoolSection.Font = New-Object System.Drawing.Font($lblBoolSection.Font, [System.Drawing.FontStyle]::Bold)
            $grpSpecialOptions.Controls.Add($lblBoolSection)
            $yPos += 22
            
            $rbTrue = New-Object System.Windows.Forms.RadioButton
            $rbTrue.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbTrue.Size = New-Object System.Drawing.Size(100, 24)  # Larger
            $rbTrue.Text = "True"
            $rbTrue.Checked = ($txtValue.Text -eq "True" -or $txtValue.Text -eq "$true")
            $rbTrue.Add_Click({
                $txtValue.Text = "$true"
            })
            $grpSpecialOptions.Controls.Add($rbTrue)
            
            $rbFalse = New-Object System.Windows.Forms.RadioButton
            $rbFalse.Location = New-Object System.Drawing.Point(130, $yPos)
            $rbFalse.Size = New-Object System.Drawing.Size(100, 24)  # Larger
            $rbFalse.Text = "False"
            $rbFalse.Checked = ($txtValue.Text -eq "False" -or $txtValue.Text -eq "$false")
            $rbFalse.Add_Click({
                $txtValue.Text = "$false"
            })
            $grpSpecialOptions.Controls.Add($rbFalse)
            
            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }
        
        # Adjust group box height based on content
        if ($hasSpecialOptions) {
            $grpSpecialOptions.Height = [int]$yPos + 45  # Add some padding at the bottom
            $grpSpecialOptions.Visible = $true
        } else {
            $grpSpecialOptions.Visible = $false
        }
        
        # Adjust form height
        if ($grpSpecialOptions.Visible) {
            $formHeight = $grpSpecialOptions.Location.Y + $grpSpecialOptions.Height + 120
            # Cap the maximum height to prevent it from getting too large
            if ($formHeight > 600) { $formHeight = 600 }
        } else {
            $formHeight = $grpSpecialOptions.Location.Y + 150
        }
        $form.ClientSize = New-Object System.Drawing.Size($form.ClientSize.Width, $formHeight)
        
        # Reposition OK and Cancel buttons
        $buttonY = $form.ClientSize.Height - 40
        $btnOK.Location = New-Object System.Drawing.Point(145, $buttonY)
        $btnCancel.Location = New-Object System.Drawing.Point(245, $buttonY)
    }
    
    # Initialize special options
    UpdateSpecialOptions
    
    # Show the form
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Update parameter value and type
        $selectedItem.SubItems[1].Text = $txtValue.Text
        $selectedItem.SubItems[2].Text = $cboType.SelectedItem.ToString()
        
        # Update the script's parameters
        $selectedIndex = $lvScripts.SelectedIndices[0]
        $paramIndex = $lvParameters.Items.IndexOf($selectedItem)
        $script:Scripts[$selectedIndex].Parameters[$paramIndex].Value = $txtValue.Text
        $script:Scripts[$selectedIndex].Parameters[$paramIndex].Type = $cboType.SelectedItem.ToString()
    }
}

function Validate-OutputPath {
    param(
        [string]$Path,
        [switch]$CreateIfNotExists
    )

    try {
        # Check if path is null or empty
        if ([string]::IsNullOrWhiteSpace($Path)) {
            return $false
        }

        # Resolve full path (handles relative paths)
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        # Check if path is rooted (valid path structure)
        if (-not [System.IO.Path]::IsPathRooted($fullPath)) {
            Write-Log "Invalid path: $Path" -Level "ERROR"
            return $false
        }

        # If CreateIfNotExists is set, attempt to create directory
        if ($CreateIfNotExists) {
            if (-not (Test-Path $fullPath)) {
                try {
                    New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                    Write-Log "Created directory: $fullPath" -Level "INFO"
                } catch {
                    Write-Log "Could not create directory: $fullPath. Error: $_" -Level "ERROR"
                    return $false
                }
            }
        } else {
            # Just check if directory exists
            if (-not (Test-Path $fullPath -PathType Container)) {
                Write-Log "Path does not exist: $Path" -Level "WARNING"
                return $false
            }
        }

        return $true
    } catch {
        Write-Log "Error validating path: $_" -Level "ERROR"
        return $false
    }
}


function Remove-ScriptParameter {
    try {
        if ($lvScripts.SelectedItems.Count -eq 0 -or $lvParameters.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script and parameter to remove", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        $selectedScriptIndex = $lvScripts.SelectedIndices[0]
        $selectedOrder = [int]$lvScripts.Items[$selectedScriptIndex].Text
        $selectedScript = $script:Scripts | Where-Object { $_.Order -eq $selectedOrder }
        
        $selectedParamIndex = $lvParameters.SelectedIndices[0]
        $paramName = $lvParameters.SelectedItems[0].Text
        
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to remove parameter '$($paramName)'?", "Confirm Removal", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Remove from ListView
            $lvParameters.Items.RemoveAt($selectedParamIndex)
            
            # Remove from script parameters
            $selectedScript.Parameters = $selectedScript.Parameters | Where-Object { $_.Name -ne $paramName }
            
            Write-Log "Removed parameter '$($paramName)' from script: $($selectedScript.Name)"
        }
    }
    catch {
        Write-Log "Error removing parameter: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error removing parameter: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

#endregion

#region Script Execution Functions

function Run-AllScripts {
    try {
        if ($script:Scripts.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No scripts to run", "No Scripts", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Confirm execution
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to run all enabled scripts?", "Confirm Execution", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Get enabled scripts
            $enabledScripts = $script:Scripts | Where-Object { $_.Enabled -eq $true } | Sort-Object -Property Order
            
            if ($enabledScripts.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("No enabled scripts to run", "No Enabled Scripts", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }
            
            # Update UI
            Update-UIState -State "Running"
            $txtExecutionOutput.Clear()
            $progressOverall.Maximum = $enabledScripts.Count
            $progressOverall.Value = 0
            $progressCurrentScript.Value = 0
            
            Write-Log "Starting execution of $($enabledScripts.Count) scripts" -Level "INFO"
            
            # Start execution
            Start-ScriptExecution -Scripts $enabledScripts
        }
    }
    catch {
        Write-Log "Error running scripts: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error running scripts: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Update-UIState -State "Error"
    }
}

function Run-SelectedScript {
    try {
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to run", "No Script Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        $selectedIndex = $lvScripts.SelectedIndices[0]
        $selectedOrder = [int]$lvScripts.Items[$selectedIndex].Text
        $script = $script:Scripts | Where-Object { $_.Order -eq $selectedOrder }
        
        if (-not $script.Enabled) {
            $result = [System.Windows.Forms.MessageBox]::Show("The selected script is disabled. Do you want to run it anyway?", "Script Disabled", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return
            }
        }
        
        # Update UI
        Update-UIState -State "Running"
        $txtExecutionOutput.Clear()
        $progressOverall.Maximum = 1
        $progressOverall.Value = 0
        $progressCurrentScript.Value = 0
        
        Write-Log "Starting execution of script: $($script.Name)" -Level "INFO"
        
        # Start execution
        Start-ScriptExecution -Scripts @($script)
    }
    catch {
        Write-Log "Error running selected script: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error running selected script: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Update-UIState -State "Error"
    }
}

function Start-ScriptExecution {
    param (
        [array]$Scripts
    )
    
    # Create a background runspace
    $script:runspace = [runspacefactory]::CreateRunspace()
    $script:runspace.ApartmentState = "STA"
    $script:runspace.ThreadOptions = "ReuseThread"
    $script:runspace.Open()
    
    # Create a synchronization hashtable to handle UI updates
    $syncHash = [hashtable]::Synchronized(@{})
    # Remove $host reference - not needed and can cause issues
    $syncHash.ProgressOverall = $progressOverall
    $syncHash.ProgressCurrentScript = $progressCurrentScript
    $syncHash.TxtExecutionOutput = $txtExecutionOutput
    $syncHash.StatusStripLabel = $statusStripLabel
    $syncHash.Form = $form
    $syncHash.BtnRunAll = $btnRunAll
    $syncHash.BtnRunSelected = $btnRunSelected
    $syncHash.BtnStopExecution = $btnStopExecution
    
    # Add variables to runspace
    $script:runspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
    $script:runspace.SessionStateProxy.SetVariable("scripts", $Scripts)
    $script:runspace.SessionStateProxy.SetVariable("vCenterConfig", $script:vCenterConfig)
    $script:runspace.SessionStateProxy.SetVariable("executionSettings", $script:executionSettings)
    $script:runspace.SessionStateProxy.SetVariable("logPath", $script:config.LogPath)
    $script:runspace.SessionStateProxy.SetVariable("reportsPath", $script:config.ReportsPath)
    
    # Create PowerShell instance
    $script:powershell = [powershell]::Create()
    $script:powershell.Runspace = $script:runspace
    
    # Add script to execute
    $script:powershell.AddScript({
        # Function to safely update UI from background thread
        function Update-UI {
            param(
                [Parameter(Mandatory=$true)]
                [ScriptBlock]$Code
            )
            
            try {
                # Check if we need to use Invoke or can run directly
                if ($syncHash.Form.InvokeRequired) {
                    $syncHash.Form.Invoke([Action]{
                        Invoke-Command -ScriptBlock $Code
                    })
                } else {
                    Invoke-Command -ScriptBlock $Code
                }
            }
            catch {
                # If UI update fails, at least write to the log
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $errorMsg = "[$timestamp] [ERROR] UI update failed: $($_.Exception.Message)"
                Add-Content -Path $logPath -Value $errorMsg
            }
        }
        
        # Function to write to log file and update UI
        function Write-ExecutionLog {
            param (
                [string]$Message,
                [string]$Level = "INFO"
            )
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [$Level] $Message"
            
            # Write to log file
            try {
                Add-Content -Path $logPath -Value $logEntry -ErrorAction Stop
            }
            catch {
                # If log file write fails, continue execution
                $errorMsg = "Failed to write to log file: $($_.Exception.Message)"
                # Don't try to log this error to avoid recursion
            }
            
            # Update UI safely
            Update-UI {
                if ($null -ne $syncHash.TxtExecutionOutput) {
                    $syncHash.TxtExecutionOutput.AppendText("$logEntry`r`n")
                    $syncHash.TxtExecutionOutput.ScrollToCaret()
                }
                
                if ($null -ne $syncHash.StatusStripLabel) {
                    $syncHash.StatusStripLabel.Text = $Message
                }
            }
        }
        
        # Set global variable to track if script should stop
        $global:StopScript = $false
        
        # Function to create credentials
        function Get-VCenterCredential {
            param (
                [string]$Type
            )
            
            if ($vCenterConfig.UseCurrentCredentials) {
                return $null  # Will use current Windows credentials
            }
            
            if ($Type -eq "Source") {
                $username = $vCenterConfig.SourceUsername
                $password = $vCenterConfig.SourcePassword
            } else {
                $username = $vCenterConfig.TargetUsername
                $password = $vCenterConfig.TargetPassword
            }
            
            if ([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($password)) {
                return $null
            }
            
            $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
            return New-Object System.Management.Automation.PSCredential ($username, $secPassword)
        }
        
        # Function to write logs in a format the scripts can use
        function Write-Log {
            param (
                [string]$Message,
                [string]$Severity = "Info"
            )
            
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [$Severity] $Message"
            
            try {
                Add-Content -Path $logPath -Value $logEntry -ErrorAction Stop
            }
            catch {
                # If log file write fails, continue execution
            }
            
            # Also write to the execution log
            Write-ExecutionLog $Message -Level $Severity
        }
        
        # Connect to vCenter servers
        $sourceServer = $null
        $targetServer = $null
        
        try {
            Write-ExecutionLog "Connecting to source vCenter: $($vCenterConfig.SourcevCenter)"
            
            # Check if PowerCLI is available
            if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
                Write-ExecutionLog "VMware PowerCLI module is not installed. Cannot connect to vCenter." -Level "ERROR"
                
                # Update UI
                Update-UI {
                    $syncHash.BtnRunAll.Enabled = $true
                    $syncHash.BtnRunSelected.Enabled = $true
                    $syncHash.BtnStopExecution.Enabled = $false
                }
                
                return
            }
            
            # Import the module
            Write-ExecutionLog "Importing VMware.PowerCLI module..."
            #Import-Module VMware.PowerCLI -ErrorAction Stop
            
            # Set PowerCLI configuration to ignore certificate warnings
            Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            
            if ($vCenterConfig.UseCurrentCredentials) {
                $sourceServer = Connect-VIServer -Server $vCenterConfig.SourcevCenter -ErrorAction Stop
            } else {
                $sourceCredential = Get-VCenterCredential -Type "Source"
                if ($sourceCredential) {
                    $sourceServer = Connect-VIServer -Server $vCenterConfig.SourcevCenter -Credential $sourceCredential -ErrorAction Stop
                } else {
                    $sourceServer = Connect-VIServer -Server $vCenterConfig.SourcevCenter -ErrorAction Stop
                }
            }
            
            Write-ExecutionLog "Connecting to target vCenter: $($vCenterConfig.TargetvCenter)"
            
            if ($vCenterConfig.UseCurrentCredentials) {
                $targetServer = Connect-VIServer -Server $vCenterConfig.TargetvCenter -ErrorAction Stop
            } else {
                $targetCredential = Get-VCenterCredential -Type "Target"
                if ($targetCredential) {
                    $targetServer = Connect-VIServer -Server $vCenterConfig.TargetvCenter -Credential $targetCredential -ErrorAction Stop
                } else {
                    $targetServer = Connect-VIServer -Server $vCenterConfig.TargetvCenter -ErrorAction Stop
                }
            }
            
            Write-ExecutionLog "Successfully connected to both vCenter servers"
        }
        catch {
            Write-ExecutionLog "Failed to connect to vCenter servers: $($_)" -Level "ERROR"
            
            # Get detailed error information
            $errorMessage = $_.Exception.Message
            $errorType = $_.Exception.GetType().FullName
            $stackTrace = $_.ScriptStackTrace
            
            Write-ExecutionLog "Error Type: $errorType" -Level "ERROR"
            Write-ExecutionLog "Stack Trace: $stackTrace" -Level "ERROR"
            
            # Update UI
            Update-UI {
                $syncHash.BtnRunAll.Enabled = $true
                $syncHash.BtnRunSelected.Enabled = $true
                $syncHash.BtnStopExecution.Enabled = $false
            }
            
            return
        }
        
        # Execute scripts
        $totalScripts = $scripts.Count
        $currentScript = 0
        $sourceCredential = Get-VCenterCredential -Type "Source"
        $targetCredential = Get-VCenterCredential -Type "Target"
        
        foreach ($script in $scripts) {
            # Check if execution should stop
            if ($global:StopScript) {
                Write-ExecutionLog "Execution stopped by user" -Level "WARNING"
                break
            }
            
            $currentScript++
            
            # Update progress
            Update-UI {
                $syncHash.ProgressOverall.Value = [Math]::Min(100, [Math]::Round(($currentScript / $totalScripts) * 100))
                $syncHash.ProgressCurrentScript.Value = 0
            }
            
            Write-ExecutionLog "Executing script $($currentScript) of $($totalScripts): $($script.Name)"
            
            try {
                # Build parameter hashtable
                $parameters = @{}
                
                foreach ($param in $script.Parameters) {
                    $value = $param.Value
                    
                    # Handle special parameter values
                    if ($param.Type -eq "PSCredential") {
                        if ($value -eq "SourceCredential") {
                            $value = $sourceCredential
                        } elseif ($value -eq "TargetCredential") {
                            $value = $targetCredential
                        }
                    } elseif ($param.Type -eq "Int32" -or $param.Type -eq "Double") {
                        $value = [convert]::ChangeType($value, [type]$param.Type)
                    } elseif ($param.Type -eq "Boolean") {
                        $value = [System.Convert]::ToBoolean($value)
                    } elseif ($param.Type -eq "DateTime") {
                        $value = [datetime]$value
                    } elseif ($param.Name -eq "vCenter" -and $value -eq "SourcevCenter") {
                        $value = $vCenterConfig.SourcevCenter
                    } elseif ($param.Name -eq "vCenter" -and $value -eq "TargetvCenter") {
                        $value = $vCenterConfig.TargetvCenter
                    } elseif ($param.Name -eq "SourcevCenter" -or ($param.Name -eq "vCenter" -and $value -eq "SourcevCenter")) {
                        $value = $vCenterConfig.SourcevCenter
                    } elseif ($param.Name -eq "TargetvCenter") {
                        $value = $vCenterConfig.TargetvCenter
                    } elseif ($param.Name -eq "vCenterName" -and $value -eq "SourcevCenter") {
                        $value = "Source vCenter"
                    } elseif ($param.Name -eq "vCenterName" -and $value -eq "TargetvCenter") {
                        $value = "Target vCenter"
                    } elseif ($param.Name -eq "vCenterConnection" -and $value -eq "SourceConnection") {
                        $value = $sourceServer
                    } elseif ($param.Name -eq "vCenterConnection" -and $value -eq "TargetConnection") {
                        $value = $targetServer
                    } elseif ($param.Name -eq "LogOutputLocation") {
                        $value = $logPath
                    } elseif ($param.Name -eq "ReportOutputLocation") {
                        # Ensure the reports directory exists
                        if (-not (Test-Path $reportsPath)) {
                            New-Item -Path $reportsPath -ItemType Directory -Force | Out-Null
                        }
                        $value = $reportsPath
                    }
                    
                    $parameters[$param.Name] = $value
                }
                
                # Execute the script
                Write-ExecutionLog "Loading script content from: $($script.Path)"
                $scriptContent = Get-Content -Path $script.Path -Raw -ErrorAction Stop
                $scriptBlock = [scriptblock]::Create($scriptContent)
                
                Write-ExecutionLog "Starting script job with parameters: $($parameters.Keys -join ', ')"
                $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $parameters
                
                # Monitor job progress
                $timeout = $executionSettings.Timeout
                $elapsed = 0
                $interval = 1  # Check every second
                
                while ($job.State -eq "Running" -and $elapsed -lt $timeout -and -not $global:StopScript) {
                    Start-Sleep -Seconds $interval
                    $elapsed += $interval
                    
                    # Update progress
                    $progressPercent = [math]::Min(100, [math]::Round(($elapsed / $timeout) * 100))
                    Update-UI {
                        $syncHash.ProgressCurrentScript.Value = $progressPercent
                    }
                    
                    # Get job output
                    $output = Receive-Job -Job $job
                    if ($output) {
                        foreach ($line in $output) {
                            Write-ExecutionLog "  $($line)"
                        }
                    }
                }
                
                # Check job status
                if ($job.State -eq "Running") {
                    Stop-Job -Job $job
                    Write-ExecutionLog "Script execution timed out after $($timeout) seconds" -Level "WARNING"
                    
                    if ($executionSettings.StopOnError) {
                        Write-ExecutionLog "Stopping execution due to timeout" -Level "ERROR"
                        break
                    }
                } elseif ($global:StopScript) {
                    Stop-Job -Job $job
                    Write-ExecutionLog "Script execution stopped by user" -Level "WARNING"
                    break
                } else {
                    # Get final output
                    $output = Receive-Job -Job $job
                    if ($output) {
                        foreach ($line in $output) {
                            Write-ExecutionLog "  $($line)"
                        }
                    }
                    
                    if ($job.State -eq "Failed") {
                        # Get detailed error information
                        $errorDetails = $null
                        
                        # Try to get error details from the job
                        if ($job.ChildJobs[0].Error) {
                            $errorDetails = $job.ChildJobs[0].Error | Out-String
                        }
                        
                        # If we have error records, get more details
                        if ($job.ChildJobs[0].JobStateInfo.Reason) {
                            $errorDetails += "`nReason: " + ($job.ChildJobs[0].JobStateInfo.Reason | Out-String)
                        }
                        
                        # Get error record details if available
                        try {
                            $errorRecord = $job.ChildJobs[0].Error[0]
                            if ($errorRecord) {
                                $errorDetails += "`nException Type: $($errorRecord.Exception.GetType().FullName)"
                                $errorDetails += "`nException Message: $($errorRecord.Exception.Message)"
                                
                                if ($errorRecord.InvocationInfo) {
                                    $errorDetails += "`nPosition: $($errorRecord.InvocationInfo.PositionMessage)"
                                    $errorDetails += "`nLine Number: $($errorRecord.InvocationInfo.ScriptLineNumber)"
                                    $errorDetails += "`nOffset: $($errorRecord.InvocationInfo.OffsetInLine)"
                                    $errorDetails += "`nLine: $($errorRecord.InvocationInfo.Line)"
                                    $errorDetails += "`nScript Name: $($errorRecord.InvocationInfo.ScriptName)"
                                }
                                
                                # Get the inner exception details if available
                                if ($errorRecord.Exception.InnerException) {
                                    $errorDetails += "`nInner Exception: $($errorRecord.Exception.InnerException.Message)"
                                }
                                
                                # Get the stack trace
                                if ($errorRecord.Exception.StackTrace) {
                                    $errorDetails += "`nStack Trace: $($errorRecord.Exception.StackTrace)"
                                }
                            }
                        }
                        catch {
                            $errorDetails += "`nError extracting detailed error information: $($_)"
                        }
                        
                        # Log the detailed error
                        Write-ExecutionLog "Script execution failed with the following error:" -Level "ERROR"
                        foreach ($line in ($errorDetails -split "`n")) {
                            if (-not [string]::IsNullOrWhiteSpace($line)) {
                                Write-ExecutionLog "  $line" -Level "ERROR"
                            }
                        }
                        
                        if ($executionSettings.StopOnError) {
                            Write-ExecutionLog "Stopping execution due to error" -Level "ERROR"
                            break
                        }
                    } else {
                        Write-ExecutionLog "Script execution completed successfully"
                        
                        # Set progress to 100%
                        Update-UI {
                            $syncHash.ProgressCurrentScript.Value = 100
                        }
                    }
                }
                
                # Clean up job
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-ExecutionLog "Error executing script: $($_)" -Level "ERROR"
                Write-ExecutionLog "Error Type: $($_.Exception.GetType().FullName)" -Level "ERROR"
                Write-ExecutionLog "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
                
                if ($executionSettings.StopOnError) {
                    Write-ExecutionLog "Stopping execution due to error" -Level "ERROR"
                    break
                }
            }
        }
        
        # Disconnect from vCenter servers
        try {
            Write-ExecutionLog "Disconnecting from vCenter servers"
            Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            Write-ExecutionLog "Error disconnecting from vCenter servers: $($_)" -Level "WARNING"
        }
        
        # Update UI
        Update-UI {
            $syncHash.BtnRunAll.Enabled = $true
            $syncHash.BtnRunSelected.Enabled = $true
            $syncHash.BtnStopExecution.Enabled = $false
        }
        
        Write-ExecutionLog "Execution completed"
    })
    
    # Start asynchronous execution
    $script:handle = $script:powershell.BeginInvoke()
}

function Stop-ScriptExecution {
    try {
        if ($script:powershell -and $script:handle) {
            Write-Log "Stopping script execution" -Level "WARNING"
            
            # Stop the PowerShell instance
            $script:powershell.Stop()
            
            # Clean up
            $script:powershell.Dispose()
            $script:runspace.Dispose()
            
            # Update UI
            Update-UIState -State "Stopped"
            
            $statusStripLabel.Text = "Execution stopped by user"
            $txtExecutionOutput.AppendText("`r`n[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [WARNING] Execution stopped by user`r`n")
            $txtExecutionOutput.ScrollToCaret()
        }
    }
    catch {
        Write-Log "Error stopping script execution: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error stopping script execution: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

#endregion

#region Form Settings and Log Management Functions

function Load-FormSettings {
    try {
        # Load connection settings
        $txtSourceServer.Text = $script:vCenterConfig.SourcevCenter
        $txtSourceUsername.Text = $script:vCenterConfig.SourceUsername
        $txtSourcePassword.Text = $script:vCenterConfig.SourcePassword
        $txtTargetServer.Text = $script:vCenterConfig.TargetvCenter
        $txtTargetUsername.Text = $script:vCenterConfig.TargetUsername
        $txtTargetPassword.Text = $script:vCenterConfig.TargetPassword
        
        # Set the checkbox value
        $chkUseCurrentCredentials.Checked = $script:vCenterConfig.UseCurrentCredentials
        
        # Manually update the UI based on checkbox state
        if ($chkUseCurrentCredentials.Checked) {
            $txtSourceUsername.Enabled = $false
            $txtSourcePassword.Enabled = $false
            $txtTargetUsername.Enabled = $false
            $txtTargetPassword.Enabled = $false
        } else {
            $txtSourceUsername.Enabled = $true
            $txtSourcePassword.Enabled = $true
            $txtTargetUsername.Enabled = $true
            $txtTargetPassword.Enabled = $true
        }
        
        # Load execution settings
        $chkStopOnError.Checked = $script:executionSettings.StopOnError
        $chkSkipConfirmation.Checked = $script:executionSettings.SkipConfirmation
        $numTimeout.Value = $script:executionSettings.Timeout
        $numMaxJobs.Value = $script:executionSettings.MaxConcurrentJobs
    }
    catch {
        Write-Log "Error loading form settings: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error loading form settings: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Refresh-Logs {
    try {
        # Clear the logs text box first
        if ($null -ne $logTextBox) {  # Use the correct variable name from your designer
            $logTextBox.Clear()
        } else {
            Write-Log "Error: logTextBox control is null" -Level "Error"
            return
        }
        
        # Check if log path is defined and file exists
        if ([string]::IsNullOrEmpty($script:config.LogPath)) {
            $logTextBox.AppendText("Log path is not defined in configuration.`r`n")
            Write-Log "Error: Log path is not defined in configuration" -Level "Error"
            return
        }
        
        if (Test-Path $script:config.LogPath) {
            # Get the log content with error handling
            try {
                $logEntries = Get-Content -Path $script:config.LogPath -Tail 100 -ErrorAction Stop
                
                if ($null -eq $logEntries -or $logEntries.Count -eq 0) {
                    $logTextBox.AppendText("Log file exists but is empty.`r`n")
                } else {
                    foreach ($entry in $logEntries) {
                        $logTextBox.AppendText("$($entry)`r`n")
                    }
                }
                
                # Scroll to the end
                $logTextBox.SelectionStart = $logTextBox.Text.Length
                $logTextBox.ScrollToCaret()
                
                $statusStripLabel.Text = "Logs refreshed successfully"
            }
            catch {
                $logTextBox.AppendText("Error reading log file: $($_.Exception.Message)`r`n")
                Write-Log "Error reading log file: $($_.Exception.Message)" -Level "Error"
            }
        } else {
            $logTextBox.AppendText("Log file not found at $($script:config.LogPath)`r`n")
            Write-Log "Log file not found at $($script:config.LogPath)" -Level "Warning"
        }
    }
    catch {
        # Handle any other errors
        $errorMessage = "Error refreshing logs: $($_.Exception.Message)"
        Write-Log $errorMessage -Level "Error"
        
        # Try to show error in UI if possible
        try {
            [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
        catch {
            # If even showing the error fails, write to console
            Write-Host "Critical error in Refresh-Logs: $errorMessage" -ForegroundColor Red
        }
    }
}
function Clear-Logs {
    try {
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to clear the log file?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Clear-Content -Path $script:config.LogPath -ErrorAction Stop
            $logTextBox.Clear()  # Use correct variable name
            $logTextBox.AppendText("Log file cleared at $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))`r`n")
            Write-Log "Log file cleared by user"
        }
    }
    catch {
        Write-Log "Error clearing logs: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error clearing logs: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Export-Logs {
    try {
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "Log files (*.log)|*.log|Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $saveFileDialog.Title = "Export Logs"
        $saveFileDialog.FileName = "vCenterMigration_$([DateTime]::Now.ToString('yyyyMMdd_HHmmss')).log"
        
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Copy-Item -Path $script:config.LogPath -Destination $saveFileDialog.FileName -ErrorAction Stop
            $statusStripLabel.Text = "Logs exported to $($saveFileDialog.FileName)"
            Write-Log "Logs exported to $($saveFileDialog.FileName)"
        }
    }
    catch {
        Write-Log "Error exporting logs: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error exporting logs: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Save-AllSettings {
    try {
        # Save connection settings
        $script:vCenterConfig.SourcevCenter = $txtSourceServer.Text
        $script:vCenterConfig.SourceUsername = $txtSourceUsername.Text
        $script:vCenterConfig.SourcePassword = $txtSourcePassword.Text
        $script:vCenterConfig.TargetvCenter = $txtTargetServer.Text
        $script:vCenterConfig.TargetUsername = $txtTargetUsername.Text
        $script:vCenterConfig.TargetPassword = $txtTargetPassword.Text
        $script:vCenterConfig.UseCurrentCredentials = $chkUseCurrentCredentials.Checked
        
        # Save execution settings
        $script:executionSettings.StopOnError = $chkStopOnError.Checked
        $script:executionSettings.SkipConfirmation = $chkSkipConfirmation.Checked
        $script:executionSettings.Timeout = $numTimeout.Value
        $script:executionSettings.MaxConcurrentJobs = $numMaxJobs.Value
        
        # Save all settings
        $saved = Save-MigrationConfig
        if ($saved) {
            $statusStripLabel.Text = "All settings saved successfully"
            Write-Log "All settings saved successfully"
            [System.Windows.Forms.MessageBox]::Show("All settings saved successfully", "Save Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            $statusStripLabel.Text = "Failed to save settings"
            Write-Log "Failed to save settings" -Level "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Failed to save settings", "Save Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    catch {
        Write-Log "Error saving settings: $($_.Exception.Message)" -Level "Error"
        [System.Windows.Forms.MessageBox]::Show("Error saving settings: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Show-Help {
    $helpText = @"
vCenter Migration Workflow Manager Help

This tool helps you manage and execute PowerCLI scripts for vCenter migration.

Key Features:
- Connect to source and target vCenter servers
- Manage a collection of migration scripts
- Configure script parameters
- Execute scripts in sequence
- Monitor execution progress
- View and export logs

For more information, please contact your administrator.
"@
    
    [System.Windows.Forms.MessageBox]::Show($helpText, "Help", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Check-PowerCLI {
    try {
        Write-Log "Checking if VMware PowerCLI is available..."
        
        # Check if module is available without loading it
        $moduleAvailable = Get-Module -Name VMware.PowerCLI -ListAvailable
        
        if ($null -eq $moduleAvailable) {
            Write-Log "VMware PowerCLI module is not installed." -Level "Warning"
            $message = "VMware PowerCLI module is not installed. This tool requires PowerCLI for vCenter operations.`n`n"
            $message += "Please install PowerCLI using: Install-Module -Name VMware.PowerCLI -Scope CurrentUser"
            
            [System.Windows.Forms.MessageBox]::Show($message, "PowerCLI Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return $false
        }
        
        Write-Log "VMware PowerCLI module is installed."
        return $true
    }
    catch {
        Write-Log "Error checking PowerCLI: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Add to AI_Gen_Workflow_Wrapper.ps1
function Register-EventHandlers {
    Write-Log "Registering event handlers" -Level "INFO"
    
    # Add Click handlers for Connection tab
    $mainForm.chkUseCurrentCredentials.Add_CheckedChanged({
        $mainForm.txtSourceUsername.Enabled = -not $mainForm.chkUseCurrentCredentials.Checked
        $mainForm.txtSourcePassword.Enabled = -not $mainForm.chkUseCurrentCredentials.Checked
        $mainForm.txtTargetUsername.Enabled = -not $mainForm.chkUseCurrentCredentials.Checked
        $mainForm.txtTargetPassword.Enabled = -not $mainForm.chkUseCurrentCredentials.Checked
    })
    
    $mainForm.btnBrowse.Add_Click({ Browse-ScriptFile })
    $mainForm.btnSaveAll.Add_Click({ Save-AllSettings })
    $mainForm.btnExit.Add_Click({ $mainForm.Close() })
    $mainForm.btnHelp.Add_Click({ Show-Help })
    
    # Scripts tab event handlers
    $mainForm.lvScripts.Add_SelectedIndexChanged({ Load-ScriptDetails })
    
    # We're only adding handlers that aren't already defined in the designer
    # The designer-defined handlers use the pattern: $element.add_Event($function_name)
    
    Write-Log "Event handlers registered successfully" -Level "INFO"
}

function Initialize-ListViews {
    Write-Log "Initializing ListView controls" -Level "INFO"
    
    # Initialize Scripts ListView columns
    $mainForm.lvScripts.Columns.Clear()
    $mainForm.lvScripts.Columns.Add("Order", 50) | Out-Null
    $mainForm.lvScripts.Columns.Add("Script", 200) | Out-Null
    $mainForm.lvScripts.Columns.Add("Enabled", 80) | Out-Null
    
    # Initialize Parameters ListView columns
    $mainForm.lvParameters.Columns.Clear()
    $mainForm.lvParameters.Columns.Add("Name", 120) | Out-Null
    $mainForm.lvParameters.Columns.Add("Value", 150) | Out-Null
    $mainForm.lvParameters.Columns.Add("Type", 100) | Out-Null
    
    Write-Log "ListView columns initialized successfully" -Level "INFO"
}
#endregion
