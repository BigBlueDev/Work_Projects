<#
.SYNOPSIS
    Migrates a virtual machine from one vCenter Server to another using cross-vCenter vMotion or creates a clone.

.DESCRIPTION
    This script performs a cross-vCenter vMotion of a specified virtual machine.  It handles folder and resource pool path resolution,
    network mapping, and datastore selection on the destination vCenter. It also includes enhanced logging for troubleshooting.
    By default, the script performs a vMotion (moves) the VM.  If the -Clone switch is used, it creates a clone instead.

.PARAMETER SourceVCenter
    The hostname or IP address of the source vCenter Server.

.PARAMETER DestVCenter
    The hostname or IP address of the destination vCenter Server.

.PARAMETER VMToMigrateName
    The name of the virtual machine to migrate or clone.

.PARAMETER SourceVCCredential
    A PSCredential object containing the username and password for the source vCenter Server.  If not provided, the script will prompt for credentials.

.PARAMETER DestVCCredential
    A PSCredential object containing the username and password for the destination vCenter Server. If not provided, the script will prompt for credentials.

.PARAMETER LogFile
    The base name of the log file. The script will add a timestamp and save the log in a "logs" subfolder.  Defaults to "CrossVCVMotion".

.PARAMETER SkipModuleCheck
    A switch parameter that, when present, skips the check for the VMware PowerCLI module.  Use this if you know the module is already installed or you don't want the script to automatically try to install it.

.PARAMETER DestinationCluster
    The name of the destination cluster. If specified, the destination host will be selected from this cluster. Otherwise, the host with the least memory usage will be selected from the entire destination vCenter.

.PARAMETER Clone
    A switch parameter. If specified, the script will create a clone of the VM instead of performing a vMotion (move).

.EXAMPLE
    .\CrossVCvmMigrate.ps1 -SourceVCenter "source_vc.example.com" -DestVCenter "dest_vc.example.com" -VMToMigrateName "MyVM" -SourceVCCredential (Get-Credential) -DestVCCredential (Get-Credential)

.EXAMPLE
    .\CrossVCvmMigrate.ps1 -SourceVCenter "source_vc.example.com" -DestVCenter "dest_vc.example.com" -VMToMigrateName "MyVM" -SourceVCCredential (Get-Credential) -DestVCCredential (Get-Credential) -Verbose

.EXAMPLE
    .\CrossVCvmMigrate.ps1 -SourceVCenter "source_vc.example.com" -DestVCenter "dest_vc.example.com" -VMToMigrateName "MyVM" -SourceVCCredential (Get-Credential) -DestVCCredential (Get-Credential) -SkipModuleCheck

.EXAMPLE
    .\CrossVCvmMigrate.ps1 -SourceVCenter "source_vc.example.com" -DestVCenter "dest_vc.example.com" -VMToMigrateName "MyVM" -SourceVCCredential (Get-Credential) -DestVCCredential (Get-Credential) -DestinationCluster "MyCluster"

.EXAMPLE
    .\CrossVCvmMigrate.ps1 -SourceVCenter "source_vc.example.com" -DestVCenter "dest_vc.example.com" -VMToMigrateName "MyVM" -SourceVCCredential (Get-Credential) -DestVCCredential (Get-Credential) -Clone

.NOTES
    *   Requires the VMware PowerCLI module to be installed.
    *   The user accounts used to connect to the vCenter Servers must have the necessary permissions to perform vMotion operations.
    *   Network names must match between the source and destination vCenter Servers for network adapter mapping to succeed.
    *   The script will select the destination host with the least memory usage and the datastore with the most free space that is large enough for the VM.
    *   To enable verbose output, run the script with the `-Verbose` switch or set `$VerbosePreference = "Continue"`.

.LINK
    https://developer.vmware.com/powercli
#>
param(
    [Parameter(Mandatory=$true)][string]$SourceVCenter,
    [Parameter(Mandatory=$true)][string]$DestVCenter,
    [Parameter(Mandatory=$true)][string]$VMToMigrateName,
    [Parameter()][PSCredential]$SourceVCCredential,
    [Parameter()][PSCredential]$DestVCCredential,
    [string]$LogFile = "CrossVCVMotion",
    [string]$DestinationCluster,
    [switch]$SkipModuleCheck,
    [switch]$Clone
)

# Create the "logs" subfolder if it doesn't exist
$LogDirectory = Join-Path -Path $PSScriptRoot -ChildPath "logs"
if (!(Test-Path -Path $LogDirectory -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $LogDirectory -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "ERROR: Failed to create 'logs' directory: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Generate the log file name with timestamp
$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$LogFileName = "$($LogFile)-$($Timestamp).log"
$LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host $timestamp
    $logMessage = "$timestamp [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFilePath -Value $logMessage

    if ($Level -eq "DEBUG" -and ($VerbosePreference -eq "Continue" -or $VerbosePreference -eq "Inquire")) {
        Write-Host "DEBUG: $logMessage" -ForegroundColor DarkGray
    }
}

function Get-OrCreateFolderPath {
    param(
        [string]$Path,
        [object]$RootFolder,
        [object]$VIServer
    )
    $currentFolder = $RootFolder
    foreach ($folderName in $Path.Split('\')) {
        if ($folderName -eq '' -or $folderName -eq 'vm') { continue }
        $nextFolder = Get-Folder -Server $VIServer -Name $folderName -Location $currentFolder -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $nextFolder) {
            Write-Log "Creating folder '$folderName' under '$($currentFolder.Name)'"
            try {
                $nextFolder = New-Folder -Server $VIServer -Name $folderName -Location $currentFolder -ErrorAction Stop
            }
            catch {
                Write-Log "ERROR: Failed to create folder '$($currentFolder.Name)' under '$($currentFolder.Name)'. Error: $($_.Exception.Message)" "ERROR"
                throw
            }
        }
        $currentFolder = $nextFolder
    }
    return $currentFolder
}

function Get-OrCreateResourcePoolPath {
    param(
        [string]$Path,
        [object]$RootResourcePool,
        [object]$VIServer
    )
    $currentRP = $RootResourcePool
    foreach ($rpName in $Path.Split('\')) {
        if ($rpName -eq '' -or $rpName -eq 'Resources') { continue }
        $nextRP = Get-ResourcePool -Server $VIServer -Name $rpName -Location $currentRP -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $nextRP) {
            Write-Log "Creating resource pool '$rpName' under '$($currentRP.Name)'"
            try {
                $nextRP = New-ResourcePool -Server $VIServer -Name $rpName -Location $currentRP -ErrorAction Stop
            }
            catch {
                Write-Log "ERROR: Failed to create resource pool '$rpName' under '$($currentRP.Name)'. Error: $($_.Exception.Message)" "ERROR"
                throw
            }
        }
        $currentRP = $nextRP
    }
    return $currentRP
}

# Log script parameters
Write-Log "Script started with the following parameters:"
Write-Log "SourceVCenter: $($SourceVCenter)"
Write-Log "DestVCenter: $($DestVCenter)"
Write-Log "VMToMigrateName: $($VMToMigrateName)"
Write-Log "LogFile: $($LogFile)"
Write-Log "DestinationCluster: $($DestinationCluster)"
Write-Log "SkipModuleCheck: $($SkipModuleCheck.IsPresent)"
Write-Log "Clone: $($Clone.IsPresent)"

# Check for VMware PowerCLI module
if (-not $SkipModuleCheck) {
    Write-Log "Checking for VMware PowerCLI module..."
    try {
        Import-Module -Name VMware.PowerCLI -ErrorAction Stop
        Write-Log "VMware PowerCLI module found."
    }
    catch {
        Write-Log "VMware PowerCLI module not found.  Please install it." "ERROR"
        Write-Log "You can install it by running: Install-Module -Name VMware.PowerCLI -AllowClobber" "ERROR"
        throw "VMware PowerCLI module not found."
    }
} else {
    Write-Log "Skipping VMware PowerCLI module check."
}

# Prompt for credentials if not provided
if (-not $SourceVCCredential) {
    Write-Log "Prompting for source vCenter credentials"
    $SourceVCCredential = Get-Credential -Message "Enter credentials for source vCenter ($($SourceVCenter))"
}
if (-not $DestVCCredential) {
    Write-Log "Prompting for destination vCenter credentials"
    $DestVCCredential = Get-Credential -Message "Enter credentials for destination vCenter ($($DestVCenter))"
}

try {
    Write-Log "Connecting to source vCenter: $($SourceVCenter)"
    try {
        $sourceVI = Connect-VIServer -Server $SourceVCenter -Credential $SourceVCCredential -ErrorAction Stop
    }
    catch {
        Write-Log "ERROR: Failed to connect to source vCenter '$($SourceVCenter)'. Error: $($_.Exception.Message)" "ERROR"
        throw
    }

    Write-Log "Connecting to destination vCenter: $($DestVCenter)"
    try {
        $destVI = Connect-VIServer -Server $DestVCenter -Credential $DestVCCredential -ErrorAction Stop
    }
    catch {
        Write-Log "ERROR: Failed to connect to destination vCenter '$($DestVCenter)'. Error: $($_.Exception.Message)" "ERROR"
        throw
    }

    Write-Log "Getting VM to migrate: $($VMToMigrateName)"
    try {
        $vmToMigrate = Get-VM -Server $sourceVI -Name $VMToMigrateName -ErrorAction Stop
        Write-Log "VM found: $($($vmToMigrate.Name)), PowerState: $($($vmToMigrate.PowerState))" -Level "DEBUG"
    }
    catch {
        Write-Log "ERROR: Failed to get VM '$($VMToMigrateName)' from source vCenter. Error: $($_.Exception.Message)" "ERROR"
        throw
    }

    # --- Folder path resolution ---
    $sourceFolder = Get-Folder -Server $sourceVI -Id $vmToMigrate.FolderId
    $folderPath = $sourceFolder.Name
    $parent = $sourceFolder.Parent
    while ($parent -and $parent.Name -ne "vm") {
        $folderPath = $($parent.Name) + "\" + $($folderPath)
        $parent = $parent.Parent
    }
    Write-Log "Source folder path: $($folderPath)"

    $destRootFolder = Get-Folder -Server $destVI -Name "vm" | Where-Object { $_.ParentId -eq $null }
    $destFolder = Get-OrCreateFolderPath -Path $folderPath -RootFolder $destRootFolder -VIServer $destVI
    Write-Log "Destination folder path ensured: $($($destFolder.Name))"

    # --- Resource pool path resolution ---
    $sourceRP = Get-ResourcePool -Server $sourceVI -Id $vmToMigrate.ResourcePoolId
    $resourcePoolPath = $sourceRP.Name
    $parentRP = $sourceRP.Parent
    while ($parentRP -and $parentRP.Name -ne "Resources") {
        $resourcePoolPath = $($parentRP.Name) + "\" + $($resourcePoolPath)
        $parentRP = $parentRP.Parent
    }
    Write-Log "Source resource pool path: $($resourcePoolPath)"

    $destRootRP = Get-ResourcePool -Server $destVI | Where-Object { $_.Name -eq "Resources" -and $_.ParentId -eq $null }
    $destResourcePool = Get-OrCreateResourcePoolPath -Path $resourcePoolPath -RootResourcePool $destRootRP -VIServer $destVI
    Write-Log "Destination resource pool ensured: $($($destResourcePool.Name))"

    # --- Host and datastore selection ---
    Write-Log "Finding suitable destination host"
    try {
        if ($DestinationCluster) {
            Write-Log "Using specified destination cluster: $($DestinationCluster)"
            $cluster = Get-Cluster -Server $destVI -Name $DestinationCluster -ErrorAction Stop
            $destHost = Get-VMHost -Server $destVI -Location $cluster | Sort-Object -Property @{ Expression = { $_.ExtensionData.Summary.QuickStats.OverallMemoryUsage }; Ascending = $true } | Select-Object -First 1
        }
        else {
            Write-Log "No destination cluster specified, selecting host with least memory usage."
            $destHost = Get-VMHost -Server $destVI | Sort-Object -Property @{ Expression = { $_.ExtensionData.Summary.QuickStats.OverallMemoryUsage }; Ascending = $true } | Select-Object -First 1
        }

        if ($destHost) {
            Write-Log "Selected destination host: $($($destHost.Name)) (Memory Usage: $($($destHost.ExtensionData.Summary.QuickStats.OverallMemoryUsage)))"
        }
        else {
            Write-Log "ERROR: No suitable destination ESXi host found." "ERROR"
            throw "No suitable destination ESXi host found."
        }

    }
    catch {
        Write-Log "ERROR: Error finding a destination host. Error: $($_.Exception.Message)" "ERROR"
        throw
    }

    Write-Log "Finding suitable destination datastore"
    try {
        $destDatastore = Get-Datastore -Server $destVI | Where-Object { $_.FreeSpaceMB -gt $vmToMigrate.UsedSpaceGB * 1024 } | Sort-Object -Property FreeSpaceMB -Descending | Select-Object -First 1
        if ($destDatastore) {
            Write-Log "Selected destination datastore: $($($destDatastore.Name)) (Free Space: $($($destDatastore.FreeSpaceGB)) GB)"
        } else {
            Write-Log "ERROR: No suitable destination datastore found." "ERROR"
            throw "No suitable destination datastore found."
        }
    }
    catch {
        Write-Log "ERROR: Error finding a destination datastore. Error: $($_.Exception.Message)" "ERROR"
        throw
    }

    Write-Log "Destination host: $($($destHost.Name)), datastore: $($($destDatastore.Name))"

    # --- Network mapping by name ---
    $sourceNetAdapters = $vmToMigrate | Get-NetworkAdapter
    $networkMapping = @()
    foreach ($adapter in $sourceNetAdapters) {
        Write-Log "Mapping network adapter '$($($adapter.Name))' (Network: $($($adapter.NetworkName)))" -Level "DEBUG"
        $targetPG = Get-VirtualPortGroup -Server $destVI -Name $adapter.NetworkName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $targetPG) {
            Write-Log "ERROR: No matching port group '$($($adapter.NetworkName))' exists on destination vCenter." "ERROR"
            throw "No matching port group '$($($adapter.NetworkName))' exists on destination vCenter."
        }
        $networkMapping += [PSCustomObject]@{
            Adapter   = $adapter
            PortGroup = $targetPG
        }
        Write-Log "Mapped network adapter '$($($adapter.Name))' to port group '$($($targetPG.Name))'" -Level "DEBUG"
    }

    if ($Clone) {
        Write-Log "Cloning VM '$($VMToMigrateName)' to destination vCenter..."
        try {
            New-VM -VM $vmToMigrate `
                -Name "$($VMToMigrateName)-Clone" `
                -Destination $destHost `
                -Datastore $destDatastore `
                -NetworkAdapter $networkMapping.Adapter `
                -PortGroup $networkMapping.PortGroup `
                -InventoryLocation $destFolder `
                -ResourcePool $destResourcePool `
                -Confirm:$false `
                -ErrorAction Stop
            Write-Log "VM cloned successfully."
        }
        catch {
            Write-Log "ERROR: Cloning failed for VM '$($VMToMigrateName)'. Error: $($_.Exception.Message)" "ERROR"
            throw
        }
    } else {
        Write-Log "Starting cross-vCenter vMotion for VM '$($VMToMigrateName)'..."
        try {
            Move-VM -VM $vmToMigrate `
                -Destination $destHost `
                -Datastore $destDatastore `
                -NetworkAdapter $adapters `
                -PortGroup $portGroups `
                -InventoryLocation $destFolder `
                -Confirm:$false `
                -ErrorAction Stop
            Write-Log "Move-VM command executed successfully."
        }
        catch {
            Write-Log "ERROR: Cross-vCenter vMotion failed for VM '$($VMToMigrateName)'. Error: $($_.Exception.Message)" "ERROR"
            throw
        }

        Write-Log "Cross-vCenter vMotion completed successfully for VM '$($VMToMigrateName)'."

        # Wait for the VM to appear in the destination vCenter, then move to resource pool
        $maxAttempts = 30
        $attempt = 0
        $destVM = $null
        do {
            Start-Sleep -Seconds 10
            Write-Log "Checking for VM '$($VMToMigrateName)' on destination vCenter (Attempt: $($attempt + 1)/$maxAttempts)" -Level "DEBUG"
            $destVM = Get-VM -Server $destVI -Name $VMToMigrateName -ErrorAction SilentlyContinue
            if ($destVM) {
                Write-Log "VM '$($VMToMigrateName)' found on destination vCenter." -Level "DEBUG"
            }
            $attempt++
        } while (-not $destVM -and $attempt -lt $maxAttempts)

        if (-not $destVM) {
            Write-Log "ERROR: Migrated VM not found on destination vCenter after migration." "ERROR"
            throw "Migrated VM not found on destination vCenter."
        }

        if ($destVM.ResourcePoolId -ne $destResourcePool.Id) {
            Write-Log "Placing VM in the correct resource pool after migration."
            try {
                Move-VM -VM $destVM -Destination $destResourcePool -Confirm:$false -ErrorAction Stop
                Write-Log "VM placed in the correct resource pool."
            }
            catch {
                Write-Log "ERROR: Failed to move VM to resource pool. Error: $($_.Exception.Message)" "ERROR"
                throw
            }
        } else {
            Write-Log "VM is already in the correct resource pool."
        }

        # Check if the VM is on the network (all adapters connected)
        $networkAdapters = Get-NetworkAdapter -VM $destVM
        $disconnectedAdapters = $networkAdapters | Where-Object { -not $_.ConnectionState.Connected }

        if ($disconnectedAdapters) {
            Write-Log "WARNING: The following network adapters are disconnected:" "WARNING"
            foreach ($adapter in $disconnectedAdapters) {
                Write-Log "Adapter: $($($adapter.Name)), Network: $($($adapter.NetworkName))" "WARNING"
            }
            Write-Log "VM '$($VMToMigrateName)' is NOT fully connected to the network." "WARNING"
            Write-Host "VM '$($VMToMigrateName)' is NOT fully connected to the network. See log for details." -ForegroundColor Yellow
        } else {
            Write-Log "All network adapters are connected. VM '$($VMToMigrateName)' is on the network."
            Write-Host "All network adapters are connected. VM '$($VMToMigrateName)' is on the network." -ForegroundColor Green
        }
    }

} catch {
    Write-Log "ERROR: $_" "ERROR"
    throw
} finally {
    if ($sourceVI) {
        Write-Log "Disconnecting from source vCenter"
        try {
            Disconnect-VIServer -Server $sourceVI -Confirm:$false | Out-Null
        }
        catch {
            Write-Log "ERROR: Failed to disconnect from source vCenter. Error: $($_.Exception.Message)" "ERROR"
        }
    }
    if ($destVI) {
        Write-Log "Disconnecting from destination vCenter"
        try {
            Disconnect-VIServer -Server $destVI -Confirm:$false | Out-Null
        }
        catch {
            Write-Log "ERROR: Failed to disconnect from destination vCenter. Error: $($_.Exception.Message)" "ERROR"
        }
    }
}
