# Launch.ps1
# Simple, reliable entry point for AI Gen Workflow Wrapper

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

# Load application components directly from root
Write-Host "`n--- Loading Application Components ---" -ForegroundColor Cyan

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

# Load the required files
$loadSuccess = $true

# Load Globals first (if it exists)
$globalsFile = Join-Path $Global:ScriptRoot "Globals.ps1"
if (Test-Path $globalsFile) {
    $loadSuccess = $loadSuccess -and (Import-AppFile -FileName "Globals.ps1" -Description "Global Functions")
}

# Load form components
$loadSuccess = $loadSuccess -and (Import-AppFile -FileName "AI_Gen_Workflow_Wrapper.designer.ps1" -Description "Form Designer")
$loadSuccess = $loadSuccess -and (Import-AppFile -FileName "AI_Gen_Workflow_Wrapper.ps1" -Description "Core Application Logic")

# Start application
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    try {
        # Enhanced form variable detection with debugging
        Write-Host "`n--- Searching for Form Variables ---" -ForegroundColor Yellow
        
        # Show all variables that might be forms
        $allVars = Get-Variable | Where-Object { 
            $_.Value -and 
            ($_.Value.GetType().Name -like "*Form*" -or $_.Name -like "*Form*" -or $_.Name -like "*AI_Gen*")
        }
        
        if ($allVars) {
            Write-Host "Found potential form variables:" -ForegroundColor Cyan
            foreach ($var in $allVars) {
                Write-Host "  - $($var.Name) = $($var.Value.GetType().Name)" -ForegroundColor Gray
            }
        }
        
        # Try common form variable names
        $formVariableNames = @(
            'AI_Gen_Workflow_Wrapper',
            'mainForm', 
            'MainForm', 
            'form', 
            'Form1'
        )
        
        $formFound = $false
        foreach ($varName in $formVariableNames) {
            Write-Host "Checking for variable: $varName" -ForegroundColor Gray
            
            $formVar = Get-Variable -Name $varName -ErrorAction SilentlyContinue
            if ($formVar -and $formVar.Value -and $formVar.Value.GetType().Name -like "*Form*") {
                Write-Host "✓ Found main form: $varName ($($formVar.Value.GetType().Name))" -ForegroundColor Green
                Write-Log "Application started successfully with form: $varName" -Level "INFO"
                
                # Show the main form
                $result = $formVar.Value.ShowDialog()
                Write-Log "Form closed with result: $result" -Level "INFO"
                $formFound = $true
                break
            }
        }
        
        if (-not $formFound) {
            # Try to find ANY form variable
            $anyForm = $allVars | Where-Object { $_.Value.GetType().Name -like "*Form*" } | Select-Object -First 1
            
            if ($anyForm) {
                Write-Host "✓ Using discovered form: $($anyForm.Name) ($($anyForm.Value.GetType().Name))" -ForegroundColor Yellow
                Write-Log "Using discovered form: $($anyForm.Name)" -Level "INFO"
                $anyForm.Value.ShowDialog()
                $formFound = $true
            } else {
                throw "No form variables found. The form designer may not have created the form properly."
            }
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
    Write-Log "Application failed to load required components" -Level "ERROR"
    exit 1
}

Write-Log "Application session ended" -Level "INFO"
