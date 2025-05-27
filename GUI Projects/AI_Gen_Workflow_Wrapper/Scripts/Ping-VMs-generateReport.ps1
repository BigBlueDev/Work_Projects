<#
.SYNOPSIS
Generates an HTML report from a JSON file.

.DESCRIPTION
This script takes a path to a JSON file containing VM data and generates an HTML report.

.PARAMETER JSONFilePath
The path to the JSON file containing the VM data.

.PARAMETER HTMLReportFilePath
The path to save the HTML report.

.EXAMPLE
.\Generate-HTMLReport.ps1 -JSONFilePath "C:\Reports\vm_report.json" -HTMLReportFilePath "C:\HTMLReports\vm_report.html"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the path to the JSON file")]
    [string]$JSONFilePath,

    [Parameter(Mandatory = $true, HelpMessage = "Enter the path to save the HTML report")]
    [string]$HTMLReportFilePath
)

try {
    # Load the JSON data
    $ReportData = Get-Content -Path $JSONFilePath -Raw | ConvertFrom-Json -ErrorAction Stop

    # Start building the HTML
    $HTML = @"
<!DOCTYPE html>
<html>
<head>
<title>VM Report for $($ReportData.HostName)</title>
<style>
body { font-family: sans-serif; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid black; padding: 8px; text-align: left; }
th { background-color: #f2f2f2; }
.success { color: green; }
.failed { color: red; }
.noip { color: orange; }
.error { color: purple; }
</style>
</head>
<body>
<h1>VM Report for $($ReportData.HostName)</h1>
<p>VCenter Server: $($ReportData.VCenter)</p>
<p>Total VMs: $($ReportData.VMs.Count)</p>
"@

    # Loop through each VM
    foreach ($VM in $ReportData.VMs) {
        $HTML += @"
<h2>VM: $($VM.Name)</h2>
<table>
<tr><th>Property</th><th>Value</th></tr>
<tr><td>PowerState</td><td>$($VM.PowerState)</td></tr>
<tr><td>GuestOS</td><td>$($VM.GuestOS)</td></tr>
<tr><td>DNSName</td><td>$($VM.DNSName)</td></tr>
</table>

<h3>Network Adapters</h3>
<table>
<tr><th>Name</th><th>NetworkName</th><th>MacAddress</th><th>IPAddress</th><th>PingResult</th></tr>
"@

        # Loop through each Network Adapter
        foreach ($Adapter in $VM.NetworkAdapters) {
            $HTML += @"
<tr>
<td>$($Adapter.Name)</td>
<td>$($Adapter.NetworkName)</td>
<td>$($Adapter.MacAddress)</td>
<td>$($Adapter.IPAddress)</td>
<td class="$($Adapter.PingResult)">$($Adapter.PingResult)</td>
</tr>
"@
        }

        $HTML += @"
</table>
"@
    }

    # Close the HTML
    $HTML += @"
</body>
</html>
"@

    # Save the HTML to a file
    $HTML | Out-File -FilePath $HTMLReportFilePath -Encoding UTF8 -ErrorAction Stop
    Write-Host "HTML Report saved to: $($HTMLReportFilePath)"
}
catch {
    Write-Host "Error generating HTML report: $($_.Exception.Message)" -ForegroundColor Red
}
