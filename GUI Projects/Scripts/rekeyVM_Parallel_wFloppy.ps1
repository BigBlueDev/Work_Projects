<#
.SYNOPSIS
    Rekey multiple VMs to a new key provider.

.DESCRIPTION
    This script rekeys multiple VMs to a new key provider.  It connects to vCenter,
    retrieves the key providers, and then processes each VM.  The script checks if
    the VM is encrypted and, if so, rekeys it to the new key provider.  If the VM
    is not encrypted, it applies encryption using the new key provider.  The script
    also handles VMs with vTPM encryption.  It removes floppy drives before rekeying.

.PARAMETER vCenterServer
    The vCenter server to connect to.

.PARAMETER vmNames
    An array of VM names to rekey.

.PARAMETER CurrentNKP
    The name or ID of the current Native Key Provider.

.PARAMETER NewNKP
    The name or ID of the new Native Key Provider.

.PARAMETER Credential
    The credential to use to connect to vCenter.

.PARAMETER SkipModuleCheck
    Skip checking/importing PowerCLI modules (for faster subsequent runs).

.EXAMPLE
    .\Rekey-VMs.ps1 -vCenterServer "vcsa.example.com" -vmNames "VM1","VM2" -CurrentNKP "OldProvider" -NewNKP "NewProvider" -Credential (Get-Credential)

.EXAMPLE
    .\Rekey-VMs.ps1 -vCenterServer "vcsa.example.com" -vmNames "VM1","VM2" -CurrentNKP "OldProvider" -NewNKP "NewProvider" -Credential (Get-Credential) -SkipModuleCheck

.NOTES
    Requires VMware PowerCLI modules.
#>

param(
    [Parameter(Mandatory)][string]       $vCenterServer,
    [Parameter(Mandatory)][string[]]     $vmNames,
    [Parameter(Mandatory)][string]       $CurrentNKP,
    [Parameter(Mandatory)][string]       $NewNKP,
    [Parameter(Mandatory)][PSCredential] $Credential,
    [Parameter()][switch]                $SkipModuleCheck
)

#region Setup

# 1. Module Check
if (-not $SkipModuleCheck) {
    try {
        Write-Host "Checking PowerCLI modules..."
        Get-Module -Name VMware.VimAutomation.Core -ListAvailable -ErrorAction Stop | Out-Null
        Get-Module -Name VMware.VimAutomation.Storage -ListAvailable -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Required PowerCLI modules not found. Attempting to import..."
        try {
            Import-Module VMware.VimAutomation.Core -ErrorAction Stop | Out-Null
            Import-Module VMware.VimAutomation.Storage -ErrorAction Stop | Out-Null
            Write-Host "PowerCLI modules imported successfully."
        }
        catch {
            Write-Error "Failed to import PowerCLI modules. Please ensure they are installed."
            return
        }
    }
}
else {
    Write-Host "Skipping PowerCLI module check."
    # Verify essential cmdlets are available
    if (-not (Get-Command Get-VM) -or -not (Get-Command Get-KeyProvider)) {
        Write-Error "Essential PowerCLI cmdlets not found.  Ensure modules are loaded."
        return
    }
}

# 2. Connect to vCenter
try {
    Write-Host "Connecting to vCenter $($vCenterServer)..."
    Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop | Out-Null
    $vCenterServerName = $vCenterServer # Store the server name
    $credentialForWorker = $Credential # Store the credential
    Write-Host "Successfully connected to vCenter."
}
catch {
    Write-Error "Failed to connect to vCenter: $($_.Exception.Message)"
    return
}

# 3. Resolve Key Providers
try {
    Write-Host "Getting Key Providers..."
    $providers = Get-KeyProvider
    if (-not $providers) {
        Write-Error "No Key Providers found."
        return
    }

    # Resolve Current Key Provider
    $oldProv = $providers | Where-Object { $_.Name -eq $CurrentNKP -or $_.Id -eq $CurrentNKP } | Select-Object -First 1
    if (-not $oldProv) {
        Write-Error "Current Key Provider '$CurrentNKP' not found."
        return
    }
    $oldProviderId = $oldProv.KeyProviderId.Id
    Write-Host "Current Key Provider: $($oldProv.Name) (ID: $($oldProviderId))"

    # Resolve New Key Provider
    $newProv = $providers | Where-Object { $_.Name -eq $NewNKP -or $_.Id -eq $NewNKP } | Select-Object -First 1
    if (-not $newProv) {
        Write-Error "New Key Provider '$NewNKP' not found."
        return
    }
    Write-Host "New Key Provider: $($newProv.Name) (ID: $($newProv.KeyProviderId.Id))"
}
catch {
    Write-Error "Error resolving Key Providers: $($_.Exception.Message)"
    return
}

# 4. Get VMs
try {
    Write-Host "Getting VMs..."
    $vms = Get-VM -Name $vmNames -ErrorAction SilentlyContinue
    if ($vms.Count -ne $vmNames.Count) {
        Write-Warning "Some VMs not found."
    }
    Write-Host "Found $($vms.Count) VMs."
}
catch {
    Write-Error "Error getting VMs: $($_.Exception.Message)"
    return
}

# 5. Logging Setup
$scriptName = Split-Path -Path $MyInvocation.MyCommand.Path -Leaf
$logFolder  = Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "logs"
if (-not (Test-Path -Path $logFolder -PathType Container)) {
    try {
        Write-Host "Creating log folder: $($logFolder)"
        New-Item -ItemType Directory -Path $logFolder -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to create log folder: $($_.Exception.Message)"
        return
    }
}
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = Join-Path -Path $logFolder -ChildPath "$($scriptName)-$($timestamp).log"
Write-Host "Logging to: $($logFile)"

#endregion Setup

# 5. Process VMs sequentially
foreach ($vm in $vms) {
    try {
        $vmName = $vm.Name

        # local Write-Log inside runspace
        function Write-Log {
            param(
                [string]$Message,
                [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO',
                [string]$VMName = '',
                [string]$LogFilePath # Pass the log file path as a parameter
            )
            $ts     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $prefix = if ($VMName) { "[$($VMName)] " } else { "" }
            $line   = "[$($ts)] [$($Level)] $($prefix)$($Message)" # Corrected string
            switch ($Level) {
                'INFO'  { Write-Host $line -ForegroundColor White }
                'WARN'  { Write-Host $line -ForegroundColor Yellow }
                'ERROR' { Write-Host $line -ForegroundColor Red }
            }
            Add-Content -Path $LogFilePath -Value $line # Use the parameter
        }

        Write-Log "Starting" 'INFO' $vmName $LogFile

        # Check for floppy drive and remove it
        $floppy = $vm | Get-FloppyDrive
        if ($floppy) {
            Write-Log "Floppy drive found on VM: $($vmName)" 'INFO' $vmName $LogFile
            if ($vm.PowerState -eq "PoweredOn") {
                Write-Log "Shutting down VM: $($vmName) to remove floppy drive" 'INFO' $vmName $LogFile
                Stop-VM -VM $vm -Confirm:$false -ErrorAction Stop
                Write-Log "Successfully shut down VM: $($vmName)" 'INFO' $vmName $LogFile

                # Wait for VM to power off
                $timeout = 300 # 5 minutes
                $interval = 10
                $elapsed = 0
                while (($vm.PowerState -ne "PoweredOff") -and ($elapsed -lt $timeout)) {
                    Start-Sleep -Seconds $interval
                    $elapsed += $interval
                    # Refresh the VM object
                    $vm = Get-VM -Name $vmName -Server $vCenterServer
                }

                if ($vm.PowerState -ne "PoweredOff") {
                    throw "Timeout waiting for VM to power off"
                }
            }

            Write-Log "Removing floppy drive from VM: $($vmName)" 'INFO' $vmName $LogFile
            $floppy | Remove-FloppyDrive -Confirm:$false -ErrorAction Stop
            Write-Log "Successfully removed floppy drive from VM: $($vmName)" 'INFO' $vmName $LogFile

            # Refresh the VM object after hardware change
            $vm = Get-VM -Name $vmName -Server $vCenterServer
        } else {
            Write-Log "No floppy drive found on VM: $($vmName)" 'INFO' $vmName $LogFile
        }

        # Check disk encryption
        $crypto = $vm.ExtensionData.CryptoState
        $vtpm   = $vm.ExtensionData.Config.Hardware.Device |
                  Where-Object { $_.GetType().Name -eq 'VirtualTPM' }

        if ($crypto -and $crypto.KeyId) {
            $curId = $crypto.KeyId.KeyProviderId.Id
            Write-Log "Disk encrypted by $($curId)" 'INFO' $vmName $LogFile
            if ($curId -ne $oldProviderId) {
                Write-Log "Skipping – unexpected provider ($($curId))" 'WARN' $vmName $LogFile
                return
            }
            if ($vm.PowerState -eq 'PoweredOn') {
                Write-Log "Must power off for rekey" 'WARN' $vmName $LogFile
                return
            }

            # --- Use ReconfigVM_Task ---
            Write-Log "Rekeying disk using ReconfigVM_Task" 'INFO' $vmName $LogFile

            #Get the new key provider ID
            $newProvId = $newProv.KeyProviderId # Get key provider ID
            Write-Log "New Provider ID: $($newProvId.id)" 'INFO' $vmName $LogFile

            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $spec.Crypto = New-Object VMware.Vim.CryptoSpecShallowRecrypt
            $spec.Crypto.NewKeyId = New-Object VMware.Vim.CryptoKeyId
            # Set the provier id for the key provider
            $spec.Crypto.NewKeyId.ProviderId = New-Object VMware.Vim.KeyProviderId
            $spec.Crypto.NewKeyId.ProviderId.Id = $newProvId.id  # Use the object
            $spec.Crypto.NewKeyId.KeyId = ''

            $vmView = Get-View -Id $vm.Id  # Get the View object
            $task = $vmView.ReconfigVM_Task($spec)

            Write-Log "ReconfigVM_Task initiated. Task ID: $($task.Value)" 'INFO' $vmName $LogFile

            # Optionally, wait for the task to complete (with timeout)
            #$task | Wait-Task -Timeout 300  # 5 minutes

        }
        elseif ($vtpm -and $vtpm.Backing -and $vtpm.Backing.KeyId) {
            $curId = $vtpm.Backing.KeyId.KeyProviderId.Id
            Write-Log "vTPM encrypted by $($curId)" 'INFO' $vmName $LogFile
            if ($curId -ne $oldProviderId) {
                Write-Log "Skipping – unexpected provider ($($curId))" 'WARN' $vmName $LogFile
                return
            }

            # --- Use ReconfigVM_Task ---
            Write-Log "Rekeying vTPM using ReconfigVM_Task" 'INFO' $vmName $LogFile

            #Get the new key provider ID
            $newProvId = $newProv.KeyProviderId # Get key provider ID
            Write-Log "New Provider ID: $($newProvId.id)" 'INFO' $vmName $LogFile

            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $spec.Crypto = New-Object VMware.Vim.CryptoSpecShallowRecrypt
            $spec.Crypto.NewKeyId = New-Object VMware.Vim.CryptoKeyId
            # Set the provier id for the key provider
            $spec.Crypto.NewKeyId.ProviderId = New-Object VMware.Vim.KeyProviderId
            $spec.Crypto.NewKeyId.ProviderId.Id = $newProvId.id  # Use the object
            $spec.Crypto.NewKeyId.KeyId = ''

            $vmView = Get-View -Id $vm.Id  # Get the View object
            $task = $vmView.ReconfigVM_Task($spec)

            Write-Log "ReconfigVM_Task initiated. Task ID: $($task.Value)" 'INFO' $vmName $LogFile

            # Optionally, wait for the task to complete (with timeout)
            #$task | Wait-Task -Timeout 300  # 5 minutes

        }
        else {
            # --- Use ReconfigVM_Task ---
            Write-Log "Not encrypted – applying new encryption using ReconfigVM_Task" 'INFO' $vmName $LogFile

            #Get the new key provider ID
            $newProvId = $newProv.KeyProviderId # Get key provider ID
            Write-Log "New Provider ID: $($newProvId.id)" 'INFO' $vmName $LogFile

            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $spec.Crypto = New-Object VMware.Vim.CryptoSpecShallowRecrypt
            $spec.Crypto.NewKeyId = New-Object VMware.Vim.CryptoKeyId
            # Set the provier id for the key provider
            $spec.Crypto.NewKeyId.ProviderId = New-Object VMware.Vim.KeyProviderId
            $spec.Crypto.NewKeyId.ProviderId.Id = $newProvId.id  # Use the object
            $spec.Crypto.NewKeyId.KeyId = ''

            $vmView = Get-View -Id $vm.Id  # Get the View object
            $task = $vmView.ReconfigVM_Task($spec)

            Write-Log "ReconfigVM_Task initiated. Task ID: $($task.Value)" 'INFO' $vmName $LogFile

            # Optionally, wait for the task to complete (with timeout)
            #$task | Wait-Task -Timeout 300  # 5 minutes
        }
    }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)" 'ERROR' $vmName $LogFile
    }
}
