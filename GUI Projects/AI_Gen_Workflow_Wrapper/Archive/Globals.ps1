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
                $jobError = $Global:AppConfig.CurrentJob.JobStateInfo.Reason.Message
                Write-Log "Script execution failed: $jobError" -Level "ERROR" -UpdateUI
                
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
