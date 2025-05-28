# Globals.ps1
# Global variables and functions for AI Gen Workflow Wrapper
# Simplified version with syntax fixes

#region Application State Variables

# Core application state
$script:Scripts = @()
$script:Parameters = @()
$script:SelectedScript = $null
$script:SelectedParameter = $null
$script:Config = @{}

# Form control references (set when forms are loaded)
$script:MainForm = $null
$script:ScriptsListView = $null
$script:ParametersListView = $null
$script:SelectedScriptLabel = $null
$script:ExecuteButton = $null
$script:AddScriptButton = $null
$script:RemoveScriptButton = $null
$script:EditParameterButton = $null

# Application runtime state
$script:BrowsingScript = $false
$script:EventHandlersRegistered = $false
$script:ApplicationStartTime = Get-Date

#endregion

#region Simple Path Management Functions

function Get-AppDataPath {
    param([string]$FileName)
    $dataDir = if ($Global:Paths) { $Global:Paths.Data } else { Join-Path $PSScriptRoot "Data" }
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    return Join-Path $dataDir $FileName
}

function Get-AppConfigPath {
    param([string]$FileName)
    $configDir = if ($Global:Paths) { $Global:Paths.Config } else { Join-Path $PSScriptRoot "Data\Config" }
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    return Join-Path $configDir $FileName
}

function Get-AppLogPath {
    param([string]$FileName)
    $logDir = if ($Global:Paths) { $Global:Paths.Logs } else { Join-Path $PSScriptRoot "Data\Logs" }
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    return Join-Path $logDir $FileName
}

#endregion

#region Enhanced Logging System

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [string]$Source = "Application"
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] [$Source] $Message"
        
        # File logging if Global:LogFile is available
        if ($Global:LogFile) {
            try {
                Add-Content -Path $Global:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
            } catch {
                # Silent fail for file logging issues
            }
        }
        
        # Console logging with color coding
        switch ($Level) {
            "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
            "INFO" { Write-Host $logEntry -ForegroundColor White }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "CRITICAL" { Write-Host $logEntry -ForegroundColor Magenta }
        }
    } catch {
        # Ultimate fallback
        Write-Warning "Logging system error: $($_.Exception.Message)"
        Write-Host "[$Level] $Message" -ForegroundColor Red
    }
}

#endregion

#region Configuration Management

function Initialize-DefaultConfiguration {
    return @{
        Application = @{
            Name = "AI Gen Workflow Wrapper"
            Version = "1.0.0"
            LogLevel = "INFO"
            AutoSave = $true
        }
        UI = @{
            WindowWidth = 800
            WindowHeight = 600
            Theme = "Default"
        }
        Scripts = @{
            DefaultDirectory = if ($Global:ScriptRoot) { $Global:ScriptRoot } else { $PSScriptRoot }
            AllowedExtensions = @(".ps1", ".bat", ".cmd")
        }
        Paths = @{
            ConfigDirectory = Get-AppConfigPath -FileName ""
            LogDirectory = Get-AppLogPath -FileName ""
            DataDirectory = Get-AppDataPath -FileName ""
        }
    }
}

function Save-Configuration {
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Config = $script:Config
    )
    
    try {
        $configFile = Get-AppConfigPath -FileName "config.json"
        Write-Log "Saving configuration to: $configFile" -Level "DEBUG"
        
        $jsonConfig = $Config | ConvertTo-Json -Depth 10
        Set-Content -Path $configFile -Value $jsonConfig -Encoding UTF8
        
        Write-Log "Configuration saved successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error saving configuration: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Load-Configuration {
    try {
        $configFile = Get-AppConfigPath -FileName "config.json"
        Write-Log "Loading configuration from: $configFile" -Level "DEBUG"
        
        if (Test-Path -Path $configFile) {
            $jsonContent = Get-Content -Path $configFile -Raw
            $script:Config = $jsonContent | ConvertFrom-Json -AsHashtable
            Write-Log "Configuration loaded successfully" -Level "INFO"
        } else {
            Write-Log "Configuration file not found, initializing defaults" -Level "INFO"
            $script:Config = Initialize-DefaultConfiguration
            Save-Configuration -Config $script:Config
        }
        
        return $script:Config
        
    } catch {
        Write-Log "Error loading configuration: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Using default configuration" -Level "INFO"
        $script:Config = Initialize-DefaultConfiguration
        return $script:Config
    }
}

#endregion

#region Script Management Functions

function Add-ScriptToCollection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )
    
    try {
        if (-not (Test-Path -Path $Path)) {
            throw "Script file not found: $Path"
        }
        
        # Generate name if not provided
        if (-not $Name) {
            $Name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        }
        
        # Check for duplicates
        $existingScript = $script:Scripts | Where-Object { $_.Path -eq $Path }
        if ($existingScript) {
            throw "Script already exists: $Path"
        }
        
        # Create script object
        $scriptObject = [PSCustomObject]@{
            Id = [guid]::NewGuid().ToString()
            Name = $Name
            Path = $Path
            Description = $Description
            Parameters = $Parameters
            DateAdded = Get-Date
            LastModified = (Get-Item $Path).LastWriteTime
            ExecutionCount = 0
            LastExecuted = $null
            LastResult = $null
        }
        
        # Add to collection
        $script:Scripts += $scriptObject
        
        Write-Log "Added script: $Name ($Path)" -Level "INFO"
        return $scriptObject
        
    } catch {
        Write-Log "Error adding script: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-ScriptParameters {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )
    
    try {
        if (-not (Test-Path -Path $ScriptPath)) {
            throw "Script file not found: $ScriptPath"
        }
        
        $scriptContent = Get-Content -Path $ScriptPath -Raw
        $parameters = @()
        
        # Simple regex-based parameter detection
        $paramBlockPattern = '(?s)param\s*\( (.*?) \)'
        $paramMatches = [regex]::Matches($scriptContent, $paramBlockPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        foreach ($match in $paramMatches) {
            $paramContent = $match.Groups[1].Value
            
            # Extract individual parameters
            $individualParamPattern = '\[ ([^ \]]+) \]\s*\$(\w+)(?:\s*=\s*([^, \)]+))?'
            $individualMatches = [regex]::Matches($paramContent, $individualParamPattern)
            
            foreach ($paramMatch in $individualMatches) {
                $paramType = $paramMatch.Groups[1].Value.Trim()
                $paramName = $paramMatch.Groups[2].Value.Trim()
                $defaultValue = if ($paramMatch.Groups[3].Success) { $paramMatch.Groups[3].Value.Trim() } else { $null }
                
                $parameters += [PSCustomObject]@{
                    Name = $paramName
                    Type = $paramType
                    DefaultValue = $defaultValue
                    Required = $paramType -like "*Mandatory*"
                    Description = ""
                }
            }
        }
        
        Write-Log "Detected $($parameters.Count) parameters in script: $ScriptPath" -Level "DEBUG"
        return $parameters
        
    } catch {
        Write-Log "Error parsing script parameters: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
}

#endregion

#region UI Helper Functions
function Show-ModuleStatus {
    <#
    .SYNOPSIS
        Displays current module status for troubleshooting
    #>
    
    if (Get-Command "Get-ModuleStatus" -ErrorAction SilentlyContinue) {
        $modules = @("PowerShellGet", "PackageManagement", "ImportExcel", "PSWriteHTML")
        $statusReport = Get-ModuleStatus -ModuleNames $modules
        
        Write-Host "`n=== Module Status Report ===" -ForegroundColor Cyan
        foreach ($module in $statusReport) {
            $status = if ($module.IsImported) { "? Imported" } elseif ($module.IsInstalled) { "? Installed" } else { "? Missing" }
            $version = if ($module.ImportedVersion) { "v$($module.ImportedVersion)" } elseif ($module.InstalledVersion) { "v$($module.InstalledVersion)" } else { "N/A" }
            
            Write-Host "$($module.ModuleName): $status ($version)" -ForegroundColor $(
                if ($module.IsImported) { "Green" } elseif ($module.IsInstalled) { "Yellow" } else { "Red" }
            )
        }
    } else {
        Write-Warning "ModuleManager not available - cannot show module status"
    }
}

function Update-ScriptsListView {
    <#
    .SYNOPSIS
        Updates the scripts ListView with current script collection
    #>
    
    if ($script:ScriptsListView) {
        try {
            $script:ScriptsListView.BeginUpdate()
            $script:ScriptsListView.Items.Clear()
            
            foreach ($scriptItem in $script:Scripts) {
                $listViewItem = New-Object System.Windows.Forms.ListViewItem($scriptItem.Name)
                $listViewItem.SubItems.Add($scriptItem.Path)
                $listViewItem.SubItems.Add($scriptItem.Description)
                $listViewItem.SubItems.Add($scriptItem.Parameters.Count.ToString())
                $listViewItem.SubItems.Add($scriptItem.ExecutionCount.ToString())
                
                # Format last executed date
                $lastExecutedText = if ($scriptItem.LastExecuted) { 
                    $scriptItem.LastExecuted.ToString("yyyy-MM-dd HH:mm")
                } else { 
                    "Never" 
                }
                $listViewItem.SubItems.Add($lastExecutedText)
                
                $listViewItem.Tag = $scriptItem
                
                # Color coding based on status
                if ($scriptItem.ExecutionCount -eq 0) {
                    $listViewItem.ForeColor = [System.Drawing.Color]::Gray
                } elseif ($scriptItem.LastResult -eq "Success") {
                    $listViewItem.ForeColor = [System.Drawing.Color]::DarkGreen
                } elseif ($scriptItem.LastResult -eq "Error") {
                    $listViewItem.ForeColor = [System.Drawing.Color]::DarkRed
                }
                
                $script:ScriptsListView.Items.Add($listViewItem)
            }
            
            Write-Log "Updated scripts ListView with $($script:Scripts.Count) items" -Level "DEBUG"
            
        } catch {
            Write-Log "Error updating scripts ListView: $($_.Exception.Message)" -Level "ERROR"
        } finally {
            $script:ScriptsListView.EndUpdate()
        }
    }
}

function Update-ParametersListView {
    <#
    .SYNOPSIS
        Updates the parameters ListView with parameters from selected script
    #>
    
    if ($script:ParametersListView -and $script:SelectedScript) {
        try {
            $script:ParametersListView.BeginUpdate()
            $script:ParametersListView.Items.Clear()
            
            foreach ($paramPair in $script:SelectedScript.Parameters.GetEnumerator()) {
                $param = $paramPair.Value
                $listViewItem = New-Object System.Windows.Forms.ListViewItem($paramPair.Key)
                
                $currentValue = if ($param.CurrentValue) { $param.CurrentValue } else { $param.DefaultValue }
                if (-not $currentValue) { $currentValue = "" }
                $listViewItem.SubItems.Add($currentValue)
                
                $paramType = if ($param.Type) { $param.Type } else { "String" }
                $listViewItem.SubItems.Add($paramType)
                
                $isRequired = if ($param.Required) { "Yes" } else { "No" }
                $listViewItem.SubItems.Add($isRequired)
                
                $description = if ($param.Description) { $param.Description } else { "" }
                $listViewItem.SubItems.Add($description)
                
                # Color coding for required parameters
                if ($param.Required -and [string]::IsNullOrEmpty($currentValue)) {
                    $listViewItem.ForeColor = [System.Drawing.Color]::Red
                    $listViewItem.Font = New-Object System.Drawing.Font($listViewItem.Font, [System.Drawing.FontStyle]::Bold)
                }
                
                $script:ParametersListView.Items.Add($listViewItem)
            }
            
            Write-Log "Updated parameters ListView with $($script:SelectedScript.Parameters.Count) items" -Level "DEBUG"
            
        } catch {
            Write-Log "Error updating parameters ListView: $($_.Exception.Message)" -Level "ERROR"
        } finally {
            $script:ParametersListView.EndUpdate()
        }
    }
}

function Show-EditParameterDialog {
    param(
        [string]$ParameterName = "",
        [string]$CurrentValue = "",
        [string]$ParameterType = "String",
        [bool]$IsRequired = $false,
        [string]$Description = ""
    )
    
    try {
        # Load EditParam files directly from root
        $rootDir = if ($Global:ScriptRoot) { $Global:ScriptRoot } else { $PSScriptRoot }
        $designerPath = Join-Path $rootDir "EditParam.designer.ps1"
        $logicPath = Join-Path $rootDir "EditParam.ps1"
        
        Write-Log "Loading EditParam form: Designer=$designerPath, Logic=$logicPath" -Level "DEBUG"
        
        if (Test-Path $designerPath) { . $designerPath }
        if (Test-Path $logicPath) { . $logicPath }
        
        # Find the EditParam form variable
        $possibleNames = @('EditParam', 'editParam', 'EditParamForm', 'formEditParam')
        $editForm = $null
        
        foreach ($name in $possibleNames) {
            $var = Get-Variable -Name $name -ErrorAction SilentlyContinue
            if ($var -and $var.Value -and $var.Value.GetType().Name -like "*Form*") {
                $editForm = $var.Value
                break
            }
        }
        
        if ($editForm) {
            # Set form properties if they exist
            $formProperties = $editForm.PSObject.Properties.Name
            
            if ($formProperties -contains "ParameterName") { $editForm.ParameterName = $ParameterName }
            if ($formProperties -contains "ParameterValue") { $editForm.ParameterValue = $CurrentValue }
            if ($formProperties -contains "ParameterType") { $editForm.ParameterType = $ParameterType }
            if ($formProperties -contains "IsRequired") { $editForm.IsRequired = $IsRequired }
            if ($formProperties -contains "Description") { $editForm.Description = $Description }
            
            Write-Log "Showing EditParam dialog for parameter: $ParameterName" -Level "INFO"
            return $editForm.ShowDialog()
        }
        else {
            Write-Log "EditParam form not found. Tried: $($possibleNames -join ', ')" -Level "WARNING"
            return [System.Windows.Forms.DialogResult]::Cancel
        }
        
    } catch {
        Write-Log "Error loading EditParam form: $($_.Exception.Message)" -Level "ERROR"
        return [System.Windows.Forms.DialogResult]::Cancel
    }
}

#endregion

#region Application Lifecycle Management

function Initialize-Application {
    try {
        Write-Log "Initializing AI Gen Workflow Wrapper application" -Level "INFO"
        
        # Load configuration
        Load-Configuration
        
        # Initialize data structures
        if (-not $script:Scripts) {
            $script:Scripts = @()
        }
        
        Write-Log "Application initialization completed successfully" -Level "INFO"
        
    } catch {
        Write-Log "Critical error during application initialization: $($_.Exception.Message)" -Level "CRITICAL"
        throw
    }
}

function Save-ApplicationState {
    try {
        # Save scripts
        $scriptsFile = Get-AppDataPath -FileName "saved_scripts.json"
        $script:Scripts | ConvertTo-Json -Depth 10 | Set-Content $scriptsFile -Encoding UTF8
        
        # Save configuration
        Save-Configuration
        
        Write-Log "Application state saved successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error saving application state: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

# Initialize application when this file is loaded
Write-Log "Loading Globals.ps1 - Global functions and variables initialized" -Level "INFO"

# Auto-initialize if not already done
if (-not $script:Config -or $script:Config.Count -eq 0) {
    Initialize-Application
}
