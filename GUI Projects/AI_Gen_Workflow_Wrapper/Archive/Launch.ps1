# Launch.ps1
# Complete entry point for AI Gen Workflow Wrapper with form variable fix

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the script's root directory
$Global:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $Global:ScriptRoot

Write-Host "=== AI Gen Workflow Wrapper v1.0.0 ===" -ForegroundColor Green
Write-Host "Root Directory: $($Global:ScriptRoot)" -ForegroundColor Cyan

# Define simple path structure
$Global:Paths = @{
    Root = $Global:ScriptRoot
    Data = Join-Path $Global:ScriptRoot "Data"
    Config = Join-Path $Global:ScriptRoot "Data\Config"
    Logs = Join-Path $Global:ScriptRoot "Data\Logs"
    Scripts = Join-Path $Global:ScriptRoot "Data\Scripts"
    Exports = Join-Path $Global:ScriptRoot "Data\Exports"
    Imports = Join-Path $Global:ScriptRoot "Data\Imports"
    Backups = Join-Path $Global:ScriptRoot "Data\Backups"
    Reports = Join-Path $Global:ScriptRoot "Data\Reports"
    Temp = Join-Path $Global:ScriptRoot "Data\Temp"
    Cache = Join-Path $Global:ScriptRoot "Data\Cache"
    Resources = Join-Path $Global:ScriptRoot "Resources"
}

# Create required directories
Write-Host "`n--- Creating Required Directories ---" -ForegroundColor Cyan
foreach ($pathPair in $Global:Paths.GetEnumerator()) {
    if (-not (Test-Path $pathPair.Value)) {
        try {
            New-Item -ItemType Directory -Path $pathPair.Value -Force | Out-Null
            Write-Host "➕ Created: $($pathPair.Key) -> $($pathPair.Value)" -ForegroundColor Yellow
        } catch {
            Write-Warning "Failed to create directory: $($pathPair.Value) - $($_)"
        }
    } else {
        Write-Host "✓ Exists: $($pathPair.Key)" -ForegroundColor Green
    }
}

# Initialize simple logging
$Global:LogFile = Join-Path $Global:Paths.Logs "application_$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO"
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
}

Write-Log "Application initialization started" -Level "INFO"

# Load Module Manager
$moduleManagerScript = Join-Path $Global:ScriptRoot "ModuleManager.ps1"
if (Test-Path $moduleManagerScript) {
    try {
        . $moduleManagerScript
        
        # Initialize module manager with cache in Data folder
        Initialize-ModuleManager -CacheDirectory $Global:Paths.Cache
        
        Write-Host "`n--- Checking Required Modules ---" -ForegroundColor Cyan
        
        # Define required modules for your application
        $requiredModules = @(
            @{ Name = "PowerShellGet"; MinVersion = "2.0.0" },
            @{ Name = "PackageManagement"; MinVersion = "1.4.0" }
            # Add any other modules your application needs:
            # @{ Name = "ImportExcel"; MinVersion = "7.0.0" },
            # @{ Name = "PSWriteHTML"; MinVersion = "0.0.170" },
            # @{ Name = "PnP.PowerShell"; MinVersion = "1.12.0" }
        )
        
        $moduleIssues = @()
        
        foreach ($moduleReq in $requiredModules) {
            Write-Host "Checking module: $($moduleReq.Name)" -NoNewline -ForegroundColor Yellow
            
            if (Test-ModuleAvailable -ModuleName $moduleReq.Name -MinVersion $moduleReq.MinVersion) {
                Write-Host " ✓ Available" -ForegroundColor Green
                Write-Log "Module $($moduleReq.Name) is available" -Level "DEBUG"
            } else {
                Write-Host " ⚠ Missing/Outdated" -ForegroundColor Red
                Write-Log "Module $($moduleReq.Name) needs installation/update" -Level "WARNING"
                
                # Try to install/update
                Write-Host "  Installing/Updating $($moduleReq.Name)..." -ForegroundColor Yellow
                if (Install-RequiredModule -ModuleName $moduleReq.Name -MinVersion $moduleReq.MinVersion) {
                    Write-Host "  ✓ Successfully installed/updated" -ForegroundColor Green
                    Write-Log "Successfully installed/updated module $($moduleReq.Name)" -Level "INFO"
                } else {
                    Write-Host "  ✗ Failed to install" -ForegroundColor Red
                    Write-Log "Failed to install module $($moduleReq.Name)" -Level "ERROR"
                    $moduleIssues += $moduleReq.Name
                }
            }
        }
        
        # Report any issues
        if ($moduleIssues.Count -gt 0) {
            Write-Warning "Some modules could not be installed: $($moduleIssues -join ', ')"
            Write-Warning "The application may not function correctly."
            Write-Log "Module installation issues: $($moduleIssues -join ', ')" -Level "WARNING"
        } else {
            Write-Host "✓ All required modules are available" -ForegroundColor Green
            Write-Log "All required modules are available" -Level "INFO"
        }
        
    } catch {
        Write-Warning "Error loading ModuleManager: $_"
        Write-Log "Error loading ModuleManager: $_" -Level "ERROR"
    }
} else {
    Write-Warning "ModuleManager.ps1 not found - skipping module checks"
    Write-Log "ModuleManager.ps1 not found - skipping module checks" -Level "WARNING"
}

# Enhanced file loading function
function Import-AppFile {
    param(
        [string]$FileName,
        [string]$Description
    )
    
    $filePath = Join-Path $Global:ScriptRoot $FileName
    
    Write-Host "Loading $Description`: " -NoNewline -ForegroundColor Yellow
    Write-Host $filePath -ForegroundColor White
    
    if (Test-Path $filePath) {
        try {
            # Create a new scope for file execution to capture variables
            $beforeVars = Get-Variable | ForEach-Object { $_.Name }
            
            . $filePath
            
            # Check what new variables were created
            $afterVars = Get-Variable | ForEach-Object { $_.Name }
            $newVars = $afterVars | Where-Object { $_ -notin $beforeVars }
            
            if ($newVars) {
                Write-Host "  New variables created: $($newVars -join ', ')" -ForegroundColor Gray
            }
            
            Write-Host "✓ Successfully loaded $Description" -ForegroundColor Green
            Write-Log "Successfully loaded $Description" -Level "INFO"
            return $true
        }
        catch {
            Write-Error "✗ Failed to load $Description`: $_"
            Write-Log "Failed to load $Description`: $_" -Level "ERROR"
            return $false
        }
    }
    else {
        Write-Error "✗ File not found: $filePath"
        Write-Log "File not found: $filePath" -Level "ERROR"
        return $false
    }
}

# Load application components
Write-Host "`n--- Loading Application Components ---" -ForegroundColor Cyan

$loadSuccess = $true

# Load Globals first (if it exists)
$globalsFile = Join-Path $Global:ScriptRoot "Globals.ps1"
if (Test-Path $globalsFile) {
    $loadSuccess = $loadSuccess -and (Import-AppFile -FileName "Globals.ps1" -Description "Global Functions")
}

# Load form components with enhanced tracking
Write-Host "`n--- Loading Form Designer ---" -ForegroundColor Cyan
$loadSuccess = $loadSuccess -and (Import-AppFile -FileName "AI_Gen_Workflow_Wrapper.designer.ps1" -Description "Form Designer")
if ($loadSuccess) {
    Write-Host "`n--- Initializing Main Form ---" -ForegroundColor Cyan
    if (Get-Command Initialize-MainForm -ErrorAction SilentlyContinue) {
        if (Initialize-MainForm) {
            Write-Host "✓ Main form initialized successfully" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to initialize main form" -ForegroundColor Red
            $loadSuccess = $false
        }
    } else {
        Write-Host "⚠ Initialize-MainForm function not found in Globals.ps1" -ForegroundColor Yellow
    }
}
# FORM VARIABLE FIX: Create expected form variables after designer loads
if ($loadSuccess) {
    Write-Host "`n--- Creating Form Variable Aliases ---" -ForegroundColor Cyan
    
    try {
        # Check if mainForm exists (created by designer)
        $mainFormFound = $false
        
        if (Get-Variable -Name "mainForm" -ErrorAction SilentlyContinue) {
            $mainFormVar = Get-Variable -Name "mainForm"
            if ($mainFormVar.Value -and $mainFormVar.Value.GetType().Name -like "*Form*") {
                
                # Create the expected variable names
                $Global:AI_Gen_Workflow_Wrapper = $mainFormVar.Value
                $Global:MainForm = $mainFormVar.Value
                Set-Variable -Name "AI_Gen_Workflow_Wrapper" -Value $mainFormVar.Value -Scope Global -Force
                
                $mainFormFound = $true
                Write-Host "✓ Form variables created successfully" -ForegroundColor Green
                Write-Host "  - AI_Gen_Workflow_Wrapper: $($mainFormVar.Value.GetType().Name)" -ForegroundColor Gray
                Write-Host "  - MainForm: $($mainFormVar.Value.GetType().Name)" -ForegroundColor Gray
                Write-Host "  - Form Text: '$($mainFormVar.Value.Text)'" -ForegroundColor Gray
                Write-Log "Form variables initialized: AI_Gen_Workflow_Wrapper, MainForm" -Level "INFO"
                
            } else {
                Write-Host "⚠ mainForm variable exists but doesn't contain a form" -ForegroundColor Yellow
                Write-Log "mainForm variable found but invalid" -Level "WARNING"
            }
        }
        
        if (-not $mainFormFound) {
            Write-Host "⚠ mainForm variable not found from designer" -ForegroundColor Yellow
            Write-Log "mainForm variable not found - checking for other form variables" -Level "WARNING"
        }
        
    } catch {
        Write-Host "⚠ Error creating form variable aliases: $($_)" -ForegroundColor Yellow
        Write-Log "Error creating form variable aliases: $($_)" -Level "ERROR"
    }
}

# Check immediately after loading designer and creating aliases
Write-Host "`n--- Verifying Form Variables After Alias Creation ---" -ForegroundColor Yellow
$allVarsAfterDesigner = Get-Variable | Where-Object { 
    $_.Value -and 
    ($_.Value.GetType().Name -like "*Form*" -or $_.Name -like "*Form*" -or $_.Name -like "*AI_Gen*" -or $_.Name -like "*Wrapper*" -or $_.Name -eq "mainForm")
}

if ($allVarsAfterDesigner) {
    Write-Host "Form variables found:" -ForegroundColor Cyan
    foreach ($var in $allVarsAfterDesigner) {
        Write-Host "  - $($var.Name) = $($var.Value.GetType().Name)" -ForegroundColor Gray
        
        # Check if this is a form and validate it
        if ($var.Value.GetType().Name -like "*Form*") {
            try {
                $isDisposed = $var.Value.IsDisposed
                $formText = $var.Value.Text
                $statusText = if ($isDisposed) { "DISPOSED" } else { "ACTIVE" }
                Write-Host "    ↳ Form Status: $($statusText), Text: '$($formText)'" -ForegroundColor $(if ($isDisposed) { "Red" } else { "Green" })
                Write-Log "Found form variable: $($var.Name) - Status: $($statusText)" -Level "INFO"
            } catch {
                Write-Host "    ↳ Error checking form status: $($_)" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "No form variables found after designer load!" -ForegroundColor Red
    Write-Log "No form variables found after designer load" -Level "WARNING"
}

# Load main logic
Write-Host "`n--- Loading Main Logic ---" -ForegroundColor Cyan
$loadSuccess = $loadSuccess -and (Import-AppFile -FileName "AI_Gen_Workflow_Wrapper.ps1" -Description "Core Application Logic")

# Start application with enhanced form detection
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    try {
        # Enhanced form variable search with disposal checking
        Write-Host "`n--- Enhanced Form Search ---" -ForegroundColor Yellow
        
        # Method 1: Check specific variable names (prioritize expected names)
        $formVariableNames = @(
            'AI_Gen_Workflow_Wrapper',     # This should be created by our alias
            'mainForm',                    # This is what the designer creates
            'MainForm',                    # Backup alias we created
            'form', 
            'Form1'
        )
        
        $formFound = $false
        foreach ($varName in $formVariableNames) {
            Write-Host "Checking for variable: $($varName)" -ForegroundColor Gray
            
            # Check in different scopes
            foreach ($scope in @("Global", "Script", "Local")) {
                $formVar = Get-Variable -Name $varName -Scope $scope -ErrorAction SilentlyContinue
                if ($formVar -and $formVar.Value -and $formVar.Value.GetType().Name -like "*Form*") {
                    
                    # Validate the form is not disposed
                    try {
                        $isDisposed = $formVar.Value.IsDisposed
                        if ($isDisposed) {
                            Write-Host "  Form $($varName) in $($scope) scope is disposed, skipping..." -ForegroundColor Yellow
                            continue
                        }
                        
                        # Validate the form has essential properties
                        $formText = $formVar.Value.Text
                        $formSize = $formVar.Value.Size
                        
                        Write-Host "✓ Found valid form in $($scope) scope: $($varName) ($($formVar.Value.GetType().Name))" -ForegroundColor Green
                        Write-Host "  Form Text: '$($formText)'" -ForegroundColor Cyan
                        Write-Host "  Form Size: $($formSize)" -ForegroundColor Cyan
                        Write-Log "Application started successfully with form: $($varName) from $($scope) scope" -Level "INFO"
                        
                        # Show the main form
                        Write-Host "  Showing main form..." -ForegroundColor Green
                        $result = $formVar.Value.ShowDialog()
                        Write-Host "  Form closed with result: $($result)" -ForegroundColor Cyan
                        Write-Log "Form closed with result: $($result)" -Level "INFO"
                        $formFound = $true
                        break
                        
                    } catch {
                        Write-Host "  Error validating form $($varName) in $($scope) scope: $($_)" -ForegroundColor Red
                        Write-Log "Error validating form $($varName)`: $($_)" -Level "ERROR"
                        continue
                    }
                }
            }
            if ($formFound) { break }
        }
        
        if (-not $formFound) {
            # Method 2: Search all variables for valid forms
            Write-Host "`n--- Searching ALL Variables for Valid Forms ---" -ForegroundColor Yellow
            
            $allVars = Get-Variable | Where-Object { 
                $_.Value -and $_.Value.GetType().Name -like "*Form*" 
            }
            
            if ($allVars) {
                Write-Host "Found form variables, validating..." -ForegroundColor Cyan
                foreach ($var in $allVars) {
                    try {
                        $isDisposed = $var.Value.IsDisposed
                        $formText = $var.Value.Text
                        $statusText = if ($isDisposed) { "DISPOSED" } else { "VALID" }
                        Write-Host "  - $($var.Name) = $($var.Value.GetType().Name) [$($statusText)] '$($formText)'" -ForegroundColor $(if ($isDisposed) { "Red" } else { "Gray" })
                        
                        if (-not $isDisposed) {
                            Write-Host "✓ Using valid form: $($var.Name) ($($var.Value.GetType().Name))" -ForegroundColor Yellow
                            Write-Log "Using discovered valid form: $($var.Name)" -Level "INFO"
                            
                            $result = $var.Value.ShowDialog()
                            Write-Log "Form closed with result: $($result)" -Level "INFO"
                            $formFound = $true
                            break
                        }
                    } catch {
                        Write-Host "  - $($var.Name) = ERROR: $($_)" -ForegroundColor Red
                    }
                }
            }
        }
        
        if (-not $formFound) {
            # Method 3: Create a diagnostic form explaining the issue
            Write-Host "`n--- Creating Diagnostic Form ---" -ForegroundColor Yellow
            Write-Log "No valid form found - creating diagnostic form" -Level "WARNING"
            
            $diagForm = New-Object System.Windows.Forms.Form
            $diagForm.Text = "AI Gen Workflow Wrapper - Diagnostic"
            $diagForm.Size = New-Object System.Drawing.Size(600, 400)
            $diagForm.StartPosition = "CenterScreen"
            $diagForm.FormBorderStyle = "FixedDialog"
            $diagForm.MaximizeBox = $false
            
            # Main label
            $titleLabel = New-Object System.Windows.Forms.Label
            $titleLabel.Text = "DIAGNOSTIC: Form Loading Issue"
            $titleLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
            $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
            $titleLabel.Size = New-Object System.Drawing.Size(550, 30)
            $titleLabel.ForeColor = [System.Drawing.Color]::Red
            $diagForm.Controls.Add($titleLabel)
            
            # Instructions
            $instructions = New-Object System.Windows.Forms.Label
            $instructions.Text = @"
The main form was not created properly or is disposed.

Possible causes:
• Designer file didn't create the mainForm variable
• Form was disposed before ShowDialog() was called
• Variable scope issues between designer and main logic

Check the console output and log file for detailed information.

Log file location:
$Global:LogFile
"@
            $instructions.Location = New-Object System.Drawing.Point(20, 60)
            $instructions.Size = New-Object System.Drawing.Size(550, 250)
            $instructions.Font = New-Object System.Drawing.Font("Arial", 9)
            $diagForm.Controls.Add($instructions)
            
            # Buttons
            $okButton = New-Object System.Windows.Forms.Button
            $okButton.Text = "OK"
            $okButton.Location = New-Object System.Drawing.Point(400, 330)
            $okButton.Size = New-Object System.Drawing.Size(75, 30)
            $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $diagForm.Controls.Add($okButton)
            
            $logButton = New-Object System.Windows.Forms.Button
            $logButton.Text = "Open Log"
            $logButton.Location = New-Object System.Drawing.Point(300, 330)
            $logButton.Size = New-Object System.Drawing.Size(85, 30)
            $logButton.Add_Click({
                if (Test-Path $Global:LogFile) {
                    Start-Process notepad.exe -ArgumentList $Global:LogFile
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Log file not found: $($Global:LogFile)", "Log File", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                }
            })
            $diagForm.Controls.Add($logButton)
            
            $diagForm.AcceptButton = $okButton
            
            Write-Host "✓ Showing diagnostic form (main form issue detected)" -ForegroundColor Yellow
            $diagForm.ShowDialog()
            $diagForm.Dispose()
        }
        
    }
    catch {
        $errorMessage = "Application error: $($_)"
        Write-Error $errorMessage
        Write-Log $errorMessage -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Application Error:`n`n$($errorMessage)`n`nCheck the log file for more details:`n$($Global:LogFile)", 
            "Application Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
} else {
    $errorMessage = "Application failed to load required components"
    Write-Error $($errorMessage)
    Write-Log $($errorMessage) -Level "ERROR"
    
    [System.Windows.Forms.MessageBox]::Show(
        "Application failed to load required components.`n`nCheck the log file for details:`n$($Global:LogFile)", 
        "Load Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

Write-Log "Application session ended" -Level "INFO"
Write-Host "`n--- Application Session Ended ---" -ForegroundColor Cyan
