# PathManager.ps1
# Centralized, future-proof path management system

class PathManager {
    # Static properties for path configuration
    static [hashtable] $PathConfig = @{}
    static [string] $RootDirectory = ""
    static [bool] $IsInitialized = $false
    
    # Initialize the path manager with auto-detection or explicit root
    static [void] Initialize([string]$ExplicitRoot = "") {
        if ([PathManager]::IsInitialized) { return }
        
        # Determine root directory
        if ($ExplicitRoot -and (Test-Path $ExplicitRoot)) {
            [PathManager]::RootDirectory = $ExplicitRoot
        } else {
            [PathManager]::RootDirectory = [PathManager]::DetectRootDirectory()
        }
        
        Write-Host "PathManager: Root directory set to $([PathManager]::RootDirectory)" -ForegroundColor Cyan
        
        # Load path configuration
        [PathManager]::LoadPathConfiguration()
        [PathManager]::IsInitialized = $true
    }
    
    # Auto-detect root directory based on current script location
    static [string] DetectRootDirectory() {
        $currentLocation = $PSScriptRoot
        if (-not $currentLocation) {
            $currentLocation = Get-Location
        }
        
        # Look for key indicator files to determine root
        $indicators = @("Launch.ps1", "AI_Gen_Workflow_Wrapper.designer.ps1")
        
        $testPath = $currentLocation
        $maxLevels = 5  # Prevent infinite loops
        $level = 0
        
        while ($level -lt $maxLevels) {
            foreach ($indicator in $indicators) {
                if (Test-Path (Join-Path $testPath $indicator)) {
                    return $testPath
                }
            }
            
            $parent = Split-Path -Parent $testPath
            if ($parent -eq $testPath) { break }  # Reached drive root
            $testPath = $parent
            $level++
        }
        
        # Fallback to current location
        return $currentLocation
    }
    
    # Load path configuration from file or use defaults
    static [void] LoadPathConfiguration() {
        $configFile = Join-Path ([PathManager]::RootDirectory) "PathConfig.json"
        
        if (Test-Path $configFile) {
            try {
                $configContent = Get-Content $configFile -Raw | ConvertFrom-Json -AsHashtable
                [PathManager]::PathConfig = $configContent
                Write-Host "PathManager: Loaded path configuration from $configFile" -ForegroundColor Green
                return
            } catch {
                Write-Warning "PathManager: Failed to load path config: $_"
            }
        }
        
        # Use default configuration
        [PathManager]::PathConfig = [PathManager]::GetDefaultConfiguration()
        [PathManager]::SavePathConfiguration()
    }
    
    # Get default path configuration
    static [hashtable] GetDefaultConfiguration() {
        return @{
            Version = "1.0"
            Description = "AI Gen Workflow Wrapper - Path Configuration"
            Paths = @{
                Root = ""  # Will be set to actual root
                Forms = ""  # Same as root in flat structure
                SubForms = ""  # Same as root in flat structure
                Config = "Config"
                Logs = "Logs"
                Data = "Data"
                Resources = "Resources"
                Temp = "Data\Temp"
                Reports = "Data\Reports"
                Exports = "Data\Exports"
                Imports = "Data\Imports"
            }
            FilePatterns = @{
                MainForm = "AI_Gen_Workflow_Wrapper"
                EditForm = "EditParam"
                ConfigFile = "config.json"
                SettingsFile = "settings.json"
                LogFile = "application_{date}.log"
            }
            Extensions = @{
                Scripts = @(".ps1", ".bat", ".cmd")
                Data = @(".json", ".xml", ".csv")
                Logs = @(".log", ".txt")
            }
        }
    }
    
    # Save current configuration to file
    static [void] SavePathConfiguration() {
        $configFile = Join-Path ([PathManager]::RootDirectory) "PathConfig.json"
        try {
            $json = [PathManager]::PathConfig | ConvertTo-Json -Depth 10
            Set-Content -Path $configFile -Value $json -Encoding UTF8
            Write-Host "PathManager: Saved path configuration to $configFile" -ForegroundColor Green
        } catch {
            Write-Warning "PathManager: Failed to save path config: $_"
        }
    }
    
    # Get absolute path for a logical path name
    static [string] GetPath([string]$PathName) {
        if (-not [PathManager]::IsInitialized) {
            [PathManager]::Initialize()
        }
        
        if ([PathManager]::PathConfig.Paths.ContainsKey($PathName)) {
            $relativePath = [PathManager]::PathConfig.Paths[$PathName]
            if ([string]::IsNullOrEmpty($relativePath)) {
                return [PathManager]::RootDirectory
            }
            return Join-Path ([PathManager]::RootDirectory) $relativePath
        }
        
        # Fallback to root if path not found
        Write-Warning "PathManager: Unknown path name '$PathName', using root directory"
        return [PathManager]::RootDirectory
    }
    
    # Get file path with automatic directory creation
    static [string] GetFilePath([string]$PathName, [string]$FileName, [bool]$EnsureDirectory = $true) {
        $directory = [PathManager]::GetPath($PathName)
        
        if ($EnsureDirectory -and (-not (Test-Path $directory))) {
            try {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
                Write-Host "PathManager: Created directory $directory" -ForegroundColor Yellow
            } catch {
                Write-Warning "PathManager: Failed to create directory $directory`: $_"
            }
        }
        
        return Join-Path $directory $FileName
    }
    
    # Get file path with pattern substitution
    static [string] GetFilePathWithPattern([string]$PathName, [string]$PatternName, [hashtable]$Substitutions = @{}) {
        if (-not [PathManager]::PathConfig.FilePatterns.ContainsKey($PatternName)) {
            throw "Unknown file pattern: $PatternName"
        }
        
        $pattern = [PathManager]::PathConfig.FilePatterns[$PatternName]
        
        # Apply substitutions
        foreach ($sub in $Substitutions.GetEnumerator()) {
            $pattern = $pattern -replace "\{$($sub.Key)\}", $sub.Value
        }
        
        # Apply common substitutions
        $pattern = $pattern -replace "\{date\}", (Get-Date -Format "yyyy-MM-dd")
        $pattern = $pattern -replace "\{datetime\}", (Get-Date -Format "yyyy-MM-dd_HH-mm-ss")
        $pattern = $pattern -replace "\{timestamp\}", (Get-Date -Format "yyyyMMddHHmmss")
        
        return [PathManager]::GetFilePath($PathName, $pattern, $true)
    }
    
    # Validate all configured paths
    static [hashtable] ValidatePaths([bool]$CreateMissing = $false) {
        $results = @{
            Valid = @()
            Missing = @()
            Created = @()
            Errors = @()
        }
        
        foreach ($pathPair in [PathManager]::PathConfig.Paths.GetEnumerator()) {
            $fullPath = [PathManager]::GetPath($pathPair.Key)
            
            if (Test-Path $fullPath) {
                $results.Valid += @{ Name = $pathPair.Key; Path = $fullPath }
            } else {
                $results.Missing += @{ Name = $pathPair.Key; Path = $fullPath }
                
                if ($CreateMissing) {
                    try {
                        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                        $results.Created += @{ Name = $pathPair.Key; Path = $fullPath }
                    } catch {
                        $results.Errors += @{ Name = $pathPair.Key; Path = $fullPath; Error = $_.Exception.Message }
                    }
                }
            }
        }
        
        return $results
    }
    
    # Update path configuration (for future migrations)
    static [void] UpdatePathConfiguration([hashtable]$NewPaths) {
        foreach ($pathUpdate in $NewPaths.GetEnumerator()) {
            [PathManager]::PathConfig.Paths[$pathUpdate.Key] = $pathUpdate.Value
            Write-Host "PathManager: Updated path '$($pathUpdate.Key)' to '$($pathUpdate.Value)'" -ForegroundColor Cyan
        }
        [PathManager]::SavePathConfiguration()
    }
}

# Convenience functions for easier access
function Get-AppPath {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Root", "Forms", "SubForms", "Config", "Logs", "Data", "Resources", "Temp", "Reports", "Exports", "Imports")]
        [string]$PathName
    )
    return [PathManager]::GetPath($PathName)
}

function Get-AppFilePath {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Root", "Forms", "SubForms", "Config", "Logs", "Data", "Resources", "Temp", "Reports", "Exports", "Imports")]
        [string]$PathName,
        
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [Parameter(Mandatory=$false)]
        [bool]$EnsureDirectory = $true
    )
    return [PathManager]::GetFilePath($PathName, $FileName, $EnsureDirectory)
}

function Get-AppFilePathFromPattern {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Root", "Forms", "SubForms", "Config", "Logs", "Data", "Resources", "Temp", "Reports", "Exports", "Imports")]
        [string]$PathName,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("MainForm", "EditForm", "ConfigFile", "SettingsFile", "LogFile")]
        [string]$PatternName,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Substitutions = @{}
    )
    return [PathManager]::GetFilePathWithPattern($PathName, $PatternName, $Substitutions)
}

function Initialize-AppPaths {
    param([string]$RootDirectory = "")
    [PathManager]::Initialize($RootDirectory)
}

function Test-AppPaths {
    param([bool]$CreateMissing = $false)
    return [PathManager]::ValidatePaths($CreateMissing)
}

# Export functions for module use
Export-ModuleMember -Function @(
    'Get-AppPath',
    'Get-AppFilePath', 
    'Get-AppFilePathFromPattern',
    'Initialize-AppPaths',
    'Test-AppPaths'
)
