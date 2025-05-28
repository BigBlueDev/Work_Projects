# Globals.ps1
# Global variables, functions, and configuration for AI Gen Workflow Wrapper
# Enhanced version using PathManager and .psd1 configuration

#region Initialization and Path Management Integration

# Ensure PathManager is available
if (-not ([System.Management.Automation.PSTypeName]'PathManager').Type) {
    $pathManagerScript = Join-Path $PSScriptRoot "PathManager.ps1"
    if (Test-Path $pathManagerScript) {
        . $pathManagerScript
    } else {
        Write-Warning "PathManager.ps1 not found. Some path functions may not work correctly."
    }
}

# Initialize paths if not already done
if (-not [PathManager]::IsInitialized) {
    Initialize-AppPaths
}

#endregion

#region Application State Variables

# Core application state
$script:Scripts = @()
$script:Parameters = @()
$script:SelectedScript = $null
$script:SelectedParameter = $null
$script:Config = @{}
$script:AppConfig = @{}

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
$script:LastConfigSave = $null

#endregion

#region Enhanced Logging System

# Logging configuration from AppConfig.psd1
$script:LoggingConfig = Get-AppConfig -ConfigPath "Logging" -DefaultValue @{
    DefaultLevel = 'INFO'
    EnableFileLogging = $true
    EnableConsoleLogging = $true
    MaxLogFileSizeMB = 10
    MaxLogFiles = 5
    DateFormat = 'yyyy-MM-dd HH:mm:ss'
}

# Current log file path
$script:CurrentLogFile = Get-AppFileFromPattern -PathName "Logs" -PatternName "LogFile"

# Enhanced logging function with configuration support
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory = $false)]
        [string]$Source = "Application",
        
        [Parameter(Mandatory = $false)]
        [switch]$Force  # Override level filtering
    )
    
    try {
        # Check if we should log this level
        $configLevel = $script:LoggingConfig.DefaultLevel
        $levelHierarchy = @{
            'DEBUG' = 0
            'INFO' = 1
            'WARNING' = 2
            'ERROR' = 3
            'CRITICAL' = 4
        }
        
        if (-not $Force -and $levelHierarchy[$Level] -lt $levelHierarchy[$configLevel]) {
            return  # Skip logging this level
        }
        
        $timestamp = Get-Date -Format $script:LoggingConfig.DateFormat
        $logEntry = "[$timestamp] [$Level] [$Source] $Message"
        
        # File logging
        if ($script:LoggingConfig.EnableFileLogging) {
            try {
                # Check log file size and rotate if needed
                if (Test-Path $script:CurrentLogFile) {
                    $fileSize = (Get-Item $script:CurrentLogFile).Length / 1MB
                    if ($fileSize -gt $script:LoggingConfig.MaxLogFileSizeMB) {
                        Rotate-LogFile
                    }
                }
                
                Add-Content -Path $script:CurrentLogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
            } catch {
                # Silent fail for file logging issues
            }
        }
        
        # Console logging
        if ($script:LoggingConfig.EnableConsoleLogging) {
            switch ($Level) {
                "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
                "INFO" { Write-Host $logEntry -ForegroundColor White }
                "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
                "ERROR" { Write-Host $logEntry -ForegroundColor Red }
                "CRITICAL" { 
                    Write-Host $logEntry -ForegroundColor Magenta
                    Write-Host "CRITICAL ERROR LOGGED - Check log file for details" -ForegroundColor Red -BackgroundColor Yellow
                }
            }
        }
    } catch {
        # Ultimate fallback - write to console without formatting
        Write-Warning "Logging system error: $($_.Exception.Message)"
        Write-Host "[$Level] $Message" -ForegroundColor Red
    }
}

# Log file rotation
function Rotate-LogFile {
    try {
        $logDir = Get-AppPath -PathName "Logs"
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($script:CurrentLogFile)
        $extension = [System.IO.Path]::GetExtension($script:CurrentLogFile)
        
        # Rotate existing files
        for ($i = $script:LoggingConfig.MaxLogFiles; $i -gt 1; $i--) {
            $oldFile = Join-Path $logDir "$baseName.$($i-1)$extension"
            $newFile = Join-Path $logDir "$baseName.$i$extension"
            
            if (Test-Path $oldFile) {
                if (Test-Path $newFile) {
                    Remove-Item $newFile -Force
                }
                Move-Item $oldFile $newFile -Force
            }
        }
        
        # Move current log to .1
        $archiveFile = Join-Path $logDir "$baseName.1$extension"
        if (Test-Path $script:CurrentLogFile) {
            Move-Item $script:CurrentLogFile $archiveFile -Force
        }
        
        Write-Log "Log file rotated. Previous log archived as $archiveFile" -Level "INFO" -Force
    } catch {
        Write-Warning "Failed to rotate log file: $_"
    }
}

#endregion

#region Configuration Management with .psd1 Integration

function Initialize-ApplicationConfiguration {
    <#
    .SYNOPSIS
        Initializes application configuration using both .psd1 app config and runtime JSON config
    #>
    
    try {
        # Load application configuration from .psd1
        $script:AppConfig = @{}
        
        # Get all configuration sections
        $script:AppConfig.ApplicationInfo = Get-AppConfig -ConfigPath "ApplicationInfo" -DefaultValue @{}
        $script:AppConfig.UI = Get-AppConfig -ConfigPath "UI" -DefaultValue @{}
        $script:AppConfig.Execution = Get-AppConfig -ConfigPath "Execution" -DefaultValue @{}
        $script:AppConfig.Features = Get-AppConfig -ConfigPath "Features" -DefaultValue @{}
        
        # Load runtime configuration from JSON
        $configFile = Get-AppFileFromPattern -PathName "Config" -PatternName "ConfigFile"
        if (Test-Path $configFile) {
            $jsonContent = Get-Content -Path $configFile -Raw | ConvertFrom-Json -AsHashtable
            $script:Config = $jsonContent
            Write-Log "Runtime configuration loaded from $configFile" -Level "INFO"
        } else {
            $script:Config = Initialize-DefaultRuntimeConfiguration
            Save-RuntimeConfiguration
        }
        
        Write-Log "Application configuration initialized successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error initializing configuration: $($_.Exception.Message)" -Level "ERROR"
        $script:Config = Initialize-DefaultRuntimeConfiguration
    }
}

function Initialize-DefaultRuntimeConfiguration {
    <#
    .SYNOPSIS
        Creates default runtime configuration (separate from .psd1 app config)
    #>
    
    return @{
        Runtime = @{
            LastStartup = Get-Date
            SessionCount = 1
            LastScriptDirectory = Get-AppPath -PathName "Root"
            WindowPosition = $script:AppConfig.UI.DefaultPosition
            WindowSize = $script:AppConfig.UI.DefaultWindowSize
        }
        UserPreferences = @{
            ShowParameterTooltips = $true
            AutoSaveOnExit = $script:AppConfig.UI.AutoSave
            ConfirmBeforeDelete = $true
            RecentScripts = @()
            MaxRecentScripts = 10
        }
        ScriptSettings = @{
            DefaultTimeout = $script:AppConfig.Execution.TimeoutSeconds
            ShowExecutionWindow = $script:AppConfig.Execution.ShowExecutionWindow
            CaptureOutput = $script:AppConfig.Execution.CaptureOutput
        }
    }
}

function Save-RuntimeConfiguration {
    <#
    .SYNOPSIS
        Saves runtime configuration to JSON file
    #>
    
    try {
        $configFile = Get-AppFileFromPattern -PathName "Config" -PatternName "ConfigFile"
        
        # Update last save time
        $script:Config.Runtime.LastSaved = Get-Date
        
        # Convert to JSON and save
        $jsonConfig = $script:Config | ConvertTo-Json -Depth 10
        Set-Content -Path $configFile -Value $jsonConfig -Encoding UTF8
        
        $script:LastConfigSave = Get-Date
        Write-Log "Runtime configuration saved to $configFile" -Level "DEBUG"
        
    } catch {
        Write-Log "Error saving runtime configuration: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Get-ApplicationSetting {
    <#
    .SYNOPSIS
        Gets a setting value from either app config (.psd1) or runtime config (JSON)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingPath,
        
        [Parameter(Mandatory = $false)]
        [object]$DefaultValue = $null,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("AppConfig", "RuntimeConfig", "Auto")]
        [string]$Source = "Auto"
    )
    
    if ($Source -eq "AppConfig" -or $Source -eq "Auto") {
        $appValue = Get-AppConfig -ConfigPath $SettingPath -DefaultValue $null
        if ($null -ne $appValue) {
            return $appValue
        }
    }
    
    if ($Source -eq "RuntimeConfig" -or $Source -eq "Auto") {
        # Navigate through runtime config
        $parts = $SettingPath -split '\.'
        $current = $script:Config
        
        foreach ($part in $parts) {
            if ($current -is [hashtable] -and $current.ContainsKey($part)) {
                $current = $current[$part]
            } else {
                return $DefaultValue
            }
        }
        return $current
    }
    
    return $DefaultValue
}

function Set-RuntimeSetting {
    <#
    .SYNOPSIS
        Sets a runtime configuration value
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingPath,
        
        [Parameter(Mandatory = $true)]
        [object]$Value
    )
    
    $parts = $SettingPath -split '\.'
    $current = $script:Config
    
    for ($i = 0; $i -lt ($parts.Length - 1); $i++) {
        $part = $parts[$i]
        if (-not $current.ContainsKey($part)) {
            $current[$part] = @{}
        }
        $current = $current[$part]
    }
    
    $current[$parts[-1]] = $Value
    Write-Log "Runtime setting updated: $SettingPath = $Value" -Level "DEBUG"
}

#endregion

#region Script Management Functions

function Add-ScriptToCollection {
    <#
    .SYNOPSIS
        Adds a new script to the collection with enhanced metadata
    #>
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
        
        # Auto-detect parameters if none provided
        if ($Parameters.Count -eq 0) {
            $detectedParams = Get-ScriptParameters -ScriptPath $Path
            foreach ($param in $detectedParams) {
                $Parameters[$param.Name] = @{
                    Type = $param.Type
                    Required = $param.Required
                    DefaultValue = $param.DefaultValue
                    Description = $param.Description
                    CurrentValue = $param.DefaultValue
                }
            }
        }
        
        # Create enhanced script object
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
            FileSize = (Get-Item $Path).Length
            Hash = (Get-FileHash $Path -Algorithm SHA256).Hash
        }
        
        # Add to collection
        $script:Scripts += $scriptObject
        
        # Add to recent scripts
        Add-ToRecentScripts -ScriptPath $Path
        
        Write-Log "Added script: $Name ($Path)" -Level "INFO"
        return $scriptObject
        
    } catch {
        Write-Log "Error adding script: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-ScriptParameters {
    <#
    .SYNOPSIS
        Enhanced script parameter detection with better parsing
    #>
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
        
        # Parse using AST for better accuracy
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
        
        # Find param blocks
        $paramBlocks = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ParamBlockAst]
        }, $true)
        
        foreach ($paramBlock in $paramBlocks) {
            foreach ($param in $paramBlock.Parameters) {
                $paramName = $param.Name.VariablePath.UserPath
                $paramType = if ($param.StaticType) { $param.StaticType.Name } else { "Object" }
                
                # Extract attributes
                $isMandatory = $false
                $defaultValue = $null
                $helpMessage = ""
                
                foreach ($attribute in $param.Attributes) {
                    if ($attribute.TypeName.Name -eq "Parameter") {
                        foreach ($namedArg in $attribute.NamedArguments) {
                            if ($namedArg.ArgumentName -eq "Mandatory" -and $namedArg.Argument.Value) {
                                $isMandatory = $true
                            }
                            if ($namedArg.ArgumentName -eq "HelpMessage") {
                                $helpMessage = $namedArg.Argument.Value
                            }
                        }
                    }
                }
                
                # Get default value
                if ($param.DefaultValue) {
                    $defaultValue = $param.DefaultValue.Value
                }
                
                $parameters += [PSCustomObject]@{
                    Name = $paramName
                    Type = $paramType
                    Required = $isMandatory
                    DefaultValue = $defaultValue
                    Description = $helpMessage
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

function Add-ToRecentScripts {
    param([string]$ScriptPath)
    
    $recentScripts = Get-ApplicationSetting -SettingPath "UserPreferences.RecentScripts" -DefaultValue @()
    $maxRecent = Get-ApplicationSetting -SettingPath "UserPreferences.MaxRecentScripts" -DefaultValue 10
    
    # Remove if already exists
    $recentScripts = $recentScripts | Where-Object { $_ -ne $ScriptPath }
    
    # Add to front
    $recentScripts = @($ScriptPath) + $recentScripts
    
    # Trim to max
    if ($recentScripts.Count -gt $maxRecent) {
        $recentScripts = $recentScripts[0..($maxRecent-1)]
    }
    
    Set-RuntimeSetting -SettingPath "UserPreferences.RecentScripts" -Value $recentScripts
}

#endregion

#region Enhanced UI Helper Functions

function Update-ScriptsListView {
    <#
    .SYNOPSIS
        Updates the scripts ListView with enhanced formatting
    #>
    
    if ($script:ScriptsListView) {
        try {
            $script:ScriptsListView.BeginUpdate()
            $script:ScriptsListView.Items.Clear()
            
            foreach ($scriptItem in $script:Scripts) {
                $listViewItem = New-Object System.Windows.Forms.ListViewItem($scriptItem.Name)
                $listViewItem.SubItems.Add($scriptItem.Path)
                $listViewItem.SubItems.Add($scriptItem.Description)
                $listViewItem.SubItems.Add($scriptItem.Parameters.Count)
                $listViewItem.SubItems.Add($scriptItem.ExecutionCount)
                $listViewItem.SubItems.Add(
                    if ($scriptItem.LastExecuted) { 
                        $scriptItem.LastExecuted.ToString("yyyy-MM-dd HH:mm")
                    } else { 
                        "Never" 
                    }
                )
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
        Updates the parameters ListView with enhanced parameter info
    #>
    
    if ($script:ParametersListView -and $script:SelectedScript) {
        try {
            $script:ParametersListView.BeginUpdate()
            $script:ParametersListView.Items.Clear()
            
            foreach ($paramPair in $script:SelectedScript.Parameters.GetEnumerator()) {
                $param = $paramPair.Value
                $listViewItem = New-Object System.Windows.Forms.ListViewItem($paramPair.Key)
                $listViewItem.SubItems.Add($param.CurrentValue ?? $param.DefaultValue ?? "")
                $listViewItem.SubItems.Add($param.Type ?? "String")
                $listViewItem.SubItems.Add(if ($param.Required) { "Yes" } else { "No" })
                $listViewItem.SubItems.Add($param.Description ?? "")
                
                # Color coding for required parameters
                if ($param.Required -and [string]::IsNullOrEmpty($param.CurrentValue)) {
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
    <#
    .SYNOPSIS
        Enhanced parameter editing with validation
    #>
    param(
        [string]$ParameterName = "",
        [string]$CurrentValue = "",
        [string]$ParameterType = "String",
        [bool]$IsRequired = $false,
        [string]$Description = ""
    )
    
    try {
        # Load EditParam form using PathManager
        $designerPath = Get-AppFileFromPattern -PathName "SubForms" -PatternName "EditForm"
        $designerPath += ".designer.ps1"
        
        $logicPath = Get-AppFileFromPattern -PathName "SubForms" -PatternName "EditForm"  
        $logicPath += ".ps1"
        
        Write-Log "Loading EditParam form: Designer=$designerPath, Logic=$logicPath" -Level "DEBUG"
        
        if (Test-Path $designerPath) { . $designerPath }
        if (Test-Path $logicPath) { . $logicPath }
        
        # Find the form variable
        $formPattern = Get-AppConfig -ConfigPath "FilePatterns.EditForm"
        $possibleNames = @($formPattern, $formPattern.ToLower(), "$($formPattern)Form", "form$formPattern")
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
            [System.Windows.Forms.MessageBox]::Show(
                "Parameter editing form could not be loaded.",
                "Form Load Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return [System.Windows.Forms.DialogResult]::Cancel
        }
        
    } catch {
        Write-Log "Error loading EditParam form: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error loading parameter editing form: $($_.Exception.Message)",
            "Form Load Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return [System.Windows.Forms.DialogResult]::Cancel
    }
}

#endregion

#region Application Lifecycle Management

function Initialize-Application {
    <#
    .SYNOPSIS
        Enhanced application initialization
    #>
    
    try {
        Write-Log "Initializing AI Gen Workflow Wrapper application" -Level "INFO"
        
        # Initialize configuration
        Initialize-ApplicationConfiguration
        
        # Initialize data structures
        if (-not $script:Scripts) {
            $script:Scripts = @()
        }
        
        # Load saved scripts if any
        $scriptsFile = Get-AppFilePath -PathName "Data" -FileName "saved_scripts.json" -EnsureDirectory $false
        if (Test-Path $scriptsFile) {
            try {
                $savedScripts = Get-Content $scriptsFile -Raw | ConvertFrom-Json
                $script:Scripts = $savedScripts
                Write-Log "Loaded $($script:Scripts.Count) saved scripts" -Level "INFO"
            } catch {
                Write-Log "Error loading saved scripts: $_" -Level "WARNING"
            }
        }
        
        # Update session count
        $sessionCount = Get-ApplicationSetting -SettingPath "Runtime.SessionCount" -DefaultValue 0
        Set-RuntimeSetting -SettingPath "Runtime.SessionCount" -Value ($sessionCount + 1)
        Set-RuntimeSetting -SettingPath "Runtime.LastStartup" -Value (Get-Date)
        
        Write-Log "Application initialization completed successfully (Session #$($sessionCount + 1))" -Level "INFO"
        
    } catch {
        Write-Log "Critical error during application initialization: $($_.Exception.Message)" -Level "CRITICAL"
        throw
    }
}

function Save-ApplicationState {
    <#
    .SYNOPSIS
        Saves current application state
    #>
    
    try {
        # Save scripts
        $scriptsFile = Get-AppFilePath -PathName "Data" -FileName "saved_scripts.json"
        $script:Scripts | ConvertTo-Json -Depth 10 | Set-Content $scriptsFile -Encoding UTF8
        
        # Save runtime configuration
        Save-RuntimeConfiguration
        
        Write-Log "Application state saved successfully" -Level "INFO"
        
    } catch {
        Write-Log "Error saving application state: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Exit-Application {
    <#
    .SYNOPSIS
        Clean application shutdown
    #>
    
    try {
        Write-Log "Application shutdown initiated" -Level "INFO"
        
        # Auto-save if enabled
        if (Get-ApplicationSetting -SettingPath "UserPreferences.AutoSaveOnExit" -DefaultValue $true) {
            Save-ApplicationState
        }
        
        # Calculate session duration
        $sessionDuration = (Get-Date) - $script:ApplicationStartTime
        Write-Log "Session duration: $($sessionDuration.ToString())" -Level "INFO"
        Write-Log "Application shutdown completed" -Level "INFO"
        
    } catch {
        Write-Log "Error during application shutdown: $($_.Exception.Message)" -Level "ERROR"
    }
}

#endregion

#region Auto-Initialization

# Initialize application when this file is loaded
Write-Log "Loading Globals.ps1 - Enhanced global functions and variables" -Level "INFO"

# Auto-initialize if not already done
if (-not $script:Config -or $script:Config.Count -eq 0) {
    Initialize-Application
}

# Register cleanup on module removal
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Exit-Application
}

#endregion

# Export key functions for external use
Export-ModuleMember -Function @(
    'Write-Log',
    'Initialize-Application',
    'Save-ApplicationState', 
    'Exit-Application',
    'Add-ScriptToCollection',
    'Update-ScriptsListView',
    'Update-ParametersListView',
    'Show-EditParameterDialog',
    'Get-ApplicationSetting',
    'Set-RuntimeSetting'
) -Variable @(
    'Scripts',
    'SelectedScript',
    'SelectedParameter',
    'Config',
    'AppConfig'
)
