# Launch.ps1
# Entry point for the vCenter Migration Workflow Manager application

# Set script location as the current directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $scriptPath

write-host "Current Script path is: $($scriptpath)"
# Import form designer
try {
    . "$scriptPath\AI_Gen_Workflow_Wrapper.designer.ps1"
    Write-Host "Loaded form designer"
} catch {
    Write-Error "Failed to load form designer: $_"
    [System.Windows.Forms.MessageBox]::Show("Failed to load form designer: $_", "Initialization Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

# Import global variables and initialization
try {
    . "$scriptPath\Globals.ps1"
    Write-Host "Loaded global variables and initialization"
} catch {
    Write-Error "Failed to load global variables: $_"
    [System.Windows.Forms.MessageBox]::Show("Failed to load global variables: $_", "Initialization Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

# Import core functionality
try {
    . "$scriptPath\AI_Gen_Workflow_Wrapper.ps1"
    Write-Host "Loaded core functionality"
} catch {
    Write-Error "Failed to load core functionality: $_"
    [System.Windows.Forms.MessageBox]::Show("Failed to load core functionality: $_", "Initialization Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}



# Initialize application
try {
    # Initialize application components
    Initialize-Application
    Write-Host "Application started successfully"
    Write-Log "Application started successfully"  # Assuming Write-Log is available here
    # Show the form
    $mainForm.ShowDialog()
} catch {
    Write-Error "Application initialization error: $_"
    [System.Windows.Forms.MessageBox]::Show("Application initialization error: $_", "Initialization Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}
