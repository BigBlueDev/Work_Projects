function Get-VMsWithFloppyDrives {
    <#
    .SYNOPSIS
        Discovers and reports VMs with attached floppy drives in a vCenter environment.
    .DESCRIPTION
        Connects to a vCenter server and generates a detailed report of VMs with floppy drives,
        including VM name, power state, and floppy drive details.
    .PARAMETER VCenterServer
        The FQDN or IP address of the vCenter server.
    .PARAMETER Credential
        PSCredential object with permissions to connect to vCenter.
    .PARAMETER OutputFolder
        Optional folder to save CSV and HTML reports. Defaults to script directory.
    .PARAMETER GenerateReports
        Switch to generate CSV and HTML reports in addition to console output.
    .EXAMPLE
        $cred = Get-Credential
        Get-VMsWithFloppyDrives -VCenterServer "vcenter.mydomain.local" -Credential $cred -GenerateReports
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VCenterServer,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory=$false)]
        [string]$OutputFolder = $PSScriptRoot,

        [Parameter(Mandatory=$false)]
        [switch]$GenerateReports
    )

    # Ensure VMware PowerCLI is installed and imported
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        try {
            Install-Module VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
            Import-Module VMware.PowerCLI
        } catch {
            Write-Error "Failed to install or import VMware PowerCLI: $_"
            return
        }
    } else {
        Import-Module VMware.PowerCLI
    }

    # Disable PowerCLI version warnings
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

    # Prepare output folder and files
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvReport = Join-Path $OutputFolder "FloppyDriveVMs_$timestamp.csv"
    $htmlReport = Join-Path $OutputFolder "FloppyDriveVMs_$timestamp.html"

    # Logging function
    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
        Write-Verbose $logEntry
    }

    try {
        # Connect to vCenter
        Write-Log "Connecting to vCenter: $VCenterServer"
        $viServer = Connect-VIServer -Server $VCenterServer -Credential $Credential -ErrorAction Stop

        # Collect VMs with floppy drives
        Write-Log "Scanning VMs for floppy drives"
        $floppyVMs = Get-VM | Where-Object { 
            ($_ | Get-FloppyDrive) 
        } | ForEach-Object {
            $vm = $_
            $floppyDrives = $vm | Get-FloppyDrive
            
            $floppyDrives | ForEach-Object {
                [PSCustomObject]@{
                    VMName = $vm.Name
                    PowerState = $vm.PowerState
                    Cluster = $vm.VMHost.Parent.Name
                    HostName = $vm.VMHost.Name
                    FloppyFileName = $_.FileName
                    FloppyType = $_.Type
                }
            }
        }

        # Prepare results
        $vmCount = $floppyVMs.Count
        $uniqueVMCount = ($floppyVMs | Select-Object -Unique VMName).Count

        # Console output
        Write-Host "`n=== Floppy Drive Scan Results ===" -ForegroundColor Cyan
        Write-Host "Total VMs with Floppy Drives: $uniqueVMCount" -ForegroundColor Green
        Write-Host "Total Floppy Drive Instances: $vmCount" -ForegroundColor Green

        # Detailed VM List
        Write-Host "`nDetailed Floppy Drive Information:" -ForegroundColor Yellow
        $floppyVMs | Format-Table -AutoSize

        # Generate CSV Report if requested
        if ($GenerateReports) {
            Write-Log "Generating CSV report"
            $floppyVMs | Export-Csv -Path $csvReport -NoTypeInformation
            Write-Host "`nCSV Report saved to: $csvReport" -ForegroundColor Green

            # Generate HTML Report
            Write-Log "Generating HTML report"
            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>vCenter Floppy Drive Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary { margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>vCenter Floppy Drive Report</h1>
    <div class="summary">
        <p><strong>Total VMs with Floppy Drives:</strong> $uniqueVMCount</p>
        <p><strong>Total Floppy Drive Instances:</strong> $vmCount</p>
        <p><strong>Generated:</strong> $(Get-Date)</p>
    </div>
    <table>
        <tr>
            <th>VM Name</th>
            <th>Power State</th>
            <th>Cluster</th>
            <th>Host Name</th>
            <th>Floppy File Name</th>
            <th>Floppy Type</th>
        </tr>
        $(foreach ($item in $floppyVMs) {
            "<tr>
                <td>$($item.VMName)</td>
                <td>$($item.PowerState)</td>
                <td>$($item.Cluster)</td>
                <td>$($item.HostName)</td>
                <td>$($item.FloppyFileName)</td>
                <td>$($item.FloppyType)</td>
            </tr>"
        })
    </table>
</body>
</html>
"@
            $htmlContent | Out-File -FilePath $htmlReport
            Write-Host "HTML Report saved to: $htmlReport" -ForegroundColor Green
        }

        # Return results object for potential further processing
        return @{
            TotalVMsWithFloppyDrives = $uniqueVMCount
            TotalFloppyDriveInstances = $vmCount
            FloppyVMs = $floppyVMs
            CSVReportPath = $(if($GenerateReports){$csvReport}else{$null})
            HTMLReportPath = $(if($GenerateReports){$htmlReport}else{$null})
        }

    } catch {
        Write-Error "An error occurred: $_"
    } finally {
        # Disconnect from vCenter
        if ($viServer) {
            Disconnect-VIServer -Server $viServer -Confirm:$false
        }
    }
}

# Example usage
$credential = Get-Credential
Get-VMsWithFloppyDrives -VCenterServer "vcenter.yourdomain.com" -Credential $credential -GenerateReports -Verbose
