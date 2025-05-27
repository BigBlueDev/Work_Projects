# Launch.ps1
# Entry point for the AI Gen Workflow Wrapper application

# Get the script's root directory
$Global:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $Global:ScriptRoot

Write-Host "=== AI Gen Workflow Wrapper ===" -ForegroundColor Green
Write-Host "Current Script Root: $Global:ScriptRoot" -ForegroundColor Cyan

# Define folder structure paths
$Global:Paths = @{
    Root        = $Global:ScriptRoot
    MainForm    = Join-Path $Global:ScriptRoot "MainForm"
    App         = Join-Path $Global:ScriptRoot "MainForm\App"
    Forms       = Join-Path $Global:ScriptRoot "MainForm\App\Forms"
    SubForms    = Join-Path $Global:ScriptRoot "MainForm\App\Forms\SubForm"
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
        [ValidateSet("Root", "MainForm", "App", "Forms", "SubForms", "Resources", "Config", "Logs", "Data")]
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

# Initialize logging first
try {
    if (-not (Test-Path $Global:Paths.Logs)) {
        New-Item -ItemType Directory -Path $Global:Paths.Logs -Force | Out-Null
    }
    
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

# Load components in correct order
$loadSuccess = $true

# 1. Load Global Variables and Functions
if (-not (Import-ProjectFile -FileName "Globals.ps1" -Location "Forms" -Description "Global Variables and Functions")) {
    $loadSuccess = $false
}

# 2. Load Form Designer
if ($loadSuccess -and (-not (Import-ProjectFile -FileName "AI_Gen_Workflow_Wrapper.designer.ps1" -Location "Forms" -Description "Form Designer"))) {
    $loadSuccess = $false
}

# 3. Load Core Functionality
if ($loadSuccess -and (-not (Import-ProjectFile -FileName "AI_Gen_Workflow_Wrapper.ps1" -Location "Forms" -Description "Core Application Logic"))) {
    $loadSuccess = $false
}

# 4. Load SubForm if needed (EditParam)
if ($loadSuccess) {
    Write-Host "`n--- Loading Sub-Forms ---" -ForegroundColor Cyan
    
    # Load EditParam SubForm
    if (-not (Import-ProjectFile -FileName "EditParam.designer.ps1" -Location "SubForms" -Description "EditParam Form Designer")) {
        Write-Warning "EditParam designer failed to load - some features may not work"
    }
    
    if (-not (Import-ProjectFile -FileName "EditParam.ps1" -Location "SubForms" -Description "EditParam Form Logic")) {
        Write-Warning "EditParam logic failed to load - some features may not work"
    }
}

# Initialize and start application
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    try {
        # Initialize application components (if Initialize-Application function exists)
        if (Get-Command Initialize-Application -ErrorAction SilentlyContinue) {
            Initialize-Application
            Write-Log "Application initialized successfully" -Level "INFO"
        }
        
        # Verify main form exists
        if ($null -eq $mainForm) {
            throw "Main form object not found. Form designer may not have loaded correctly."
        }
        
        Write-Host "✓ Application started successfully" -ForegroundColor Green
        Write-Log "Application started successfully" -Level "INFO"
        
        # Show the main form
        [void]$mainForm.ShowDialog()
        
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