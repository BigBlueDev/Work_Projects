# Launch.ps1
# Future-proof entry point using centralized path management

# Load required assemblies first
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load the path manager
$pathManagerScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "PathManager.ps1"
if (Test-Path $pathManagerScript) {
    . $pathManagerScript
} else {
    throw "Critical Error: PathManager.ps1 not found at $pathManagerScript"
}

# Initialize path management system
Initialize-AppPaths

Write-Host "=== AI Gen Workflow Wrapper ===" -ForegroundColor Green
Write-Host "Root Directory: $(Get-AppPath -PathName 'Root')" -ForegroundColor Cyan

# Validate and create directory structure
Write-Host "`n--- Validating Directory Structure ---" -ForegroundColor Cyan
$pathValidation = Test-AppPaths -CreateMissing $true

foreach ($validPath in $pathValidation.Valid) {
    Write-Host "✓ $($validPath.Name): $($validPath.Path)" -ForegroundColor Green
}

foreach ($createdPath in $pathValidation.Created) {
    Write-Host "➕ Created $($createdPath.Name): $($createdPath.Path)" -ForegroundColor Yellow
}

foreach ($errorPath in $pathValidation.Errors) {
    Write-Host "✗ Error $($errorPath.Name): $($errorPath.Error)" -ForegroundColor Red
}

# Initialize logging
$Global:LogFile = Get-AppFilePathFromPattern -PathName "Logs" -PatternName "LogFile"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        Add-Content -Path $Global:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch { }
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "INFO" { Write-Host $logEntry -ForegroundColor White }
        "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
    }
}

Write-Log "Application initialization started" -Level "INFO"

# Load application components
Write-Host "`n--- Loading Application Components ---" -ForegroundColor Cyan

# Function to safely load PowerShell files
function Import-AppFile {
    param(
        [string]$PathName,
        [string]$FileName,
        [string]$Description = "file"
    )
    
    $filePath = Get-AppFilePath -PathName $PathName -FileName $FileName -EnsureDirectory $false
    
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

# Load components in order
$loadSuccess = $true
$loadSuccess = $loadSuccess -and (Import-AppFile -PathName "Forms" -FileName "AI_Gen_Workflow_Wrapper.designer.ps1" -Description "Form Designer")
$loadSuccess = $loadSuccess -and (Import-AppFile -PathName "Forms" -FileName "AI_Gen_Workflow_Wrapper.ps1" -Description "Core Application Logic")

# Start application
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    if (Get-Variable -Name "AI_Gen_Workflow_Wrapper" -ErrorAction SilentlyContinue) {
        $mainFormVar = Get-Variable -Name "AI_Gen_Workflow_Wrapper"
        if ($mainFormVar.Value -and $mainFormVar.Value.GetType().Name -like "*Form*") {
            Write-Host "✓ Found main form: AI_Gen_Workflow_Wrapper" -ForegroundColor Green
            Write-Log "Application started successfully" -Level "INFO"
            [void]$mainFormVar.Value.ShowDialog()
        } else {
            throw "Main form variable exists but is not a valid form object"
        }
    } else {
        throw "Main form variable 'AI_Gen_Workflow_Wrapper' not found"
    }
} else {
    Write-Error "Application failed to load required components"
    exit 1
}

Write-Log "Application session ended" -Level "INFO"