# AppConfig.psd1
# AI Gen Workflow Wrapper - Simplified Configuration for Flat Structure

@{
    # Application metadata
    ApplicationInfo = @{
        Name = 'AI Gen Workflow Wrapper'
        Version = '1.0.0'
        Author = 'Your Name'
        Description = 'PowerShell GUI wrapper for AI-generated workflows'
        Copyright = '(c) 2025. All rights reserved.'
        LastModified = '2025-01-28'
    }

    # Path configuration - simplified for flat structure
    Paths = @{
        # Core directories - all forms are in root
        Root = ''                    # Application root (auto-detected)
        
        # Main data directory with organized subdirectories
        Data = 'Data'               # General data storage
        Resources = 'Resources'     # Images, icons, etc.
        
        # Organized data subdirectories
        Config = 'Data\Config'      # Configuration files
        Logs = 'Data\Logs'          # Log files
        Scripts = 'Data\Scripts'    # User script storage
        Exports = 'Data\Exports'    # Exported configurations
        Imports = 'Data\Imports'    # Import staging area
        Backups = 'Data\Backups'    # Backup files
        Reports = 'Data\Reports'    # Generated reports
        Temp = 'Data\Temp'          # Temporary files
        Cache = 'Data\Cache'        # Application cache
    }

    # File naming patterns - all in root directory
    FilePatterns = @{
        # Form files (all in root)
        MainFormDesigner = 'AI_Gen_Workflow_Wrapper.designer.ps1'
        MainFormLogic = 'AI_Gen_Workflow_Wrapper.ps1'
        EditFormDesigner = 'EditParam.designer.ps1'
        EditFormLogic = 'EditParam.ps1'
        
        # Configuration files
        ConfigFile = 'config.json'
        SettingsFile = 'settings.json'
        UserPrefs = 'userprefs.json'
        AppState = 'appstate.json'
        
        # Log files with date patterns
        LogFile = 'application_{date}.log'
        ErrorLog = 'errors_{date}.log'
        DebugLog = 'debug_{datetime}.log'
        
        # Data files
        ExportFile = 'export_{timestamp}.json'
        BackupFile = 'backup_{date}.zip'
        ScriptCache = 'script_cache.json'
        SavedScripts = 'saved_scripts.json'
    }

    # File extension mappings
    Extensions = @{
        Scripts = @('.ps1', '.bat', '.cmd', '.py')
        Data = @('.json', '.xml', '.csv', '.txt')
        Logs = @('.log', '.txt')
        Archives = @('.zip', '.7z', '.tar')
        Images = @('.png', '.jpg', '.jpeg', '.gif', '.ico')
        Config = @('.json', '.xml', '.psd1')
    }

    # UI Configuration
    UI = @{
        DefaultWindowSize = @{
            Width = 800
            Height = 600
        }
        DefaultPosition = @{
            X = 100
            Y = 100
        }
        Theme = 'Default'
        FontSize = 9
        AutoSave = $true
        AutoSaveIntervalSeconds = 300
        ShowTooltips = $true
        ConfirmOnExit = $false
    }

    # Logging configuration
    Logging = @{
        DefaultLevel = 'INFO'
        EnableFileLogging = $true
        EnableConsoleLogging = $true
        MaxLogFileSizeMB = 10
        MaxLogFiles = 2
        DateFormat = 'yyyy-MM-dd HH:mm:ss'
        RotateLogsOnStartup = $false
    }

    # Script execution settings
    Execution = @{
        TimeoutSeconds = 300
        ShowExecutionWindow = $true
        CaptureOutput = $true
        LogExecution = $true
        AllowedExecutionPolicies = @('RemoteSigned', 'Unrestricted')
        MaxConcurrentScripts = 3
    }

    # Feature flags
    Features = @{
        EnableScriptValidation = $true
        EnableParameterValidation = $true
        EnableAutoBackup = $true
        EnableUpdateCheck = $false
        EnableTelemetry = $false
        EnableScriptCache = $true
        EnableRecentScripts = $true
    }

    # Directory settings
    DirectorySettings = @{
        EnsureDirectoriesOnStartup = $true
        CreateMissingDirectories = $true
        ValidatePermissions = $true
        RequiredDirectories = @(
            'Data'
            'Data\Config'
            'Data\Logs' 
            'Data\Scripts'
            'Data\Temp'
            'Resources'
        )
    }
}
