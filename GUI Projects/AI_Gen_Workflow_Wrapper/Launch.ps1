<#
.SYNOPSIS
    vCenter Migration Workflow Manager - Main Launch Script

.DESCRIPTION
    This script launches the vCenter Migration Workflow Manager application.
    It loads all required components, initializes the application, and starts the GUI.

.NOTES
    Author: vCenter Migration Team
    Version: 1.0
    Requires: PowerShell 5.1+, Windows Forms, PowerShell Pro Tools compatible
#>

[CmdletBinding()]
param()

# Enable strict mode for better error handling
Set-StrictMode -Version Latest

# Set error action preference
$ErrorActionPreference = "Stop"

try {
    Write-Host "Starting vCenter Migration Workflow Manager..." -ForegroundColor Green
    
    # Set script location as working directory
    Set-Location -Path $PSScriptRoot
    Write-Host "Working directory set to: $($PSScriptRoot)" -ForegroundColor Cyan
    
    # Define script paths
    $GlobalsPath = Join-Path -Path $PSScriptRoot -ChildPath "Globals.ps1"
    $FormDesignerPath = Join-Path -Path $PSScriptRoot -ChildPath "MainForm.designer.ps1"
    $WrapperPath = Join-Path -Path $PSScriptRoot -ChildPath "AI_Gen_Workflow_Wrapper.ps1"
    
    # Verify required files exist
    $requiredFiles = @(
        @{ Path = $GlobalsPath; Name = "Globals.ps1" }
        @{ Path = $FormDesignerPath; Name = "MainForm.designer.ps1" }
        @{ Path = $WrapperPath; Name = "AI_Gen_Workflow_Wrapper.ps1" }
    )
    
    Write-Host "Verifying required files..." -ForegroundColor Cyan
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path -Path $file.Path)) {
            throw "Required file not found: $($file.Name) at path: $($file.Path)"
        }
        Write-Host "  ✓ Found: $($file.Name)" -ForegroundColor Green
    }
    
    # Load application components in order
    Write-Host "Loading application components..." -ForegroundColor Cyan
    
    # Load globals first (contains configuration and logging setup)
    Write-Host "  Loading globals and configuration..." -ForegroundColor Yellow
    . $GlobalsPath
    
    # Verify logging is working
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log "Launch script started successfully" -Level "INFO"
        Write-Log "PowerShell version: $($PSVersionTable.PSVersion)" -Level "INFO"
        Write-Log "Operating system: $($PSVersionTable.OS)" -Level "INFO"
    } else {
        Write-Warning "Write-Log function not available from Globals.ps1"
    }
    
    # Load form designer (creates UI components)
    Write-Host "  Loading form designer..." -ForegroundColor Yellow
    . $FormDesignerPath
    Write-Log "Form designer loaded successfully" -Level "INFO"
    
    # Load core functionality (business logic and event handlers)
    Write-Host "  Loading core functionality..." -ForegroundColor Yellow
    . $WrapperPath
    Write-Log "Core functionality loaded successfully" -Level "INFO"
    
    # Verify main form was created
    if (-not $mainForm) {
        throw "Main form was not created by the form designer"
    }
    
    Write-Log "All components loaded successfully" -Level "INFO"
    
    # Initialize the application
    Write-Host "Initializing application..." -ForegroundColor Cyan
    if (Get-Command Initialize-Application -ErrorAction SilentlyContinue) {
        Initialize-Application
        Write-Log "Application initialized successfully" -Level "INFO"
    } else {
        Write-Log "Initialize-Application function not found, skipping initialization" -Level "WARNING"
    }
    
    # Set up application-level error handling
    $mainForm.add_FormClosed({
        Write-Log "Main form closed by user" -Level "INFO"
    })
    
    # Handle unhandled exceptions
    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $e)
        $errorMsg = "Unhandled thread exception: $($e.Exception.Message)"
        Write-Log $errorMsg -Level "ERROR"
        Write-Log "Stack trace: $($e.Exception.StackTrace)" -Level "ERROR"
        
        [System.Windows.Forms.MessageBox]::Show(
            "An unexpected error occurred:`n`n$($e.Exception.Message)`n`nPlease check the logs for more details.",
            "Application Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    })
    
    # Enable visual styles for better appearance
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    
    # Show the form using enhanced method
    Write-Host "Displaying main form..." -ForegroundColor Cyan
    if (Get-Command Show-MainForm -ErrorAction SilentlyContinue) {
        Show-MainForm
        Write-Log "Main form displayed successfully" -Level "INFO"
    } else {
        # Fallback to basic form showing if Show-MainForm not available
        Write-Log "Show-MainForm function not found, using basic form display" -Level "WARNING"
        $mainForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $mainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $mainForm.Show()
        $mainForm.BringToFront()
        $mainForm.Activate()
    }
    
    Write-Host "Application started successfully!" -ForegroundColor Green
    Write-Host "Starting message loop..." -ForegroundColor Cyan
    
    # Start the Windows Forms message loop
    Write-Log "Starting application message loop" -Level "INFO"
    [System.Windows.Forms.Application]::Run($mainForm)
    
    Write-Log "Application message loop ended - application closing normally" -Level "INFO"
    Write-Host "Application closed normally." -ForegroundColor Green
    
} catch {
    # Handle startup errors
    $errorMessage = "Critical error during application startup: $($_.Exception.Message)"
    
    # Try to log the error if logging is available
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log $errorMessage -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        Write-Log "Exception details: $($_.Exception.GetType().FullName)" -Level "ERROR"
    }
    
    # Display error to user
    Write-Host $errorMessage -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
    # Show message box if Windows Forms is available
    try {
        [System.Windows.Forms.MessageBox]::Show(
            "$($errorMessage)`n`nStack trace:`n$($_.ScriptStackTrace)",
            "Startup Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } catch {
        Write-Host "Could not display error dialog: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Exit with error code
    exit 1
    
} finally {
    # Cleanup resources
    Write-Host "Cleaning up application resources..." -ForegroundColor Cyan
    
    try {
        # Log cleanup start
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log "Starting application cleanup" -Level "INFO"
        }
        
        # Stop any running timers
        if (Get-Variable -Name "ExecutionTimer" -Scope Script -ErrorAction SilentlyContinue) {
            if (Get-Command Stop-ExecutionMonitor -ErrorAction SilentlyContinue) {
                Stop-ExecutionMonitor
                Write-Log "Execution monitor stopped" -Level "INFO"
            }
        }
        
        # Cleanup execution resources
        if (Get-Variable -Name "ExecutionPowerShell" -Scope Script -ErrorAction SilentlyContinue) {
            if ($script:ExecutionPowerShell) {
                try {
                    $script:ExecutionPowerShell.Dispose()
                    Write-Log "Execution PowerShell instance disposed" -Level "INFO"
                } catch {
                    Write-Log "Error disposing PowerShell instance: $($_.Exception.Message)" -Level "WARNING"
                }
            }
        }
        
        if (Get-Variable -Name "ExecutionRunspace" -Scope Script -ErrorAction SilentlyContinue) {
            if ($script:ExecutionRunspace) {
                try {
                    $script:ExecutionRunspace.Close()
                    $script:ExecutionRunspace.Dispose()
                    Write-Log "Execution runspace closed and disposed" -Level "INFO"
                } catch {
                    Write-Log "Error disposing runspace: $($_.Exception.Message)" -Level "WARNING"
                }
            }
        }
        
        # Dispose of the main form
        if (Get-Variable -Name "mainForm" -ErrorAction SilentlyContinue) {
            if ($mainForm) {
                try {
                    $mainForm.Dispose()
                    Write-Log "Main form disposed" -Level "INFO"
                } catch {
                    Write-Log "Error disposing main form: $($_.Exception.Message)" -Level "WARNING"
                }
            }
        }
        
        # Final cleanup log
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log "Application cleanup completed successfully" -Level "INFO"
            Write-Log "=== Application session ended ===" -Level "INFO"
        }
        
        Write-Host "Cleanup completed." -ForegroundColor Green
        
    } catch {
        $cleanupError = "Error during cleanup: $($_.Exception.Message)"
        
        if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
            Write-Log $cleanupError -Level "WARNING"
        }
        
        Write-Host $cleanupError -ForegroundColor Yellow
    }
}
