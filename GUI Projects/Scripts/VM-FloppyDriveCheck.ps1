<#
.SYNOPSIS
    Checks for floppy drives on a specified VM and provides removal options.
.DESCRIPTION
    Connects to vCenter, checks for floppy drives on a specified VM, and allows interactive
    removal with logging to a file in the Logs subfolder.
.NOTES
    File Name      : VM-FloppyDriveCheck.ps1
    Prerequisite   : PowerShell 5.1 or later, PowerCLI module
#>

# Import required module
try {
    Import-Module VMware.PowerCLI -ErrorAction Stop
    Write-Output "VMware.PowerCLI module loaded successfully."
} catch {
    Write-Output "VMware.PowerCLI module not found. Installing..."
    try {
        Install-Module VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
        Import-Module VMware.PowerCLI
        Write-Output "VMware.PowerCLI module installed and loaded successfully."
    } catch {
        Write-Output "Failed to install VMware.PowerCLI module. Please install manually."
        exit 1
    }
}

# Set up logging
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFolder = Join-Path -Path $scriptPath -ChildPath "Logs"
$logFile = Join-Path -Path $logFolder -ChildPath ("VM_Floppy_Check_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

# Create Logs directory if it doesn't exist
if (-not (Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

# Function to write to log file
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    
    # Also output to console
    Write-Output $logEntry
}

# Main script execution
try {
    Write-Log "Script started"
    
    # Get vCenter connection details
    $vCenter = Read-Host "Enter vCenter Server FQDN or IP"
    $vmName = Read-Host "Enter the VM name to check"
    
    # Connect to vCenter
    try {
        Write-Log "Connecting to vCenter server: $vCenter"
        Connect-VIServer -Server $vCenter -Credential $credential -ErrorAction Stop | Out-Null
        Write-Log "Successfully connected to vCenter server: $vCenter"
    } catch {
        Write-Log "Failed to connect to vCenter server: $vCenter. Error: $_" -Level "ERROR"
        throw
    }
    
    # Get the VM
    try {
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        Write-Log "Retrieved VM: $vmName"
    } catch {
        Write-Log "Failed to retrieve VM: $vmName. Error: $_" -Level "ERROR"
        throw
    }
    
    # Check for floppy drives
    $floppy = $vm | Get-FloppyDrive
    if ($floppy) {
        Write-Log "Floppy drive found on VM: $vmName"
        Write-Output "Floppy drive detected on $vmName"
        
        $choice = Read-Host "Do you want to shutdown the VM and remove the floppy drive? (Y/N)"
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            # Shutdown VM if not already off
            if ($vm.PowerState -eq "PoweredOn") {
                try {
                    Write-Log "Shutting down VM: $vmName"
                    Stop-VM -VM $vm -Confirm:$false -ErrorAction Stop
                    Write-Log "Successfully shut down VM: $vmName"
                    
                    # Wait for VM to power off
                    $timeout = 300 # 5 minutes
                    $interval = 10
                    $elapsed = 0
                    while (($vm.PowerState -ne "PoweredOff") -and ($elapsed -lt $timeout)) {
                        Start-Sleep -Seconds $interval
                        $elapsed += $interval
                        $vm = Get-VM -Name $vmName
                    }
                    
                    if ($vm.PowerState -ne "PoweredOff") {
                        throw "Timeout waiting for VM to power off"
                    }
                } catch {
                    Write-Log "Failed to shutdown VM: $vmName. Error: $_" -Level "ERROR"
                    throw
                }
            }
            
            # Remove floppy drive
            try {
                Write-Log "Removing floppy drive from VM: $vmName"
                $floppy | Remove-FloppyDrive -Confirm:$false -ErrorAction Stop
                Write-Log "Successfully removed floppy drive from VM: $vmName"
                Write-Output "Floppy drive removed successfully."
                
                # Option to start VM
                $startChoice = Read-Host "Do you want to start the VM now? (Y/N)"
                if ($startChoice -eq 'Y' -or $startChoice -eq 'y') {
                    try {
                        Write-Log "Starting VM: $vmName"
                        Start-VM -VM $vm -Confirm:$false -ErrorAction Stop
                        Write-Log "Successfully started VM: $vmName"
                        Write-Output "VM $vmName has been started."
                    } catch {
                        Write-Log "Failed to start VM: $vmName. Error: $_" -Level "ERROR"
                        throw
                    }
                }
            } catch {
                Write-Log "Failed to remove floppy drive from VM: $vmName. Error: $_" -Level "ERROR"
                throw
            }
        } else {
            Write-Log "User chose not to remove floppy drive from VM: $vmName"
            Write-Output "No changes were made to the VM."
        }
    } else {
        Write-Log "No floppy drive found on VM: $vmName"
        Write-Output "No floppy drive detected on $vmName"
    }
} catch {
    Write-Log "Script encountered an error: $_" -Level "ERROR"
} finally {
    # Disconnect from vCenter if connected
    if ($global:DefaultVIServers) {
        try {
            Write-Log "Disconnecting from vCenter server"
            Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Disconnected from vCenter server"
        } catch {
            Write-Log "Error disconnecting from vCenter: $_" -Level "ERROR"
        }
    }
    
    Write-Log "Script completed"
    Write-Output "Log file created at: $logFile"
}
