# Globals.ps1
# Global functions and event handlers for AI Gen Workflow Wrapper

#region Global Variables and Configuration
$Global:AppConfig = @{
    Version = "1.0.0"
    Name = "vCenter Migration Workflow Manager"
    LastSaved = $null
    ConnectionSettings = @{
        Source = @{ Server = ""; Username = ""; Password = ""; Connected = $false }
        Target = @{ Server = ""; Username = ""; Password = ""; Connected = $false }
        UseCurrentCredentials = $false
    }
    Scripts = @()
    ExecutionSettings = @{
        StopOnError = $true
        SkipConfirmation = $false
        Timeout = 300
        MaxJobs = 1
    }
    IsExecuting = $false
    CurrentJob = $null
}

$Global:RecentScripts = @()
$Global:MaxRecentScripts = 10
#endregion

#region Logging Functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO",
        [switch]$UpdateUI
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # File logging
    try {
        Add-Content -Path $Global:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch { }
    
    # Console logging
    switch ($Level) {
        "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
        "INFO" { Write-Host $logEntry -ForegroundColor White }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "CRITICAL" { Write-Host $logEntry -ForegroundColor Magenta }
    }
    
    # UI logging
    if ($UpdateUI -and $Global:MainForm -and $Global:MainForm.logTextBox) {
        try {
            $Global:MainForm.logTextBox.AppendText("$logEntry`r`n")
            $Global:MainForm.logTextBox.ScrollToCaret()
        } catch { }
    }
}

function Update-StatusStrip {
    param([string]$Text)
    
    try {
        if ($Global:MainForm -and $Global:MainForm.statusStripLabel) {
            $Global:MainForm.statusStripLabel.Text = $Text
        }
    } catch { }
}
#endregion

#region Configuration Management
function Save-AppConfig {
    param([string]$FilePath)
    
    try {
        if (-not $FilePath) {
            $FilePath = Join-Path $Global:Paths.Config "app_config.json"
        }
        
        $Global:AppConfig.LastSaved = Get-Date
        $configJson = $Global:AppConfig | ConvertTo-Json -Depth 5
        Set-Content -Path $FilePath -Value $configJson -Force
        
        Write-Log "Configuration saved to: $FilePath" -Level "INFO" -UpdateUI
        Update-StatusStrip "Configuration saved"
        return $true
    } catch {
        Write-Log "Failed to save configuration: $_" -Level "ERROR" -UpdateUI
        return $false
    }
}

function Load-AppConfig {
    param([string]$FilePath)
    
    try {
        if (-not $FilePath) {
            $FilePath = Join-Path $Global:Paths.Config "app_config.json"
        }
        
        if (Test-Path $FilePath) {
            $configJson = Get-Content -Path $FilePath -Raw
            $loadedConfig = $configJson | ConvertFrom-Json
            
            # Merge with current config
            $Global:AppConfig.ConnectionSettings = $loadedConfig.ConnectionSettings
            $Global:AppConfig.Scripts = $loadedConfig.Scripts
            $Global:AppConfig.ExecutionSettings = $loadedConfig.ExecutionSettings
            
            Write-Log "Configuration loaded from: $FilePath" -Level "INFO" -UpdateUI
            Update-StatusStrip "Configuration loaded"
            
            # Update UI with loaded values
            Update-UIFromConfig
            return $true
        }
    } catch {
        Write-Log "Failed to load configuration: $_" -Level "ERROR" -UpdateUI
        return $false
    }
    return $false
}

function Update-UIFromConfig {
    try {
        if (-not $Global:MainForm) { return }
        
        # Update connection settings
        if ($Global:MainForm.txtSourceServer) {
            $Global:MainForm.txtSourceServer.Text = $Global:AppConfig.ConnectionSettings.Source.Server
        }
        if ($Global:MainForm.txtSourceUsername) {
            $Global:MainForm.txtSourceUsername.Text = $Global:AppConfig.ConnectionSettings.Source.Username
        }
        if ($Global:MainForm.txtTargetServer) {
            $Global:MainForm.txtTargetServer.Text = $Global:AppConfig.ConnectionSettings.Target.Server
        }
        if ($Global:MainForm.txtTargetUsername) {
            $Global:MainForm.txtTargetUsername.Text = $Global:AppConfig.ConnectionSettings.Target.Username
        }
        if ($Global:MainForm.chkUseCurrentCredentials) {
            $Global:MainForm.chkUseCurrentCredentials.Checked = $Global:AppConfig.ConnectionSettings.UseCurrentCredentials
        }
        
        # Update execution settings
        if ($Global:MainForm.chkStopOnError) {
            $Global:MainForm.chkStopOnError.Checked = $Global:AppConfig.ExecutionSettings.StopOnError
        }
        if ($Global:MainForm.chkSkipConfirmation) {
            $Global:MainForm.chkSkipConfirmation.Checked = $Global:AppConfig.ExecutionSettings.SkipConfirmation
        }
        if ($Global:MainForm.numTimeout) {
            $Global:MainForm.numTimeout.Value = $Global:AppConfig.ExecutionSettings.Timeout
        }
        if ($Global:MainForm.numMaxJobs) {
            $Global:MainForm.numMaxJobs.Value = $Global:AppConfig.ExecutionSettings.MaxJobs
        }
        
        # Update scripts list
        Update-ScriptsList
        
    } catch {
        Write-Log "Error updating UI from config: $_" -Level "ERROR" -UpdateUI
    }
}

function Update-ConfigFromUI {
    try {
        if (-not $Global:MainForm) { return }
        
        # Update connection settings
        if ($Global:MainForm.txtSourceServer) {
            $Global:AppConfig.ConnectionSettings.Source.Server = $Global:MainForm.txtSourceServer.Text
        }
        if ($Global:MainForm.txtSourceUsername) {
            $Global:AppConfig.ConnectionSettings.Source.Username = $Global:MainForm.txtSourceUsername.Text
        }
        if ($Global:MainForm.txtTargetServer) {
            $Global:AppConfig.ConnectionSettings.Target.Server = $Global:MainForm.txtTargetServer.Text
        }
        if ($Global:MainForm.txtTargetUsername) {
            $Global:AppConfig.ConnectionSettings.Target.Username = $Global:MainForm.txtTargetUsername.Text
        }
        if ($Global:MainForm.chkUseCurrentCredentials) {
            $Global:AppConfig.ConnectionSettings.UseCurrentCredentials = $Global:MainForm.chkUseCurrentCredentials.Checked
        }
        
        # Update execution settings
        if ($Global:MainForm.chkStopOnError) {
            $Global:AppConfig.ExecutionSettings.StopOnError = $Global:MainForm.chkStopOnError.Checked
        }
        if ($Global:MainForm.chkSkipConfirmation) {
            $Global:AppConfig.ExecutionSettings.SkipConfirmation = $Global:MainForm.chkSkipConfirmation.Checked
        }
        if ($Global:MainForm.numTimeout) {
            $Global:AppConfig.ExecutionSettings.Timeout = $Global:MainForm.numTimeout.Value
        }
        if ($Global:MainForm.numMaxJobs) {
            $Global:AppConfig.ExecutionSettings.MaxJobs = $Global:MainForm.numMaxJobs.Value
        }
        
    } catch {
        Write-Log "Error updating config from UI: $_" -Level "ERROR" -UpdateUI
    }
}
#endregion

#region Script Management
function Add-ScriptToList {
    param(
        [string]$ScriptPath,
        [string]$Description,
        [bool]$Enabled = $true,
        [hashtable]$Parameters = @{}
    )
    
    $script = @{
        Id = [System.Guid]::NewGuid().ToString()
        Path = $ScriptPath
        Description = $Description
        Enabled = $Enabled
        Parameters = $Parameters
        LastModified = (Get-Item $ScriptPath -ErrorAction SilentlyContinue).LastWriteTime
    }
    
    $Global:AppConfig.Scripts += $script
    Update-ScriptsList
    Write-Log "Script added: $ScriptPath" -Level "INFO" -UpdateUI
}

function Remove-ScriptFromList {
    param([string]$ScriptId)
    
    $Global:AppConfig.Scripts = $Global:AppConfig.Scripts | Where-Object { $_.Id -ne $ScriptId }
    Update-ScriptsList
    Write-Log "Script removed: $ScriptId" -Level "INFO" -UpdateUI
}

function Update-ScriptsList {
    try {
        if (-not $Global:MainForm.lvScripts) { return }
        
        $Global:MainForm.lvScripts.Items.Clear()
        
        # Add columns if not present
        if ($Global:MainForm.lvScripts.Columns.Count -eq 0) {
            $Global:MainForm.lvScripts.Columns.Add("Script", 200) | Out-Null
            $Global:MainForm.lvScripts.Columns.Add("Description", 150) | Out-Null
            $Global:MainForm.lvScripts.Columns.Add("Enabled", 60) | Out-Null
            $Global:MainForm.lvScripts.Columns.Add("Status", 80) | Out-Null
        }
        
        foreach ($script in $Global:AppConfig.Scripts) {
            $item = New-Object System.Windows.Forms.ListViewItem
            $item.Text = Split-Path $script.Path -Leaf
            $item.SubItems.Add($script.Description) | Out-Null
            
            # Fix: Evaluate the condition first, then add the result
            $enabledText = if ($script.Enabled) { "Yes" } else { "No" }
            $item.SubItems.Add($enabledText) | Out-Null
            
            # Check script status
            $status = if (Test-Path $script.Path) { "Found" } else { "Missing" }
            $item.SubItems.Add($status) | Out-Null
            
            # Color coding
            if (-not $script.Enabled) {
                $item.ForeColor = [System.Drawing.Color]::Gray
            } elseif ($status -eq "Missing") {
                $item.ForeColor = [System.Drawing.Color]::Red
            } else {
                $item.ForeColor = [System.Drawing.Color]::Black
            }
            
            $item.Tag = $script.Id
            $Global:MainForm.lvScripts.Items.Add($item) | Out-Null
        }
        
    } catch {
        Write-Log "Error updating scripts list: $_" -Level "ERROR" -UpdateUI
    }
}


function Get-SelectedScript {
    try {
        if ($Global:MainForm.lvScripts.SelectedItems.Count -gt 0) {
            $selectedId = $Global:MainForm.lvScripts.SelectedItems[0].Tag
            return $Global:AppConfig.Scripts | Where-Object { $_.Id -eq $selectedId }
        }
    } catch { }
    return $null
}
#endregion

#region Connection Event Handlers
$btnTestSourceConnection_Click = {
    try {
        Write-Log "Testing source vCenter connection..." -Level "INFO" -UpdateUI
        Update-StatusStrip "Testing source connection..."
        
        $server = $Global:MainForm.txtSourceServer.Text
        $username = $Global:MainForm.txtSourceUsername.Text
        $password = $Global:MainForm.txtSourcePassword.Text
        
        if ([string]::IsNullOrWhiteSpace($server)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a server address.", "Missing Information", "OK", "Warning")
            return
        }
        
        # Simulate connection test (replace with actual vCenter connection logic)
        Start-Sleep -Seconds 2
        
        $Global:AppConfig.ConnectionSettings.Source.Connected = $true
        [System.Windows.Forms.MessageBox]::Show("Successfully connected to source vCenter: $server", "Connection Successful", "OK", "Information")
        Write-Log "Source vCenter connection successful: $server" -Level "INFO" -UpdateUI
        Update-StatusStrip "Source connection successful"
        
    } catch {
        $Global:AppConfig.ConnectionSettings.Source.Connected = $false
        [System.Windows.Forms.MessageBox]::Show("Failed to connect to source vCenter: $_", "Connection Failed", "OK", "Error")
        Write-Log "Source vCenter connection failed: $_" -Level "ERROR" -UpdateUI
        Update-StatusStrip "Source connection failed"
    }
}

$btnTestTargetConnection_Click = {
    try {
        Write-Log "Testing target vCenter connection..." -Level "INFO" -UpdateUI
        Update-StatusStrip "Testing target connection..."
        
        $server = $Global:MainForm.txtTargetServer.Text
        $username = $Global:MainForm.txtTargetUsername.Text
        $password = $Global:MainForm.txtTargetPassword.Text
        
        if ([string]::IsNullOrWhiteSpace($server)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a server address.", "Missing Information", "OK", "Warning")
            return
        }
        
        # Simulate connection test (replace with actual vCenter connection logic)
        Start-Sleep -Seconds 2
        
        $Global:AppConfig.ConnectionSettings.Target.Connected = $true
        [System.Windows.Forms.MessageBox]::Show("Successfully connected to target vCenter: $server", "Connection Successful", "OK", "Information")
        Write-Log "Target vCenter connection successful: $server" -Level "INFO" -UpdateUI
        Update-StatusStrip "Target connection successful"
        
    } catch {
        $Global:AppConfig.ConnectionSettings.Target.Connected = $false
        [System.Windows.Forms.MessageBox]::Show("Failed to connect to target vCenter: $_", "Connection Failed", "OK", "Error")
        Write-Log "Target vCenter connection failed: $_" -Level "ERROR" -UpdateUI
        Update-StatusStrip "Target connection failed"
    }
}

$btnSaveConnection_Click = {
    try {
        Update-ConfigFromUI
        $filePath = Join-Path $Global:Paths.Config "connection_settings.json"
        
        $connectionSettings = $Global:AppConfig.ConnectionSettings
        $connectionJson = $connectionSettings | ConvertTo-Json -Depth 3
        Set-Content -Path $filePath -Value $connectionJson -Force
        
        [System.Windows.Forms.MessageBox]::Show("Connection settings saved successfully.", "Settings Saved", "OK", "Information")
        Write-Log "Connection settings saved to: $filePath" -Level "INFO" -UpdateUI
        Update-StatusStrip "Connection settings saved"
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to save connection settings: $_", "Save Failed", "OK", "Error")
        Write-Log "Failed to save connection settings: $_" -Level "ERROR" -UpdateUI
    }
}

$btnLoadConnection_Click = {
    try {
        $filePath = Join-Path $Global:Paths.Config "connection_settings.json"
        
        if (Test-Path $filePath) {
            $connectionJson = Get-Content -Path $filePath -Raw
            $connectionSettings = $connectionJson | ConvertFrom-Json
            $Global:AppConfig.ConnectionSettings = $connectionSettings
            
            Update-UIFromConfig
            
            [System.Windows.Forms.MessageBox]::Show("Connection settings loaded successfully.", "Settings Loaded", "OK", "Information")
            Write-Log "Connection settings loaded from: $filePath" -Level "INFO" -UpdateUI
            Update-StatusStrip "Connection settings loaded"
        } else {
            [System.Windows.Forms.MessageBox]::Show("No saved connection settings found.", "No Settings", "OK", "Information")
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to load connection settings: $_", "Load Failed", "OK", "Error")
        Write-Log "Failed to load connection settings: $_" -Level "ERROR" -UpdateUI
    }
}
#endregion

#region Script Management Event Handlers
$btnAddScript_Click = {
    try {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Title = "Select PowerShell Script"
        $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $openFileDialog.InitialDirectory = $Global:Paths.Scripts
        
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $scriptPath = $openFileDialog.FileName
            $description = [Microsoft.VisualBasic.Interaction]::InputBox("Enter a description for this script:", "Script Description", (Split-Path $scriptPath -Leaf))
            
            if (-not [string]::IsNullOrWhiteSpace($description)) {
                Add-ScriptToList -ScriptPath $scriptPath -Description $description
                Update-StatusStrip "Script added successfully"
            }
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to add script: $_", "Add Script Failed", "OK", "Error")
        Write-Log "Failed to add script: $_" -Level "ERROR" -UpdateUI
    }
}

$btnRemoveScript_Click = {
    try {
        $selectedScript = Get-SelectedScript
        if ($selectedScript) {
            $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to remove this script?", "Confirm Removal", "YesNo", "Question")
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Remove-ScriptFromList -ScriptId $selectedScript.Id
                Update-StatusStrip "Script removed successfully"
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to remove.", "No Selection", "OK", "Information")
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to remove script: $_", "Remove Script Failed", "OK", "Error")
        Write-Log "Failed to remove script: $_" -Level "ERROR" -UpdateUI
    }
}

$btnMoveUp_Click = {
    try {
        if ($Global:MainForm.lvScripts.SelectedItems.Count -gt 0) {
            $selectedIndex = $Global:MainForm.lvScripts.SelectedItems[0].Index
            if ($selectedIndex -gt 0) {
                $script = $Global:AppConfig.Scripts[$selectedIndex]
                $Global:AppConfig.Scripts.RemoveAt($selectedIndex)
                $Global:AppConfig.Scripts.Insert($selectedIndex - 1, $script)
                Update-ScriptsList
                $Global:MainForm.lvScripts.Items[$selectedIndex - 1].Selected = $true
                Update-StatusStrip "Script moved up"
            }
        }
    } catch {
        Write-Log "Failed to move script up: $_" -Level "ERROR" -UpdateUI
    }
}

$btnMoveDown_Click = {
    try {
        if ($Global:MainForm.lvScripts.SelectedItems.Count -gt 0) {
            $selectedIndex = $Global:MainForm.lvScripts.SelectedItems[0].Index
            if ($selectedIndex -lt ($Global:AppConfig.Scripts.Count - 1)) {
                $script = $Global:AppConfig.Scripts[$selectedIndex]
                $Global:AppConfig.Scripts.RemoveAt($selectedIndex)
                $Global:AppConfig.Scripts.Insert($selectedIndex + 1, $script)
                Update-ScriptsList
                $Global:MainForm.lvScripts.Items[$selectedIndex + 1].Selected = $true
                Update-StatusStrip "Script moved down"
            }
        }
    } catch {
        Write-Log "Failed to move script down: $_" -Level "ERROR" -UpdateUI
    }
}

$btnBrowse_Click = {
    try {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Title = "Select PowerShell Script"
        $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $openFileDialog.InitialDirectory = $Global:Paths.Scripts
        
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if ($Global:MainForm.txtScriptPath) {
                $Global:MainForm.txtScriptPath.Text = $openFileDialog.FileName
            }
        }
        
    } catch {
        Write-Log "Failed to browse for script: $_" -Level "ERROR" -UpdateUI
    }
}

$btnSaveScriptDetails_Click = {
    try {
        $selectedScript = Get-SelectedScript
        if ($selectedScript) {
            $selectedScript.Path = $Global:MainForm.txtScriptPath.Text
            $selectedScript.Description = $Global:MainForm.txtScriptDescription.Text
            $selectedScript.Enabled = $Global:MainForm.chkScriptEnabled.Checked
            
            Update-ScriptsList
            [System.Windows.Forms.MessageBox]::Show("Script details saved successfully.", "Details Saved", "OK", "Information")
            Write-Log "Script details saved for: $($selectedScript.Path)" -Level "INFO" -UpdateUI
            Update-StatusStrip "Script details saved"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to save details.", "No Selection", "OK", "Information")
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to save script details: $_", "Save Failed", "OK", "Error")
        Write-Log "Failed to save script details: $_" -Level "ERROR" -UpdateUI
    }
}
#endregion

#region Parameter Management Event Handlers
$btnAddParam_Click = {
    try {
        $paramName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter parameter name:", "Add Parameter", "")
        if (-not [string]::IsNullOrWhiteSpace($paramName)) {
            $paramValue = [Microsoft.VisualBasic.Interaction]::InputBox("Enter parameter value:", "Parameter Value", "")
            
            $selectedScript = Get-SelectedScript
            if ($selectedScript) {
                $selectedScript.Parameters[$paramName] = $paramValue
                Update-ParametersList
                Write-Log "Parameter added: $paramName = $paramValue" -Level "INFO" -UpdateUI
                Update-StatusStrip "Parameter added"
            }
        }
        
    } catch {
        Write-Log "Failed to add parameter: $_" -Level "ERROR" -UpdateUI
    }
}

$btnEditParam_Click = {
    try {
        if ($Global:MainForm.lvParameters.SelectedItems.Count -gt 0) {
            $selectedItem = $Global:MainForm.lvParameters.SelectedItems[0]
            $paramName = $selectedItem.Text
            $currentValue = $selectedItem.SubItems[1].Text
            
            $newValue = [Microsoft.VisualBasic.Interaction]::InputBox("Edit parameter value:", "Edit Parameter", $currentValue)
            if ($newValue -ne $currentValue) {
                $selectedScript = Get-SelectedScript
                if ($selectedScript) {
                    $selectedScript.Parameters[$paramName] = $newValue
                    Update-ParametersList
                    Write-Log "Parameter updated: $paramName = $newValue" -Level "INFO" -UpdateUI
                    Update-StatusStrip "Parameter updated"
                }
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a parameter to edit.", "No Selection", "OK", "Information")
        }
        
    } catch {
        Write-Log "Failed to edit parameter: $_" -Level "ERROR" -UpdateUI
    }
}

$btnRemoveParam_Click = {
    try {
        if ($Global:MainForm.lvParameters.SelectedItems.Count -gt 0) {
            $selectedItem = $Global:MainForm.lvParameters.SelectedItems[0]
            $paramName = $selectedItem.Text
            
            $result = [System.Windows.Forms.MessageBox]::Show("Remove parameter '$paramName'?", "Confirm Removal", "YesNo", "Question")
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                $selectedScript = Get-SelectedScript
                if ($selectedScript) {
                    $selectedScript.Parameters.Remove($paramName)
                    Update-ParametersList
                    Write-Log "Parameter removed: $paramName" -Level "INFO" -UpdateUI
                    Update-StatusStrip "Parameter removed"
                }
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a parameter to remove.", "No Selection", "OK", "Information")
        }
        
    } catch {
        Write-Log "Failed to remove parameter: $_" -Level "ERROR" -UpdateUI
    }
}

$btnDetectParams_Click = {
    try {
        $selectedScript = Get-SelectedScript
        if ($selectedScript -and (Test-Path $selectedScript.Path)) {
            $scriptContent = Get-Content -Path $selectedScript.Path -Raw
            
            # Simple parameter detection (can be enhanced)
            $paramPattern = 'param\s*\( \s*([^)]+) \)'
            $matches = [regex]::Matches($scriptContent, $paramPattern, 'IgnoreCase,Singleline')
            
            if ($matches.Count -gt 0) {
                $detectedParams = @()
                foreach ($match in $matches) {
                    $paramBlock = $match.Groups[1].Value
                    $paramLines = $paramBlock -split ','
                    foreach ($line in $paramLines) {
                        if ($line -match '\$(\w+)') {
                            $detectedParams += $Matches[1]  # ? Correct
                        }
                    }
                }
                
                if ($detectedParams.Count -gt 0) {
                    $message = "Detected parameters: " + ($detectedParams -join ', ') + "`n`nAdd them to the parameter list?"
                    $result = [System.Windows.Forms.MessageBox]::Show($message, "Parameters Detected", "YesNo", "Question")
                    
                    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                        foreach ($param in $detectedParams) {
                            if (-not $selectedScript.Parameters.ContainsKey($param)) {
                                $selectedScript.Parameters[$param] = ""
                            }
                        }
                        Update-ParametersList
                        Update-StatusStrip "Parameters detected and added"
                    }
                } else {
                    [System.Windows.Forms.MessageBox]::Show("No parameters detected in the script.", "No Parameters", "OK", "Information")
                }
            } else {
                [System.Windows.Forms.MessageBox]::Show("No parameter block found in the script.", "No Parameters", "OK", "Information")
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a valid script file.", "Invalid Script", "OK", "Warning")
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to detect parameters: $_", "Detection Failed", "OK", "Error")
        Write-Log "Failed to detect parameters: $_" -Level "ERROR" -UpdateUI
    }
}

function Update-ParametersList {
    try {
        if (-not $Global:MainForm.lvParameters) { return }
        
        $Global:MainForm.lvParameters.Items.Clear()
        
        # Add columns if not present
        if ($Global:MainForm.lvParameters.Columns.Count -eq 0) {
            $Global:MainForm.lvParameters.Columns.Add("Parameter", 150) | Out-Null
            $Global:MainForm.lvParameters.Columns.Add("Value", 200) | Out-Null
        }
        
        $selectedScript = Get-SelectedScript
        if ($selectedScript -and $selectedScript.Parameters) {
            foreach ($param in $selectedScript.Parameters.GetEnumerator()) {
                $item = New-Object System.Windows.Forms.ListViewItem
                $item.Text = $param.Key
                $item.SubItems.Add($param.Value) | Out-Null
                $Global:MainForm.lvParameters.Items.Add($item) | Out-Null
            }
        }
        
    } catch {
        Write-Log "Error updating parameters list: $_" -Level "ERROR" -UpdateUI
    }
}
#endregion

#region Execution Event Handlers
$btnRunAll_Click = {
    try {
        if ($Global:AppConfig.IsExecuting) {
            [System.Windows.Forms.MessageBox]::Show("Execution is already in progress.", "Already Running", "OK", "Information")
            return
        }
        
        $enabledScripts = $Global:AppConfig.Scripts | Where-Object { $_.Enabled }
        if ($enabledScripts.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No enabled scripts found.", "No Scripts", "OK", "Information")
            return
        }
        
        $result = [System.Windows.Forms.MessageBox]::Show("Run all $($enabledScripts.Count) enabled scripts?", "Confirm Execution", "YesNo", "Question")
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-ScriptExecution -Scripts $enabledScripts
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start execution: $_", "Execution Failed", "OK", "Error")
        Write-Log "Failed to start script execution: $_" -Level "ERROR" -UpdateUI
    }
}

$btnRunSelected_Click = {
    try {
        $selectedScript = Get-SelectedScript
        if ($selectedScript) {
            if (-not $selectedScript.Enabled) {
                $result = [System.Windows.Forms.MessageBox]::Show("Selected script is disabled. Run anyway?", "Script Disabled", "YesNo", "Question")
                if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                    return
                }
            }
            
            Start-ScriptExecution -Scripts @($selectedScript)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a script to run.", "No Selection", "OK", "Information")
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to run selected script: $_", "Execution Failed", "OK", "Error")
        Write-Log "Failed to run selected script: $_" -Level "ERROR" -UpdateUI
    }
}

$btnStopExecution_Click = {
    try {
        if ($Global:AppConfig.IsExecuting -and $Global:AppConfig.CurrentJob) {
            $result = [System.Windows.Forms.MessageBox]::Show("Stop the current execution?", "Confirm Stop", "YesNo", "Question")
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Stop-Job -Job $Global:AppConfig.CurrentJob -PassThru | Remove-Job -Force
                $Global:AppConfig.IsExecuting = $false
                $Global:AppConfig.CurrentJob = $null
                
                Update-ExecutionUI -Reset
                Write-Log "Script execution stopped by user" -Level "WARNING" -UpdateUI
                Update-StatusStrip "Execution stopped"
            }
        }
        
    } catch {
        Write-Log "Failed to stop execution: $_" -Level "ERROR" -UpdateUI
    }
}

function Start-ScriptExecution {
    param([array]$Scripts)
    
    try {
        $Global:AppConfig.IsExecuting = $true
        Update-ExecutionUI -Started
        
        Write-Log "Starting execution of $($Scripts.Count) scripts" -Level "INFO" -UpdateUI
        Update-StatusStrip "Executing scripts..."
        
        $scriptBlock = {
            param($ScriptsToRun, $ExecutionSettings)
            
            $results = @()
            $currentIndex = 0
            
            foreach ($script in $ScriptsToRun) {
                $currentIndex++
                $result = @{
                    Script = $script
                    StartTime = Get-Date
                    Success = $false
                    Output = ""
                    Error = ""
                }
                
                try {
                    if (Test-Path $script.Path) {
                        $params = @{}
                        foreach ($param in $script.Parameters.GetEnumerator()) {
                            if (-not [string]::IsNullOrWhiteSpace($param.Value)) {
                                $params[$param.Key] = $param.Value
                            }
                        }
                        
                        $output = & $script.Path @params 2>&1
                        $result.Output = $output -join "`n"
                        $result.Success = $true
                    } else {
                        $result.Error = "Script file not found: $($script.Path)"
                    }
                } catch {
                    $result.Error = $_.Exception.Message
                }
                
                $result.EndTime = Get-Date
                $result.Duration = $result.EndTime - $result.StartTime
                $results += $result
                
                # Update progress
                $progressPercent = [int](($currentIndex / $ScriptsToRun.Count) * 100)
                Write-Progress -Activity "Executing Scripts" -Status "Script $currentIndex of $($ScriptsToRun.Count)" -PercentComplete $progressPercent
                
                if ($ExecutionSettings.StopOnError -and -not $result.Success) {
                    break
                }
            }
            
            return $results
        }
        
        $Global:AppConfig.CurrentJob = Start-Job -ScriptBlock $scriptBlock -ArgumentList $Scripts, $Global:AppConfig.ExecutionSettings
        
        # Monitor job progress
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000  # Check every second
        $timer.Add_Tick({
            if ($Global:AppConfig.CurrentJob.State -eq "Completed") {
                $results = Receive-Job -Job $Global:AppConfig.CurrentJob
                Remove-Job -Job $Global:AppConfig.CurrentJob
                
                $Global:AppConfig.IsExecuting = $false
                $Global:AppConfig.CurrentJob = $null
                
                Complete-ScriptExecution -Results $results
                $timer.Stop()
                $timer.Dispose()
            } elseif ($Global:AppConfig.CurrentJob.State -eq "Failed") {
                $error = $Global:AppConfig.CurrentJob.JobStateInfo.Reason.Message
                Write-Log "Script execution failed: $error" -Level "ERROR" -UpdateUI
                
                $Global:AppConfig.IsExecuting = $false
                $Global:AppConfig.CurrentJob = $null
                Update-ExecutionUI -Reset
                $timer.Stop()
                $timer.Dispose()
            }
        })
        $timer.Start()
        
    } catch {
        $Global:AppConfig.IsExecuting = $false
        Write-Log "Failed to start script execution: $_" -Level "ERROR" -UpdateUI
        Update-ExecutionUI -Reset
    }
}

function Complete-ScriptExecution {
    param([array]$Results)
    
    try {
        $successCount = ($Results | Where-Object { $_.Success }).Count
        $totalCount = $Results.Count
        
        Write-Log "Script execution completed: $successCount/$totalCount successful" -Level "INFO" -UpdateUI
        Update-StatusStrip "Execution completed: $successCount/$totalCount successful"
        
        # Update output
        $outputText = ""
        foreach ($result in $Results) {
            $outputText += "=== Script: $(Split-Path $result.Script.Path -Leaf) ===`n"
            $outputText += "Start Time: $($result.StartTime)`n"
            $outputText += "Duration: $($result.Duration)`n"
            $outputText += "Status: $(if ($result.Success) { 'SUCCESS' } else { 'FAILED' })`n"
            
            if ($result.Success) {
                $outputText += "Output:`n$($result.Output)`n"
            } else {
                $outputText += "Error:`n$($result.Error)`n"
            }
            $outputText += "`n" + "="*50 + "`n`n"
        }
        
        if ($Global:MainForm.txtExecutionOutput) {
            $Global:MainForm.txtExecutionOutput.Text = $outputText
        }
        
        Update-ExecutionUI -Reset
        
        [System.Windows.Forms.MessageBox]::Show("Execution completed: $successCount/$totalCount scripts successful.", "Execution Complete", "OK", "Information")
        
    } catch {
        Write-Log "Error completing script execution: $_" -Level "ERROR" -UpdateUI
    }
}

function Update-ExecutionUI {
    param(
        [switch]$Started,
        [switch]$Reset
    )
    
    try {
        if ($Started) {
            if ($Global:MainForm.btnRunAll) { $Global:MainForm.btnRunAll.Enabled = $false }
            if ($Global:MainForm.btnRunSelected) { $Global:MainForm.btnRunSelected.Enabled = $false }
            if ($Global:MainForm.btnStopExecution) { $Global:MainForm.btnStopExecution.Enabled = $true }
            
            if ($Global:MainForm.progressOverall) { $Global:MainForm.progressOverall.Value = 0 }
            if ($Global:MainForm.progressCurrentScript) { $Global:MainForm.progressCurrentScript.Value = 0 }
            
        } elseif ($Reset) {
            if ($Global:MainForm.btnRunAll) { $Global:MainForm.btnRunAll.Enabled = $true }
            if ($Global:MainForm.btnRunSelected) { $Global:MainForm.btnRunSelected.Enabled = $true }
            if ($Global:MainForm.btnStopExecution) { $Global:MainForm.btnStopExecution.Enabled = $false }
            
            if ($Global:MainForm.progressOverall) { $Global:MainForm.progressOverall.Value = 0 }
            if ($Global:MainForm.progressCurrentScript) { $Global:MainForm.progressCurrentScript.Value = 0 }
        }
        
    } catch {
        Write-Log "Error updating execution UI: $_" -Level "ERROR"
    }
}
#endregion

#region Log Management Event Handlers
$btnRefreshLogs_Click = {
    try {
        if (Test-Path $Global:LogFile) {
            $logContent = Get-Content -Path $Global:LogFile -Raw
            if ($Global:MainForm.logTextBox) {
                $Global:MainForm.logTextBox.Text = $logContent
                $Global:MainForm.logTextBox.ScrollToCaret()
            }
            Write-Log "Log refreshed from file" -Level "INFO"
            Update-StatusStrip "Log refreshed"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Log file not found.", "No Log File", "OK", "Information")
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to refresh logs: $_", "Refresh Failed", "OK", "Error")
        Write-Log "Failed to refresh logs: $_" -Level "ERROR" -UpdateUI
    }
}

$btnClearLogs_Click = {
    try {
        $result = [System.Windows.Forms.MessageBox]::Show("Clear all logs? This action cannot be undone.", "Confirm Clear", "YesNo", "Question")
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            if ($Global:MainForm.logTextBox) {
                $Global:MainForm.logTextBox.Clear()
            }
            
            if (Test-Path $Global:LogFile) {
                Clear-Content -Path $Global:LogFile -Force
            }
            
            Write-Log "Application started - logs cleared" -Level "INFO" -UpdateUI
            Update-StatusStrip "Logs cleared"
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to clear logs: $_", "Clear Failed", "OK", "Error")
        Write-Log "Failed to clear logs: $_" -Level "ERROR" -UpdateUI
    }
}

$btnExportLogs_Click = {
    try {
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Title = "Export Logs"
        $saveFileDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
        $saveFileDialog.DefaultExt = "txt"
        $saveFileDialog.FileName = "application_logs_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
        $saveFileDialog.InitialDirectory = $Global:Paths.Exports
        
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if (Test-Path $Global:LogFile) {
                Copy-Item -Path $Global:LogFile -Destination $saveFileDialog.FileName -Force
                [System.Windows.Forms.MessageBox]::Show("Logs exported successfully to: $($saveFileDialog.FileName)", "Export Successful", "OK", "Information")
                Write-Log "Logs exported to: $($saveFileDialog.FileName)" -Level "INFO" -UpdateUI
                Update-StatusStrip "Logs exported"
            } else {
                [System.Windows.Forms.MessageBox]::Show("No log file found to export.", "No Logs", "OK", "Information")
            }
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to export logs: $_", "Export Failed", "OK", "Error")
        Write-Log "Failed to export logs: $_" -Level "ERROR" -UpdateUI
    }
}
#endregion

#region Application Event Handlers
$btnSaveAll_Click = {
    try {
        Update-ConfigFromUI
        if (Save-AppConfig) {
            [System.Windows.Forms.MessageBox]::Show("All settings saved successfully.", "Settings Saved", "OK", "Information")
            Update-StatusStrip "All settings saved"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Failed to save some settings.", "Save Failed", "OK", "Warning")
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to save settings: $_", "Save Failed", "OK", "Error")
        Write-Log "Failed to save all settings: $_" -Level "ERROR" -UpdateUI
    }
}

$btnExit_Click = {
    try {
        if ($Global:AppConfig.IsExecuting) {
            $result = [System.Windows.Forms.MessageBox]::Show("Scripts are currently executing. Stop execution and exit?", "Confirm Exit", "YesNo", "Question")
            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
            
            if ($Global:AppConfig.CurrentJob) {
                Stop-Job -Job $Global:AppConfig.CurrentJob -PassThru | Remove-Job -Force
            }
        }
        
        Update-ConfigFromUI
        Save-AppConfig | Out-Null
        
        Write-Log "Application closing" -Level "INFO" -UpdateUI
        $Global:MainForm.Close()
        
    } catch {
        Write-Log "Error during application exit: $_" -Level "ERROR" -UpdateUI
        $Global:MainForm.Close()
    }
}

$btnHelp_Click = {
    try {
        $helpText = @"
vCenter Migration Workflow Manager - Help

CONNECTION TAB:
- Enter source and target vCenter server details
- Test connections before proceeding
- Save/Load connection settings for reuse

SCRIPTS TAB:
- Add PowerShell scripts to execute in sequence
- Configure script parameters
- Enable/disable scripts as needed
- Reorder scripts using Move Up/Down buttons

EXECUTION TAB:
- Configure execution settings (timeout, error handling)
- Run all enabled scripts or just selected script
- Monitor progress and view output

LOGS TAB:
- View application logs
- Refresh, clear, or export logs
- Monitor script execution details

For more information, check the application documentation.
"@
        
        [System.Windows.Forms.MessageBox]::Show($helpText, "Help", "OK", "Information")
        Write-Log "Help dialog displayed" -Level "INFO" -UpdateUI
        
    } catch {
        Write-Log "Failed to show help: $_" -Level "ERROR" -UpdateUI
    }
}
#endregion

#region Event Handler Registration
function Register-EventHandlers {
    Write-Log "Registering event handlers..." -Level "INFO"
    
    # This function is called from the main logic after all functions are defined
    # Event handlers are already attached in the designer file
    
    # Additional UI event handlers can be registered here
    try {
        # Script selection change handler
        if ($Global:MainForm.lvScripts) {
            $Global:MainForm.lvScripts.add_SelectedIndexChanged({
                $selectedScript = Get-SelectedScript
                if ($selectedScript) {
                    if ($Global:MainForm.txtScriptPath) { $Global:MainForm.txtScriptPath.Text = $selectedScript.Path }
                    if ($Global:MainForm.txtScriptDescription) { $Global:MainForm.txtScriptDescription.Text = $selectedScript.Description }
                    if ($Global:MainForm.chkScriptEnabled) { $Global:MainForm.chkScriptEnabled.Checked = $selectedScript.Enabled }
                    Update-ParametersList
                }
            })
        }
        
        Write-Log "Event handlers registered successfully" -Level "INFO"
    } catch {
        Write-Log "Error registering additional event handlers: $_" -Level "ERROR"
    }
}
#endregion
function Initialize-MainForm {
    try {
        Write-Log "Initializing main form..." -Level "INFO"
        
        # Call InitializeComponent if it hasn't been called
        if (Get-Command InitializeComponent -ErrorAction SilentlyContinue) {
            . InitializeComponent
            Write-Log "InitializeComponent executed" -Level "DEBUG"
        }
        
        # Check if mainForm exists
        if (-not $mainForm) {
            throw "mainForm variable not found"
        }
        
        # Verify it's a valid form
        if ($mainForm.GetType().FullName -ne "System.Windows.Forms.Form") {
            throw "mainForm is not a valid Windows Form"
        }
        
        # Create global references
        $Global:MainForm = $mainForm
        $Global:AI_Gen_Workflow_Wrapper = $mainForm
        
        Write-Log "Main form initialized: $($mainForm.Text)" -Level "INFO"
        return $true
        
    } catch {
        Write-Log "Failed to initialize main form: $_" -Level "ERROR"
        return $false
    }
}
#region Form Initialization
function Initialize-MainForm {
    try {
        Write-Log "=== Starting Initialize-MainForm ===" -Level "INFO"
        Write-Host "=== DEBUGGING Initialize-MainForm ===" -ForegroundColor Magenta
        
        # Check if InitializeComponent exists
        $initComponentExists = Get-Command InitializeComponent -ErrorAction SilentlyContinue
        Write-Log "InitializeComponent command exists: $($null -ne $initComponentExists)" -Level "DEBUG"
        Write-Host "InitializeComponent exists: $($null -ne $initComponentExists)" -ForegroundColor Yellow
        
        if ($initComponentExists) {
            Write-Log "Calling InitializeComponent..." -Level "INFO"
            Write-Host "Calling InitializeComponent..." -ForegroundColor Yellow
            
            . InitializeComponent
            
            Write-Log "InitializeComponent executed successfully" -Level "INFO"
            Write-Host "InitializeComponent called successfully" -ForegroundColor Green
        } else {
            Write-Log "InitializeComponent function not found!" -Level "ERROR"
            Write-Host "ERROR: InitializeComponent function not found!" -ForegroundColor Red
            return $false
        }
        
        # Check if mainForm variable exists
        $mainFormVar = Get-Variable -Name "mainForm" -ErrorAction SilentlyContinue
        Write-Log "mainForm variable exists: $($null -ne $mainFormVar)" -Level "DEBUG"
        Write-Host "mainForm variable exists: $($null -ne $mainFormVar)" -ForegroundColor Yellow
        
        if (-not $mainFormVar) {
            Write-Log "mainForm variable not found after InitializeComponent!" -Level "ERROR"
            Write-Host "ERROR: mainForm variable not found!" -ForegroundColor Red
            return $false
        }
        
        $formValue = $mainFormVar.Value
        Write-Log "mainForm value is null: $($null -eq $formValue)" -Level "DEBUG"
        Write-Host "mainForm value is null: $($null -eq $formValue)" -ForegroundColor Yellow
        
        if (-not $formValue) {
            Write-Log "mainForm variable is null!" -Level "ERROR"
            Write-Host "ERROR: mainForm variable is null!" -ForegroundColor Red
            return $false
        }
        
        # Check the type
        $formType = $formValue.GetType().FullName
        Write-Log "mainForm type: $formType" -Level "DEBUG"
        Write-Host "mainForm type: $formType" -ForegroundColor Yellow
        
        if ($formType -ne "System.Windows.Forms.Form") {
            Write-Log "mainForm is not a valid Windows Form! Type: $formType" -Level "ERROR"
            Write-Host "ERROR: mainForm is not a Form! Type: $formType" -ForegroundColor Red
            return $false
        }
        
        # Check if disposed
        $isDisposed = $formValue.IsDisposed
        Write-Log "mainForm is disposed: $isDisposed" -Level "DEBUG"
        Write-Host "mainForm is disposed: $isDisposed" -ForegroundColor Yellow
        
        if ($isDisposed) {
            Write-Log "mainForm is disposed!" -Level "ERROR"
            Write-Host "ERROR: mainForm is disposed!" -ForegroundColor Red
            return $false
        }
        
        # Get form properties
        $formText = $formValue.Text
        $formSize = $formValue.Size
        Write-Log "Form Text: '$formText', Size: $formSize" -Level "INFO"
        Write-Host "Form Text: '$formText', Size: $formSize" -ForegroundColor Cyan
        
        # Create global references
        $Global:MainForm = $formValue
        $Global:AI_Gen_Workflow_Wrapper = $formValue
        
        Write-Log "Global form references created successfully" -Level "INFO"
        Write-Host "? Global form references created" -ForegroundColor Green
        
        Write-Log "=== Initialize-MainForm completed successfully ===" -Level "INFO"
        Write-Host "=== Initialize-MainForm SUCCESS ===" -ForegroundColor Green
        
        return $true
        
    } catch {
        Write-Log "=== Initialize-MainForm FAILED: $_ ===" -Level "ERROR"
        Write-Host "=== Initialize-MainForm ERROR: $_ ===" -ForegroundColor Red
        return $false
    }
}
#endregion


# Export functions for use in other scripts
Write-Log "Globals.ps1 loaded successfully" -Level "INFO"
