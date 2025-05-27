# ---------------------------------------------------------------
# Script: Get-AllVMsEVCStatus.ps1
# Purpose: Connect to vCenter, gather all VMs per cluster, and report EVC status
# Prerequisite: VMware.PowerCLI module installed (v12.x or newer)
# ---------------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string] $vCenter = "vcenter.mycompany.local",

    # Either supply a PSCredential or supply UserName/Password
    [Parameter(Mandatory=$false)]
    [PSCredential] $Credential,

    [Parameter(Mandatory=$false)]
    [string] $UserName,

    [Parameter(Mandatory=$false)]
    [string] $Password,

    [Parameter(Mandatory=$false)]
    [string] $CsvOutput = "$PSScriptRoot\EVC_VMs_Report.csv",

    [Parameter(Mandatory=$false)]
    [string] $LogFile = "$PSScriptRoot\EVC_VMs_Report.log",

    [Parameter(Mandatory=$false)]
    [switch] $SkipCsvExport
)

function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string] $Message,
        [Parameter(Mandatory=$false)][ValidateSet("INFO","WARNING","ERROR")][string] $Level = "INFO"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$Level] $Message"
    switch ($Level) {
        "INFO"    { Write-Host $entry -ForegroundColor Cyan }
        "WARNING" { Write-Host $entry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $entry -ForegroundColor Red }
    }
    Add-Content -Path $LogFile -Value $entry
}

# --- Initialization & Logging ---
if (-not (Test-Path $LogFile)) { New-Item -Path $LogFile -ItemType File -Force | Out-Null }
Write-Log "Script started"
Write-Log "vCenter: $vCenter"
Write-Log "CSV Output: $($SkipCsvExport ? 'Disabled' : $CsvOutput)"
Write-Log "Log File: $LogFile"

# --- Credential Handling ---
if (-not $Credential) {
    if ($UserName -and $Password) {
        Write-Log "Building PSCredential from UserName/Password"
        try {
            $securePwd = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($UserName, $securePwd)
        }
        catch {
            Write-Log "Failed to create PSCredential: $_" -Level "ERROR"
            throw
        }
    }
    else {
        Write-Log "Prompting for credentials"
        $Credential = Get-Credential -Message "Enter vCenter credentials"
    }
}
else {
    Write-Log "Using supplied PSCredential"
}

# --- Connect to vCenter ---
Write-Log "Connecting to vCenter [$vCenter]..."
try {
    Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop | Out-Null
    Write-Log "Connected successfully"
}
catch {
    Write-Log "Connection failed: $_" -Level "ERROR"
    throw
}

# --- Retrieve Clusters ---
Write-Log "Retrieving clusters..."
try {
    $clusters = Get-Cluster
    Write-Log "Found $($clusters.Count) clusters"
}
catch {
    Write-Log "Error getting clusters: $_" -Level "ERROR"
    throw
}

# --- Build Report ---
Write-Log "Gathering VM/EVC info..."
$report = foreach ($cluster in $clusters) {
    $mode       = $cluster.EVCMode
    $enabled    = if ($mode -and $mode -ne 'None') { $true } else { $false }
    Write-Log "Cluster '$($cluster.Name)': EVC Enabled = $enabled; Baseline = $mode"

    try {
        $vms = Get-Cluster -Name $cluster.Name | Get-VM
        foreach ($vm in $vms) {
            [PSCustomObject]@{
                ClusterName   = $cluster.Name
                VMName        = $vm.Name
                PowerState    = $vm.PowerState
                EVC_Enabled   = $enabled
                EVC_Baseline  = if ($enabled) { $mode } else { "" }
            }
        }
    }
    catch {
        Write-Log "Failed to enumerate VMs in $($cluster.Name): $_" -Level "WARNING"
    }
}

# --- Display & Export ---
Write-Log "Displaying report to console"
$report | Sort-Object ClusterName, VMName | Format-Table -AutoSize

if (-not $SkipCsvExport) {
    Write-Log "Exporting to CSV: $CsvOutput"
    try {
        $report | Export-Csv -Path $CsvOutput -NoTypeInformation -Encoding UTF8
        Write-Log "CSV export complete"
    }
    catch {
        Write-Log "CSV export failed: $_" -Level "ERROR"
    }
}

# --- Summary ---
$totalVMs      = $report.Count
$vmsWithEVC    = ($report | Where-Object { $_.EVC_Enabled }).Count
$vmsWithoutEVC = $totalVMs - $vmsWithEVC
Write-Log "Summary: Total VMs = $totalVMs; With EVC = $vmsWithEVC; Without EVC = $vmsWithoutEVC"

# --- Cleanup ---
Write-Log "Disconnecting from vCenter"
Disconnect-VIServer -Server $vCenter -Confirm:$false | Out-Null
Write-Log "Disconnected; script complete"
