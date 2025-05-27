<#
.SYNOPSIS
    Imports resource pools into a vSphere cluster with scalable, expandable, and unlimited settings.
.DESCRIPTION
    Reads a JSON file describing resource pools and creates them in the specified cluster.
    All new resource pools are set to:
      - CPU/Memory Shares: Normal
      - CPU/Memory Reservation: Unlimited (0)
      - CPU/Memory Limit: Unlimited (0)
      - CPU/Memory Expandable Reservation: Enabled
    No permissions are applied.
    All actions and errors are logged.
.PARAMETER DestVC
    The destination vCenter server.
.PARAMETER DestCred
    PSCredential for the destination vCenter.
.PARAMETER InputJson
    Path to the JSON file describing resource pools.
.PARAMETER TargetCluster
    Name of the cluster in which to create the resource pools.
.PARAMETER LogPath
    Path to the log file (default: .\Import-ResourcePools.log).
.EXAMPLE
    .\Import-ResourcePools.ps1 -DestVC vcsa.lab.local -DestCred (Get-Credential) -InputJson .\pools.json -TargetCluster "Cluster-A"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DestVC,

    [Parameter(Mandatory = $true)]
    [PSCredential]$DestCred,

    [Parameter(Mandatory = $true)]
    [string]$InputJson,

    [Parameter(Mandatory = $true)]
    
    [string]$TargetCluster,
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = ".\ResourcePoolMigration_$(Get-Date -Format 'yyyyMMdd_HHmmss').html",


    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\Import-ResourcePools.log"
)

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logLine = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $logLine
    switch ($Level) {
        'INFO'  { Write-Host $logLine }
        'WARN'  { Write-Host $logLine -ForegroundColor Yellow }
        'ERROR' { Write-Host $logLine -ForegroundColor Red }
    }
}

# Start log
if (Test-Path -Path $LogPath) {
    Remove-Item -Path $LogPath -Force
}
Write-Log -Message "Script started. Target vCenter: '$DestVC', Target Cluster: '$TargetCluster'"

try {
    Import-Module VMware.PowerCLI -ErrorAction Stop
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    Write-Log -Message "VMware.PowerCLI module imported."
}
catch {
    $errMsg = $_.Exception.Message
    Write-Log -Message "Failed to import VMware.PowerCLI: $errMsg" -Level 'ERROR'
    throw
}

try {
    $null = Connect-VIServer -Server $DestVC -Credential $DestCred -ErrorAction Stop
    Write-Log -Message "Connected to vCenter '$DestVC'."
}
catch {
    $errMsg = $_.Exception.Message
    Write-Log -Message "Failed to connect to vCenter '$DestVC': $errMsg" -Level 'ERROR'
    throw
}

try {
    $cluster = Get-Cluster -Name $TargetCluster -ErrorAction Stop
    Write-Log -Message "Found target cluster: '$TargetCluster'."
}
catch {
    $errMsg = $_.Exception.Message
    Write-Log -Message "Target cluster '$TargetCluster' not found: $errMsg" -Level 'ERROR'
    Disconnect-VIServer -Server $DestVC -Confirm:$false | Out-Null
    throw
}

if (-not (Test-Path -Path $InputJson)) {
    Write-Log -Message "Input JSON file not found: '$InputJson'" -Level 'ERROR'
    Disconnect-VIServer -Server $DestVC -Confirm:$false | Out-Null
    throw "Input JSON file not found."
}

try {
    $configs = Get-Content -Path $InputJson -Raw | ConvertFrom-Json
    if ($null -eq $configs) {
        Write-Log -Message "No resource pool definitions found in JSON." -Level 'ERROR'
        Disconnect-VIServer -Server $DestVC -Confirm:$false | Out-Null
        throw "No resource pool definitions found."
    }
    Write-Log -Message "Found $($configs.Count) resource pool definitions in JSON."
}
catch {
    $errMsg = $_.Exception.Message
    Write-Log -Message "Failed to parse JSON file: $errMsg" -Level 'ERROR'
    Disconnect-VIServer -Server $DestVC -Confirm:$false | Out-Null
    throw
}

$created = @()
$failed = @()

foreach ($c in $configs) {
    try {
        Write-Log -Message "Creating pool '$($c.Name)' under cluster '$($cluster.Name)'."
        $newPool = New-ResourcePool -Name $c.Name `
            -Location $cluster `
            -CpuSharesLevel 'Normal' `
            -MemSharesLevel 'Normal' `
            -CpuReservationMHz 0 `
            -MemReservationMB 0 `
            -CpuLimitMHz 0 `
            -MemLimitMB 0 `
            -CpuExpandableReservation $true `
            -MemExpandableReservation $true `
            -ErrorAction Stop
        $created += $c.Name
        Write-Log -Message "Successfully created pool '$($c.Name)'."
    }
    catch {
        $errMsg = $_.Exception.Message
        $failed += $c.Name
        Write-Log -Message "FAILED to create pool '$($c.Name)': $errMsg" -Level 'ERROR'
    }
}

try {
    Disconnect-VIServer -Server $DestVC -Confirm:$false | Out-Null
    Write-Log -Message "Disconnected from vCenter."
}
catch {
    $errMsg = $_.Exception.Message
    Write-Log -Message "Error disconnecting from vCenter: $errMsg" -Level 'WARN'
}

Write-Log -Message "=== IMPORT SUMMARY ==="
Write-Log -Message ("Created: {0} pools: {1}" -f $created.Count, ($created -join ', '))
if ($failed.Count -gt 0) {
    Write-Log -Message ("Failed:  {0} pools: {1}" -f $failed.Count, ($failed -join ', ')) -Level 'ERROR'
} else {
    Write-Log -Message "Failed:  0 pools"
}

Write-Host "`n=== IMPORT SUMMARY ===" -ForegroundColor Cyan
Write-Host "Created: $($created.Count) pools: $($created -join ', ')" -ForegroundColor Green
if ($failed.Count -gt 0) {
    Write-Host "Failed:  $($failed.Count) pools: $($failed -join ', ')" -ForegroundColor Red
} else {
    Write-Host "Failed:  0 pools" -ForegroundColor Green
}

Write-Log -Message "Script finished."
