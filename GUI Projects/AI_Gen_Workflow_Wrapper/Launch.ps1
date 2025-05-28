# Launch.ps1
# Complete entry point for AI Gen Workflow Wrapper with module management

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the script's root directory
$Global:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $Global:ScriptRoot

Write-Host "=== AI Gen Workflow Wrapper v1.0.0 ===" -ForegroundColor Green
Write-Host "Root Directory: $Global:ScriptRoot" -ForegroundColor Cyan

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
            Write-Warning "Failed to create directory: $($pathPair.Value) - $_"
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

# Check immediately after loading designer
Write-Host "`n--- Checking Form Variables After Designer Load ---" -ForegroundColor Yellow
$allVarsAfterDesigner = Get-Variable | Where-Object { 
    $_.Value -and 
    ($_.Value.GetType().Name -like "*Form*" -or $_.Name -like "*Form*" -or $_.Name -like "*AI_Gen*" -or $_.Name -like "*Wrapper*" -or $_.Name -eq "mainForm")
}

if ($allVarsAfterDesigner) {
    Write-Host "Variables found after designer load:" -ForegroundColor Cyan
    foreach ($var in $allVarsAfterDesigner) {
        Write-Host "  - $($var.Name) = $($var.Value.GetType().Name)" -ForegroundColor Gray
        
        # Check if this is a form
        if ($var.Value.GetType().Name -like "*Form*") {
            Write-Host "    ↳ This is a FORM! Text: '$($var.Value.Text)'" -ForegroundColor Green
            Write-Log "Found form variable: $($var.Name) with text '$($var.Value.Text)'" -Level "INFO"
            
            # Make sure it's global
            Set-Variable -Name $var.Name -Value $var.Value -Scope Global -Force
            Write-Host "    ↳ Set as global variable" -ForegroundColor Green
        }
    }
} else {
    Write-Host "No form variables found after designer load!" -ForegroundColor Red
    Write-Log "No form variables found after designer load" -Level "WARNING"
}

# Load main logic
Write-Host "`n--- Loading Main Logic ---" -ForegroundColor Cyan
$loadSuccess = $loadSuccess -and (Import-AppFile -FileName "AI_Gen_Workflow_Wrapper.ps1" -Description "Core Application Logic")

# Start application with comprehensive form detection
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    try {
        # Comprehensive form variable search
        Write-Host "`n--- Comprehensive Form Search ---" -ForegroundColor Yellow
        
        # Method 1: Check specific variable names (prioritize mainForm since that's what the designer creates)
        $formVariableNames = @(
            'mainForm',                    # This is what your designer creates
            'AI_Gen_Workflow_Wrapper',     # This is what the fix should create
            'AI_Gen_Workflow_WrapperForm',
            'MainForm', 
            'form', 
            'Form1',
            'wrapper',
            'Wrapper'
        )
        
        $formFound = $false
        foreach ($varName in $formVariableNames) {
            Write-Host "Checking for variable: $varName" -ForegroundColor Gray
            
            # Check in different scopes
            foreach ($scope in @("Global", "Script", "Local")) {
                $formVar = Get-Variable -Name $varName -Scope $scope -ErrorAction SilentlyContinue
                if ($formVar -and $formVar.Value -and $formVar.Value.GetType().Name -like "*Form*") {
                    Write-Host "✓ Found form in $scope scope: $varName ($($formVar.Value.GetType().Name))" -ForegroundColor Green
                    Write-Host "  Form Text: '$($formVar.Value.Text)'" -ForegroundColor Cyan
                    Write-Host "  Form Size: $($formVar.Value.Size)" -ForegroundColor Cyan
                    Write-Log "Application started successfully with form: $varName from $scope scope" -Level "INFO"
                    
                    # Show the main form
                    Write-Host "  Showing main form..." -ForegroundColor Green
                    $result = $formVar.Value.ShowDialog()
                    Write-Host "  Form closed with result: $result" -ForegroundColor Cyan
                    Write-Log "Form closed with result: $result" -Level "INFO"
                    $formFound = $true
                    break
                }
            }
            if ($formFound) { break }
        }
        
        if (-not $formFound) {
            # Method 2: Search all variables for forms
            Write-Host "`n--- Searching ALL Variables for Forms ---" -ForegroundColor Yellow
            
            $allVars = Get-Variable | Where-Object { 
                $_.Value -and $_.Value.GetType().Name -like "*Form*" 
            }
            
            if ($allVars) {
                Write-Host "Found form variables:" -ForegroundColor Cyan
                foreach ($var in $allVars) {
                    Write-Host "  - $($var.Name) = $($var.Value.GetType().Name)" -ForegroundColor Gray
                    try {
                        Write-Host "    Text: '$($var.Value.Text)'" -ForegroundColor Gray
                        Write-Host "    Size: $($var.Value.Size)" -ForegroundColor Gray
                    } catch {
                        Write-Host "    (Cannot read form properties)" -ForegroundColor Gray
                    }
                }
                
                # Use the first form we find
                $firstForm = $allVars | Select-Object -First 1
                Write-Host "✓ Using discovered form: $($firstForm.Name) ($($firstForm.Value.GetType().Name))" -ForegroundColor Yellow
                Write-Log "Using discovered form: $($firstForm.Name)" -Level "INFO"
                
                $result = $firstForm.Value.ShowDialog()
                Write-Log "Form closed with result: $result" -Level "INFO"
                $formFound = $true
            }
        }
        
        if (-not $formFound) {
            # Method 3: Create a diagnostic test form
            Write-Host "`n--- Creating Diagnostic Test Form ---" -ForegroundColor Yellow
            Write-Log "No form found - creating diagnostic test form" -Level "WARNING"
            
            $testForm = New-Object System.Windows.Forms.Form
            $testForm.Text = "AI Gen Workflow Wrapper - Diagnostic"
            $testForm.Size = New-Object System.Drawing.Size(500, 350)
            $testForm.StartPosition = "CenterScreen"
            $testForm.FormBorderStyle = "FixedDialog"
            $testForm.MaximizeBox = $false
            
            # Main label
            $label = New-Object System.Windows.Forms.Label
            $label.Text = "DIAGNOSTIC MODE - Form Designer Issue Detected"
            $label.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
            $label.Location = New-Object System.Drawing.Point(20, 20)
            $label.Size = New-Object System.Drawing.Size(450, 30)
            $label.ForeColor = [System.Drawing.Color]::Red
            $testForm.Controls.Add($label)
            
            # Instructions
            $instructions = New-Object System.Windows.Forms.Label
            $instructions.Text = @"
The main form was not created properly by the designer file.

Possible solutions:
1. Check AI_Gen_Workflow_Wrapper.designer.ps1 for syntax errors
2. Ensure the designer file creates a form variable
3. Add the fix code to the end of the designer file:

   `$AI_Gen_Workflow_Wrapper = `$mainForm
   `$Global:AI_Gen_Workflow_Wrapper = `$mainForm
   `$Global:MainForm = `$mainForm

Check the console output and log file for more details.
"@
            $instructions.Location = New-Object System.Drawing.Point(20, 60)
            $instructions.Size = New-Object System.Drawing.Size(450, 200)
            $instructions.Font = New-Object System.Drawing.Font("Arial", 9)
            $testForm.Controls.Add($instructions)
            
            # Buttons
            $okButton = New-Object System.Windows.Forms.Button
            $okButton.Text = "OK"
            $okButton.Location = New-Object System.Drawing.Point(300, 280)
            $okButton.Size = New-Object System.Drawing.Size(75, 30)
            $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $testForm.Controls.Add($okButton)
            
            $logButton = New-Object System.Windows.Forms.Button
            $logButton.Text = "Open Log"
            $logButton.Location = New-Object System.Drawing.Point(200, 280)
            $logButton.Size = New-Object System.Drawing.Size(85, 30)
            $logButton.Add_Click({
                if (Test-Path $Global:LogFile) {
                    Start-Process notepad.exe -ArgumentList $Global:LogFile
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Log file not found: $Global:LogFile", "Log File", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                }
            })
            $testForm.Controls.Add($logButton)
            
            $testForm.AcceptButton = $okButton
            
            Write-Host "✓ Showing diagnostic form (main form creation failed)" -ForegroundColor Yellow
            $testForm.ShowDialog()
            $testForm.Dispose()
        }
        
    }
    catch {
        $errorMessage = "Application error: $_"
        Write-Error $errorMessage
        Write-Log $errorMessage -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            "Application Error:`n`n$errorMessage`n`nCheck the log file for more details:`n$Global:LogFile", 
            "Application Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
} else {
    $errorMessage = "Application failed to load required components"
    Write-Error $errorMessage
    Write-Log $errorMessage -Level "ERROR"
    
    [System.Windows.Forms.MessageBox]::Show(
        "Application failed to load required components.`n`nCheck the log file for details:`n$Global:LogFile", 
        "Load Error", 
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

Write-Log "Application session ended" -Level "INFO"
Write-Host "`n--- Application Session Ended ---" -ForegroundColor Cyan
