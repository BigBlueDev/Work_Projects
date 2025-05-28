# Launch.ps1
# Entry point for the AI Gen Workflow Wrapper application

# Load required assemblies first
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the script's root directory
$Global:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $Global:ScriptRoot

Write-Host "=== AI Gen Workflow Wrapper ===" -ForegroundColor Green
Write-Host "Current Script Root: $Global:ScriptRoot" -ForegroundColor Cyan

# Define folder structure paths based on ACTUAL current structure
$Global:Paths = @{
    Root        = $Global:ScriptRoot
    Forms       = $Global:ScriptRoot                # Forms are in root now
    SubForms    = $Global:ScriptRoot                # SubForms are in root now  
    Resources   = Join-Path $Global:ScriptRoot "Resources"
    Config      = Join-Path $Global:ScriptRoot "Config"
    Logs        = Join-Path $Global:ScriptRoot "Logs"
    Data        = Join-Path $Global:ScriptRoot "Data"
}

# Function to get the correct path for project files
function Get-ProjectPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Root", "Forms", "SubForms", "Resources", "Config", "Logs", "Data")]
        [string]$Location = "Forms"
    )
    
    $basePath = $Global:Paths[$Location]
    return Join-Path $basePath $FileName
}

# Function to safely load a PowerShell file
function Import-ProjectFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [Parameter(Mandatory=$false)]
        [string]$Location = "Forms",
        
        [Parameter(Mandatory=$false)]
        [string]$Description = "file"
    )
    
    $filePath = Get-ProjectPath -FileName $FileName -Location $Location
    
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
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to load $Description`: $filePath`n`nError: $_", 
                "Initialization Error", 
                [System.Windows.Forms.MessageBoxButtons]::OK, 
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
    }
    else {
        Write-Error "✗ File not found: $filePath"
        [System.Windows.Forms.MessageBox]::Show(
            "Required file not found: $filePath", 
            "File Missing", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

# Initialize required directories
Write-Host "`n--- Initializing Directory Structure ---" -ForegroundColor Cyan
foreach ($pathPair in $Global:Paths.GetEnumerator()) {
    if (-not (Test-Path $pathPair.Value)) {
        try {
            New-Item -ItemType Directory -Path $pathPair.Value -Force | Out-Null
            Write-Host "Created directory: $($pathPair.Key) -> $($pathPair.Value)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to create directory: $($pathPair.Value) - $_"
        }
    }
    else {
        Write-Host "✓ Directory exists: $($pathPair.Key)" -ForegroundColor Gray
    }
}

# Initialize basic logging
try {
    $Global:LogFile = Join-Path $Global:Paths.Logs "Application_$(Get-Date -Format 'yyyy-MM-dd').log"
    
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
        }
        catch {
            # Silently fail if logging fails
        }
        
        switch ($Level) {
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "INFO" { Write-Host $logEntry -ForegroundColor White }
            "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
        }
    }
    
    Write-Log "Application initialization started" -Level "INFO"
}
catch {
    Write-Warning "Failed to initialize logging: $_"
}

Write-Host "`n--- Loading Application Components ---" -ForegroundColor Cyan

# Load components in correct order for CURRENT structure
$loadSuccess = $true

# 1. Load Form Designer (it's in root now)
if (-not (Import-ProjectFile -FileName "AI_Gen_Workflow_Wrapper.designer.ps1" -Location "Forms" -Description "Form Designer")) {
    $loadSuccess = $false
}

# 2. Load Core Functionality (it's in root now)
if ($loadSuccess -and (-not (Import-ProjectFile -FileName "AI_Gen_Workflow_Wrapper.ps1" -Location "Forms" -Description "Core Application Logic"))) {
    $loadSuccess = $false
}

# Initialize and start application
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    try {
        # Debug: Show all available form variables
        Write-Host "`n--- Debug: Available Variables ---" -ForegroundColor Yellow
        $allVars = Get-Variable | Where-Object { 
            $_.Value -and 
            ($_.Value.GetType().Name -like "*Form*" -or $_.Name -like "*Form*" -or $_.Name -like "*AI_Gen*")
        }
        
        if ($allVars) {
            foreach ($var in $allVars) {
                Write-Host "  Variable: $($var.Name) = $($var.Value.GetType().Name)" -ForegroundColor Gray
            }
        }
        
        # Try the exact variable name from the designer file first
        if (Get-Variable -Name "AI_Gen_Workflow_Wrapper" -ErrorAction SilentlyContinue) {
            $mainFormVar = Get-Variable -Name "AI_Gen_Workflow_Wrapper"
            if ($mainFormVar.Value -and $mainFormVar.Value.GetType().Name -like "*Form*") {
                Write-Host "✓ Found main form: AI_Gen_Workflow_Wrapper" -ForegroundColor Green
                Write-Log "Application started successfully" -Level "INFO"
                
                # Show the main form
                [void]$mainFormVar.Value.ShowDialog()
            }
            else {
                throw "Variable 'AI_Gen_Workflow_Wrapper' exists but is not a valid form object"
            }
        }
        else {
            # Fallback: try other common names
            $formVariableNames = @('mainForm', 'MainForm', 'form', 'Form1')
            $formFound = $false
            
            foreach ($varName in $formVariableNames) {
                $formVar = Get-Variable -Name $varName -ErrorAction SilentlyContinue
                if ($formVar -and $formVar.Value -and $formVar.Value.GetType().Name -like "*Form*") {
                    Write-Host "✓ Found main form: $varName" -ForegroundColor Green
                    Write-Log "Application started successfully" -Level "INFO"
                    
                    # Show the main form
                    [void]$formVar.Value.ShowDialog()
                    $formFound = $true
                    break
                }
            }
            
            if (-not $formFound) {
                throw "Main form variable not found. Expected 'AI_Gen_Workflow_Wrapper' or alternatives: $($formVariableNames -join ', ')"
            }
        }
        
    }
    catch {
        $errorMessage = "Application initialization error: $_"
        Write-Error $errorMessage
        Write-Log $errorMessage -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            $errorMessage, 
            "Initialization Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }
}
else {
    Write-Error "Application failed to load required components"
    Write-Log "Application failed to load required components" -Level "ERROR"
    exit 1
}

Write-Log "Application session ended" -Level "INFO"
