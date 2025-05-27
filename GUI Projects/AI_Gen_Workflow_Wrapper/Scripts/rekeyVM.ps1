<#
.SYNOPSIS
    Encrypt or rekey a VM with a Native Key Provider using PowerCLI.

.DESCRIPTION
    1. Connects to vCenter.
    2. Loads all key providers using Get-KeyProvider.
    3. Validates the user-supplied “current” and “new” provider names/IDs.
    4. Detects whether the VM is encrypted (disk or vTPM).
    5. If not encrypted → calls Set-VM –KeyProvider with the new provider.
    6. If encrypted → checks that it matches the “current” provider.
       • If it already equals the “new” provider → no action.
       • Else → for disk encryption, ensures the VM is powered off, then calls Set-VM –KeyProvider to rekey.

.PARAMETER vCenterServer
    FQDN or IP of vCenter.

.PARAMETER vmName
    Name of the VM to process.

.PARAMETER CurrentNKP
    The “old” key provider. Can be the provider Name or KeyProviderId.Id.

.PARAMETER NewNKP
    The “new” key provider. Can be the provider Name or KeyProviderId.Id.

.PARAMETER Credential
    PSCredential for vCenter.

.EXAMPLE
    .\EncryptOrRekey-VM.ps1 `
      -vCenterServer vcsa.lab.local `
      -vmName MyVM `
      -CurrentNKP "Old-NKP-Name" `
      -NewNKP   "New-NKP-Name" `
      -Credential (Get-Credential)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]       $vCenterServer,
    [Parameter(Mandatory)][string]       $vmName,
    [Parameter(Mandatory)][string]       $CurrentNKP,
    [Parameter(Mandatory)][string]       $NewNKP,
    [Parameter(Mandatory)][PSCredential] $Credential
)

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR')][string]$Level='INFO')
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$time] [$Level] $Message"
}

try {
    # 1. Import PowerCLI modules
    Write-Log "Loading VMware.PowerCLI modules..."
    $pc = Get-Module -ListAvailable VMware.PowerCLI | 
          Sort-Object Version -Descending | 
          Select-Object -First 1
    if (-not $pc) {
        throw "VMware.PowerCLI module is not installed."
    }
    
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop
    Import-Module VMware.VimAutomation.Security -ErrorAction SilentlyContinue
    
    Write-Log "PowerCLI version $($pc.Version) detected and modules imported."
    
    # 2. Connect to vCenter
    Write-Log "Connecting to vCenter '$vCenterServer'..."
    $vc = Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
    Write-Log "Connected to vCenter: $($vc.Name)."
    
    # 3. Retrieve all native key providers using Get-KeyProvider
    Write-Log "Retrieving key providers using Get-KeyProvider..."
    $allProviders = Get-KeyProvider -ErrorAction Stop
    if (-not $allProviders) {
        throw "No key providers found in vCenter."
    }
    Write-Log ("Found providers: " + ($allProviders | ForEach-Object { $_.Name } | Sort | Out-String).Trim())
    
    # Helper function to resolve the key provider from a name or id
    function Resolve-Provider {
        param([string]$NameOrId)
        return $allProviders |
               Where-Object {
                   $_.Name -eq $NameOrId -or $_.KeyProviderId.Id -eq $NameOrId
               }
    }
    
    $oldProv = Resolve-Provider $CurrentNKP
    if (-not $oldProv) {
        throw "Current key provider '$CurrentNKP' not found."
    }
    $newProv = Resolve-Provider $NewNKP
    if (-not $newProv) {
        throw "New key provider '$NewNKP' not found."
    }
    
    Write-Log "Using current Key Provider: $($oldProv.Name) [$($oldProv.KeyProviderId.Id)]"
    Write-Log "Using new Key Provider: $($newProv.Name) [$($newProv.KeyProviderId.Id)]"
    
    # 4. Retrieve the target VM
    Write-Log "Retrieving VM '$vmName'..."
    $vm = Get-VM -Name $vmName -ErrorAction Stop
    Write-Log "VM '$($vm.Name)' found."
    
    # 5. Determine encryption state
    $encrypted      = $false
    $encryptionType = $null  # "Disk" or "vTPM"
    $currentId      = $null
    
    $crypto = $vm.ExtensionData.CryptoState
    if ($crypto -and $crypto.KeyId) {
        $encrypted      = $true
        $encryptionType = "Disk"
        $currentId      = $crypto.KeyId.KeyProviderId.Id
        Write-Log "Disk encryption detected (ProviderId: $currentId)."
    }
    else {
        $vtpm = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_.GetType().Name -eq "VirtualTPM" }
        if ($vtpm -and $vtpm.Backing -and $vtpm.Backing.KeyId) {
            $encrypted      = $true
            $encryptionType = "vTPM"
            $currentId      = $vtpm.Backing.KeyId.KeyProviderId.Id
            Write-Log "vTPM encryption detected (ProviderId: $currentId)."
        }
    }
    
    # 6a. If the VM is not encrypted, perform initial encryption
    if (-not $encrypted) {
        Write-Log "VM is not encrypted. Encrypting with key provider '$($newProv.Name)'..."
        if ($vm.PowerState -eq 'PoweredOn') {
            Write-Log "Warning: VM is powered on; disk encryption may require a reboot to take effect." -Level WARN
        }
        Set-VM -VM $vm -KeyProvider $newProv -Confirm:$false -ErrorAction Stop
        Write-Log "Encryption task submitted."
        return
    }
    
    # 6b. If the VM is already encrypted, perform rekey logic
    Write-Log "VM is already encrypted ($encryptionType). Current provider id: $currentId."
    if ($currentId -ne $oldProv.KeyProviderId.Id) {
        Write-Log "Current provider id [$currentId] does not match expected [$($oldProv.KeyProviderId.Id)]. Aborting rekey." -Level WARN
        return
    }
    if ($currentId -eq $newProv.KeyProviderId.Id) {
        Write-Log "VM already uses target provider '$($newProv.Name)'. No action is required."
        return
    }
    
    # For disk encryption, ensure the VM is powered off before rekeying
    if ($encryptionType -eq "Disk" -and $vm.PowerState -eq 'PoweredOn') {
        Write-Log "Disk-level rekey requires the VM to be powered off. Please shut down VM '$vmName' and rerun the script." -Level WARN
        return
    }
    
    Write-Log "Rekeying VM from '$($oldProv.Name)' to '$($newProv.Name)'..."
    Set-VM -VM $vm -KeyProvider $newProv -Confirm:$false -ErrorAction Stop
    Write-Log "Rekey task submitted."
    
}
catch {
    Write-Log "ERROR: $_" -Level ERROR
}
finally {
    if ($vc -and $vc.IsConnected) {
        Write-Log "Disconnecting from vCenter..."
        Disconnect-VIServer -Server $vc -Confirm:$false | Out-Null
        Write-Log "Disconnected."
    }
}
