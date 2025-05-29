<#
.SYNOPSIS
    vCenter Migration Workflow Manager - Global Variables and Configuration

.DESCRIPTION
    This script contains all global variables, configuration settings, and core utility
    functions used throughout the vCenter Migration Workflow Manager application.

.NOTES
    Author: vCenter Migration Team
    Version: 1.0
    Requires: PowerShell 5.1+, Windows Forms
    Compatible: PowerShell Pro Tools
#>

# Ensure strict mode for better error handling
Set-StrictMode -Version Latest

#region Script-Level Variables

# Initialize script-level variables
$script:Scripts = @()
$script:StopExecution = $false
$script:Config = $null
$script:ExecutionTimer = $null
$script:ExecutionPowerShell = $null
$script:ExecutionRunspace = $null
$script:ExecutionHandle = $null

#endregion

#region Path Configuration

# Get application root directory
$script:AppRoot = $PSScriptRoot

# Configuration directories
$script:ConfigDir = Join-Path -Path $script:AppRoot -ChildPath "Config"
$script:LogDir = Join-Path -Path $script:AppRoot -ChildPath "Logs"
$script:ReportsDir = Join-Path -Path $script:AppRoot -ChildPath "Reports"
$script:TempDir = Join-Path -Path $script:AppRoot -ChildPath "Temp"

# Configuration files
$script:ConfigPath = Join-Path -Path $script:ConfigDir -ChildPath "config.json"
$script:LogPath = Join-Path -Path $script:LogDir -ChildPath "application.log"
$script:SettingsPath = Join-Path -Path $script:ConfigDir -ChildPath "settings.json"
$script:BrowsingScript = $false
$script:EventHandlersRegistered = $false

# Ensure all required directories exist
$requiredDirectories = @($script:ConfigDir, $script:LogDir, $script:ReportsDir, $script:TempDir)
foreach ($dir in $requiredDirectories) {
    if (-not (Test-Path -Path $dir)) {
        try {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $($dir)" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to create directory: $($dir) - $($_.Exception.Message)"
        }
    }
}

#endregion

#region Logging Functions

function Write-Log {
    <#
    .SYNOPSIS
        Writes log entries to file and optionally to console
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$($timestamp)] [$($Level)] $($Message)"
        
        # Write to log file
        if ($script:LogPath) {
            Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        
        # Write to console if not suppressed
        if (-not $NoConsole) {
            switch ($Level) {
                "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
                "INFO" { Write-Host $logEntry -ForegroundColor White }
                "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
                "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            }
        }
        
    } catch {
        # Fail silently to prevent infinite loops
        Write-Warning "Logging error: $($_.Exception.Message)"
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes the logging system
    #>
    try {
        # Create log file if it doesn't exist
        if (-not (Test-Path -Path $script:LogPath)) {
            New-Item -Path $script:LogPath -ItemType File -Force | Out-Null
        }
        
        # Write startup log entry
        Write-Log "=== vCenter Migration Workflow Manager Started ===" -Level "INFO"
        Write-Log "Application Root: $($script:AppRoot)" -Level "INFO"
        Write-Log "Log File: $($script:LogPath)" -Level "INFO"
        Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level "INFO"
        Write-Log "Operating System: $($PSVersionTable.OS)" -Level "INFO"
        
        return $true
        
    } catch {
        Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
        return $false
    }
}


function Clear-OldLogs {
    <#
    .SYNOPSIS
        Clears log files older than specified days
    #>
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysToKeep = 30
    )
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
        $logFiles = Get-ChildItem -Path $script:LogDir -Filter "*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        foreach ($logFile in $logFiles) {
            Remove-Item -Path $logFile.FullName -Force
            Write-Log "Removed old log file: $($logFile.Name)" -Level "INFO"
        }
        
    } catch {
        Write-Log "Error clearing old logs: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region Configuration Management Functions

function Get-DefaultConfiguration {
    <#
    .SYNOPSIS
        Returns default configuration object
    #>
    return [PSCustomObject]@{
        # Connection Settings
        SourceServer = ""
        SourceUsername = ""
        SourcePassword = $null
        TargetServer = ""
        TargetUsername = ""
        TargetPassword = $null
        UseCurrentCredentials = $true
        
        # Execution Settings
        ExecutionTimeout = 300
        MaxConcurrentJobs = 1
        StopOnError = $true
        SkipConfirmation = $false
        
        # Scripts Collection
        Scripts = @()
        
        # Window Settings
        WindowState = "Normal"
        WindowSize = @{
            Width = 1200
            Height = 800
        }
        WindowLocation = @{
            X = 100
            Y = 100
        }
        
        # Application Settings
        LastConfigSave = (Get-Date)
        Version = "1.0"
        
        # Advanced Settings
        LogLevel = "INFO"
        AutoSaveInterval = 300
        BackupCount = 5
        
        # PowerCLI Settings
        PowerCLIIgnoreInvalidCertificates = $true
        PowerCLIParticipateInCEIP = $false
    }
}

function Load-Configuration {
    <#
    .SYNOPSIS
        Loads configuration from file or returns default if not found
    #>
    try {
        if (Test-Path -Path $script:ConfigPath) {
            Write-Log "Loading configuration from: $($script:ConfigPath)" -Level "DEBUG"
            
            $configContent = Get-Content -Path $script:ConfigPath -Raw -Encoding UTF8
            $configData = $configContent | ConvertFrom-Json
            
            # Convert back to PSCustomObject with proper types
            $loadedConfig = Get-DefaultConfiguration
            
            # Update with loaded values, preserving structure
            foreach ($property in $configData.PSObject.Properties) {
                if ($loadedConfig.PSObject.Properties.Name -contains $property.Name) {
                    if ($property.Value -is [PSCustomObject] -and $loadedConfig.$($property.Name) -is [PSCustomObject]) {
                        # Handle nested objects
                        foreach ($subProperty in $property.Value.PSObject.Properties) {
                            $loadedConfig.$($property.Name).$($subProperty.Name) = $subProperty.Value
                        }
                    } else {
                        $loadedConfig.$($property.Name) = $property.Value
                    }
                }
            }
            
            Write-Log "Configuration loaded successfully" -Level "INFO"
            return $loadedConfig
        } else {
            Write-Log "Configuration file not found, using defaults" -Level "INFO"
            return Get-DefaultConfiguration
        }
    } catch {
        Write-Log "Error loading configuration: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Using default configuration" -Level "WARNING"
        return Get-DefaultConfiguration
    }
}

function Save-Configuration {
    <#
    .SYNOPSIS
        Saves configuration to file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    try {
        Write-Log "Saving configuration to: $($script:ConfigPath)" -Level "DEBUG"
        
        # Ensure config directory exists
        $configDir = Split-Path -Path $script:ConfigPath -Parent
        if (-not (Test-Path -Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-Log "Created configuration directory: $($configDir)" -Level "DEBUG"
        }
        
        # Create backup of existing config
        if (Test-Path -Path $script:ConfigPath) {
            $backupPath = "$($script:ConfigPath).backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $script:ConfigPath -Destination $backupPath -Force
            Write-Log "Configuration backup created: $($backupPath)" -Level "DEBUG"
        }
        
        # Update save timestamp
        $Config.LastConfigSave = Get-Date
        
        # Convert to JSON and save
        $configJson = $Config | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $configJson -Encoding UTF8
        
        Write-Log "Configuration saved successfully" -Level "INFO"
        
        # Clean up old backups (keep last 5)
        Clean-ConfigBackups
        
    } catch {
        Write-Log "Error saving configuration: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Test-ConfigurationIntegrity {
    <#
    .SYNOPSIS
        Tests configuration file integrity
    #>
    try {
        if (-not (Test-Path -Path $script:ConfigPath)) {
            Write-Log "Configuration file does not exist" -Level "DEBUG"
            return $false
        }
        
        $configContent = Get-Content -Path $script:ConfigPath -Raw -Encoding UTF8
        $config = $configContent | ConvertFrom-Json
        
        # Basic validation
        if (-not $config) {
            Write-Log "Configuration file is empty or invalid" -Level "WARNING"
            return $false
        }
        
        # Check for required properties
        $requiredProperties = @("SourceServer", "TargetServer", "ExecutionTimeout", "Scripts")
        foreach ($prop in $requiredProperties) {
            if (-not ($config.PSObject.Properties.Name -contains $prop)) {
                Write-Log "Configuration missing required property: $($prop)" -Level "WARNING"
                return $false
            }
        }
        
        Write-Log "Configuration integrity test passed" -Level "DEBUG"
        return $true
        
    } catch {
        Write-Log "Configuration integrity test failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Clean-ConfigBackups {
    <#
    .SYNOPSIS
        Cleans up old configuration backup files
    #>
    try {
        $configDir = Split-Path -Path $script:ConfigPath -Parent
        $backupFiles = @(Get-ChildItem -Path $configDir -Filter "config.json.backup.*" -ErrorAction SilentlyContinue)
        
        if ($backupFiles -and $backupFiles.Count -gt 5) {
            $sortedFiles = $backupFiles | Sort-Object LastWriteTime -Descending
            $filesToDelete = $sortedFiles | Select-Object -Skip 5
            
            foreach ($file in $filesToDelete) {
                Remove-Item -Path $file.FullName -Force
                Write-Log "Removed old config backup: $($file.Name)" -Level "DEBUG"
            }
        }
        
    } catch {
        Write-Log "Error cleaning config backups: $($_.Exception.Message)" -Level "WARNING"
    }
}


function Reset-Configuration {
    <#
    .SYNOPSIS
        Resets configuration to defaults
    #>
    try {
        # Backup current config if it exists
        if (Test-Path -Path $script:ConfigPath) {
            $backupPath = "$($script:ConfigPath).reset.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $script:ConfigPath -Destination $backupPath -Force
            Write-Log "Configuration backed up before reset: $($backupPath)" -Level "INFO"
        }
        
        # Create default configuration
        $defaultConfig = Get-DefaultConfiguration
        Save-Configuration -Config $defaultConfig
        
        Write-Log "Configuration reset to defaults" -Level "INFO"
        return $defaultConfig
        
    } catch {
        Write-Log "Error resetting configuration: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Environment Setup Functions

function Initialize-Environment {
    <#
    .SYNOPSIS
        Initializes the application environment
    #>
    try {
        Write-Log "Initializing application environment..." -Level "INFO"
        
        # Initialize logging
        if (-not (Initialize-Logging)) {
            Write-Warning "Logging initialization failed"
        }
        
        # Clear old logs
        Clear-OldLogs -DaysToKeep 30
        
        # Load or create configuration
        if (Test-ConfigurationIntegrity) {
            $script:Config = Load-Configuration
        } else {
            Write-Log "Configuration integrity check failed, creating new configuration" -Level "WARNING"
            $script:Config = Get-DefaultConfiguration
            Save-Configuration -Config $script:Config
        }
        
        # Check PowerCLI availability
        Test-PowerCLIAvailability
        
        # Initialize Windows Forms if not already done
        if (-not ([System.Windows.Forms.Application]::RenderWithVisualStyles)) {
            [System.Windows.Forms.Application]::EnableVisualStyles()
            [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
        }
        
        Write-Log "Environment initialization completed successfully" -Level "INFO"
        return $true
        
    } catch {
        Write-Log "Error initializing environment: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-PowerCLIAvailability {
    <#
    .SYNOPSIS
        Tests if VMware PowerCLI is available
    #>
    try {
        $powerCLIModule = Get-Module -Name VMware.PowerCLI -ListAvailable
        
        if ($powerCLIModule) {
            Write-Log "VMware PowerCLI found: Version $($powerCLIModule[0].Version)" -Level "INFO"
            
            # Test if we can import it
            try {
                Import-Module VMware.PowerCLI -Force -ErrorAction Stop
                Write-Log "VMware PowerCLI imported successfully" -Level "DEBUG"
                return $true
            } catch {
                Write-Log "VMware PowerCLI found but cannot be imported: $($_.Exception.Message)" -Level "WARNING"
                return $false
            }
        } else {
            Write-Log "VMware PowerCLI not found" -Level "WARNING"
            return $false
        }
        
    } catch {
        Write-Log "Error testing PowerCLI availability: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Tests all application prerequisites
    #>
    $prerequisites = @{
        PowerShellVersion = $false
        WindowsForms = $false
        PowerCLI = $false
        Directories = $false
        Permissions = $false
    }
    
    try {
        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            $prerequisites.PowerShellVersion = $true
            Write-Log "PowerShell version check passed: $($PSVersionTable.PSVersion)" -Level "DEBUG"
        } else {
            Write-Log "PowerShell version too old: $($PSVersionTable.PSVersion)" -Level "ERROR"
        }
        
        # Check Windows Forms
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $prerequisites.WindowsForms = $true
            Write-Log "Windows Forms available" -Level "DEBUG"
        } catch {
            Write-Log "Windows Forms not available: $($_.Exception.Message)" -Level "ERROR"
        }
        
        # Check PowerCLI
        $prerequisites.PowerCLI = Test-PowerCLIAvailability
        
        # Check directories
        $allDirsExist = $true
        foreach ($dir in @($script:ConfigDir, $script:LogDir, $script:ReportsDir, $script:TempDir)) {
            if (-not (Test-Path -Path $dir)) {
                $allDirsExist = $false
                Write-Log "Required directory missing: $($dir)" -Level "ERROR"
            }
        }
        $prerequisites.Directories = $allDirsExist
        
        # Check write permissions
        try {
            $testFile = Join-Path -Path $script:ConfigDir -ChildPath "test.tmp"
            "test" | Out-File -FilePath $testFile -Force
            Remove-Item -Path $testFile -Force
            $prerequisites.Permissions = $true
            Write-Log "Write permissions check passed" -Level "DEBUG"
        } catch {
            Write-Log "Write permissions check failed: $($_.Exception.Message)" -Level "ERROR"
        }
        
        # Log summary
        $passedCount = ($prerequisites.Values | Where-Object { $_ -eq $true }).Count
        $totalCount = $prerequisites.Count
        Write-Log "Prerequisites check: $($passedCount)/$($totalCount) passed" -Level "INFO"
        
        return $prerequisites
        
    } catch {
        Write-Log "Error testing prerequisites: $($_.Exception.Message)" -Level "ERROR"
        return $prerequisites
    }
}

#endregion

#region Utility Functions

function Get-ApplicationInfo {
    <#
    .SYNOPSIS
        Returns application information
    #>
    return [PSCustomObject]@{
        Name = "vCenter Migration Workflow Manager"
        Version = "1.0"
        Author = "vCenter Migration Team"
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OS = $PSVersionTable.OS
        AppRoot = $script:AppRoot
        ConfigPath = $script:ConfigPath
        LogPath = $script:LogPath
        StartTime = Get-Date
    }
}

function Show-ApplicationInfo {
    <#
    .SYNOPSIS
        Displays application information
    #>
    $info = Get-ApplicationInfo
    
    Write-Host "=== Application Information ===" -ForegroundColor Cyan
    Write-Host "Name: $($info.Name)" -ForegroundColor White
    Write-Host "Version: $($info.Version)" -ForegroundColor White
    Write-Host "Author: $($info.Author)" -ForegroundColor White
    Write-Host "PowerShell Version: $($info.PowerShellVersion)" -ForegroundColor White
    Write-Host "Operating System: $($info.OS)" -ForegroundColor White
    Write-Host "Application Root: $($info.AppRoot)" -ForegroundColor White
    Write-Host "Configuration: $($info.ConfigPath)" -ForegroundColor White
    Write-Host "Log File: $($info.LogPath)" -ForegroundColor White
    Write-Host "Start Time: $($info.StartTime)" -ForegroundColor White
    Write-Host "===============================" -ForegroundColor Cyan
}

function ConvertTo-SecureStringFromPlainText {
    <#
    .SYNOPSIS
        Safely converts plain text to secure string
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainText
    )
    
    try {
        return ConvertTo-SecureString $PlainText -AsPlainText -Force
    } catch {
        Write-Log "Error converting to secure string: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function ConvertFrom-SecureStringToPlainText {
    <#
    .SYNOPSIS
        Safely converts secure string to plain text
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$SecureString
    )
    
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        try {
            return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    } catch {
        Write-Log "Error converting from secure string: $($_.Exception.Message)" -Level "ERROR"
        return ""
    }
}

function Test-PathWritable {
    <#
    .SYNOPSIS
        Tests if a path is writable
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $testFile = Join-Path -Path $Path -ChildPath "writetest_$(Get-Random).tmp"
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item -Path $testFile -Force
        return $true
    } catch {
        return $false
    }
}

function Get-UniqueFileName {
    <#
    .SYNOPSIS
        Generates a unique filename in the specified directory
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseName,
        
        [Parameter(Mandatory = $false)]
        [string]$Extension = ".txt"
    )
    
    $counter = 1
    do {
        if ($counter -eq 1) {
            $fileName = "$($BaseName)$($Extension)"
        } else {
            $fileName = "$($BaseName)_$($counter)$($Extension)"
        }
        $fullPath = Join-Path -Path $Directory -ChildPath $fileName
        $counter++
    } while (Test-Path -Path $fullPath)
    
    return $fullPath
}

#endregion

#region Startup Initialization

# Initialize the environment when this script is loaded
try {
    Write-Host "Loading vCenter Migration Workflow Manager globals..." -ForegroundColor Green
    
    # Show application info
    Show-ApplicationInfo
    
    # Initialize environment
    if (Initialize-Environment) {
        Write-Host "Environment initialized successfully" -ForegroundColor Green
    } else {
        Write-Host "Environment initialization completed with warnings" -ForegroundColor Yellow
    }
    
    # Test prerequisites
    $prereqResults = Test-Prerequisites
    $failedPrereqs = $prereqResults.GetEnumerator() | Where-Object { $_.Value -eq $false }
    
    if ($failedPrereqs.Count -gt 0) {
        Write-Host "Warning: Some prerequisites failed:" -ForegroundColor Yellow
        foreach ($failed in $failedPrereqs) {
            Write-Host "  - $($failed.Key)" -ForegroundColor Red
        }
    }
    
    Write-Log "Globals.ps1 loaded successfully" -Level "INFO"
    
} catch {
    Write-Error "Critical error loading globals: $($_.Exception.Message)"
    Write-Log "Critical error in globals initialization: $($_.Exception.Message)" -Level "ERROR"
}

#endregion

# Export key variables for use in other scripts
$script:GlobalsLoaded = $true
