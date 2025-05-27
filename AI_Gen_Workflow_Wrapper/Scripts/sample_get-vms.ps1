<#
.SYNOPSIS
    Retrieves a list of VMs from a vCenter server and collects key data points.

.DESCRIPTION
    This script connects to a vCenter server (specified by the GUI workflow tool) and retrieves a list of
    virtual machines. For each VM, it collects the name, power state, number of CPUs, memory (GB),
    and guest operating system.

.PARAMETER vCenter
    The hostname or IP address of the vCenter server. This parameter is automatically passed by the GUI.

.PARAMETER vCenterName
    The friendly name of the vCenter server. This parameter is automatically passed by the GUI.
#>

#Access the parameters from the hashtable, setting defaults if needed
#param (
#    [string]$vCenter,  # vCenter Server Address
#    [string]$vCenterName, # vCenter Friendly Name
#    [Hashtable]$ScriptParams # Script Parameters
#)

#Access the parameters from the hashtable, setting defaults if needed
#Access the parameters from the hashtable, setting defaults if needed
#if ($ScriptParams["ServerName"]) {
#    $ServerName = $ScriptParams["ServerName"]
#} else {
#    $ServerName = "localhost"
#}

#if ($ScriptParams["Port"]) {
#    $Port = $ScriptParams["Port"]
#} else {
#    $Port = 443
#}

#if ($ScriptParams["UseSSL"]) {
#    $UseSSL = $ScriptParams["UseSSL"]
#} else {
#    $UseSSL = $true
#}

#if ($ScriptParams["ReportPath"]) {
#    $ReportPath = $ScriptParams["ReportPath"]
#} else {
#    $ReportPath = "C:\Reports\SampleReport.txt"
#}

param (
    [string]$vCenter,  # vCenter Server Address
    [string]$vCenterName # vCenter Friendly Name
)

try {
    Write-Output "Starting VM Report Script..."
    Write-Output "Connecting to vCenter: $vCenterName ($vCenter)..."

    # Connect to vCenter
    Connect-VIServer -Server $vCenter -Credential (Get-Credential) -ErrorAction Stop | Out-Null

    Write-Output "Retrieving list of VMs..."
    $vms = Get-VM

    Write-Output "Generating VM report..."
    $report = ""
    foreach ($vm in $vms) {
        $report += "VM Name: $($vm.Name)`n"
        $report += "Power State: $($vm.PowerState)`n"
        $report += "Number of CPUs: $($vm.NumCPU)`n"
        $report += "Memory (GB): $($vm.MemoryGB)`n"
        $report += "Guest OS: $($vm.Guest.OSFullName)`n"
        $report += "---`n"
    }

    Write-Output "Saving report to: $ReportPath"
    $report | Out-File -FilePath $ReportPath -Encoding UTF8

    Write-Output "VM Report Script completed successfully. Report saved to: $ReportPath"
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
finally {
    Disconnect-VIServer -force -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "VM Report Script finished."
}
