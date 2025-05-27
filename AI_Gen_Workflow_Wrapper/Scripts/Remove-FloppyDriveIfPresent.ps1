function Remove-FloppyDriveIfPresent {
    <#
    .SYNOPSIS
        Checks if a VM has a floppy drive, optionally shuts down the VM, removes the floppy drive, and optionally restarts the VM.
    .DESCRIPTION
        Connects to a vCenter server using provided credentials, inspects the specified VM for floppy drives,
        prompts for shutdown/removal/restart, and logs all actions to a timestamped log file under Logs subfolder.
    .PARAMETER VCenterServer
        The FQDN or IP address of the vCenter server.
    .PARAMETER VMName
        The name of the virtual machine to check.
    .PARAMETER Credential
        The PSCredential object with permissions to connect to the vCenter server.
    .PARAMETER LogFolder
        (Optional) The folder where logs will be saved. Defaults to 'Logs' folder in the current script directory.
    .PARAMETER ConfirmActions
        (Switch) If specified, prompts user interactively before shutdown/removal/restart.
        If not specified, the function will perform removal without prompting.
    .EXAMPLE
        $cred = Get-Credential
        Remove-FloppyDriveIfPresent -VCenterServer "vcenter.mydomain.local" -VMName "TestVM" -Credential $cred -ConfirmActions
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$VCenterServer,

        [Parameter(Mandatory,Position=1)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [string]$LogFolder = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\Logs",

        [Parameter()]
        [switch]$ConfirmActions
    )

    # Internal helper function for logging
    function Write-Log {
        param (
            [string]$Message,
            [string]$Level = "INFO"
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $logFile -Value $logEntry
        Write-Verbose $logEntry
    }

    # Ensure VMware PowerCLI module is available
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        Write-Verbose "VMware.PowerCLI module not found. Attempting to install..."
        try {
            Install-Module VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Verbose "VMware.PowerCLI module installed successfully."
        } catch {
            Write-Error "Failed to install VMware.PowerCLI module: $_"
            return @{ Success = $false; Message = "VMware.PowerCLI module installation failed." }
        }
    }

    try {
        Import-Module VMware.PowerCLI -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Failed to import VMware.PowerCLI module: $_"
        return @{ Success = $false; Message = "VMware.PowerCLI module import failed." }
    }

    # Prepare logging
    if (-not (Test-Path -Path $LogFolder)) {
        try {
            New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
        } catch {
            Write-Error "Could not create log folder '$LogFolder': $_"
            return @{ Success = $false; Message = "Log folder creation failed." }
        }
    }

    $logFile = Join-Path -Path $LogFolder -ChildPath ("VM_FloppyCheck_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

    try {
        Write-Log "Function started"
        Write-Log "Connecting to vCenter server: $VCenterServer"

        $connection = Connect-VIServer -Server $VCenterServer -Credential $Credential -ErrorAction Stop

        Write-Log "Successfully connected to vCenter server: $VCenterServer"

        # Get VM object
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        Write-Log "Retrieved VM: $VMName"

        # Check for floppy drive
        $floppy = $vm | Get-FloppyDrive -ErrorAction SilentlyContinue
        if ($null -eq $floppy) {
            Write-Log "No floppy drive found on VM: $VMName"
            Write-Output "No floppy drive detected on VM $VMName."
            return @{ Success = $true; Message = "No floppy drive detected."; VMName = $VMName; Removed = $false; LogFile = $logFile }
        }

        Write-Log "Floppy drive found on VM: $VMName"

        $proceedToRemove = $true

        if ($ConfirmActions) {
            $response = Read-Host "Floppy drive detected on $VMName. Do you want to shutdown and remove it? (Y/N)"
            if ($response -notin @('Y','y')) {
                Write-Log "User chose not to remove floppy drive."
                $proceedToRemove = $false
            }
        }

        if (-not $proceedToRemove) {
            Write-Output "Floppy drive removal cancelled by user."
            return @{ Success = $true; Message = "Removal cancelled by user."; VMName = $VMName; Removed = $false; LogFile = $logFile }
        }

        # Shutdown VM if powered on
        if ($vm.PowerState -eq "PoweredOn") {
            Write-Log "VM is powered on. Preparing to shut down VM."

            try {
                Stop-VM -VM $vm -Confirm:$false -ErrorAction Stop
                Write-Log "Shutdown command issued to VM."

                # Wait for VM to power off (timeout 5 min)
                $timeout = 300
                $interval = 10
                $elapsed = 0
                do {
                    Start-Sleep -Seconds $interval
                    $elapsed += $interval
                    $vm = Get-VM -Name $VMName
                } while (($vm.PowerState -ne "PoweredOff") -and ($elapsed -lt $timeout))

                if ($vm.PowerState -ne "PoweredOff") {
                    throw "Timeout waiting for VM to power off."
                }
                Write-Log "VM is powered off."
            } catch {
                Write-Log "Error shutting down VM: $_" -Level "ERROR"
                return @{ Success = $false; Message = "Failed to shutdown VM."; VMName = $VMName; Removed = $false; LogFile = $logFile }
            }
        }
        else {
            Write-Log "VM is already powered off."
        }

        # Remove floppy drive
        try {
            Write-Log "Removing floppy drive from VM: $VMName"
            $floppy | Remove-FloppyDrive -Confirm:$false -ErrorAction Stop
            Write-Log "Floppy drive removed."
        } catch {
            Write-Log "Failed to remove floppy drive: $_" -Level "ERROR"
            return @{ Success = $false; Message = "Failed to remove floppy drive."; VMName = $VMName; Removed = $false; LogFile = $logFile }
        }

        # Optionally start VM
        if ($ConfirmActions) {
            $startResponse = Read-Host "Do you want to start the VM now? (Y/N)"
            if ($startResponse -in @('Y','y')) {
                try {
                    Write-Log "Starting VM: $VMName"
                    Start-VM -VM $vm -Confirm:$false -ErrorAction Stop
                    Write-Log "VM started."
                } catch {
                    Write-Log "Failed to start VM: $_" -Level "ERROR"
                    return @{ Success = $false; Message = "Failed to start VM."; VMName = $VMName; Removed = $true; LogFile = $logFile }
                }
            } else {
                Write-Log "User chose not to start the VM."
            }
        }

        Write-Log "Function completed successfully."
        return @{ Success = $true; Message = "Floppy drive removed successfully."; VMName = $VMName; Removed = $true; LogFile = $logFile }

    } catch {
        Write-Log "Exception encountered: $_" -Level "ERROR"
        return @{ Success = $false; Message = "$_" }
    } finally {
        if ($connection -and $connection.IsConnected) {
            Disconnect-VIServer -Server $connection -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Disconnected from vCenter server."
        }
    }
}
