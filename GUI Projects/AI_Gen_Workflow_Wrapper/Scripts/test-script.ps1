<#
.SYNOPSIS
    Retrieves a list of VMs from a vCenter server and collects key data points.

.DESCRIPTION
    This script connects to a vCenter server (specified by the GUI workflow tool) and retrieves a list of
    virtual machines. For each VM, it collects the name, power state, number of CPUs, memory (GB),
    and guest operating system.

.PARAMETER vCenter
    The hostname or IP address of the vCenter server. This parameter is automatically passed by the GUI.


.PARAMETER LogOutputLocation
    The location to store log files.
.PARAMETER ReportOutputLocation
    The location to store report files.
#>
param(   
    [Parameter(Mandatory=$true)]
    [string]$vCenterName,
      
    [Parameter(Mandatory=$false)]
    [string]$LogOutputLocation = "C:\Logs",
    
    [Parameter(Mandatory=$false)]
    [string]$ReportOutputLocation = "C:\Reports"
)

try {
    # Function to append text to GUI status textbox (replace with your actual method)
    function Write-GUIStatus {
        param([string]$Message)
        # Replace this with the correct way to access and update the GUI textbox
        Write-Host $Message  # Placeholder for testing in console
        # Example (adapt to your GUI):
        # [void]$txtStatus.Invoke([Action[string]]{param($s) $txtStatus.AppendText("$s`r`n")}, $Message)
    }

    Write-GUIStatus "Starting VM Report Script..."
    Write-GUIStatus "Connecting to vCenter: $vCenterName ($vCenter)..."

    Write-GUIStatus "Retrieving list of VMs..."
    $vms = Get-VM -Server $vCenterConnection  # Use the existing connection

    Write-GUIStatus "Generating VM report..."
    $report = ""
    foreach ($vm in $vms) {
        # Check for cancellation
        if ($global:StopScript) {
            Write-Log "Script cancelled by user." -Severity Info
            Write-GUIStatus "Script cancelled."
            break  # Exit the loop
        }

        $report += "VM Name: $($vm.Name)`n"
        $report += "Power State: $($vm.PowerState)`n"
        $report += "Number of CPUs: $($vm.NumCPU)`n"
        $report += "Memory (GB): $($vm.MemoryGB)`n"
        $report += "Guest OS: $($vm.Guest.OSFullName)`n"
        $report += "---`n"
    }

    Write-GUIStatus "Saving report to: $ReportOutputLocation\VMReport.txt"
    $report | Out-File -FilePath "$ReportOutputLocation\VMReport.txt" -Encoding UTF8

    Write-GUIStatus "VM Report Script completed successfully. Report saved to: $ReportOutputLocation"
    Write-Log "VM Report Script completed successfully. Report saved to: $ReportOutputLocation" -Severity Info
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    Write-Log "An error occurred: $($_.Exception.Message) - $($_.ScriptStackTrace)" -Severity Error
    Write-GUIStatus "An error occurred: $($_.Exception.Message)"
}
finally {
    Write-GUIStatus "VM Report Script finished."
}
