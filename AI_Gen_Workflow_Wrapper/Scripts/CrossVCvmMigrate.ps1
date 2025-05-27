<#
.SYNOPSIS
    Migrates or clones a list of virtual machines from one vCenter Server to another using Move-VM.

.DESCRIPTION
    This script performs cross-vCenter vMotion or cloning of a list of specified virtual machines using the Move-VM cmdlet.

    By default, the script performs a vMotion (moves) the VMs.  If the -Clone switch is used, it creates clones instead.

.PARAMETER SourceVCenter
    The hostname or IP address of the source vCenter Server.

.PARAMETER DestVCenter
    The hostname or IP address of the destination vCenter Server.

.PARAMETER VMList
    An array of virtual machine names to migrate or clone.  If specified, the script will iterate
    through this list.  Cannot be used with -VMListFile.

.PARAMETER VMListFile
    The path to a text file containing a list of virtual machine names, one per line.  If specified,
    the script will read the VM names from this file and iterate through them. Cannot be used with -VMList.

.PARAMETER SourceVCCredential
    A PSCredential object containing the username and password for the source vCenter Server.
    If not provided, the script will prompt for credentials.

.PARAMETER DestVCCredential
    A PSCredential object containing the username and password for the destination vCenter Server.
    If not provided, the script will prompt for credentials.

.PARAMETER LogFile
    The base name of the log file. The script will add a timestamp and save the log in a "logs" subfolder.
    Defaults to "CrossVCVMotion".

.PARAMETER SkipModuleCheck
    A switch parameter that, when present, skips the check for the VMware PowerCLI module.
    Use this if you know the module is already installed or you don't want the script to automatically try to install it.

.PARAMETER DestinationCluster
    The name of the destination cluster. If specified, the destination host will be selected from this cluster.
    Otherwise, the host with the least memory usage will be selected from the entire destination vCenter.

.PARAMETER Clone
    A switch parameter. If specified, the script will create a clone of the VMs instead of performing a vMotion (move).

.EXAMPLE
    .\CrossVCvmMigrate.ps1 -SourceVCenter "source_vc.example.com" -DestVCenter "dest_vc.example.com" -VMList "VM1","VM2","VM3" -SourceVCCredential (Get-Credential) -DestVCCredential (Get-Credential)

.EXAMPLE
    .\CrossVCvmMigrate.ps1 -SourceVCenter "source_vc.example.com" -DestVCenter "dest_vc.example.com" -VMListFile "C:\VMs.txt" -SourceVCCredential (Get-Credential) -DestVCCredential (Get-Credential) -Clone

.NOTES
    *   Requires the VMware PowerCLI module to be installed.
    *   The user accounts used to connect to the vCenter Servers must have the necessary permissions to perform vMotion operations.
    *   Network names must match between the source and destination vCenter Servers for network adapter mapping to succeed.
    *   The script will select the destination host with the least memory usage and the datastore with the most free space that is large enough for the VM.
    *   To enable verbose output, run the script with the `-Verbose` switch or set `$VerbosePreference = "Continue"`.
    *   When using -VMListFile, ensure the file contains one VM name per line.

.LINK
    https://developer.vmware.com/powercli
#>
param(
    [Parameter(Mandatory=$true)][string]$SourceVCenter,
    [Parameter(Mandatory=$true)][string]$DestVCenter,
    [Parameter(ParameterSetName='List', Mandatory=$true)][string[]]$VMList,
    [Parameter(ParameterSetName='File', Mandatory=$true)][string]$VMListFile,
    [Parameter()][PSCredential]$SourceVCCredential,
    [Parameter()][PSCredential]$DestVCCredential,
    [string]$LogFile = "CrossVCVMotion",
    [string]$DestinationCluster,
    [switch]$SkipModuleCheck,
    [switch]$Clone
)

# Check if VMList and VMListFile are used together
if ($VMList -and $VMListFile) {
    throw "Parameters -VMList and -VMListFile cannot be used together."
}

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

#--------------- Start of Get-VcConnection Function ---------------
<#
.SYNOPSIS
Gets VI server connection by a given server uuid.

.DESCRIPTION
Gets VI server connection by a given server instance uuid from the default connected VI servers collection.
#>
function Get-VcConnection([string]$VcInstanceUuid) {
    $DefaultVIServers | Where-Object {$_.InstanceUuid -eq $vcInstanceUuid}
}
#--------------- End of Get-VcConnection Function ---------------

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
                $nextRP = New-Folder -Server $VIServer -Name $rpName -Location $currentRP -ErrorAction Stop
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
if ($VMList) {
    Write-Log "VMList: $($VMList)"
} elseif ($VMListFile) {
    Write-Log "VMListFile: $($VMListFile)"
}
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
    # Get the list of VMs to process
    if ($VMList) {
        $VMs = $VMList
    } elseif ($VMListFile) {
        try {
            $VMs = Get-Content -Path $VMListFile -ErrorAction Stop
        }
        catch {
            Write-Log "ERROR: Failed to read VM list from file '$($VMListFile)'. Error: $($_.Exception.Message)" "ERROR"
            throw
        }
    } else {
        # This should never happen due to the Parameter Sets, but just in case
        Write-Log "ERROR: No VM list provided." "ERROR"
        throw "No VM list provided."
    }

    # Iterate through the VMs
    foreach ($VMToMigrateName in $VMs) {
        Write-Log "Starting processing for VM: $($VMToMigrateName)"

        # Initialize $sourceVI and $destVI to $null in case connection fails
        $sourceVI = $null
        $destVI = $null

        try {
            # Connect to vCenter Servers (INSIDE the loop)
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

            # Get Host, Datastore, Folder, ResourcePool
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

            $destFolder = Get-Folder -Server $destVI -Name "vm"
            $destResourcePool = Get-ResourcePool -Server $destVI -Name "Resources"

            # --- Network mapping by name ---
            $sourceNetAdapters = $vmToMigrate | Get-NetworkAdapter
            $networkMapping = @()
            foreach ($adapter in $sourceNetAdapters) {
                $targetPG = Get-VirtualPortGroup -Server $destVI -Name $adapter.NetworkName -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $targetPG) {
                    Write-Log "ERROR: No matching port group '$($($adapter.NetworkName))' exists on destination vCenter." "ERROR"
                    throw "No matching port group '$($($adapter.NetworkName))' exists on destination vCenter."
                }
                $networkMapping += [PSCustomObject]@{
                    Adapter   = $adapter
                    PortGroup = $targetPG
                }
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
                        -NetworkAdapter $networkMapping.Adapter `
                        -PortGroup $networkMapping.PortGroup `
                        -InventoryLocation $destFolder `
                        -Confirm:$false `
                        -ErrorAction Stop
                    Write-Log "Cross-vCenter vMotion completed successfully for VM '$($VMToMigrateName)'."
                }
                catch {
                    Write-Log "ERROR: Cross-vCenter vMotion failed for VM '$($VMToMigrateName)'. Error: $($_.Exception.Message)" "ERROR"
                    throw
                }
            }

        } catch {
            Write-Log "ERROR: Processing failed for VM '$($VMToMigrateName)'. Error: $_" "ERROR"
            # Continue to the next VM
        } finally {
            # Disconnect from vCenter Servers (INSIDE the loop)
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
            Write-Log "Completed processing for VM: $($VMToMigrateName)"
        }
    } # End foreach VM

} catch {
    Write-Log "ERROR: Script failed. Error: $_" "ERROR"
    throw
} finally {
    # The disconnects are now done within the loop. Removing the disconnects from the final block
}
