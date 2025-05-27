<#
.SYNOPSIS
    Connects to vCenter using PowerCLI v13 and reports on VMs using native key providers for TPM or disk encryption.
.DESCRIPTION
    This script connects to a specified vCenter server, collects information about VMs that use native key providers
    for TPM or disk encryption, and exports the results to a CSV file.
.PARAMETER vCenterServer
    The FQDN or IP address of the vCenter server to connect to.
.PARAMETER Credential
    PSCredential object containing credentials for vCenter authentication.
.PARAMETER OutputPath
    Path where the CSV report will be saved. If not specified, saves to Documents folder.
.PARAMETER IncludeAllVMs
    Switch to include all VMs in the report, even those without encryption.
.EXAMPLE
    .\Get-VMEncryptionReport.ps1 -vCenterServer vcenter.contoso.com -Credential (Get-Credential)
.EXAMPLE
    $cred = Get-Credential
    .\Get-VMEncryptionReport.ps1 -vCenterServer vcenter.contoso.com -Credential $cred -OutputPath C:\Reports\
.EXAMPLE
    $cred = Get-Credential
    $cred | .\Get-VMEncryptionReport.ps1 -vCenterServer vcenter.contoso.com
.NOTES
    Author: CodingFleet Assistant
    Requires: PowerCLI v13 or later
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$vCenterServer,
    
    [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
    [System.Management.Automation.PSCredential]$Credential,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeAllVMs
)

Begin {
    # Check if PowerCLI is installed and import the module
    if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
        Write-Host "VMware PowerCLI is not installed. Installing now..." -ForegroundColor Yellow
        Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force
    }

    # Import PowerCLI module
    Import-Module VMware.PowerCLI

    # Set PowerCLI configuration to ignore invalid certificates
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session | Out-Null
    
    # Set default output path if not specified
    if (-not $OutputPath) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $OutputPath = Join-Path -Path $env:USERPROFILE -ChildPath "Documents\VMEncryptionReport-$timestamp.csv"
    }
    else {
        # Check if path is a directory or file
        if (Test-Path -Path $OutputPath -PathType Container) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $OutputPath = Join-Path -Path $OutputPath -ChildPath "VMEncryptionReport-$timestamp.csv"
        }
    }
}

Process {
    # Initialize results array
    $results = @()
    
    # Connect to vCenter
    try {
        Write-Verbose "Connecting to vCenter server: $vCenterServer"
        $vCenterConnection = Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
        Write-Host "Successfully connected to $vCenterServer" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to vCenter: $_"
        return
    }
    
    # Get all VMs
    $allVMs = Get-VM
    $totalVMs = $allVMs.Count
    $currentVM = 0

    Write-Host "Collecting encryption information for $totalVMs VMs..." -ForegroundColor Cyan

    foreach ($vm in $allVMs) {
        $currentVM++
        Write-Progress -Activity "Analyzing VMs" -Status "Processing $vm ($currentVM of $totalVMs)" -PercentComplete (($currentVM / $totalVMs) * 100)
        
        # Get VM encryption info
        $vmView = $vm | Get-View
        $vmConfigInfo = $vmView.Config
        
        # Check for VM encryption
        $vmEncrypted = $vmConfigInfo.KeyId -ne $null
        $vmKeyProvider = if ($vmEncrypted) { $vmConfigInfo.KeyId.ProviderId.Id } else { "N/A" }
        
        # Check for vTPM
        $vTPMEnabled = $false
        $vTPMKeyProvider = "N/A"
        
        foreach ($device in $vmConfigInfo.Hardware.Device) {
            if ($device.DeviceInfo.Label -match "TPM") {
                $vTPMEnabled = $true
                # For vTPM, we need to check the VM's encryption key provider
                $vTPMKeyProvider = $vmKeyProvider
                break
            }
        }
        
        # Check for encrypted disks
        $encryptedDisks = @()
        $vm | Get-HardDisk | ForEach-Object {
            $diskView = $_ | Get-View
            if ($diskView.Backing.KeyId -ne $null) {
                $encryptedDisks += [PSCustomObject]@{
                    Name = $_.Name
                    KeyProvider = $diskView.Backing.KeyId.ProviderId.Id
                }
            }
        }
        
        # Skip VMs without encryption unless IncludeAllVMs is specified
        if (-not $IncludeAllVMs -and -not $vmEncrypted -and -not $vTPMEnabled -and $encryptedDisks.Count -eq 0) {
            continue
        }
        
        # Add to results
        $vmResult = [PSCustomObject]@{
            VMName = $vm.Name
            PowerState = $vm.PowerState
            VMEncrypted = $vmEncrypted
            VMKeyProvider = $vmKeyProvider
            vTPMEnabled = $vTPMEnabled
            vTPMKeyProvider = $vTPMKeyProvider
            EncryptedDisksCount = $encryptedDisks.Count
            EncryptedDisksDetails = if ($encryptedDisks.Count -gt 0) { ($encryptedDisks | ConvertTo-Json -Compress) } else { "N/A" }
            Cluster = $vm.VMHost.Parent.Name
            Datacenter = $vm.VMHost.Parent.Parent.Name
            VMHost = $vm.VMHost.Name
        }
        
        $results += $vmResult
    }

    # Export results to CSV
    if ($results.Count -gt 0) {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation
        
        # Display summary
        Write-Host "`nEncryption Report Summary:" -ForegroundColor Green
        Write-Host "Total VMs analyzed: $totalVMs" -ForegroundColor Cyan
        Write-Host "VMs included in report: $($results.Count)" -ForegroundColor Cyan
        Write-Host "VMs with VM-level encryption: $(($results | Where-Object { $_.VMEncrypted -eq $true }).Count)" -ForegroundColor Cyan
        Write-Host "VMs with vTPM enabled: $(($results | Where-Object { $_.vTPMEnabled -eq $true }).Count)" -ForegroundColor Cyan
        Write-Host "VMs with encrypted disks: $(($results | Where-Object { $_.EncryptedDisksCount -gt 0 }).Count)" -ForegroundColor Cyan
        
        Write-Host "`nReport exported to: $OutputPath" -ForegroundColor Green
    }
    else {
        Write-Warning "No VMs with encryption found. No report generated."
    }
    
    # Disconnect from vCenter
    Disconnect-VIServer -Server $vCenterServer -Confirm:$false
    Write-Host "Disconnected from vCenter server" -ForegroundColor Green
}
