# AppConfig.psd1
# AI Gen Workflow Wrapper - Main Configuration Data File

@{
    # Application metadata
    ApplicationInfo = @{
        Name = 'AI Gen Workflow Wrapper'
        Version = '1.0.0'
        Author = 'Your Name'
        Description = 'PowerShell GUI wrapper for AI-generated workflows'
        Copyright = '(c) 2025. All rights reserved.'
        LastModified = '2025-01-27'
    }

    # Path configuration - relative to application root
    Paths = @{
        # Core directories
        Root = ''                    # Application root (auto-detected)
        Forms = ''                   # Form files (currently in root)
        SubForms = ''               # Sub-form files (currently in root)  
        
        # Data directories
        Config = 'Config'           # Configuration files
        Logs = 'Logs'               # Log files
        Data = 'Data'               # General data storage
        Resources = 'Resources'     # Images, icons, etc.
        
        # Specialized data directories
        Temp = 'Data\Temp'          # Temporary files
        Reports = 'Data\Reports'    # Generated reports
        Exports = 'Data\Exports'    # Exported configurations
        Imports = 'Data\Imports'    # Import staging area
        Backups = 'Data\Backups'    # Backup files
        Scripts = 'Data\Scripts'    # User script storage
    }

    # File naming patterns with token substitution
    FilePatterns = @{
        # Form files
        MainForm = 'AI_Gen_Workflow_Wrapper'
        EditForm = 'EditParam'
        
        # Configuration files
        ConfigFile = 'config.json'
        SettingsFile = 'settings.json'
        UserPrefs = 'userprefs.json'
        
        # Log files with date patterns
        LogFile = 'application_{date}.log'
        ErrorLog = 'errors_{date}.log'
        DebugLog = 'debug_{datetime}.log'
        
        # Data files
        ExportFile = 'export_{timestamp}.json'
        BackupFile = 'backup_{date}.zip'
        ScriptCache = 'script_cache.json'
    }

    # File extension mappings
    Extensions = @{
        Scripts = @('.ps1', '.bat', '.cmd', '.py')
        Data = @('.json', '.xml', '.csv', '.txt')
        Logs = @('.log', '.txt')
        Archives = @('.zip', '.7z', '.tar')
        Images = @('.png', '.jpg', '.jpeg', '.gif', '.ico')
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
    }

    # Logging configuration
    Logging = @{
        DefaultLevel = 'INFO'
        EnableFileLogging = $true
        EnableConsoleLogging = $true
        MaxLogFileSizeMB = 10
        MaxLogFiles = 5
        DateFormat = 'yyyy-MM-dd HH:mm:ss'
    }

    # Script execution settings
    Execution = @{
        TimeoutSeconds = 300
        ShowExecutionWindow = $true
        CaptureOutput = $true
        LogExecution = $true
        AllowedExecutionPolicies = @('RemoteSigned', 'Unrestricted')
    }

    # Feature flags for future functionality
    Features = @{
        EnableScriptValidation = $true
        EnableParameterValidation = $true
        EnableAutoBackup = $true
        EnableUpdateCheck = $false
        EnableTelemetry = $false
    }

    # Migration settings for future structure changes
    Migration = @{
        ConfigVersion = '1.0'
        LastMigration = $null
        BackupBeforeMigration = $true
        MigrationScriptPath = 'Migration\MigrationScripts'
    }
}