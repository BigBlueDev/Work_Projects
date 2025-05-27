<#
.SYNOPSIS
    Collects information about virtual machines in a vCenter environment and exports it to a JSON file.

.DESCRIPTION
    This script connects to a vCenter server, retrieves detailed information about each virtual machine,
    and exports the data to a JSON file. The information includes VM configuration, network settings,
    resource allocation, folder and resource pool paths, and direct permissions. The script handles
    both standard and distributed virtual switches.

.PARAMETER vCenterConnection
    An existing vCenter server connection object. This will be provided by the wrapper.

.PARAMETER LogOutputLocation
    The directory where log files will be stored.

.PARAMETER ReportOutputLocation
    The directory where report files will be stored.

.NOTES
    * This script is designed to be run from the vCenter Migration Workflow Manager.
    * The script uses an existing vCenter connection provided by the wrapper.
    * Error handling and logging are implemented to improve script reliability.
#>
param (
    [Parameter(Mandatory = $true)]
    [VMware.VimAutomation.ViCore.Types.V1.VIServer]$vCenterConnection,
    
    [Parameter(Mandatory = $false)]
    [string]$LogOutputLocation = "C:\Logs",
    
    [Parameter(Mandatory = $false)]
    [string]$ReportOutputLocation = "C:\Reports"
)

#region Function Definition

# Define output file paths
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$vCenterName = $vCenterConnection.Name
$OutputFile = Join-Path $ReportOutputLocation "VM_Backup_Report_${vCenterName}_${timestamp}.json"
$LogFile = Join-Path $LogOutputLocation "VM_Backup_Report_${vCenterName}_${timestamp}.log"

# Function to write log messages to a file with timestamp and severity
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Severity = "Info"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Severity] $Message"
    try {
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction Stop
        Write-Output $LogEntry # Output to console for the wrapper to capture
    }
    catch {
        Write-Warning "Failed to write to log file '$LogFile': $($_.Exception.Message)"
        Write-Output $LogEntry # Output to console as a fallback
    }
}

#endregion

#region VM Information Collection

# Verify vCenter connection
if (-not $vCenterConnection -or $vCenterConnection.IsConnected -ne $true) {
    Write-Log "No active vCenter connection found. Please ensure the wrapper has connected to vCenter." -Severity "Error"
    throw "No active vCenter connection found."
}

Write-Log "Starting VM backup report for vCenter: $vCenterName"
Write-Log "Using existing vCenter connection: $($vCenterConnection.Name)"

# Ensure output directories exist
if (-not (Test-Path $ReportOutputLocation)) {
    try {
        New-Item -Path $ReportOutputLocation -ItemType Directory -Force | Out-Null
        Write-Log "Created report output directory: $ReportOutputLocation"
    }
    catch {
        Write-Log "Failed to create report output directory: $($_.Exception.Message)" -Severity "Error"
        throw "Failed to create report output directory: $($_.Exception.Message)"
    }
}

# Collect VM information
Write-Log "Collecting VM information from $vCenterName..."

$vmReport = Get-VM -Server $vCenterConnection | ForEach-Object {
    try {
        $vm = $_
        Write-Log "Processing VM: $($vm.Name)"

        # Get complete folder path
        $folderPath = ""
        $currentFolder = $vm.Folder
        while ($currentFolder.Parent -ne $null) {
            $folderPath = "$($currentFolder.Name)/$folderPath"
            $currentFolder = $currentFolder.Parent
        }
        $folderPath = "/$folderPath"

        # Resource pool with path
        $resourcePoolPath = ""
        $currentRP = $vm.ResourcePool
        while ($currentRP.Parent -ne $null -and $currentRP.Parent -isnot [VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster]) {
            $resourcePoolPath = "$($currentRP.Name)/$resourcePoolPath"
            $currentRP = $currentRP.Parent
        }
        $resourcePoolPath = "$($currentRP.Name)/$resourcePoolPath"
        $resourcePoolPath = $resourcePoolPath.TrimEnd('/')

        # Cluster info
        $cluster = $vm.VMHost.Parent.Name

        # Network info: Get all network adapters and their configurations
        $networkAdapters = Get-NetworkAdapter -VM $vm -Server $vCenterConnection | ForEach-Object {
            $netAdapter = $_

            # Check if this network is a Distributed Port Group
            $dvPortGroup = Get-VDPortgroup -Name $netAdapter.NetworkName -Server $vCenterConnection -ErrorAction SilentlyContinue

            if ($dvPortGroup) {
                # It's a distributed port group
                $dvSwitch = $dvPortGroup.VDSwitch.Name

                @{
                    Name = $netAdapter.Name
                    Type = $netAdapter.Type
                    NetworkName = $netAdapter.NetworkName
                    MacAddress = $netAdapter.MacAddress
                    Connected = $netAdapter.ConnectionState.Connected
                    NetworkType = "Distributed"
                    DVSwitch = $dvSwitch
                    PortGroupType = $dvPortGroup.PortBinding
                    VLANId = $dvPortGroup.VlanConfiguration.VlanId
                }
            }
            else {
                # It's a standard port group or other type
                @{
                    Name = $netAdapter.Name
                    Type = $netAdapter.Type
                    NetworkName = $netAdapter.NetworkName
                    MacAddress = $netAdapter.MacAddress
                    Connected = $netAdapter.ConnectionState.Connected
                    NetworkType = "Standard"
                }
            }
        }

        # Get permissions applied directly on the VM (not inherited)
        $vmPermissions = Get-VIPermission -Entity $vm -Server $vCenterConnection | Where-Object { -not $_.IsInherited } | ForEach-Object {
            @{
                Principal = $_.Principal
                Role = $_.Role
                Propagate = $_.Propagate
            }
        }

        # Create a custom object for output
        [PSCustomObject]@{
            VMName = $vm.Name
            PowerState = $vm.PowerState
            FolderPath = $folderPath
            ResourcePool = $resourcePoolPath
            Cluster = $cluster
            Host = $vm.VMHost.Name
            NetworkAdapters = $networkAdapters
            NumCPU = $vm.NumCpu
            MemoryGB = $vm.MemoryGB
            ProvisionedSpaceGB = [math]::Round($vm.ProvisionedSpaceGB, 2)
            UsedSpaceGB = [math]::Round($vm.UsedSpaceGB, 2)
            GuestOS = $vm.Guest.OSFullName
            VMVersion = $vm.Version
            UUID = $vm.ExtensionData.Config.Uuid
            Permissions = $vmPermissions
        }
    }
    catch {
        Write-Log "Error processing VM '$($vm.Name)': $($_.Exception.Message)" -Severity "Warning"
        # Return null for this VM, we'll filter these out later
        return $null
    }
}

# Remove any null entries from the report if errors occurred
$vmReport = $vmReport | Where-Object { $_ -ne $null }

Write-Log "Processed $($vmReport.Count) VMs successfully."

#endregion

#region JSON Export

# Export to JSON
Write-Log "Exporting report to JSON file '$OutputFile'..."
try {
    $vmReport | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutputFile -Encoding utf8 -ErrorAction Stop
    Write-Log "Report successfully exported to JSON file '$OutputFile'."
}
catch {
    Write-Log "Error exporting report to JSON file '$OutputFile': $($_.Exception.Message)" -Severity "Error"
    throw "Error exporting report to JSON file: $($_.Exception.Message)"
}

#endregion

#region Completion Message

Write-Log "VM backup report generation complete for $vCenterName."
Write-Log "JSON file saved to: $OutputFile"
Write-Output "VM backup report generation complete for $vCenterName. JSON file saved to: $OutputFile"

#endregion
