# Launch.ps1
# Future-proof entry point using .psd1 configuration

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Load the enhanced path manager
$pathManagerScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "PathManager.ps1"
if (-not (Test-Path $pathManagerScript)) {
    throw "Critical Error: PathManager.ps1 not found at $pathManagerScript"
}
. $pathManagerScript

# Initialize path management with .psd1 config
Initialize-AppPaths

# Display application info from config
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

foreach ($errorPath in $pathValidation.Errors) {
    Write-Host "✗ Error $($errorPath.Name): $($errorPath.Error)" -ForegroundColor Red
}

# Initialize logging using config
$loggingConfig = Get-AppConfig -ConfigPath "Logging"
$Global:LogFile = Get-AppFileFromPattern -PathName "Logs" -PatternName "LogFile"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO"
    )
    
    $logLevel = Get-AppConfig -ConfigPath "Logging.DefaultLevel" -DefaultValue "INFO"
    $enableFile = Get-AppConfig -ConfigPath "Logging.EnableFileLogging" -DefaultValue $true
    $enableConsole = Get-AppConfig -ConfigPath "Logging.EnableConsoleLogging" -DefaultValue $true
    
    $dateFormat = Get-AppConfig -ConfigPath "Logging.DateFormat" -DefaultValue "yyyy-MM-dd HH:mm:ss"
    $timestamp = Get-Date -Format $dateFormat
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if ($enableFile) {
        try {
            Add-Content -Path $Global:LogFile -Value $logEntry -ErrorAction SilentlyContinue
        } catch { }
    }
    
    if ($enableConsole) {
        switch ($Level) {
            "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
            "INFO" { Write-Host $logEntry -ForegroundColor White }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "CRITICAL" { Write-Host $logEntry -ForegroundColor Magenta }
        }
    }
}

Write-Log "Application initialization started" -Level "INFO"

# Load application components using patterns from config
Write-Host "`n--- Loading Application Components ---" -ForegroundColor Cyan

function Import-AppComponent {
    param(
        [string]$PathName,
        [string]$PatternName,
        [string]$Description
    )
    
    $filePath = Get-AppFileFromPattern -PathName $PathName -PatternName $PatternName
    $filePath += ".designer.ps1"  # Add extension
    
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

# Load components using config patterns
$loadSuccess = $true
$loadSuccess = $loadSuccess -and (Import-AppComponent -PathName "Forms" -PatternName "MainForm" -Description "Form Designer")

# Load main logic
$mainLogicPath = Get-AppFileFromPattern -PathName "Forms" -PatternName "MainForm"
$mainLogicPath += ".ps1"
if (Test-Path $mainLogicPath) {
    . $mainLogicPath
    Write-Host "✓ Successfully loaded Core Application Logic" -ForegroundColor Green
} else {
    Write-Error "✗ Core application logic not found: $mainLogicPath"
    $loadSuccess = $false
}

# Start application
if ($loadSuccess) {
    Write-Host "`n--- Starting Application ---" -ForegroundColor Cyan
    
    $mainFormPattern = Get-AppConfig -ConfigPath "FilePatterns.MainForm"
    if (Get-Variable -Name $mainFormPattern -ErrorAction SilentlyContinue) {
        $mainFormVar = Get-Variable -Name $mainFormPattern
        if ($mainFormVar.Value -and $mainFormVar.Value.GetType().Name -like "*Form*") {
            Write-Host "✓ Found main form: $mainFormPattern" -ForegroundColor Green
            Write-Log "Application started successfully" -Level "INFO"
            [void]$mainFormVar.Value.ShowDialog()
        } else {
            throw "Main form variable exists but is not a valid form object"
        }
    } else {
        throw "Main form variable '$mainFormPattern' not found"
    }
} else {
    Write-Error "Application failed to load required components"
    exit 1
}

Write-Log "Application session ended" -Level "INFO"
