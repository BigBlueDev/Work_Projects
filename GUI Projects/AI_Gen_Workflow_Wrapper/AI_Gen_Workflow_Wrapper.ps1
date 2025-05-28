


<#
.SYNOPSIS
    vCenter Migration Workflow Manager - Core Functionality Wrapper

.DESCRIPTION
    This script contains all the core functionality, event handlers, and business logic
    for the vCenter Migration Workflow Manager application. It works in conjunction with
    the form designer and globals to provide a complete workflow management solution.

.NOTES
    Author: vCenter Migration Team
    Version: 1.0
    Requires: PowerShell 5.1+, VMware PowerCLI, Windows Forms
    Compatible: PowerShell Pro Tools
#>

# Ensure strict mode for better error handling
Set-StrictMode -Version Latest

#region Future-Proof Path Management

# Helper functions using the PathManager
function Get-ConfigurationFile {
    return Get-AppFilePathFromPattern -PathName "Config" -PatternName "ConfigFile"
}

function Get-SettingsFile {
    return Get-AppFilePathFromPattern -PathName "Config" -PatternName "SettingsFile"
}

function Get-ExportFile {
    param([string]$BaseName = "export")
    return Get-AppFilePath -PathName "Exports" -FileName "$BaseName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
}

function Get-ImportDirectory {
    return Get-AppPath -PathName "Imports"
}

function Show-EditParameterDialog {
    param(
        [string]$ParameterName = "",
        [string]$CurrentValue = "",
        [string]$ParameterType = "String"
    )
    
    # Load EditParam form using path manager
    $designerPath = Get-AppFilePath -PathName "SubForms" -FileName "EditParam.designer.ps1" -EnsureDirectory $false
    $logicPath = Get-AppFilePath -PathName "SubForms" -FileName "EditParam.ps1" -EnsureDirectory $false
    
    if (Test-Path $designerPath) { . $designerPath }
    if (Test-Path $logicPath) { . $logicPath }
    
    # Rest of your EditParam logic...
}

function Initialize-FileDialogs {
    # Set up file dialogs with proper paths
    if ($script:openFileDialog1) {
        $script:openFileDialog1.InitialDirectory = Get-AppPath -PathName "Root"
    }
    
    # Set up other dialogs as needed
}

#endregion

#region Win32 API and Form Management

# Add Win32 API for enhanced window management
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    public const int SW_RESTORE = 9;
    public const int SW_SHOW = 5;
    public const int SW_NORMAL = 1;
}
"@

function Show-MainForm {
    <#
    .SYNOPSIS
        Enhanced form display function that ensures the form appears in the foreground
    #>
    try {
        Write-Log "Showing main form..." -Level "INFO"
        
        # Ensure form is properly configured
        $mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $mainForm.ShowInTaskbar = $true
        $mainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        
        # Show the form
        $mainForm.Show()
        
        # Wait a moment for the handle to be created
        $timeout = [datetime]::Now.AddSeconds(5)
        while (-not $mainForm.Handle -and [datetime]::Now -lt $timeout) {
            Start-Sleep -Milliseconds 50
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        if ($mainForm.Handle) {
            Write-Log "Form handle created: $($mainForm.Handle)" -Level "DEBUG"
            
            # Use Win32 API to bring window to front
            if ([Win32]::IsIconic($mainForm.Handle)) {
                [Win32]::ShowWindow($mainForm.Handle, [Win32]::SW_RESTORE) | Out-Null
            }
            
            [Win32]::ShowWindow($mainForm.Handle, [Win32]::SW_SHOW) | Out-Null
            [Win32]::SetForegroundWindow($mainForm.Handle) | Out-Null
            
            # Additional PowerShell methods for good measure
            $mainForm.BringToFront()
            $mainForm.Activate()
            $mainForm.Focus()
            
            # Temporary TopMost to force visibility (then reset)
            $mainForm.TopMost = $true
            $mainForm.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
            $mainForm.TopMost = $false
            
            Write-Log "Main form displayed and brought to foreground successfully" -Level "INFO"
        } else {
            Write-Log "Warning: Form handle not created within timeout period" -Level "WARNING"
        }
        
    } catch {
        Write-Log "Error showing main form: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        throw
    }
}

function Set-FormState {
    <#
    .SYNOPSIS
        Manages form window state
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Minimized", "Normal", "Maximized")]
        [string]$State
    )
    
    try {
        switch ($State) {
            "Minimized" {
                $mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
            }
            "Normal" {
                $mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
                if ($mainForm.Handle) {
                    [Win32]::SetForegroundWindow($mainForm.Handle) | Out-Null
                }
            }
            "Maximized" {
                $mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
                if ($mainForm.Handle) {
                    [Win32]::SetForegroundWindow($mainForm.Handle) | Out-Null
                }
            }
        }
        
        Write-Log "Form state set to: $($State)" -Level "DEBUG"
        
    } catch {
        Write-Log "Error setting form state: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region Application Initialization

function Initialize-Application {
    <#
    .SYNOPSIS
        Main application initialization function
    #>
    try {
        Write-Log "Initializing vCenter Migration Workflow Manager..." -Level "INFO"
        
        # Initialize form controls
        Initialize-FormControls
        
        # Initialize ListView columns
        Initialize-ListViewColumns
        
        # Register all event handlers
        Register-EventHandlers
        
        # Load saved settings
        Load-FormSettings
        
        # Set initial UI state
        Update-UIState -State "Ready"
        
        # Initialize script variables
        if (-not $script:Scripts) {
            $script:Scripts = @()
        }
        
        if (-not $script:StopExecution) {
            $script:StopExecution = $false
        }
        
        Write-Log "Application initialization completed successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error during application initialization: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        throw
    }
}

function Initialize-FormControls {
    <#
    .SYNOPSIS
        Initialize form controls with default values and settings
    #>
    try {
        Write-Log "Initializing form controls..." -Level "INFO"
        
        # Set default values for execution settings
        $numTimeout.Value = 300
        $numMaxJobs.Value = 1
        $chkStopOnError.Checked = $true
        $chkSkipConfirmation.Checked = $false
        
        # Set initial status
        $statusStripLabel.Text = "Ready"
        
        # Initialize progress bars
        $progressOverall.Value = 0
        $progressCurrentScript.Value = 0
        
        # Clear text boxes
        $txtExecutionOutput.Clear()
        $logTextBox.Clear()
        
        # Disable execution controls initially
        $btnRunAll.Enabled = $false
        $btnRunSelected.Enabled = $false
        $btnStopExecution.Enabled = $false
        
        # Set up file dialog
        $openFileDialog1.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $openFileDialog1.Title = "Select PowerShell Script"
        
        Write-Log "Form controls initialized successfully" -Level "INFO"
        
        
    } catch {
        Write-Log "Error initializing form controls: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Initialize-ListViewColumns {
    <#
    .SYNOPSIS
        Initialize ListView columns for scripts and parameters
    #>
    try {
        Write-Log "Initializing ListView columns..." -Level "DEBUG"
        
        # Scripts ListView columns
        $lvScripts.View = [System.Windows.Forms.View]::Details
        $lvScripts.FullRowSelect = $true
        $lvScripts.GridLines = $true
        $lvScripts.Columns.Clear()
        
        [void]$lvScripts.Columns.Add("Order", 50)
        [void]$lvScripts.Columns.Add("Name", 150)
        [void]$lvScripts.Columns.Add("Description", 200)
        [void]$lvScripts.Columns.Add("Enabled", 60)
        [void]$lvScripts.Columns.Add("Path", 250)
        
        # Parameters ListView columns
        $lvParameters.View = [System.Windows.Forms.View]::Details
        $lvParameters.FullRowSelect = $true
        $lvParameters.GridLines = $true
        $lvParameters.Columns.Clear()
        
        [void]$lvParameters.Columns.Add("Name", 100)
        [void]$lvParameters.Columns.Add("Value", 150)
        [void]$lvParameters.Columns.Add("Type", 80)
        [void]$lvParameters.Columns.Add("Description", 200)
        
        Write-Log "ListView columns initialized successfully" -Level "DEBUG"
        
    } catch {
        Write-Log "Error initializing ListView columns: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Event Handler Registration

function Register-EventHandlers {
    try {
        Write-Log "Registering event handlers for form controls..." -Level "DEBUG"
        
        # Event handler for Test Source Connection button
        if ($btnTestSourceConnection) {
            $btnTestSourceConnection.add_Click($btnTestSourceConnection_Click)
            Write-Host "✓ Registered: btnTestSourceConnection" -ForegroundColor Green
        } else {
            Write-Host "⚠ Not found: btnTestSourceConnection" -ForegroundColor Yellow
        }
        
        # Event handler for Test Target Connection button  
        if ($btnTestTargetConnection) {
            $btnTestTargetConnection.add_Click($btnTestTargetConnection_Click)
            Write-Host "✓ Registered: btnTestTargetConnection" -ForegroundColor Green
        } else {
            Write-Host "⚠ Not found: btnTestTargetConnection" -ForegroundColor Yellow
        }
        
        # Event handler for Load Source button
        if ($btnLoadSource) {
            $btnLoadSource.add_Click($btnLoadSource_Click)
            Write-Host "✓ Registered: btnLoadSource" -ForegroundColor Green
        } else {
            Write-Host "⚠ Not found: btnLoadSource" -ForegroundColor Yellow
        }
        
        # Event handler for Load Target button
        if ($btnLoadTarget) {
            $btnLoadTarget.add_Click($btnLoadTarget_Click)
            Write-Host "✓ Registered: btnLoadTarget" -ForegroundColor Green
        } else {
            Write-Host "⚠ Not found: btnLoadTarget" -ForegroundColor Yellow
        }
        
        # Event handler for Execute button
        if ($btnExecute) {
            $btnExecute.add_Click($btnExecute_Click)
            Write-Host "✓ Registered: btnExecute" -ForegroundColor Green
        } else {
            Write-Host "⚠ Not found: btnExecute" -ForegroundColor Yellow
        }
        
        Write-Log "Event handler registration completed" -Level "INFO"
        
    } catch {
        Write-Log "Error registering event handlers: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}


function Diagnose-EventHandlers {
    <#
    .SYNOPSIS
        Diagnostic function to verify event handlers are properly registered
    #>
    try {
        Write-Log "Diagnosing event handler registration..." -Level "DEBUG"
        
        $eventHandlers = @(
            @{ Control = "btnTestSourceConnection"; Event = "Click"; Handler = "btnTestSourceConnection_Click" }
            @{ Control = "btnTestTargetConnection"; Event = "Click"; Handler = "btnTestTargetConnection_Click" }
            @{ Control = "btnRunAll"; Event = "Click"; Handler = "btnRunAll_Click" }
            @{ Control = "btnRunSelected"; Event = "Click"; Handler = "btnRunSelected_Click" }
            @{ Control = "btnStopExecution"; Event = "Click"; Handler = "btnStopExecution_Click" }
        )
        
        foreach ($handler in $eventHandlers) {
            $control = Get-Variable -Name $handler.Control -ErrorAction SilentlyContinue
            if ($control) {
                Write-Log "✓ $($handler.Control) exists and $($handler.Event) event can be registered" -Level "DEBUG"
            } else {
                Write-Log "✗ $($handler.Control) not found" -Level "WARNING"
            }
        }
        
    } catch {
        Write-Log "Error during event handler diagnosis: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region UI State Management

function Update-UIState {
    <#
    .SYNOPSIS
        Updates UI controls based on application state
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Ready", "Running", "Stopped", "Error")]
        [string]$State
    )
    
    try {
        Write-Log "Updating UI state to: $($State)" -Level "DEBUG"
        
        switch ($State) {
            "Ready" {
                # Enable execution controls if scripts are available
                $enabledScripts = $script:Scripts | Where-Object { $_.Enabled -eq $true }
                $btnRunAll.Enabled = ($enabledScripts.Count -gt 0)
                $btnRunSelected.Enabled = ($lvScripts.SelectedItems.Count -gt 0)
                $btnStopExecution.Enabled = $false
                
                # Enable other controls
                $btnTestSourceConnection.Enabled = $true
                $btnTestTargetConnection.Enabled = $true
                $btnSaveConnection.Enabled = $true
                $btnLoadConnection.Enabled = $true
                $btnAddScript.Enabled = $true
                $btnRemoveScript.Enabled = ($lvScripts.SelectedItems.Count -gt 0)
                
                # Update status
                $statusStripLabel.Text = "Ready"
                $statusStripLabel.ForeColor = [System.Drawing.Color]::Black
                
                # Reset progress bars
                $progressOverall.Value = 0
                $progressCurrentScript.Value = 0
                $lblOverallProgress.Text = "Overall Progress:"
                $lblCurrentProgress.Text = "Current Script:"
            }
            
            "Running" {
                # Disable execution controls except stop
                $btnRunAll.Enabled = $false
                $btnRunSelected.Enabled = $false
                $btnStopExecution.Enabled = $true
                
                # Disable other controls during execution
                $btnTestSourceConnection.Enabled = $false
                $btnTestTargetConnection.Enabled = $false
                $btnAddScript.Enabled = $false
                $btnRemoveScript.Enabled = $false
                
                # Update status
                $statusStripLabel.Text = "Executing scripts..."
                $statusStripLabel.ForeColor = [System.Drawing.Color]::Blue
            }
            
            "Stopped" {
                # Re-enable controls
                $btnRunAll.Enabled = $true
                $btnRunSelected.Enabled = ($lvScripts.SelectedItems.Count -gt 0)
                $btnStopExecution.Enabled = $false
                
                $btnTestSourceConnection.Enabled = $true
                $btnTestTargetConnection.Enabled = $true
                $btnAddScript.Enabled = $true
                $btnRemoveScript.Enabled = ($lvScripts.SelectedItems.Count -gt 0)
                
                # Update status
                $statusStripLabel.Text = "Execution stopped"
                $statusStripLabel.ForeColor = [System.Drawing.Color]::Orange
            }
            
            "Error" {
                # Re-enable controls
                $btnRunAll.Enabled = $true
                $btnRunSelected.Enabled = ($lvScripts.SelectedItems.Count -gt 0)
                $btnStopExecution.Enabled = $false
                
                $btnTestSourceConnection.Enabled = $true
                $btnTestTargetConnection.Enabled = $true
                $btnAddScript.Enabled = $true
                $btnRemoveScript.Enabled = ($lvScripts.SelectedItems.Count -gt 0)
                
                # Update status
                $statusStripLabel.Text = "Error occurred"
                $statusStripLabel.ForeColor = [System.Drawing.Color]::Red
            }
        }
        
        # Refresh the form
        $mainForm.Refresh()
        
    } catch {
        Write-Log "Error updating UI state: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Enhanced Test Connection function with proper user feedback
function Test-ConnectionWithFeedback {
    param(
        [string]$ServerName,
        [string]$ConnectionType = "Unknown",
        [int]$TimeoutSeconds = 5,
        [System.Windows.Forms.Button]$Button
    )
    
    try {
        # Show that testing is in progress
        $originalText = $Button.Text
        $Button.Enabled = $false
        $Button.Text = "Testing..."
        $mainForm.Refresh()
        
        Write-Log "Testing $ConnectionType connection to: $ServerName" -Level "INFO"
        
        if ([string]::IsNullOrWhiteSpace($ServerName)) {
            throw "Server name cannot be empty"
        }
        
        # Perform the actual test (using Test-NetConnection for port 443 - vCenter default)
        Write-Host "Testing connection to $ServerName..." -ForegroundColor Yellow
        $testResult = Test-NetConnection -ComputerName $ServerName -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        if ($testResult) {
            $message = "✓ $ConnectionType connection to '$ServerName' successful!`n`nPort 443 (HTTPS) is accessible."
            Write-Log "$ConnectionType connection test successful: $ServerName" -Level "INFO"
            
            [System.Windows.Forms.MessageBox]::Show(
                $message,
                "$ConnectionType Connection Test - Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            return $true
        } else {
            $message = "✗ $ConnectionType connection to '$ServerName' failed!`n`nPort 443 (HTTPS) is not accessible.`n`nPlease check:`n• Server name/IP is correct`n• vCenter server is running`n• Firewall allows port 443`n• Network connectivity"
            Write-Log "$ConnectionType connection test failed: $ServerName" -Level "WARNING"
            
            [System.Windows.Forms.MessageBox]::Show(
                $message,
                "$ConnectionType Connection Test - Failed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            
            return $false
        }
        
    } catch {
        $errorMessage = "Error testing $ConnectionType connection: $($_.Exception.Message)"
        Write-Log $errorMessage -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            "$ConnectionType Connection Test Error:`n`n$errorMessage",
            "$ConnectionType Connection Test - Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        return $false
        
    } finally {
        # Reset button state
        $Button.Enabled = $true
        $Button.Text = $originalText
        $mainForm.Refresh()
    }
}

function Test-FormValidation {
    <#
    .SYNOPSIS
        Validates form inputs before execution
    #>
    $errors = @()
    
    try {
        # Validate connection settings
        if ([string]::IsNullOrWhiteSpace($txtSourceServer.Text)) {
            $errors += "Source server is required"
        }
        
        if ([string]::IsNullOrWhiteSpace($txtTargetServer.Text)) {
            $errors += "Target server is required"
        }
        
        # Validate credentials if not using current credentials
        if (-not $chkUseCurrentCredentials.Checked) {
            if ([string]::IsNullOrWhiteSpace($txtSourceUsername.Text)) {
                $errors += "Source username is required when not using current credentials"
            }
            if ([string]::IsNullOrWhiteSpace($txtTargetUsername.Text)) {
                $errors += "Target username is required when not using current credentials"
            }
        }
        
        # Validate that at least one script is enabled
        $enabledScripts = $script:Scripts | Where-Object { $_.Enabled -eq $true }
        if ($enabledScripts.Count -eq 0) {
            $errors += "At least one script must be enabled for execution"
        }
        
        # Validate execution settings
        if ($numTimeout.Value -le 0) {
            $errors += "Execution timeout must be greater than 0"
        }
        
        if ($numMaxJobs.Value -le 0) {
            $errors += "Maximum concurrent jobs must be greater than 0"
        }
        
        # Validate script paths exist
        foreach ($script in $enabledScripts) {
            if (-not (Test-Path -Path $script.Path)) {
                $errors += "Script file not found: $($script.Path)"
            }
        }
        
    } catch {
        Write-Log "Error during form validation: $($_.Exception.Message)" -Level "ERROR"
        $errors += "Validation error: $($_.Exception.Message)"
    }
    
    return $errors
}

function Enable-ExecutionControls {
    <#
    .SYNOPSIS
        Helper function to enable/disable execution controls based on script availability
    #>
    param([bool]$Enable)
    
    try {
        $enabledScripts = @($script:Scripts | Where-Object { $_.Enabled -eq $true })
        $hasSelection = $lvScripts.SelectedItems.Count -gt 0
        
        # Update button states
        $btnRunAll.Enabled = $Enable -and ($enabledScripts.Count -gt 0)
        $btnRunSelected.Enabled = $Enable -and $hasSelection
        $btnRemoveScript.Enabled = $hasSelection
        $btnMoveUp.Enabled = $hasSelection -and ($lvScripts.SelectedItems[0].Index -gt 0)
        $btnMoveDown.Enabled = $hasSelection -and ($lvScripts.SelectedItems[0].Index -lt ($lvScripts.Items.Count - 1))
        
        Write-Log "Execution controls updated - Enable: $($Enable), Scripts: $($enabledScripts.Count), Selection: $($hasSelection)" -Level "DEBUG"
        
    } catch {
        Write-Log "Error enabling execution controls: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region Form Event Handlers

$mainForm_Load = {
    try {
        Write-Log "Main form loading..." -Level "INFO"
        
        # Perform any additional initialization needed when form loads
        Refresh-LogDisplay
        
        Write-Log "Main form loaded successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error during main form load: $($_.Exception.Message)" -Level "ERROR"
    }
}

$mainForm_FormClosing = {
    param($sender, $e)
    
    try {
        Write-Log "Main form closing..." -Level "INFO"
        
        # Check if execution is running
        if ($script:ExecutionPowerShell -and -not $script:ExecutionHandle.IsCompleted) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Script execution is still running. Do you want to stop execution and exit?",
                "Execution in Progress",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                $e.Cancel = $true
                return
            } else {
                # Stop execution
                Stop-ScriptExecution
            }
        }
        
        # Save settings before closing
        try {
            Save-AllSettings
            Write-Log "Settings saved before closing" -Level "INFO"
        } catch {
            Write-Log "Error saving settings before closing: $($_.Exception.Message)" -Level "WARNING"
        }
        
        Write-Log "Main form closing completed" -Level "INFO"
        
    } catch {
        Write-Log "Error during main form closing: $($_.Exception.Message)" -Level "ERROR"
    }
}

$lvScripts_SelectedIndexChanged = {
    try {
        # Find the ListView control safely
        $scriptsListView = $mainForm.Controls.Find("lvScripts", $true)
        if (-not $scriptsListView) { $scriptsListView = $mainForm.Controls.Find("listViewScripts", $true) }
        
        if ($scriptsListView -and $scriptsListView.Count -gt 0) {
            $lvScripts = $scriptsListView[0]
            
            if ($lvScripts.SelectedItems.Count -gt 0) {
                $selectedIndex = $lvScripts.SelectedItems[0].Index
                if ($selectedIndex -ge 0 -and $selectedIndex -lt $script:Scripts.Count) {
                    $selectedScript = $script:Scripts[$selectedIndex]
                    Load-ScriptDetails -Script $selectedScript
                    Write-Log "Selected script: $($selectedScript.Name)" -Level "DEBUG"
                }
            } else {
                Clear-ScriptDetails
            }
            
            # Update button states
            Enable-ExecutionControls -Enable $true
        }
        
    } catch {
        Write-Log "Error in scripts ListView selection changed: $($_.Exception.Message)" -Level "ERROR"
    }
}

$lvParameters_SelectedIndexChanged = {
    try {
        $btnEditParam.Enabled = ($lvParameters.SelectedItems.Count -gt 0)
        $btnRemoveParam.Enabled = ($lvParameters.SelectedItems.Count -gt 0)
    } catch {
        Write-Log "Error in parameters ListView selection changed: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion


#region Connection Management

# Test Source Connection Button Click Event
$btnTestSourceConnection_Click = {
    try {
        Write-Log "Test Source Connection button clicked" -Level "DEBUG"
        
        # Get source server name from text box
        $serverName = ""
        
        # Try to get server name from possible source text boxes
        if ($script:txtSourceServer -and $script:txtSourceServer.Text) {
            $serverName = $script:txtSourceServer.Text.Trim()
        } elseif ($script:txtSourceVCenter -and $script:txtSourceVCenter.Text) {
            $serverName = $script:txtSourceVCenter.Text.Trim()
        } elseif ($script:sourceServerTextBox -and $script:sourceServerTextBox.Text) {
            $serverName = $script:sourceServerTextBox.Text.Trim()
        } else {
            # Check all text boxes to find the source server field
            $possibleSourceControls = @(
                'txtSourceServer', 'txtSourceVCenter', 'txtSource', 'sourceServerTextBox',
                'txtOriginServer', 'txtSrcVCenter', 'txtSrc'
            )
            
            foreach ($controlName in $possibleSourceControls) {
                $control = Get-Variable -Name $controlName -Scope Script -ErrorAction SilentlyContinue
                if ($control -and $control.Value -and $control.Value.Text) {
                    $serverName = $control.Value.Text.Trim()
                    Write-Log "Found source server in control: $controlName" -Level "DEBUG"
                    break
                }
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($serverName)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter the source vCenter server name or IP address first.",
                "No Source Server Specified",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        # Perform the connection test
        Test-ConnectionWithFeedback -ServerName $serverName -ConnectionType "Source vCenter" -Button $btnTestSourceConnection
        
    } catch {
        $errorMessage = "Error in Test Source Connection handler: $($_.Exception.Message)"
        Write-Log $errorMessage -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            $errorMessage,
            "Test Source Connection Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# Test Target Connection Button Click Event
$btnTestTargetConnection_Click = {
    try {
        Write-Log "Test Target Connection button clicked" -Level "DEBUG"
        
        # Get target server name from text box (adjust the control name as needed)
        $serverName = ""
        
        # Try to get server name from possible target text boxes
        if ($script:txtTargetServer -and $script:txtTargetServer.Text) {
            $serverName = $script:txtTargetServer.Text.Trim()
        } elseif ($script:txtTargetVCenter -and $script:txtTargetVCenter.Text) {
            $serverName = $script:txtTargetVCenter.Text.Trim()
        } elseif ($script:targetServerTextBox -and $script:targetServerTextBox.Text) {
            $serverName = $script:targetServerTextBox.Text.Trim()
        } else {
            # Check all text boxes to find the target server field
            $possibleTargetControls = @(
                'txtTargetServer', 'txtTargetVCenter', 'txtTarget', 'targetServerTextBox',
                'txtDestinationServer', 'txtDestVCenter', 'txtDest'
            )
            
            foreach ($controlName in $possibleTargetControls) {
                $control = Get-Variable -Name $controlName -Scope Script -ErrorAction SilentlyContinue
                if ($control -and $control.Value -and $control.Value.Text) {
                    $serverName = $control.Value.Text.Trim()
                    Write-Log "Found target server in control: $controlName" -Level "DEBUG"
                    break
                }
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($serverName)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter the target vCenter server name or IP address first.",
                "No Target Server Specified",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        # Perform the connection test
        Test-ConnectionWithFeedback -ServerName $serverName -ConnectionType "Target vCenter" -Button $btnTestTargetConnection
        
    } catch {
        $errorMessage = "Error in Test Target Connection handler: $($_.Exception.Message)"
        Write-Log $errorMessage -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            $errorMessage,
            "Test Target Connection Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnSaveConnection_Click = {
    try {
        Write-Log "Saving connection settings..." -Level "INFO"
        Save-ConnectionSettings
        [System.Windows.Forms.MessageBox]::Show(
            "Connection settings saved successfully!",
            "Settings Saved",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        Write-Log "Error saving connection settings: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error saving connection settings: $($_.Exception.Message)",
            "Save Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnLoadConnection_Click = {
    try {
        Write-Log "Loading connection settings..." -Level "INFO"
        Load-ConnectionSettings
        [System.Windows.Forms.MessageBox]::Show(
            "Connection settings loaded successfully!",
            "Settings Loaded",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        Write-Log "Error loading connection settings: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error loading connection settings: $($_.Exception.Message)",
            "Load Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

#region Fixed Connection Functions

function Invoke-TestSourceConnection {
    <#
    .SYNOPSIS
        Tests connection to source vCenter server
    #>
    try {
        # Get form values directly
        $serverInfo = @{
            Server = $txtSourceServer.Text.Trim()
            Username = $txtSourceUsername.Text.Trim()
            Password = $txtSourcePassword.Text
            UseCurrentCredentials = $chkUseCurrentCredentials.Checked
        }
        
        Write-Log "Testing source connection with server: $($serverInfo.Server)" -Level "DEBUG"
        Write-Log "Use current credentials: $($serverInfo.UseCurrentCredentials)" -Level "DEBUG"
        
        if (-not $serverInfo.UseCurrentCredentials) {
            Write-Log "Using specified credentials for user: $($serverInfo.Username)" -Level "DEBUG"
        }
        
        Test-vCenterConnection -ServerInfo $serverInfo -ServerType "Source"
        
    } catch {
        Write-Log "Error testing source connection: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Invoke-TestTargetConnection {
    <#
    .SYNOPSIS
        Tests connection to target vCenter server
    #>
    try {
        # Get form values directly
        $serverInfo = @{
            Server = $txtTargetServer.Text.Trim()
            Username = $txtTargetUsername.Text.Trim()
            Password = $txtTargetPassword.Text
            UseCurrentCredentials = $chkUseCurrentCredentials.Checked
        }
        
        Write-Log "Testing target connection with server: $($serverInfo.Server)" -Level "DEBUG"
        Write-Log "Use current credentials: $($serverInfo.UseCurrentCredentials)" -Level "DEBUG"
        
        if (-not $serverInfo.UseCurrentCredentials) {
            Write-Log "Using specified credentials for user: $($serverInfo.Username)" -Level "DEBUG"
        }
        
        Test-vCenterConnection -ServerInfo $serverInfo -ServerType "Target"
        
    } catch {
        Write-Log "Error testing target connection: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-vCenterConnection {
    <#
    .SYNOPSIS
        Tests vCenter server connection with improved credential handling
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ServerInfo,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Source", "Target")]
        [string]$ServerType
    )
    
    try {
        Write-Log "Testing $($ServerType) vCenter connection to: $($ServerInfo.Server)" -Level "INFO"
        
        # Validate inputs
        if ([string]::IsNullOrWhiteSpace($ServerInfo.Server)) {
            throw "$($ServerType) server address is required"
        }
        
        # Validate credentials if not using current user
        if (-not $ServerInfo.UseCurrentCredentials) {
            if ([string]::IsNullOrWhiteSpace($ServerInfo.Username)) {
                throw "$($ServerType) username is required when not using current credentials"
            }
            if ([string]::IsNullOrWhiteSpace($ServerInfo.Password)) {
                throw "$($ServerType) password is required when not using current credentials"
            }
        }
        
        # Update status
        $statusStripLabel.Text = "Testing $($ServerType) connection..."
        $statusStripLabel.ForeColor = [System.Drawing.Color]::Blue
        [System.Windows.Forms.Application]::DoEvents()
        
        # Import and configure PowerCLI
        Write-Log "Importing VMware PowerCLI modules..." -Level "DEBUG"
        #Import-Module VMware.PowerCLI -Force -ErrorAction Stop
        
        # Set PowerCLI configuration
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
        Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
        
        # Prepare credentials
        $credential = $null
        if (-not $ServerInfo.UseCurrentCredentials) {
            Write-Log "Creating credential object for user: $($ServerInfo.Username)" -Level "DEBUG"
            $securePassword = ConvertTo-SecureString $ServerInfo.Password -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($ServerInfo.Username, $securePassword)
        } else {
            Write-Log "Using current user credentials" -Level "DEBUG"
        }
        
        # Test connection
        Write-Log "Attempting to connect to $($ServerType) vCenter: $($ServerInfo.Server)" -Level "INFO"
        
        $connection = if ($credential) {
            Write-Log "Connecting with specified credentials..." -Level "DEBUG"
            Connect-VIServer -Server $ServerInfo.Server -Credential $credential -Force -ErrorAction Stop
        } else {
            Write-Log "Connecting with current user credentials..." -Level "DEBUG"
            Connect-VIServer -Server $ServerInfo.Server -Force -ErrorAction Stop
        }
        
        if ($connection) {
            Write-Log "$($ServerType) vCenter connection successful" -Level "INFO"
            
            # Get basic server info
            $serverVersion = $connection.Version
            $serverBuild = $connection.Build
            $connectedUser = $connection.User
            
            # Update status
            $statusStripLabel.Text = "$($ServerType) connection successful"
            $statusStripLabel.ForeColor = [System.Drawing.Color]::Green
            
            # Show success message
            [System.Windows.Forms.MessageBox]::Show(
                "$($ServerType) vCenter connection successful!`n`nServer: $($ServerInfo.Server)`nVersion: $($serverVersion)`nBuild: $($serverBuild)`nConnected as: $($connectedUser)",
                "Connection Successful",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            # Disconnect
            Disconnect-VIServer -Server $connection -Confirm:$false
            Write-Log "Disconnected from $($ServerType) vCenter" -Level "INFO"
            
        } else {
            throw "Failed to establish connection to $($ServerType) vCenter"
        }
        
    } catch {
        Write-Log "vCenter connection test failed for $($ServerType): $($_.Exception.Message)" -Level "ERROR"
        
        # Update status
        $statusStripLabel.Text = "$($ServerType) connection failed"
        $statusStripLabel.ForeColor = [System.Drawing.Color]::Red
        
        # Show error message
        [System.Windows.Forms.MessageBox]::Show(
            "$($ServerType) vCenter connection failed:`n`n$($_.Exception.Message)",
            "Connection Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        throw
    }
}

#endregion


function Save-ConnectionSettings {
    <#
    .SYNOPSIS
        Saves connection settings to configuration
    #>
    try {
        Write-Log "Saving connection settings..." -Level "INFO"
        
        # Update configuration
        $script:Config.SourceServer = $txtSourceServer.Text.Trim()
        $script:Config.SourceUsername = $txtSourceUsername.Text.Trim()
        $script:Config.TargetServer = $txtTargetServer.Text.Trim()
        $script:Config.TargetUsername = $txtTargetUsername.Text.Trim()
        $script:Config.UseCurrentCredentials = $chkUseCurrentCredentials.Checked
        
        # Save passwords securely (in production, consider more secure storage)
        if (-not [string]::IsNullOrWhiteSpace($txtSourcePassword.Text)) {
            $script:Config.SourcePassword = ConvertTo-SecureString $txtSourcePassword.Text -AsPlainText -Force
        }
        
        if (-not [string]::IsNullOrWhiteSpace($txtTargetPassword.Text)) {
            $script:Config.TargetPassword = ConvertTo-SecureString $txtTargetPassword.Text -AsPlainText -Force
        }
        
        # Save to file
        Save-Configuration -Config $script:Config
        
        Write-Log "Connection settings saved successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error saving connection settings: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Load-ConnectionSettings {
    <#
    .SYNOPSIS
        Loads connection settings from configuration
    #>
    try {
        Write-Log "Loading connection settings..." -Level "INFO"
        
        # Load configuration
        $script:Config = Load-Configuration
        
        # Update form controls
        $txtSourceServer.Text = $script:Config.SourceServer
        $txtSourceUsername.Text = $script:Config.SourceUsername
        $txtTargetServer.Text = $script:Config.TargetServer
        $txtTargetUsername.Text = $script:Config.TargetUsername
        $chkUseCurrentCredentials.Checked = $script:Config.UseCurrentCredentials
        
        # Load passwords (decrypt if needed)
        if ($script:Config.SourcePassword -is [System.Security.SecureString]) {
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:Config.SourcePassword)
            try {
                $txtSourcePassword.Text = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            } finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
        
        if ($script:Config.TargetPassword -is [System.Security.SecureString]) {
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:Config.TargetPassword)
            try {
                $txtTargetPassword.Text = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            } finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
        
        Write-Log "Connection settings loaded successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error loading connection settings: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Check-PowerCLI {
    <#
    .SYNOPSIS
        Checks if VMware PowerCLI is installed and available
    #>
    try {
        $powerCLIModule = Get-Module -Name VMware.PowerCLI -ListAvailable
        
        if ($powerCLIModule) {
            Write-Log "VMware PowerCLI found: Version $($powerCLIModule.Version)" -Level "INFO"
            return $true
        } else {
            Write-Log "VMware PowerCLI not found" -Level "WARNING"
            
            $result = [System.Windows.Forms.MessageBox]::Show(
                "VMware PowerCLI is required but not installed.`n`nWould you like to install it now?`n`nNote: This requires administrator privileges.",
                "PowerCLI Required",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                try {
                    Write-Log "Attempting to install VMware PowerCLI..." -Level "INFO"
                    Install-Module -Name VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser
                    Write-Log "VMware PowerCLI installed successfully" -Level "INFO"
                    return $true
                } catch {
                    Write-Log "Failed to install VMware PowerCLI: $($_.Exception.Message)" -Level "ERROR"
                    [System.Windows.Forms.MessageBox]::Show(
                        "Failed to install VMware PowerCLI:`n`n$($_.Exception.Message)",
                        "Installation Failed",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                    return $false
                }
            } else {
                return $false
            }
        }
    } catch {
        Write-Log "Error checking PowerCLI: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

#endregion


#region Script Management

$btnAddScript_Click = {
    try {
        Write-Log "Adding new script..." -Level "INFO"
        Add-NewScript
    } catch {
        Write-Log "Error in add script button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error adding script: $($_.Exception.Message)",
            "Add Script Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnRemoveScript_Click = {
    try {
        Write-Log "Removing selected script..." -Level "INFO"
        Remove-SelectedScript
    } catch {
        Write-Log "Error in remove script button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error removing script: $($_.Exception.Message)",
            "Remove Script Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnMoveUp_Click = {
    try {
        Write-Log "Moving script up..." -Level "DEBUG"
        Move-ScriptUp
    } catch {
        Write-Log "Error in move up button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error moving script up: $($_.Exception.Message)",
            "Move Script Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnMoveDown_Click = {
    try {
        Write-Log "Moving script down..." -Level "DEBUG"
        Move-ScriptDown
    } catch {
        Write-Log "Error in move down button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error moving script down: $($_.Exception.Message)",
            "Move Script Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnBrowse_Click = {
    try {
        Write-Log "Browsing for script file..." -Level "DEBUG"
        Browse-ScriptFile
    } catch {
        Write-Log "Error in browse button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error browsing for script: $($_.Exception.Message)",
            "Browse Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnSaveScriptDetails_Click = {
    try {
        Write-Log "Saving script details..." -Level "INFO"
        Save-ScriptDetails
    } catch {
        Write-Log "Error in save script details button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error saving script details: $($_.Exception.Message)",
            "Save Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Add-NewScript {
    <#
    .SYNOPSIS
        Adds a new script to the collection via file dialog with double-click prevention
    #>
    
    # Prevent multiple simultaneous executions
    if ($script:AddingScript) {
        Write-Log "Add script operation already in progress, ignoring duplicate call" -Level "DEBUG"
        return
    }
    
    try {
        $script:AddingScript = $true
        Write-Log "Starting add new script operation..." -Level "DEBUG"
        
        # Configure file dialog
        if (-not $script:openFileDialog1) {
            $script:openFileDialog1 = New-Object System.Windows.Forms.OpenFileDialog
        }
        
        $script:openFileDialog1.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $script:openFileDialog1.Title = "Select PowerShell Script"
        $script:openFileDialog1.Multiselect = $false
        $script:openFileDialog1.InitialDirectory = Get-ApplicationPath -RelativePath "" -BaseLocation "Root"
        $script:openFileDialog1.RestoreDirectory = $true
        
        Write-Log "Showing file dialog..." -Level "DEBUG"
        $dialogResult = $script:openFileDialog1.ShowDialog($mainForm)
        
        if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
            $scriptPath = $script:openFileDialog1.FileName
            
            Write-Log "User selected script file: $($scriptPath)" -Level "INFO"
            
            # Check if script already exists
            $existingScript = $script:Scripts | Where-Object { $_.Path -eq $scriptPath }
            if ($existingScript) {
                Write-Log "Script already exists in collection: $($scriptPath)" -Level "WARNING"
                [System.Windows.Forms.MessageBox]::Show(
                    "This script is already in the list.",
                    "Duplicate Script",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                return
            }
            
            # Validate script file exists
            if (-not (Test-Path -Path $scriptPath)) {
                Write-Log "Selected script file does not exist: $($scriptPath)" -Level "ERROR"
                [System.Windows.Forms.MessageBox]::Show(
                    "Selected script file does not exist.",
                    "File Not Found",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }
            
            # Create new script object
            $newScript = [PSCustomObject]@{
                Name = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
                Path = $scriptPath
                Description = ""
                Enabled = $true
                Order = $script:Scripts.Count + 1
                Parameters = @()
            }
            
            # Add to collection
            $script:Scripts += $newScript
            
            Write-Log "Script added successfully: $($newScript.Name)" -Level "INFO"
            
            # Update ListView
            Update-ScriptsListView
            
            # Select the new script
            $scriptsListView = $mainForm.Controls.Find("lvScripts", $true)
            if ($scriptsListView -and $scriptsListView.Count -gt 0) {
                $lvScripts = $scriptsListView[0]
                if ($lvScripts.Items.Count -gt 0) {
                    $newIndex = $script:Scripts.Count - 1
                    $lvScripts.Items[$newIndex].Selected = $true
                    $lvScripts.Items[$newIndex].EnsureVisible()
                    $lvScripts.Select()
                }
            }
            
            # Auto-detect parameters
            try {
                Write-Log "Auto-detecting parameters for: $($newScript.Name)" -Level "DEBUG"
                $detectedParams = Detect-ScriptParameters -Script $newScript
                if ($detectedParams.Count -gt 0) {
                    $newScript.Parameters = $detectedParams
                    Write-Log "Auto-detected $($detectedParams.Count) parameters for: $($newScript.Name)" -Level "INFO"
                    
                    # Refresh display if this script is selected
                    Load-ScriptDetails -Script $newScript
                }
            } catch {
                Write-Log "Could not auto-detect parameters for $($newScript.Name): $($_.Exception.Message)" -Level "WARNING"
            }
            
        } else {
            Write-Log "User cancelled script selection" -Level "DEBUG"
        }
        
    } catch {
        Write-Log "Error adding new script: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error adding script: $($_.Exception.Message)",
            "Add Script Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } finally {
        $script:AddingScript = $false
        Write-Log "Add script operation completed" -Level "DEBUG"
    }
}

function Remove-SelectedScript {
    <#
    .SYNOPSIS
        Removes the selected script from the collection
    #>
    try {
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a script to remove.",
                "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        $selectedIndex = $lvScripts.SelectedItems[0].Index
        $scriptToRemove = $script:Scripts[$selectedIndex]
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to remove the script '$($scriptToRemove.Name)'?",
            "Confirm Removal",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Remove from collection
            $script:Scripts = $script:Scripts | Where-Object { $_.Path -ne $scriptToRemove.Path }
            
            # Update order numbers
            for ($i = 0; $i -lt $script:Scripts.Count; $i++) {
                $script:Scripts[$i].Order = $i + 1
            }
            
            # Update ListView
            Update-ScriptsListView
            
            # Clear script details
            Clear-ScriptDetails
            
            Write-Log "Script removed successfully: $($scriptToRemove.Name)" -Level "INFO"
        }
        
    } catch {
        Write-Log "Error removing selected script: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Move-ScriptUp {
    <#
    .SYNOPSIS
        Moves the selected script up in the execution order
    #>
    try {
        if ($lvScripts.SelectedItems.Count -eq 0) {
            return
        }
        
        $selectedIndex = $lvScripts.SelectedItems[0].Index
        
        if ($selectedIndex -eq 0) {
            return # Already at top
        }
        
        # Swap scripts
        $temp = $script:Scripts[$selectedIndex]
        $script:Scripts[$selectedIndex] = $script:Scripts[$selectedIndex - 1]
        $script:Scripts[$selectedIndex - 1] = $temp
        
        # Update order numbers
        $script:Scripts[$selectedIndex].Order = $selectedIndex + 1
        $script:Scripts[$selectedIndex - 1].Order = $selectedIndex
        
        # Update ListView
        Update-ScriptsListView
        
        # Maintain selection
        $lvScripts.Items[$selectedIndex - 1].Selected = $true
        $lvScripts.Select()
        
        Write-Log "Script moved up: $($temp.Name)" -Level "DEBUG"
        
    } catch {
        Write-Log "Error moving script up: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Move-ScriptDown {
    <#
    .SYNOPSIS
        Moves the selected script down in the execution order
    #>
    try {
        if ($lvScripts.SelectedItems.Count -eq 0) {
            return
        }
        
        $selectedIndex = $lvScripts.SelectedItems[0].Index
        
        if ($selectedIndex -eq ($script:Scripts.Count - 1)) {
            return # Already at bottom
        }
        
        # Swap scripts
        $temp = $script:Scripts[$selectedIndex]
        $script:Scripts[$selectedIndex] = $script:Scripts[$selectedIndex + 1]
        $script:Scripts[$selectedIndex + 1] = $temp
        
        # Update order numbers
        $script:Scripts[$selectedIndex].Order = $selectedIndex + 1
        $script:Scripts[$selectedIndex + 1].Order = $selectedIndex + 2
        
        # Update ListView
        Update-ScriptsListView
        
        # Maintain selection
        $lvScripts.Items[$selectedIndex + 1].Selected = $true
        $lvScripts.Select()
        
        Write-Log "Script moved down: $($temp.Name)" -Level "DEBUG"
        
    } catch {
        Write-Log "Error moving script down: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Browse-ScriptFile {
    <#
    .SYNOPSIS
        Opens file dialog to browse for script file and updates the path textbox
    #>
    try {
        $openFileDialog1.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $openFileDialog1.Title = "Select PowerShell Script"
        $openFileDialog1.Multiselect = $false
        
        if ($openFileDialog1.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtScriptPath.Text = $openFileDialog1.FileName
            
            # Auto-populate name if empty
            if ([string]::IsNullOrWhiteSpace($txtScriptName.Text)) {
                $txtScriptName.Text = [System.IO.Path]::GetFileNameWithoutExtension($openFileDialog1.FileName)
            }
            
            Write-Log "Script path selected: $($openFileDialog1.FileName)" -Level "DEBUG"
        }
        
    } catch {
        Write-Log "Error browsing for script file: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Update-ScriptsListView {
    <#
    .SYNOPSIS
        Updates the scripts ListView with current script collection
    #>
    try {
        Write-Log "Updating scripts ListView with $($script:Scripts.Count) scripts..." -Level "DEBUG"
        
        # Store current selection
        $selectedIndex = -1
        if ($lvScripts.SelectedItems.Count -gt 0) {
            $selectedIndex = $lvScripts.SelectedItems[0].Index
        }
        
        # Clear existing items
        $lvScripts.Items.Clear()
        
        # Add scripts to ListView
        for ($i = 0; $i -lt $script:Scripts.Count; $i++) {
            $scriptItem = $script:Scripts[$i]
            
            # Update order to match index
            $scriptItem.Order = $i + 1
            
            # Create ListView item
            $listViewItem = New-Object System.Windows.Forms.ListViewItem($scriptItem.Order.ToString())
            $listViewItem.SubItems.Add($scriptItem.Name) | Out-Null
            $listViewItem.SubItems.Add($scriptItem.Description) | Out-Null
            $listViewItem.SubItems.Add($scriptItem.Enabled.ToString()) | Out-Null
            $listViewItem.SubItems.Add($scriptItem.Path) | Out-Null
            
            # Color coding for enabled/disabled
            if (-not $scriptItem.Enabled) {
                $listViewItem.ForeColor = [System.Drawing.Color]::Gray
            } else {
                $listViewItem.ForeColor = [System.Drawing.Color]::Black
            }
            
            $lvScripts.Items.Add($listViewItem) | Out-Null
        }
        
        # Restore selection if valid
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $lvScripts.Items.Count) {
            $lvScripts.Items[$selectedIndex].Selected = $true
            $lvScripts.Items[$selectedIndex].EnsureVisible()
        }
        
        # Update execution controls
        Enable-ExecutionControls -Enable $true
        
        Write-Log "Scripts ListView updated successfully" -Level "DEBUG"
        
    } catch {
        Write-Log "Error updating scripts ListView: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Load-ScriptDetails {
    <#
    .SYNOPSIS
        Loads script details into the form controls with safe control access
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Script
    )
    
    try {
        Write-Log "Loading script details for: $($Script.Name)" -Level "DEBUG"
        
        # Safely access controls by finding them in the form
        $scriptNameControl = $mainForm.Controls.Find("txtScriptName", $true)
        $scriptPathControl = $mainForm.Controls.Find("txtScriptPath", $true)
        $scriptDescControl = $mainForm.Controls.Find("txtScriptDescription", $true)
        $scriptEnabledControl = $mainForm.Controls.Find("chkScriptEnabled", $true)
        
        # Alternative names to try
        if (-not $scriptNameControl) { $scriptNameControl = $mainForm.Controls.Find("textBoxScriptName", $true) }
        if (-not $scriptPathControl) { $scriptPathControl = $mainForm.Controls.Find("textBoxScriptPath", $true) }
        if (-not $scriptDescControl) { $scriptDescControl = $mainForm.Controls.Find("textBoxDescription", $true) }
        if (-not $scriptEnabledControl) { $scriptEnabledControl = $mainForm.Controls.Find("checkBoxEnabled", $true) }
        
        # Load basic details if controls exist
        if ($scriptNameControl -and $scriptNameControl.Count -gt 0) {
            $scriptNameControl[0].Text = $Script.Name
            Write-Log "Set script name: $($Script.Name)" -Level "DEBUG"
        } else {
            Write-Log "Script name control not found" -Level "WARNING"
        }
        
        if ($scriptPathControl -and $scriptPathControl.Count -gt 0) {
            $scriptPathControl[0].Text = $Script.Path
            Write-Log "Set script path: $($Script.Path)" -Level "DEBUG"
        } else {
            Write-Log "Script path control not found" -Level "WARNING"
        }
        
        if ($scriptDescControl -and $scriptDescControl.Count -gt 0) {
            $scriptDescControl[0].Text = $Script.Description
            Write-Log "Set script description" -Level "DEBUG"
        } else {
            Write-Log "Script description control not found" -Level "WARNING"
        }
        
        if ($scriptEnabledControl -and $scriptEnabledControl.Count -gt 0) {
            $scriptEnabledControl[0].Checked = $Script.Enabled
            Write-Log "Set script enabled: $($Script.Enabled)" -Level "DEBUG"
        } else {
            Write-Log "Script enabled control not found" -Level "WARNING"
        }
        
        # Load parameters
        Load-ParametersListView -Parameters $Script.Parameters
        
        Write-Log "Script details loaded successfully" -Level "DEBUG"
        
    } catch {
        Write-Log "Error loading script details: $($_.Exception.Message)" -Level "ERROR"
        # Don't call Clear-ScriptDetails here to avoid recursion
    }
}
function Clear-ScriptDetails {
    <#
    .SYNOPSIS
        Clears all script detail controls safely
    #>
    try {
        Write-Log "Clearing script details..." -Level "DEBUG"
        
        # Safely access controls
        $scriptNameControl = $mainForm.Controls.Find("txtScriptName", $true)
        $scriptPathControl = $mainForm.Controls.Find("txtScriptPath", $true)
        $scriptDescControl = $mainForm.Controls.Find("txtScriptDescription", $true)
        $scriptEnabledControl = $mainForm.Controls.Find("chkScriptEnabled", $true)
        
        # Alternative names
        if (-not $scriptNameControl) { $scriptNameControl = $mainForm.Controls.Find("textBoxScriptName", $true) }
        if (-not $scriptPathControl) { $scriptPathControl = $mainForm.Controls.Find("textBoxScriptPath", $true) }
        if (-not $scriptDescControl) { $scriptDescControl = $mainForm.Controls.Find("textBoxDescription", $true) }
        if (-not $scriptEnabledControl) { $scriptEnabledControl = $mainForm.Controls.Find("checkBoxEnabled", $true) }
        
        # Clear controls if they exist
        if ($scriptNameControl -and $scriptNameControl.Count -gt 0) {
            $scriptNameControl[0].Text = ""
        }
        
        if ($scriptPathControl -and $scriptPathControl.Count -gt 0) {
            $scriptPathControl[0].Text = ""
        }
        
        if ($scriptDescControl -and $scriptDescControl.Count -gt 0) {
            $scriptDescControl[0].Text = ""
        }
        
        if ($scriptEnabledControl -and $scriptEnabledControl.Count -gt 0) {
            $scriptEnabledControl[0].Checked = $true
        }
        
        # Clear parameters
        $parametersControl = $mainForm.Controls.Find("lvParameters", $true)
        if (-not $parametersControl) { $parametersControl = $mainForm.Controls.Find("listViewParameters", $true) }
        
        if ($parametersControl -and $parametersControl.Count -gt 0) {
            $parametersControl[0].Items.Clear()
        }
        
        Write-Log "Script details cleared" -Level "DEBUG"
        
    } catch {
        Write-Log "Error clearing script details: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Save-ScriptDetails {
    <#
    .SYNOPSIS
        Saves the current script details to the selected script safely
    #>
    try {
        # Find the scripts ListView
        $scriptsListView = $mainForm.Controls.Find("lvScripts", $true)
        if (-not $scriptsListView) { $scriptsListView = $mainForm.Controls.Find("listViewScripts", $true) }
        
        if (-not $scriptsListView -or $scriptsListView.Count -eq 0) {
            Write-Log "Scripts ListView not found" -Level "ERROR"
            return
        }
        
        $lvScripts = $scriptsListView[0]
        
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a script to save details for.",
                "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        # Get form controls
        $scriptNameControl = $mainForm.Controls.Find("txtScriptName", $true)
        $scriptPathControl = $mainForm.Controls.Find("txtScriptPath", $true)
        $scriptDescControl = $mainForm.Controls.Find("txtScriptDescription", $true)
        $scriptEnabledControl = $mainForm.Controls.Find("chkScriptEnabled", $true)
        
        # Alternative names
        if (-not $scriptNameControl) { $scriptNameControl = $mainForm.Controls.Find("textBoxScriptName", $true) }
        if (-not $scriptPathControl) { $scriptPathControl = $mainForm.Controls.Find("textBoxScriptPath", $true) }
        if (-not $scriptDescControl) { $scriptDescControl = $mainForm.Controls.Find("textBoxDescription", $true) }
        if (-not $scriptEnabledControl) { $scriptEnabledControl = $mainForm.Controls.Find("checkBoxEnabled", $true) }
        
        # Validate required controls exist
        if (-not $scriptNameControl -or $scriptNameControl.Count -eq 0) {
            Write-Log "Script name control not found" -Level "ERROR"
            return
        }
        
        if (-not $scriptPathControl -or $scriptPathControl.Count -eq 0) {
            Write-Log "Script path control not found" -Level "ERROR"
            return
        }
        
        # Get values
        $scriptName = $scriptNameControl[0].Text.Trim()
        $scriptPath = $scriptPathControl[0].Text.Trim()
        $scriptDesc = if ($scriptDescControl -and $scriptDescControl.Count -gt 0) { $scriptDescControl[0].Text.Trim() } else { "" }
        $scriptEnabled = if ($scriptEnabledControl -and $scriptEnabledControl.Count -gt 0) { $scriptEnabledControl[0].Checked } else { $true }
        
        # Validate inputs
        if ([string]::IsNullOrWhiteSpace($scriptName)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Script name is required.",
                "Validation Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Script path is required.",
                "Validation Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        if (-not (Test-Path -Path $scriptPath)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Script file does not exist: $($scriptPath)",
                "File Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        # Get selected script
        $selectedIndex = $lvScripts.SelectedItems[0].Index
        $selectedScript = $script:Scripts[$selectedIndex]
        
        # Update script details
        $selectedScript.Name = $scriptName
        $selectedScript.Path = $scriptPath
        $selectedScript.Description = $scriptDesc
        $selectedScript.Enabled = $scriptEnabled
        
        # Update parameters from ListView
        $selectedScript.Parameters = Get-ParametersFromListView
        
        # Update ListView
        Update-ScriptsListView
        
        # Maintain selection
        if ($selectedIndex -lt $lvScripts.Items.Count) {
            $lvScripts.Items[$selectedIndex].Selected = $true
        }
        
        # Save configuration
        Save-Configuration -Config $script:Config
        
        Write-Log "Script details saved successfully: $($selectedScript.Name)" -Level "INFO"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Script details saved successfully!",
            "Save Successful",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
    } catch {
        Write-Log "Error saving script details: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error saving script details: $($_.Exception.Message)",
            "Save Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Get-SelectedScript {
    <#
    .SYNOPSIS
        Gets the currently selected script object
    #>
    try {
        if ($lvScripts.SelectedItems.Count -gt 0) {
            $selectedIndex = $lvScripts.SelectedItems[0].Index
            return $script:Scripts[$selectedIndex]
        }
        return $null
    } catch {
        Write-Log "Error getting selected script: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

#endregion

#region Parameter Management

$btnAddParam_Click = {
    try {
        Write-Log "Adding new parameter..." -Level "DEBUG"
        Add-NewParameter
    } catch {
        Write-Log "Error in add parameter button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error adding parameter: $($_.Exception.Message)",
            "Add Parameter Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnEditParam_Click = {
    try {
        Write-Log "Editing selected parameter..." -Level "DEBUG"
        Edit-SelectedParameter
    } catch {
        Write-Log "Error in edit parameter button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error editing parameter: $($_.Exception.Message)",
            "Edit Parameter Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnRemoveParam_Click = {
    try {
        Write-Log "Removing selected parameter..." -Level "DEBUG"
        Remove-SelectedParameter
    } catch {
        Write-Log "Error in remove parameter button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error removing parameter: $($_.Exception.Message)",
            "Remove Parameter Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnDetectParams_Click = {
    try {
        Write-Log "Detecting script parameters..." -Level "INFO"
        Detect-CurrentScriptParameters
    } catch {
        Write-Log "Error in detect parameters button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error detecting parameters: $($_.Exception.Message)",
            "Parameter Detection Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Add-NewParameter {
    <#
    .SYNOPSIS
        Opens dialog to add a new parameter
    #>
    try {
        # Create parameter input form
        $paramForm = New-Object System.Windows.Forms.Form
        $paramForm.Text = "Add Parameter"
        $paramForm.Size = New-Object System.Drawing.Size(400, 300)
        $paramForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
        $paramForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
        $paramForm.MaximizeBox = $false
        $paramForm.MinimizeBox = $false
        
        # Name label and textbox
        $lblName = New-Object System.Windows.Forms.Label
        $lblName.Text = "Parameter Name:"
        $lblName.Location = New-Object System.Drawing.Point(10, 20)
        $lblName.Size = New-Object System.Drawing.Size(100, 20)
        $paramForm.Controls.Add($lblName)
        
        $txtName = New-Object System.Windows.Forms.TextBox
        $txtName.Location = New-Object System.Drawing.Point(120, 18)
        $txtName.Size = New-Object System.Drawing.Size(250, 20)
        $paramForm.Controls.Add($txtName)
        
        # Value label and textbox
        $lblValue = New-Object System.Windows.Forms.Label
        $lblValue.Text = "Parameter Value:"
        $lblValue.Location = New-Object System.Drawing.Point(10, 50)
        $lblValue.Size = New-Object System.Drawing.Size(100, 20)
        $paramForm.Controls.Add($lblValue)
        
        $txtValue = New-Object System.Windows.Forms.TextBox
        $txtValue.Location = New-Object System.Drawing.Point(120, 48)
        $txtValue.Size = New-Object System.Drawing.Size(250, 20)
        $paramForm.Controls.Add($txtValue)
        
        # Type label and combobox
        $lblType = New-Object System.Windows.Forms.Label
        $lblType.Text = "Parameter Type:"
        $lblType.Location = New-Object System.Drawing.Point(10, 80)
        $lblType.Size = New-Object System.Drawing.Size(100, 20)
        $paramForm.Controls.Add($lblType)
        
        $cboType = New-Object System.Windows.Forms.ComboBox
        $cboType.Location = New-Object System.Drawing.Point(120, 78)
        $cboType.Size = New-Object System.Drawing.Size(150, 20)
        $cboType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
        $parameterTypes = @("String", "Int32", "Boolean", "PSCredential", "SecureString", "DateTime", "Double")
        foreach ($type in $parameterTypes) {
            $cboType.Items.Add($type) | Out-Null
        }
        $cboType.SelectedIndex = 0
        $paramForm.Controls.Add($cboType)
        
        # Description label and textbox
        $lblDescription = New-Object System.Windows.Forms.Label
        $lblDescription.Text = "Description:"
        $lblDescription.Location = New-Object System.Drawing.Point(10, 110)
        $lblDescription.Size = New-Object System.Drawing.Size(100, 20)
        $paramForm.Controls.Add($lblDescription)
        
        $txtDescription = New-Object System.Windows.Forms.TextBox
        $txtDescription.Location = New-Object System.Drawing.Point(120, 108)
        $txtDescription.Size = New-Object System.Drawing.Size(250, 60)
        $txtDescription.Multiline = $true
        $txtDescription.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
        $paramForm.Controls.Add($txtDescription)
        
        # Buttons
        $btnOK = New-Object System.Windows.Forms.Button
        $btnOK.Text = "OK"
        $btnOK.Location = New-Object System.Drawing.Point(200, 220)
        $btnOK.Size = New-Object System.Drawing.Size(75, 25)
        $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $paramForm.Controls.Add($btnOK)
        
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = "Cancel"
        $btnCancel.Location = New-Object System.Drawing.Point(295, 220)
        $btnCancel.Size = New-Object System.Drawing.Size(75, 25)
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $paramForm.Controls.Add($btnCancel)
        
        $paramForm.AcceptButton = $btnOK
        $paramForm.CancelButton = $btnCancel
        
        # Show dialog
        if ($paramForm.ShowDialog($mainForm) -eq [System.Windows.Forms.DialogResult]::OK) {
            # Validate input
            if ([string]::IsNullOrWhiteSpace($txtName.Text)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Parameter name is required.",
                    "Validation Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                return
            }
            
            # Check for duplicate parameter names
            $existingParams = Get-ParametersFromListView
            if ($existingParams | Where-Object { $_.Name -eq $txtName.Text.Trim() }) {
                [System.Windows.Forms.MessageBox]::Show(
                    "A parameter with this name already exists.",
                    "Duplicate Parameter",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                return
            }
            
            # Create new parameter
            $newParameter = [PSCustomObject]@{
                Name = $txtName.Text.Trim()
                Value = $txtValue.Text
                Type = $cboType.SelectedItem.ToString()
                Description = $txtDescription.Text.Trim()
            }
            
            # Add to ListView
            Add-ParameterToListView -Parameter $newParameter
            
            Write-Log "Parameter added: $($newParameter.Name)" -Level "INFO"
        }
        
        $paramForm.Dispose()
        
    } catch {
        Write-Log "Error adding new parameter: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Edit-SelectedParameter {
    <#
    .SYNOPSIS
        Opens dialog to edit the selected parameter
    #>
    try {
        if ($lvParameters.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a parameter to edit.",
                "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        # Get selected parameter
        $selectedItem = $lvParameters.SelectedItems[0]
        $parameterInfo = [PSCustomObject]@{
            Name = $selectedItem.SubItems[0].Text
            Value = $selectedItem.SubItems[1].Text
            Type = $selectedItem.SubItems[2].Text
            Description = $selectedItem.SubItems[3].Text
        }
        
        # Set script scope variables for the edit form
        $script:EditParameterInfo = $parameterInfo
        $script:Config = $script:Config
        
        # Load and show edit parameter form
        $editFormPath = Get-ApplicationPath -RelativePath "EditParameterForm.ps1" -BaseLocation "SubForms"
        if (Test-Path -Path $editFormPath) {
            . $editFormPath
            
            if ($EditParameterForm.ShowDialog($mainForm) -eq [System.Windows.Forms.DialogResult]::OK) {
                # Get updated parameter from form
                $updatedParameter = $EditParameterForm.Tag
                
                if ($updatedParameter) {
                    # Update ListView item
                    $selectedItem.SubItems[0].Text = $updatedParameter.Name
                    $selectedItem.SubItems[1].Text = Get-ParameterDisplayValue -Parameter $updatedParameter
                    $selectedItem.SubItems[2].Text = $updatedParameter.Type
                    $selectedItem.SubItems[3].Text = $updatedParameter.Description
                    
                    Write-Log "Parameter updated: $($updatedParameter.Name)" -Level "INFO"
                }
            }
            
            $EditParameterForm.Dispose()
        } else {
            Write-Log "EditParameterForm.ps1 not found at: $($editFormPath)" -Level "ERROR"
            [System.Windows.Forms.MessageBox]::Show(
                "Edit parameter form not found. Please ensure EditParameterForm.ps1 exists in the application directory.",
                "Form Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        
    } catch {
        Write-Log "Error editing selected parameter: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Remove-SelectedParameter {
    <#
    .SYNOPSIS
        Removes the selected parameter from the list
    #>
    try {
        if ($lvParameters.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a parameter to remove.",
                "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        $selectedItem = $lvParameters.SelectedItems[0]
        $parameterName = $selectedItem.SubItems[0].Text
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to remove the parameter '$($parameterName)'?",
            "Confirm Removal",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            $lvParameters.Items.Remove($selectedItem)
            Write-Log "Parameter removed: $($parameterName)" -Level "INFO"
        }
        
    } catch {
        Write-Log "Error removing selected parameter: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Detect-CurrentScriptParameters {
    <#
    .SYNOPSIS
        Detects parameters for the currently selected script
    #>
    try {
        if ([string]::IsNullOrWhiteSpace($txtScriptPath.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please specify a script path first.",
                "No Script Path",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        if (-not (Test-Path -Path $txtScriptPath.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Script file does not exist: $($txtScriptPath.Text)",
                "File Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        # Create temporary script object
        $tempScript = [PSCustomObject]@{
            Name = $txtScriptName.Text
            Path = $txtScriptPath.Text
            Parameters = @()
        }
        
        # Detect parameters
        $detectedParams = Detect-ScriptParameters -Script $tempScript
        
        if ($detectedParams.Count -gt 0) {
            # Ask user if they want to replace existing parameters
            $existingParams = Get-ParametersFromListView
            if ($existingParams.Count -gt 0) {
                $result = [System.Windows.Forms.MessageBox]::Show(
                    "This will replace all existing parameters with detected ones. Continue?",
                    "Replace Parameters",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Question
                )
                
                if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                    return
                }
            }
            
            # Clear existing parameters and add detected ones
            $lvParameters.Items.Clear()
            Load-ParametersListView -Parameters $detectedParams
            
            Write-Log "Detected $($detectedParams.Count) parameters for script: $($txtScriptName.Text)" -Level "INFO"
            
            [System.Windows.Forms.MessageBox]::Show(
                "Successfully detected $($detectedParams.Count) parameter(s)!",
                "Parameters Detected",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "No parameters detected in the script.",
                "No Parameters Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        
    } catch {
        Write-Log "Error detecting current script parameters: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Detect-ScriptParameters {
    <#
    .SYNOPSIS
        Detects parameters in a PowerShell script using AST parsing
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Script
    )
    
    try {
        Write-Log "Detecting parameters for script: $($Script.Path)" -Level "DEBUG"
        
        if (-not (Test-Path -Path $Script.Path)) {
            Write-Log "Script file not found: $($Script.Path)" -Level "WARNING"
            return @()
        }
        
        # Read script content
        $scriptContent = Get-Content -Path $Script.Path -Raw -Encoding UTF8
        
        # Parse script using AST
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$tokens, [ref]$parseErrors)
        
        if ($parseErrors.Count -gt 0) {
            Write-Log "Parse errors in script $($Script.Path): $($parseErrors -join '; ')" -Level "WARNING"
        }
        
        # Find param blocks
        $paramBlocks = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ParamBlockAst]
        }, $true)
        
        $detectedParameters = @()
        
        foreach ($paramBlock in $paramBlocks) {
            foreach ($parameter in $paramBlock.Parameters) {
                $paramName = $parameter.Name.VariablePath.UserPath
                $paramType = "String" # Default type
                $defaultValue = ""
                $description = ""
                
                # Get parameter type
                if ($parameter.StaticType) {
                    $paramType = $parameter.StaticType.Name
                }
                
                # Get default value
                if ($parameter.DefaultValue) {
                    $defaultValue = $parameter.DefaultValue.ToString()
                }
                
                # Look for help comments
                $helpComment = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.Language.AttributeAst] -and $_.TypeName.Name -eq "Parameter" }
                if ($helpComment) {
                    # Extract help text if available
                    $description = "Parameter with attributes"
                }
                
                $detectedParam = [PSCustomObject]@{
                    Name = $paramName
                    Value = $defaultValue
                    Type = $paramType
                    Description = $description
                }
                
                $detectedParameters += $detectedParam
                Write-Log "Detected parameter: $($paramName) ($($paramType))" -Level "DEBUG"
            }
        }
        
        Write-Log "Detected $($detectedParameters.Count) parameters in script: $($Script.Path)" -Level "INFO"
        return $detectedParameters
        
    } catch {
        Write-Log "Error detecting script parameters: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Load-ParametersListView {
    <#
    .SYNOPSIS
        Loads parameters into the ListView
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Parameters
    )
    
    try {
        Write-Log "Loading $($Parameters.Count) parameters into ListView..." -Level "DEBUG"
        
        # Clear existing items
        $lvParameters.Items.Clear()
        
        # Add parameters to ListView
        foreach ($param in $Parameters) {
            Add-ParameterToListView -Parameter $param
        }
        
        Write-Log "Parameters loaded into ListView successfully" -Level "DEBUG"
        
    } catch {
        Write-Log "Error loading parameters into ListView: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Add-ParameterToListView {
    <#
    .SYNOPSIS
        Adds a single parameter to the ListView
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Parameter
    )
    
    try {
        $listViewItem = New-Object System.Windows.Forms.ListViewItem($Parameter.Name)
        $listViewItem.SubItems.Add((Get-ParameterDisplayValue -Parameter $Parameter)) | Out-Null
        $listViewItem.SubItems.Add($Parameter.Type) | Out-Null
        $listViewItem.SubItems.Add($Parameter.Description) | Out-Null
        
        $lvParameters.Items.Add($listViewItem) | Out-Null
        
    } catch {
        Write-Log "Error adding parameter to ListView: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-ParametersFromListView {
    <#
    .SYNOPSIS
        Gets all parameters from the ListView as objects
    #>
    try {
        $parameters = @()
        
        foreach ($item in $lvParameters.Items) {
            $parameter = [PSCustomObject]@{
                Name = $item.SubItems[0].Text
                Value = $item.SubItems[1].Text
                Type = $item.SubItems[2].Text
                Description = $item.SubItems[3].Text
            }
            $parameters += $parameter
        }
        
        return $parameters
        
    } catch {
        Write-Log "Error getting parameters from ListView: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

function Get-ParameterDisplayValue {
    <#
    .SYNOPSIS
        Gets the display value for a parameter based on its type and content
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Parameter
    )
    
    try {
        $value = $Parameter.Value
        
        # Handle special values
        switch ($value) {
            "SourcevCenter" { return "Source vCenter Server" }
            "TargetvCenter" { return "Target vCenter Server" }
            "SourceCredential" { return "Source vCenter Credentials" }
            "TargetCredential" { return "Target vCenter Credentials" }
            default {
                # Handle by type
                switch ($Parameter.Type) {
                    "PSCredential" {
                        if ([string]::IsNullOrWhiteSpace($value)) {
                            return "[No Credential Set]"
                        } else {
                            return "[Credential: $($value)]"
                        }
                    }
                    "SecureString" {
                        if ([string]::IsNullOrWhiteSpace($value)) {
                            return "[No Secure String Set]"
                        } else {
                            return "[Secure String]"
                        }
                    }
                    default {
                        return $value
                    }
                }
            }
        }
    } catch {
        Write-Log "Error getting parameter display value: $($_.Exception.Message)" -Level "ERROR"
        return $Parameter.Value
    }
}

#endregion

#region Execution Management

$btnRunAll_Click = {
    try {
        Write-Log "Run All button clicked" -Level "INFO"
        
        # Validate that scripts are available
        $enabledScripts = $script:Scripts | Where-Object { $_.Enabled -eq $true }
        if ($enabledScripts.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "No enabled scripts available for execution.",
                "No Scripts",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        # Confirm execution unless skip confirmation is checked
        if (-not $chkSkipConfirmation.Checked) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Are you sure you want to run all $($enabledScripts.Count) enabled script(s)?",
                "Confirm Execution",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return
            }
        }
        
        # Start execution
        Start-ScriptExecution
        
    } catch {
        Write-Log "Error in Run All button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error starting script execution: $($_.Exception.Message)",
            "Execution Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnRunSelected_Click = {
    try {
        Write-Log "Run Selected button clicked" -Level "INFO"
        
        # Validate selection
        if ($lvScripts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a script to run.",
                "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        # Get selected script
        $selectedIndex = $lvScripts.SelectedItems[0].Index
        $selectedScript = $script:Scripts[$selectedIndex]
        
        # Check if script is enabled
        if (-not $selectedScript.Enabled) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "The selected script is disabled. Do you want to run it anyway?",
                "Script Disabled",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return
            }
        }
        
        # Confirm execution unless skip confirmation is checked
        if (-not $chkSkipConfirmation.Checked) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Are you sure you want to run the script '$($selectedScript.Name)'?",
                "Confirm Execution",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return
            }
        }
        
        # Start execution with specific script
        Start-ScriptExecution -SpecificScript $selectedScript
        
    } catch {
        Write-Log "Error in Run Selected button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error starting script execution: $($_.Exception.Message)",
            "Execution Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnStopExecution_Click = {
    try {
        Write-Log "Stop Execution button clicked" -Level "INFO"
        Stop-ScriptExecution
    } catch {
        Write-Log "Error in Stop Execution button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error stopping script execution: $($_.Exception.Message)",
            "Stop Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Start-ScriptExecution {
    <#
    .SYNOPSIS
        Starts script execution in background with enhanced error handling and UI updates
    #>
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$SpecificScript = $null
    )
    
    try {
        Write-Log "Starting script execution..." -Level "INFO"
        
        # Validate form state
        $validationErrors = Test-FormValidation
        if ($validationErrors.Count -gt 0) {
            $errorMessage = "Validation errors:`n" + ($validationErrors -join "`n")
            [System.Windows.Forms.MessageBox]::Show($errorMessage, "Validation Error", 
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        # Update execution configuration
        Update-ExecutionConfiguration
        
        # Update UI state to running
        Update-UIState -State "Running"
        
        # Reset stop flag
        $script:StopExecution = $false
        
        # Create PowerShell runspace for background execution
        $script:ExecutionRunspace = [runspacefactory]::CreateRunspace()
        $script:ExecutionRunspace.Open()
        
        # Add required variables to runspace
        $script:ExecutionRunspace.SessionStateProxy.SetVariable("Config", $script:Config)
        $script:ExecutionRunspace.SessionStateProxy.SetVariable("Scripts", $script:Scripts)
        $script:ExecutionRunspace.SessionStateProxy.SetVariable("SpecificScript", $SpecificScript)
        $script:ExecutionRunspace.SessionStateProxy.SetVariable("MainForm", $mainForm)
        $script:ExecutionRunspace.SessionStateProxy.SetVariable("LogPath", $script:LogPath)
        
        # Create PowerShell instance
        $script:ExecutionPowerShell = [powershell]::Create()
        $script:ExecutionPowerShell.Runspace = $script:ExecutionRunspace
        
        # Add the execution script block
        $executionScriptBlock = {
            param($Config, $Scripts, $SpecificScript, $MainForm, $LogPath)
            
            # Import required modules and functions
            if (Get-Module VMware.PowerCLI -ListAvailable) {
                Import-Module VMware.PowerCLI -Force
            }
            
            # Define thread-safe UI update function
            function Update-UIThreadSafe {
                param(
                    [string]$ControlName,
                    [string]$Property,
                    [object]$Value
                )
                
                try {
                    $MainForm.Invoke([System.Action]{
                        $control = $MainForm.Controls.Find($ControlName, $true)[0]
                        if ($control) {
                            $control.$Property = $Value
                        }
                    })
                } catch {
                    # Ignore invoke errors if form is closing
                }
            }
            
            # Define thread-safe logging function
            function Write-ExecutionLog {
                param([string]$Message, [string]$Level = "INFO")
                
                try {
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $logMessage = "[$($timestamp)] [$($Level)] $($Message)"
                    
                    # Write to file
                    Add-Content -Path $LogPath -Value $logMessage -Encoding UTF8
                    
                    # Update UI log
                    $MainForm.Invoke([System.Action]{
                        $txtExecutionOutput = $MainForm.Controls.Find("txtExecutionOutput", $true)[0]
                        if ($txtExecutionOutput) {
                            $txtExecutionOutput.AppendText("$($logMessage)`r`n")
                            $txtExecutionOutput.ScrollToCaret()
                        }
                    })
                } catch {
                    # Ignore logging errors during shutdown
                }
            }
            
            # Define credential helper function
            function Get-VCenterCredential {
                param(
                    [string]$ServerType,
                    [hashtable]$Config
                )
                
                if ($Config.UseCurrentCredentials) {
                    return [System.Management.Automation.PSCredential]::Empty
                } else {
                    $username = if ($ServerType -eq "Source") { $Config.SourceUsername } else { $Config.TargetUsername }
                    $password = if ($ServerType -eq "Source") { $Config.SourcePassword } else { $Config.TargetPassword }
                    
                    if ($password -is [System.Security.SecureString]) {
                        return New-Object System.Management.Automation.PSCredential($username, $password)
                    } else {
                        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                        return New-Object System.Management.Automation.PSCredential($username, $securePassword)
                    }
                }
            }
            
            try {
                Write-ExecutionLog "Background execution started"
                
                # Get scripts to execute
                $scriptsToRun = if ($SpecificScript) {
                    @($SpecificScript)
                } else {
                    $Scripts | Where-Object { $_.Enabled -eq $true }
                }
                
                if ($scriptsToRun.Count -eq 0) {
                    Write-ExecutionLog "No enabled scripts to execute" "WARNING"
                    return
                }
                
                Write-ExecutionLog "Found $($scriptsToRun.Count) script(s) to execute"
                
                # Connect to vCenter servers
                $sourceConnection = $null
                $targetConnection = $null
                
                try {
                    # Source vCenter connection
                    Write-ExecutionLog "Connecting to source vCenter: $($Config.SourceServer)"
                    Update-UIThreadSafe -ControlName "lblCurrentProgress" -Property "Text" -Value "Connecting to source vCenter..."
                    
                    $sourceCredential = Get-VCenterCredential -ServerType "Source" -Config $Config
                    
                    # Set PowerCLI configuration
                    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
                    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
                    
                    $sourceConnection = if ($sourceCredential -eq [System.Management.Automation.PSCredential]::Empty) {
                        Connect-VIServer -Server $Config.SourceServer -Force
                    } else {
                        Connect-VIServer -Server $Config.SourceServer -Credential $sourceCredential -Force
                    }
                    
                    if ($sourceConnection) {
                        Write-ExecutionLog "Successfully connected to source vCenter"
                    } else {
                        throw "Failed to connect to source vCenter"
                    }
                    
                    # Target vCenter connection
                    Write-ExecutionLog "Connecting to target vCenter: $($Config.TargetServer)"
                    Update-UIThreadSafe -ControlName "lblCurrentProgress" -Property "Text" -Value "Connecting to target vCenter..."
                    
                    $targetCredential = Get-VCenterCredential -ServerType "Target" -Config $Config
                    $targetConnection = if ($targetCredential -eq [System.Management.Automation.PSCredential]::Empty) {
                        Connect-VIServer -Server $Config.TargetServer -Force
                    } else {
                        Connect-VIServer -Server $Config.TargetServer -Credential $targetCredential -Force
                    }
                    
                    if ($targetConnection) {
                        Write-ExecutionLog "Successfully connected to target vCenter"
                    } else {
                        throw "Failed to connect to target vCenter"
                    }
                    
                    # Execute scripts
                    $totalScripts = $scriptsToRun.Count
                    $currentScriptIndex = 0
                    
                    foreach ($currentScript in $scriptsToRun) {
                        $currentScriptIndex++
                        
                        # Check for stop signal
                        if ($script:StopExecution) {
                            Write-ExecutionLog "Execution stopped by user"
                            break
                        }
                        
                        Write-ExecutionLog "Executing script $($currentScriptIndex) of $($totalScripts): $($currentScript.Name)"
                        Update-UIThreadSafe -ControlName "lblCurrentProgress" -Property "Text" -Value "Executing: $($currentScript.Name)"
                        Update-UIThreadSafe -ControlName "progressOverall" -Property "Value" -Value ([int](($currentScriptIndex - 1) / $totalScripts * 100))
                        
                        try {
                            # Prepare script parameters
                            $scriptParams = @{}
                            
                            foreach ($param in $currentScript.Parameters) {
                                $paramValue = $param.Value
                                
                                # Handle special parameter values
                                switch ($paramValue) {
                                    "SourcevCenter" { $paramValue = $Config.SourceServer }
                                    "TargetvCenter" { $paramValue = $Config.TargetServer }
                                    "SourceCredential" { $paramValue = $sourceCredential }
                                    "TargetCredential" { $paramValue = $targetCredential }
                                }
                                
                                # Type conversion
                                switch ($param.Type) {
                                    "Int32" { $paramValue = [int]$paramValue }
                                    "Boolean" { $paramValue = [bool]$paramValue }
                                    "DateTime" { $paramValue = [datetime]$paramValue }
                                    "Double" { $paramValue = [double]$paramValue }
                                }
                                
                                $scriptParams[$param.Name] = $paramValue
                            }
                            
                            # Execute script as job
                            Write-ExecutionLog "Starting script job: $($currentScript.Path)"
                            Update-UIThreadSafe -ControlName "progressCurrentScript" -Property "Value" -Value 0
                            
                            $job = Start-Job -ScriptBlock {
                                param($ScriptPath, $Parameters)
                                & $ScriptPath @Parameters
                            } -ArgumentList $currentScript.Path, $scriptParams
                            
                            # Monitor job progress
                            $timeout = [datetime]::Now.AddSeconds($Config.ExecutionTimeout)
                            
                            while ($job.State -eq "Running" -and [datetime]::Now -lt $timeout) {
                                if ($script:StopExecution) {
                                    Stop-Job -Job $job
                                    Remove-Job -Job $job
                                    Write-ExecutionLog "Script execution stopped by user"
                                    break
                                }
                                
                                Start-Sleep -Milliseconds 500
                                $progressValue = if ($job.PSBeginTime) { 50 } else { 25 }
                                Update-UIThreadSafe -ControlName "progressCurrentScript" -Property "Value" -Value $progressValue
                            }
                            
                            # Handle job completion
                            if ($job.State -eq "Completed") {
                                $jobResult = Receive-Job -Job $job
                                Write-ExecutionLog "Script completed successfully: $($currentScript.Name)"
                                Update-UIThreadSafe -ControlName "progressCurrentScript" -Property "Value" -Value 100
                                
                                # Log job output if any
                                if ($jobResult) {
                                    Write-ExecutionLog "Script output: $($jobResult -join '; ')"
                                }
                            } elseif ($job.State -eq "Failed") {
                                $jobErrors = @()
                                $jobResult = Receive-Job -Job $job -ErrorVariable jobErrors
                                Write-ExecutionLog "Script failed: $($currentScript.Name) - Error: $($jobErrors -join '; ')" "ERROR"
                                
                                if ($Config.StopOnError) {
                                    Remove-Job -Job $job
                                    break
                                }
                            } else {
                                Write-ExecutionLog "Script timed out: $($currentScript.Name)" "WARNING"
                                Stop-Job -Job $job
                            }
                            
                            Remove-Job -Job $job -Force
                            
                        } catch {
                            Write-ExecutionLog "Error executing script $($currentScript.Name): $($_.Exception.Message)" "ERROR"
                            
                            if ($Config.StopOnError) {
                                break
                            }
                        }
                    } # End foreach script
                    
                } finally {
                    # Disconnect from vCenter servers
                    if ($sourceConnection) {
                        Disconnect-VIServer -Server $sourceConnection -Confirm:$false
                        Write-ExecutionLog "Disconnected from source vCenter"
                    }
                    
                    if ($targetConnection) {
                        Disconnect-VIServer -Server $targetConnection -Confirm:$false
                        Write-ExecutionLog "Disconnected from target vCenter"
                    }
                } # End finally block for vCenter connections
                
                Write-ExecutionLog "Script execution completed"
                Update-UIThreadSafe -ControlName "progressOverall" -Property "Value" -Value 100
                Update-UIThreadSafe -ControlName "lblCurrentProgress" -Property "Text" -Value "Execution completed"
                
            } catch {
                Write-ExecutionLog "Critical error during execution: $($_.Exception.Message)" "ERROR"
            } # End main try-catch in script block
        } # End $executionScriptBlock
        
        # Add script block and parameters
        [void]$script:ExecutionPowerShell.AddScript($executionScriptBlock)
        [void]$script:ExecutionPowerShell.AddParameters(@{
            Config = $script:Config
            Scripts = $script:Scripts
            SpecificScript = $SpecificScript
            MainForm = $mainForm
            LogPath = $script:LogPath
        })
        
        # Start execution asynchronously
        $script:ExecutionHandle = $script:ExecutionPowerShell.BeginInvoke()
        
        # Start monitoring timer
        Start-ExecutionMonitor
        
        Write-Log "Background script execution started successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error starting script execution: $($_.Exception.Message)" -Level "ERROR"
        Update-UIState -State "Error"
        [System.Windows.Forms.MessageBox]::Show(
            "Error starting script execution: $($_.Exception.Message)", 
            "Execution Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Stop-ScriptExecution {
    <#
    .SYNOPSIS
        Stops the currently running script execution
    #>
    try {
        Write-Log "Stopping script execution..." -Level "INFO"
        
        # Set stop flag
        $script:StopExecution = $true
        
        # Stop monitoring timer
        if ($script:ExecutionTimer) {
            Stop-ExecutionMonitor
        }
        
        # Stop PowerShell execution
        if ($script:ExecutionPowerShell) {
            try {
                $script:ExecutionPowerShell.Stop()
                Write-Log "PowerShell execution stopped" -Level "INFO"
            } catch {
                Write-Log "Error stopping PowerShell execution: $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        # Wait for completion or timeout
        $timeout = [datetime]::Now.AddSeconds(10)
        while ($script:ExecutionHandle -and -not $script:ExecutionHandle.IsCompleted -and [datetime]::Now -lt $timeout) {
            Start-Sleep -Milliseconds 100
        }
        
        # Force cleanup if needed
        if ($script:ExecutionHandle -and -not $script:ExecutionHandle.IsCompleted) {
            Write-Log "Forcing execution cleanup after timeout" -Level "WARNING"
        }
        
        # Cleanup resources
        Cleanup-ExecutionResources
        
        # Update UI
        Update-UIState -State "Stopped"
        $lblCurrentProgress.Text = "Execution stopped by user"
        
        Write-Log "Script execution stopped successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error stopping script execution: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Start-ExecutionMonitor {
    <#
    .SYNOPSIS
        Starts a timer to monitor script execution progress
    #>
    try {
        # Create and configure timer
        $script:ExecutionTimer = New-Object System.Windows.Forms.Timer
        $script:ExecutionTimer.Interval = 1000 # Check every second
        
        # Define timer event handler
        $script:ExecutionTimer.add_Tick({
            try {
                if ($script:ExecutionHandle -and $script:ExecutionHandle.IsCompleted) {
                    # Execution completed
                    Write-Log "Execution completed, stopping monitor" -Level "DEBUG"
                    
                    # Get results
                    try {
                        $results = $script:ExecutionPowerShell.EndInvoke($script:ExecutionHandle)
                        Write-Log "Execution results retrieved" -Level "DEBUG"
                    } catch {
                        Write-Log "Error retrieving execution results: $($_.Exception.Message)" -Level "ERROR"
                    }
                    
                    # Stop monitoring
                    Stop-ExecutionMonitor
                    
                    # Cleanup resources
                    Cleanup-ExecutionResources
                    
                    # Update UI
                    Update-UIState -State "Ready"
                    
                    Write-Log "Script execution monitoring completed" -Level "INFO"
                }
            } catch {
                Write-Log "Error in execution monitor: $($_.Exception.Message)" -Level "ERROR"
            }
        })
        
        # Start timer
        $script:ExecutionTimer.Start()
        Write-Log "Execution monitor started" -Level "DEBUG"
        
    } catch {
        Write-Log "Error starting execution monitor: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Stop-ExecutionMonitor {
    <#
    .SYNOPSIS
        Stops the execution monitoring timer
    #>
    try {
        if ($script:ExecutionTimer) {
            $script:ExecutionTimer.Stop()
            $script:ExecutionTimer.Dispose()
            $script:ExecutionTimer = $null
            Write-Log "Execution monitor stopped" -Level "DEBUG"
        }
    } catch {
        Write-Log "Error stopping execution monitor: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Cleanup-ExecutionResources {
    <#
    .SYNOPSIS
        Cleans up execution-related resources
    #>
    try {
        Write-Log "Cleaning up execution resources..." -Level "DEBUG"
        
        # Dispose PowerShell instance
        if ($script:ExecutionPowerShell) {
            try {
                $script:ExecutionPowerShell.Dispose()
                $script:ExecutionPowerShell = $null
                Write-Log "PowerShell instance disposed" -Level "DEBUG"
            } catch {
                Write-Log "Error disposing PowerShell instance: $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        # Close and dispose runspace
        if ($script:ExecutionRunspace) {
            try {
                $script:ExecutionRunspace.Close()
                $script:ExecutionRunspace.Dispose()
                $script:ExecutionRunspace = $null
                Write-Log "Runspace closed and disposed" -Level "DEBUG"
            } catch {
                Write-Log "Error disposing runspace: $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        # Clear execution handle
        $script:ExecutionHandle = $null
        
        Write-Log "Execution resources cleanup completed" -Level "DEBUG"
        
    } catch {
        Write-Log "Error during execution resource cleanup: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Update-ExecutionConfiguration {
    <#
    .SYNOPSIS
        Updates execution configuration from form controls
    #>
    try {
        $script:Config.ExecutionTimeout = [int]$numTimeout.Value
        $script:Config.MaxConcurrentJobs = [int]$numMaxJobs.Value
        $script:Config.StopOnError = $chkStopOnError.Checked
        $script:Config.SkipConfirmation = $chkSkipConfirmation.Checked
        
        Write-Log "Execution configuration updated - Timeout: $($script:Config.ExecutionTimeout)s, Max Jobs: $($script:Config.MaxConcurrentJobs), Stop on Error: $($script:Config.StopOnError)" -Level "DEBUG"
        
    } catch {
        Write-Log "Error updating execution configuration: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Log Management

$btnRefreshLogs_Click = {
    try {
        Write-Log "Refreshing log display..." -Level "DEBUG"
        Refresh-LogDisplay
    } catch {
        Write-Log "Error in refresh logs button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error refreshing logs: $($_.Exception.Message)",
            "Refresh Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnClearLogs_Click = {
    try {
        Write-Log "Clearing logs..." -Level "INFO"
        Clear-LogDisplay
    } catch {
        Write-Log "Error in clear logs button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error clearing logs: $($_.Exception.Message)",
            "Clear Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnExportLogs_Click = {
    try {
        Write-Log "Exporting logs..." -Level "INFO"
        Export-LogsToFile
    } catch {
        Write-Log "Error in export logs button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error exporting logs: $($_.Exception.Message)",
            "Export Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Refresh-LogDisplay {
    <#
    .SYNOPSIS
        Refreshes the log display from the log file
    #>
    try {
        Write-Log "Refreshing log display from file..." -Level "DEBUG"
        
        if (Test-Path -Path $script:LogPath) {
            # Read log file content
            $logContent = Get-Content -Path $script:LogPath -Encoding UTF8 -ErrorAction SilentlyContinue
            
            if ($logContent) {
                # Clear current display
                $logTextBox.Clear()
                
                # Add content to textbox
                $logText = $logContent -join "`r`n"
                $logTextBox.Text = $logText
                
                # Scroll to bottom
                $logTextBox.SelectionStart = $logTextBox.Text.Length
                $logTextBox.ScrollToCaret()
                
                Write-Log "Log display refreshed with $($logContent.Count) lines" -Level "DEBUG"
            } else {
                $logTextBox.Text = "No log entries found."
                Write-Log "No log content found to display" -Level "DEBUG"
            }
        } else {
            $logTextBox.Text = "Log file not found: $($script:LogPath)"
            Write-Log "Log file not found: $($script:LogPath)" -Level "WARNING"
        }
        
    } catch {
        Write-Log "Error refreshing log display: $($_.Exception.Message)" -Level "ERROR"
        $logTextBox.Text = "Error loading log file: $($_.Exception.Message)"
        throw
    }
}

function Clear-LogDisplay {
    <#
    .SYNOPSIS
        Clears the log display and optionally the log file
    #>
    try {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to clear the log display only, or also delete the log file?`n`nYes = Clear display and delete file`nNo = Clear display only`nCancel = Do nothing",
            "Clear Logs",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        switch ($result) {
            "Yes" {
                # Clear display and delete file
                $logTextBox.Clear()
                
                if (Test-Path -Path $script:LogPath) {
                    Remove-Item -Path $script:LogPath -Force
                    Write-Log "Log file deleted and display cleared" -Level "INFO"
                } else {
                    Write-Log "Log display cleared (no file to delete)" -Level "INFO"
                }
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Log file deleted and display cleared.",
                    "Logs Cleared",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
            "No" {
                # Clear display only
                $logTextBox.Clear()
                Write-Log "Log display cleared (file preserved)" -Level "INFO"
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Log display cleared. Log file preserved.",
                    "Display Cleared",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
            "Cancel" {
                # Do nothing
                Write-Log "Log clear operation cancelled by user" -Level "DEBUG"
            }
        }
        
    } catch {
        Write-Log "Error clearing log display: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Export-LogsToFile {
    <#
    .SYNOPSIS
        Exports logs to a user-selected file
    #>
    try {
        # Configure save file dialog
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "Text Files (*.txt)|*.txt|Log Files (*.log)|*.log|All Files (*.*)|*.*"
        $saveFileDialog.Title = "Export Logs"
        $saveFileDialog.FileName = "vCenter_Migration_Logs_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        
        if ($saveFileDialog.ShowDialog($mainForm) -eq [System.Windows.Forms.DialogResult]::OK) {
            $exportPath = $saveFileDialog.FileName
            
            # Determine what to export
            $exportContent = ""
            
            if (Test-Path -Path $script:LogPath) {
                # Export from log file
                $logFileContent = Get-Content -Path $script:LogPath -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($logFileContent) {
                    $exportContent = $logFileContent -join "`r`n"
                }
            }
            
            # Also include current display content if different
            if (-not [string]::IsNullOrWhiteSpace($logTextBox.Text)) {
                if ([string]::IsNullOrWhiteSpace($exportContent)) {
                    $exportContent = $logTextBox.Text
                } elseif ($logTextBox.Text -ne $exportContent) {
                    $exportContent += "`r`n`r`n=== CURRENT DISPLAY CONTENT ===`r`n"
                    $exportContent += $logTextBox.Text
                }
            }
            
            if ([string]::IsNullOrWhiteSpace($exportContent)) {
                $exportContent = "No log content available for export."
            }
            
            # Add export header
            $header = @"
=== vCenter Migration Workflow Manager - Log Export ===
Export Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Application Version: 1.0
Source Log File: $($script:LogPath)
Export File: $($exportPath)
================================================================

"@
            
            $finalContent = $header + $exportContent
            
            # Write to export file
            Set-Content -Path $exportPath -Value $finalContent -Encoding UTF8
            
            Write-Log "Logs exported successfully to: $($exportPath)" -Level "INFO"
            
            [System.Windows.Forms.MessageBox]::Show(
                "Logs exported successfully to:`n$($exportPath)",
                "Export Successful",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        
        $saveFileDialog.Dispose()
        
    } catch {
        Write-Log "Error exporting logs: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Add-LogEntry {
    <#
    .SYNOPSIS
        Adds a log entry to both file and display
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$($timestamp)] [$($Level)] $($Message)"
        
        # Add to log file
        Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8
        
        # Add to display if visible
        if ($logTextBox.Visible) {
            $logTextBox.AppendText("$($logEntry)`r`n")
            $logTextBox.ScrollToCaret()
        }
        
    } catch {
        # Fail silently for logging errors to prevent infinite loops
    }
}

#endregion

#region Settings Management

$btnSaveAll_Click = {
    try {
        Write-Log "Saving all settings..." -Level "INFO"
        Save-AllSettings
        [System.Windows.Forms.MessageBox]::Show(
            "All settings saved successfully!",
            "Settings Saved",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        Write-Log "Error in save all button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error saving settings: $($_.Exception.Message)",
            "Save Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnExit_Click = {
    try {
        Write-Log "Exit button clicked" -Level "INFO"
        
        # Check if execution is running
        if ($script:ExecutionPowerShell -and $script:ExecutionHandle -and -not $script:ExecutionHandle.IsCompleted) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Script execution is still running. Do you want to stop execution and exit?",
                "Execution in Progress",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                return
            } else {
                Stop-ScriptExecution
            }
        }
        
        # Ask to save settings
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to save your current settings before exiting?",
            "Save Settings",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        switch ($result) {
            "Yes" {
                try {
                    Save-AllSettings
                    Write-Log "Settings saved before exit" -Level "INFO"
                } catch {
                    Write-Log "Error saving settings before exit: $($_.Exception.Message)" -Level "ERROR"
                    [System.Windows.Forms.MessageBox]::Show(
                        "Error saving settings: $($_.Exception.Message)`n`nExit anyway?",
                        "Save Error",
                        [System.Windows.Forms.MessageBoxButtons]::YesNo,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                    if ($result -eq [System.Windows.Forms.DialogResult]::No) {
                        return
                    }
                }
                $mainForm.Close()
            }
            "No" {
                Write-Log "Exiting without saving settings" -Level "INFO"
                $mainForm.Close()
            }
            "Cancel" {
                Write-Log "Exit cancelled by user" -Level "DEBUG"
                return
            }
        }
        
    } catch {
        Write-Log "Error in exit button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error during exit: $($_.Exception.Message)",
            "Exit Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

$btnHelp_Click = {
    try {
        Write-Log "Help button clicked" -Level "DEBUG"
        Show-HelpDialog
    } catch {
        Write-Log "Error in help button: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error showing help: $($_.Exception.Message)",
            "Help Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Save-AllSettings {
    <#
    .SYNOPSIS
        Saves all application settings to configuration
    #>
    try {
        Write-Log "Saving all application settings..." -Level "INFO"
        
        # Update configuration with current form values
        Update-ConfigurationFromForm
        
        # Save scripts collection
        $script:Config.Scripts = $script:Scripts
        
        # Save execution settings
        $script:Config.ExecutionTimeout = [int]$numTimeout.Value
        $script:Config.MaxConcurrentJobs = [int]$numMaxJobs.Value
        $script:Config.StopOnError = $chkStopOnError.Checked
        $script:Config.SkipConfirmation = $chkSkipConfirmation.Checked
        
        # Save window state
        $script:Config.WindowState = $mainForm.WindowState.ToString()
        $script:Config.WindowSize = @{
            Width = $mainForm.Width
            Height = $mainForm.Height
        }
        $script:Config.WindowLocation = @{
            X = $mainForm.Location.X
            Y = $mainForm.Location.Y
        }
        
        # Save to file
        Save-Configuration -Config $script:Config
        
        Write-Log "All settings saved successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error saving all settings: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}



function Update-ConfigurationFromForm {
    <#
    .SYNOPSIS
        Updates configuration object with current form values
    #>
    try {
        # Connection settings
        $script:Config.SourceServer = $txtSourceServer.Text.Trim()
        $script:Config.SourceUsername = $txtSourceUsername.Text.Trim()
        $script:Config.TargetServer = $txtTargetServer.Text.Trim()
        $script:Config.TargetUsername = $txtTargetUsername.Text.Trim()
        $script:Config.UseCurrentCredentials = $chkUseCurrentCredentials.Checked
        
        # Secure password handling
        if (-not [string]::IsNullOrWhiteSpace($txtSourcePassword.Text)) {
            $script:Config.SourcePassword = ConvertTo-SecureString $txtSourcePassword.Text -AsPlainText -Force
        }
        if (-not [string]::IsNullOrWhiteSpace($txtTargetPassword.Text)) {
            $script:Config.TargetPassword = ConvertTo-SecureString $txtTargetPassword.Text -AsPlainText -Force
        }
        
        Write-Log "Configuration updated from form values" -Level "DEBUG"
        
    } catch {
        Write-Log "Error updating configuration from form: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Show-HelpDialog {
    <#
    .SYNOPSIS
        Shows the application help dialog
    #>
    try {
        $helpText = @"
vCenter Migration Workflow Manager - Help

OVERVIEW:
This application helps you manage and execute PowerShell scripts for vCenter migration workflows.

MAIN FEATURES:

1. CONNECTION MANAGEMENT:
   - Configure source and target vCenter servers
   - Test connections before execution
   - Save/load connection settings
   - Support for current credentials or specified credentials

2. SCRIPT MANAGEMENT:
   - Add PowerShell scripts to execution queue
   - Reorder scripts for proper execution sequence
   - Enable/disable individual scripts
   - Auto-detect script parameters
   - Manual parameter configuration

3. EXECUTION:
   - Run all enabled scripts or selected script only
   - Background execution to keep UI responsive
   - Progress monitoring and logging
   - Stop execution capability
   - Configurable timeout and error handling

4. LOGGING:
   - Real-time execution logs
   - Export logs to file
   - Clear log display
   - Persistent log files

USAGE TIPS:
- Always test connections before running scripts
- Use parameter detection to automatically find script parameters
- Review and configure parameters for each script
- Monitor execution progress in the Execution tab
- Check logs for detailed execution information

TROUBLESHOOTING:
- Ensure VMware PowerCLI is installed
- Verify script paths are accessible
- Check vCenter connectivity and credentials
- Review logs for detailed error information

For additional support, check the application logs or contact your system administrator.
"@

        [System.Windows.Forms.MessageBox]::Show(
            $helpText,
            "vCenter Migration Workflow Manager - Help",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        
    } catch {
        Write-Log "Error showing help dialog: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Reset-ApplicationSettings {
    <#
    .SYNOPSIS
        Resets application to default settings
    #>
    try {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "This will reset all application settings to defaults. Continue?",
            "Reset Settings",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Reset configuration
            $script:Config = Get-DefaultConfiguration
            
            # Reset scripts
            $script:Scripts = @()
            
            # Reset form controls
            Initialize-FormControls
            Update-ScriptsListView
            Clear-ScriptDetails
            
            Write-Log "Application settings reset to defaults" -Level "INFO"
            
            [System.Windows.Forms.MessageBox]::Show(
                "Application settings have been reset to defaults.",
                "Settings Reset",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        
    } catch {
        Write-Log "Error resetting application settings: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

# End of AI_Gen_Workflow_Wrapper.ps1
