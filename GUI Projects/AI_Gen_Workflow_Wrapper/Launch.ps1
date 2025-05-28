# Launch.ps1
# Simplified entry point for flat file structure

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load the path manager
$pathManagerScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "PathManager.ps1"
if (-not (Test-Path $pathManagerScript)) {
    throw "Critical Error: PathManager.ps1 not found at $pathManagerScript"
}
. $pathManagerScript

# Initialize path management
Initialize-AppPaths

# Display application info
$appInfo = Get-AppConfig -ConfigPath "ApplicationInfo"
Write-Host "=== $($appInfo.Name) v$($appInfo.Version) ===" -ForegroundColor Green
Write-Host "Root Directory: $(Get-AppPath -PathName 'Root')" -ForegroundColor Cyan

# Validate and create directory structure
Write-Host "`n--- Validating Directory Structure ---" -ForegroundColor Cyan
$pathValidation = Test-AppPaths

foreach ($validPath in $pathValidation.Valid) {
    Write-Host "✓ $($validPath.Name): $($validPath.Path)" -ForegroundColor Green
}

foreach ($createdPath in $pathValidation.Created) {
    Write-Host "➕ Created $($createdPath.Name): $($createdPath.Path)" -ForegroundColor Yellow
}

# Initialize logging
$Global:LogFile = Get-AppFileFromPattern -PathName "Logs" -PatternName "LogFile"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO"
    )
    
    $dateFormat = Get-AppConfig -ConfigPath "Logging.DateFormat" -DefaultValue "yyyy-MM-dd HH:mm:ss"
    $timestamp = Get-Date -Format $dateFormat
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

# Load application components directly from root
Write-Host "`n--- Loading Application Components ---" -ForegroundColor Cyan

function Import-RootFile {
    param(
        [string]$PatternName,
        [string]$Description
    )
    
    $fileName = Get-AppConfig -ConfigPath "FilePatterns.$PatternName"
    $filePath = Get-AppFilePath -PathName "Root" -FileName $fileName -EnsureDirectory $false
    
    Write-Host "Loading $Description`: " -NoNewline -ForegroundColor Yellow
    Write-Host $filePath -ForegroundColor White
    
    if (Test-Path $filePath) {
        try {
            . $filePath
            Write-Host "✓ Successfully loaded $Description" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Error "✗ Failed to load $Description`: $_"
            return $false
        }
    }
    else {
        Write-Error "✗ File not found: $filePath"
        return $false
    }
}

# Load form components from root directory
$loadSuccess = $true
$loadSuccess = $loadSuccess -and (Import-RootFile -PatternName "MainFormDesigner" -Description "Form Designer")
$loadSuccess = $loadSuccess -and (Import-RootFile -PatternName "MainFormLogic" -Description "Core Application Logic")

# Start application
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    try {
        # Enhanced form variable detection
        Write-Host "`n--- Searching for Form Variables ---" -ForegroundColor Yellow
        
        $formVariableNames = @(
            'AI_Gen_Workflow_Wrapper',
            'mainForm', 
            'MainForm', 
            'form', 
            'Form1'
        )
        
        $formFound = $false
        foreach ($varName in $formVariableNames) {
            $formVar = Get-Variable -Name $varName -ErrorAction SilentlyContinue
            if ($formVar -and $formVar.Value -and $formVar.Value.GetType().Name -like "*Form*") {
                Write-Host "✓ Found main form: $varName ($($formVar.Value.GetType().Name))" -ForegroundColor Green
                Write-Log "Application started successfully with form: $varName" -Level "INFO"
                
                [void]$formVar.Value.ShowDialog()
                $formFound = $true
                break
            }
        }
        
        if (-not $formFound) {
            # Debug: Show all available variables
            $allVars = Get-Variable | Where-Object { 
                $_.Value -and 
                ($_.Value.GetType().Name -like "*Form*" -or $_.Name -like "*Form*" -or $_.Name -like "*AI_Gen*")
            }
            
            if ($allVars) {
                Write-Host "Available variables:" -ForegroundColor Cyan
                foreach ($var in $allVars) {
                    Write-Host "  - $($var.Name) = $($var.Value.GetType().Name)" -ForegroundColor Gray
                }
                
                # Try the first form we find
                $firstForm = $allVars | Where-Object { $_.Value.GetType().Name -like "*Form*" } | Select-Object -First 1
                if ($firstForm) {
                    Write-Host "✓ Using discovered form: $($firstForm.Name)" -ForegroundColor Yellow
                    [void]$firstForm.Value.ShowDialog()
                    $formFound = $true
                }
            }
        }
        
        if (-not $formFound) {
            throw "No form variables found. The form designer may not have loaded correctly."
        }
        
    }
    catch {
        $errorMessage = "Application error: $_"
        Write-Error $errorMessage
        Write-Log $errorMessage -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            $errorMessage, 
            "Application Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
} else {
    Write-Error "Application failed to load required components"
    exit 1
}

Write-Log "Application session ended" -Level "INFO"
