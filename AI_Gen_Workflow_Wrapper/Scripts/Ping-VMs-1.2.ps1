<#
.SYNOPSIS
Retrieves all VMs on a specified vCenter host and reports network status, excluding vCLS VMs.

.DESCRIPTION
This script connects to a vCenter Server, retrieves all virtual machines from a specified host,
and exports a limited set of their properties (Name, PowerState, GuestOS, DNSName, and NetworkAdapters)
to a JSON file. It excludes VMs with names starting with "vCLS". It uses the provided credentials to connect to vCenter.
All actions are logged to a file.

.PARAMETER VCenterServer
The FQDN or IP address of the vCenter Server.

.PARAMETER HostName
The name of the host in vCenter to query for VMs.

.PARAMETER Credential
A PSCredential object containing the username and password for vCenter. Can be
obtained using Get-Credential.

.PARAMETER LogPath
The base path for the log file. Defaults to ".\logs".

.PARAMETER ReportPath
The base path for the report file. Defaults to ".\Reports".

.EXAMPLE
Get-Credential | .\Get-VMData.ps1 -VCenterServer "vcenter.example.com" -HostName "esxi01.example.com" -LogPath "C:\logs" -ReportPath "C:\Reports"

.\Get-VMData.ps1 -VCenterServer "vcenter.example.com" -HostName "esxi01.example.com" -Credential (Get-Credential) -LogPath ".\logs" -ReportPath ".\Reports"

.NOTES
Requires VMware PowerCLI module. Ensure VMware.VimAutomation.Core module is imported.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the FQDN or IP of the vCenter Server")]
    [string]$VCenterServer,

    [Parameter(Mandatory = $true, HelpMessage = "Enter the name of the host in vCenter")]
    [string]$HostName,

    [Parameter(Mandatory = $true, ParameterSetName = "Credential", HelpMessage = "Enter a PSCredential object for vCenter authentication.")]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false, HelpMessage = "Enter the base path for the log file. Defaults to '.\\logs'.")]
    [string]$LogPath = ".\logs",

    [Parameter(Mandatory = $false, HelpMessage = "Enter the base path for the report file. Defaults to '.\\Reports'.")]
    [string]$ReportPath = ".\Reports"
)

#region Setup
try {
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

    # Construct the log file name with timestamp
    $ScriptFileName = Split-Path -Path $MyInvocation.MyCommand.Path -Leaf
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogFileName = "$($ScriptFileName -replace '\.ps1$', '')-$($Timestamp).log"
    $LogFilePath = Join-Path -Path $LogDirectory -ChildPath $LogFileName

    # Create the "Reports" subfolder if it doesn't exist
    $ReportDirectory = Join-Path -Path $PSScriptRoot -ChildPath "Reports"
    if (!(Test-Path -Path $ReportDirectory -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $ReportDirectory -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Host "ERROR: Failed to create 'Reports' directory: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }

    # Construct the report file name with timestamp
    $ReportFileName = "$($ScriptFileName -replace '\.ps1$', '')-$($Timestamp).json"
    $ReportFilePath = Join-Path -Path $ReportDirectory -ChildPath $ReportFileName

    # Function to write to the log file
    function Write-Log {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Message,
            [ValidateSet("Info", "Warning", "Error")]
            [string]$Severity = "Info"
        )
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "$Timestamp [$Severity] - $Message"
        Add-Content -Path $LogFilePath -Value $LogEntry
        Write-Verbose "$Timestamp [$Severity] - $Message" #Echo to console if verbose is enabled
    }

    Write-Log -Message "Script started. Logging to: $($LogFilePath)"
}
catch {
    Write-Host "Error setting up logging: $($_.Exception.Message)"
    exit 1 # Exit the script if logging fails
}
#endregion Setup

#region vCenter Connection
try {
    Write-Log -Message "Connecting to vCenter: $($VCenterServer)"
    Connect-VIServer -Server $VCenterServer -Credential $Credential -ErrorAction Stop | Out-Null # Suppress output

    Write-Log -Message "Successfully connected to vCenter: $($VCenterServer)"

}
catch {
     # Attempt to import the VMware.VimAutomation.Core module
    try {
        Write-Log -Message "Attempting to import module VMware.VimAutomation.Core"
        Import-Module -Name VMware.VimAutomation.Core -ErrorAction Stop
        Write-Log -Message "Successfully imported module VMware.VimAutomation.Core"
    }
    catch {
        Write-Log -Message "Failed to import VMware.VimAutomation.Core module: $($_.Exception.Message)" -Severity "Error"
        Write-Error "Failed to import VMware.VimAutomation.Core module: $($_.Exception.Message)"
        Disconnect-VIServer -Server $VCenterServer -Confirm:$false #Disconnect in case it partially connected
        exit 1
    }
    Write-Log -Message "Failed to connect to vCenter: $($_.Exception.Message)" -Severity "Error"
    Write-Error "Failed to import VMware.VimAutomation.Core module: $($_.Exception.Message)"
    Disconnect-VIServer -Server $VCenterServer -Confirm:$false #Disconnect in case it partially connected
    exit 1
}
#endregion vCenter Connection

#region VM Processing
try {
    # Get the host object
    $VMHost = Get-VMHost -Name $HostName -ErrorAction Stop

    if (-not $VMHost) {
        Write-Log -Message "Host '$($HostName)' not found." -Severity "Error"
        Write-Error "Host '$($HostName)' not found."
        exit 1
    }

    # Get all VMs on the specified host from the vCenter Server (excluding vCLS VMs)
    $VMs = Get-VM -Server $VCenterServer -ErrorAction Stop | Where-Object {$_.VMHost -eq $VMHost -and $_.Name -notlike "vCLS*"}

    Write-Log -Message "Found $($VMs.Count) VMs on host: $($HostName) (excluding vCLS VMs)"

    # Create the base report object
    $ReportObject = [PSCustomObject]@{
        VCenter  = $VCenterServer
        HostName = $HostName
        VMs      = @()
    }

    # Iterate through each VM and collect data
    foreach ($VM in $VMs) {
        Write-Log -Message "Collecting data for VM: $($VM.Name)"

        # Get the View object for the VM
        $VMView = Get-View -Id $VM.Id -ErrorAction Stop

        # Create a hashtable with the desired properties
        $VMData = [ordered]@{}
        $VMData["Name"] = $VM.Name
        $VMData["PowerState"] = $VM.PowerState.ToString() # Convert PowerState to string
        if($VMView.Guest){
        $VMData["GuestOS"] = $VMView.Guest.GuestFullName
        $VMData["DNSName"] = $VMView.Guest.HostName
        }
        else{
            $VMData["GuestOS"] = "N/A"
            $VMData["DNSName"] = "N/A"
        }

        #Create Network Adapter Data
        $NetworkAdapters = Get-NetworkAdapter -VM $VM
        $NetworkAdapterDataList = @()
        foreach ($NetworkAdapter in $NetworkAdapters)
        {
           $IPAddress = $null
             try {
                # Access the ExtensionData to retrieve the IP address
                $GuestNet = $VM.ExtensionData.Guest.Net | Where-Object {$_.MacAddress -eq $NetworkAdapter.MacAddress}

                 if ($GuestNet -and $GuestNet.IPAddress) {
                    $IPAddress = $GuestNet.IPAddress[0]
                    Write-Log -Message "Found IP Address $($IPAddress) for $($VM.Name) Adapter $($NetworkAdapter.Name)"
                 }
            }
            catch {
                Write-Log -Message "Error getting IP address for VM $($VM.Name) - Adapter $($NetworkAdapter.Name): $($_.Exception.Message)" -Severity "Warning"
            }

             $PingStatus = "N/A" # Initialize Ping Status
            if (-not [string]::IsNullOrEmpty($IPAddress)) {
                Write-Log -Message "Pinging VM: $($VM.Name) - Adapter: $($NetworkAdapter.Name) - IP: $($IPAddress)"
                try {
                    $PingResult = Test-Connection -ComputerName $($IPAddress) -Count 1 -Quiet -ErrorAction SilentlyContinue

                    if ($PingResult) {
                        Write-Log -Message "VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) - IP: $($IPAddress) - Ping Successful"
                        Write-Host "VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) - IP: $($IPAddress) - Ping Successful"
                        $PingStatus = "Success"
                    }
                    else {
                        Write-Log -Message "VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) - IP: $($IPAddress) - Ping Failed" -Severity "Warning"
                        Write-Host "VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) - IP: $($IPAddress) - Ping Failed"
                        $PingStatus = "Failed"
                    }
                }
                catch {
                    Write-Log -Message "Error pinging VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) - IP: $($IPAddress): $($_.Exception.Message)" -Severity "Error"
                    Write-Host "Error pinging VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) - IP: $($IPAddress): $($_.Exception.Message)"
                    $PingStatus = "Error"
                }
            }
            else {
                Write-Log -Message "VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) has a null or empty IP address. Skipping ping." -Severity "Warning"
                Write-Host "VM $($VM.Name) - Adapter: $($NetworkAdapter.Name) has a null or empty IP address. Skipping ping."
                $PingStatus = "No IP"
            }

           $NetworkAdapterData = [PSCustomObject]@{
                Name = $NetworkAdapter.Name
                NetworkName = $NetworkAdapter.NetworkName
                MacAddress = $NetworkAdapter.MacAddress
                IPAddress = $IPAddress # Include the IP Address
                PingResult = $PingStatus
                # Add other relevant NetworkAdapter properties here
            }
           # Convert the hashtable to a custom object and add it to the array
           $NetworkAdapterDataList += [PSCustomObject]$NetworkAdapterData

        }
        $VMData["NetworkAdapters"] = $NetworkAdapterDataList

        # Convert the hashtable to a custom object and add it to the array
        $ReportObject.VMs += [PSCustomObject]$VMData
    }

}
catch {
    Write-Log -Message "Error processing VMs: $($_.Exception.Message)" -Severity "Error"
    Write-Error "Error processing VMs: $($_.Exception.Message)"
}
finally {
    # Disconnect from vCenter
    try {
        Write-Log -Message "Disconnecting from vCenter."
        Disconnect-VIServer -Server $VCenterServer -Confirm:$false | Out-Null
        Write-Log -Message "Disconnected from vCenter."
    }
    catch {
        Write-Log -Message "Error disconnecting from vCenter: $($_.Exception.Message)" -Severity "Warning"
        Write-Warning "Error disconnecting from vCenter: $($_.Exception.Message)"
    }

    # Output the report
    Write-Log -Message "Generating Report:"
    Write-Host " "
    Write-Host "VM Report for Host: $($HostName)"
    Write-Host "Total VMs on Host: $($ReportObject.VMs.Count)"
    Write-Host " "
    #$ReportData | Format-Table -AutoSize #Removed since we are saving to JSON file.
    $ReportJson = ConvertTo-Json -InputObject ([PSCustomObject]$ReportObject) -Depth 5 # Capture the JSON string

    try {
        $ReportJson | Out-File -FilePath $ReportFilePath -Encoding UTF8 -ErrorAction Stop
        Write-Log -Message "Report saved to: $($ReportFilePath)"
    }
    catch {
        Write-Log -Message "Error saving report to $($ReportFilePath): $($_.Exception.Message)" -Severity "Error"
        Write-Error "Error saving report to $($ReportFilePath): $($_.Exception.Message)"
    }

    Write-Log -Message "Report Data (JSON): $($ReportJson)" # Pass the string to Write-Log
    Write-Log -Message "Script finished."
}
#endregion VM Processing
