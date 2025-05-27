<#
.SYNOPSIS
    PowerCLI 13+ script to automate vCenter VM tagging and permission assignment.
    Creates missing tag categories, tags, roles (cloned from "Support Admin Template"),
    SSO groups (using VMware.vSphere.SsoAdmin 1.4+ module),
    assigns permissions to VMs with those tags.
    Also tags Domain Controller VMs, tags VMs by OS based on GuestFullName,
    handles VMs missing guest info by tagging "NO OS",
    optionally checks PSC replication health before proceeding,
    and logs all actions to CSV.

.PARAMETER vCenterServer
    The FQDN or IP of the vCenter server.

.PARAMETER ExcelFilePath
    Path to the Excel file with tagging/permission data.

.PARAMETER Credential
    Credential to connect to vCenter and SSO.

.PARAMETER Environment
    Environment prefix used in tag category names. Defaults to "DEV".
    Not case sensitive.

.PARAMETER CheckPSCReplication
    Switch to enable PSC replication health check before proceeding.

.EXAMPLE
    .\TagPermissions.ps1 -vCenterServer vcenter.example.com -ExcelFilePath .\tags.xlsx -Credential (Get-Credential) -Environment PROD -CheckPSCReplication

#>

param(
    [Parameter(Mandatory=$true)]
    [string]$vCenterServer,

    [Parameter(Mandatory=$true)]
    [string]$ExcelFilePath,

    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory=$false)]
    [ValidateSet("DEV","IOT","PROD", IgnoreCase = $true)]
    [string]$Environment = "DEV",

    [Parameter(Mandatory=$false)]
    [switch]$CheckPSCReplication,

    [Parameter(Mandatory=$false)]
    [switch]$VerboseLogging
)

# Normalize Environment parameter to uppercase for consistent naming
$Environment = $Environment.ToUpper()

# Tag category names based on environment
$OsCategoryName = "vCenter-$Environment-OS"
$FunctionCategoryName = "vCenter-$Environment-Function"

$outputLog = [System.Collections.Generic.List[PSObject]]::new()

#region Logging Functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $timestampLog = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = [PSCustomObject]@{
        Timestamp = $timestampLog
        Level     = $Level
        Message   = $Message
    }
    if ($Level -eq "ERROR" -or $VerboseLogging) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            default { "White" }
        }
        Write-Host "$timestampLog [$Level] $Message" -ForegroundColor $color
    }
    $outputLog.Add($logEntry)
}

#endregion

#region PSC Replication Functions
function Test-VCenterPSCReplicationStatus {
    param(
        [string]$vCenterServer
    )
    Write-Log "Checking vCenter PSC replication status via REST API..."

    $baseUri = "https://$vCenterServer/rest"

    # Safer SSL certificate handling with warning
    Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    Write-Log "WARNING: SSL certificate validation is bypassed. This is not recommended for production." "WARN"

    try {
        $sessionResponse = Invoke-RestMethod -Uri "$baseUri/com/vmware/cis/session" -Method Post -ErrorAction Stop
        $sessionId = $sessionResponse.value
        if (-not $sessionId) {
            Write-Log "Failed to obtain REST session ID." "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Failed to create REST session: $_" "ERROR"
        return $false
    }

    $headers = @{ "vmware-api-session-id" = $sessionId }

    try {
        $replicationStatus = Invoke-RestMethod -Uri "$baseUri/vcenter/psc/replication/status" -Method Get -Headers $headers -ErrorAction Stop
    }
    catch {
        Write-Log "PSC replication status endpoint not available or error: $_" "WARN"
        Write-Log "Assuming no PSC replication or not applicable. Continuing."
        return $true
    }

    $allOk = $true
    foreach ($partner in $replicationStatus.value) {
        $partnerName = $partner.partner
        $status = $partner.status
        Write-Log "Replication partner '$partnerName' status: $status"
        if ($status -ne "OK") {
            $allOk = $false
        }
    }

    if (-not $allOk) {
        Write-Log "One or more PSC replication partners have non-OK status." "ERROR"
        return $false
    }

    Write-Log "PSC replication status is OK."
    return $true
}
#endregion

# Input validation for Excel file
if (-not (Test-Path -Path $ExcelFilePath -PathType Leaf)) {
    Write-Error "Excel file not found at path: $ExcelFilePath"
    exit 1
}

if ((Get-Item $ExcelFilePath).Length -eq 0) {
    Write-Error "Excel file is empty: $ExcelFilePath"
    exit 1
}
#region Tag Functions

function Get-TagCategoryIfExists {
    param([string]$Name)
    try {
        # Case-insensitive search for tag category
        $allCategories = Get-TagCategory -ErrorAction Stop
        return $allCategories | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
    }
    catch {
        Write-Log "Error retrieving tag categories: $_" "ERROR"
        return $null
    }
}

function Ensure-TagCategory {
    param([string]$CategoryName)

    $category = Get-TagCategoryIfExists -Name $CategoryName
    if ($category) {
        Write-Log "Tag category '$CategoryName' already exists."
        return $category
    }

    try {
        $category = New-TagCategory -Name $CategoryName -Cardinality Multiple -EntityType All -Description "Category for $CategoryName tags" -ErrorAction Stop
        Write-Log "Created tag category '$CategoryName'."
        return $category
    }
    catch {
        if ($_.Exception.Message -match "already exists") {
            Write-Log "Tag category '$CategoryName' already exists (caught during creation)."
            return Get-TagCategoryIfExists -Name $CategoryName
        }
        else {
            Write-Log "Failed to create tag category '$CategoryName': $_" "ERROR"
            return $null
        }
    }
}

function Get-TagIfExists {
    param(
        [string]$TagName,
        [string]$CategoryName
    )
    $category = Get-TagCategoryIfExists -Name $CategoryName
    if (-not $category) { return $null }
    try {
        $allTags = Get-Tag -Category $category -ErrorAction Stop
        return $allTags | Where-Object { $_.Name -ieq $TagName } | Select-Object -First 1
    }
    catch {
        Write-Log "Error retrieving tags from category '$CategoryName': $_" "ERROR"
        return $null
    }
}

function Ensure-Tag {
    param(
        [string]$TagName,
        $Category
    )

    $tag = Get-TagIfExists -TagName $TagName -CategoryName $Category.Name
    if ($tag) {
        Write-Log "Tag '$TagName' in category '$($Category.Name)' already exists."
        return $tag
    }

    try {
        $categoryFresh = Get-TagCategoryIfExists -Name $Category.Name
        Write-Log "Creating tag '$TagName' in category '$($categoryFresh.Name)'."
        $tag = New-Tag -Name $TagName -Category $categoryFresh -Description "Tag for $TagName" -ErrorAction Stop
        Write-Log "Created tag '$TagName' in category '$($categoryFresh.Name)'."
        return $tag
    }
    catch {
        if ($_.Exception.Message -match "already exists") {
            Write-Log "Tag '$TagName' in category '$($Category.Name)' already exists (caught during creation)."
            return Get-TagIfExists -TagName $TagName -CategoryName $Category.Name
        }
        else {
            Write-Log "Failed to create tag '$TagName' in category '$($Category.Name)': $_" "ERROR"
            return $null
        }
    }
}

#endregion

#region Role Functions

function Get-RoleIfExists {
    param([string]$RoleName)
    try {
        return Get-VIRole -Name $RoleName -ErrorAction Stop
    }
    catch {
        Write-Log "Role '$RoleName' does not exist or cannot be retrieved: $_" "WARN"
        return $null
    }
}

function Clone-RoleFromSupportAdminTemplate {
    param([string]$NewRoleName)

    $templateRole = Get-RoleIfExists -RoleName "Support Admin Template"
    if (-not $templateRole) {
        Write-Log "Support Admin Template role not found. Cannot clone role '$NewRoleName'." "ERROR"
        return $null
    }

    try {
        New-VIRole -Name $NewRoleName -Privilege $templateRole.Privileges -Description "Cloned from Support Admin Template" -ErrorAction Stop | Out-Null
        Write-Log "Created new role '$NewRoleName' cloned from 'Support Admin Template'."
        return Get-RoleIfExists -RoleName $NewRoleName
    }
    catch {
        Write-Log "Failed to create role '$NewRoleName': $_" "ERROR"
        return $null
    }
}

#endregion

#region Permission Functions

function Assign-PermissionIfNeeded {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $VM,

        [Parameter(Mandatory=$true)]
        [string]$Principal,

        [Parameter(Mandatory=$true)]
        [string]$RoleName
    )

    try {
        $existingPerm = Get-VIPermission -Entity $VM -Principal $Principal -ErrorAction Stop | Where-Object { $_.Role -eq $RoleName }
    }
    catch {
        Write-Log "Failed to query existing permissions on VM '$($VM.Name)': $_" "ERROR"
        $existingPerm = $null
    }

    if ($existingPerm) {
        Write-Log "Permission for principal '$Principal' with role '$RoleName' already assigned on VM '$($VM.Name)'. Skipping."
        return
    }

    try {
        New-VIPermission -Entity $VM -Principal $Principal -Role $RoleName -Propagate $false -ErrorAction Stop
        Write-Log "Assigned role '$RoleName' to principal '$Principal' on VM '$($VM.Name)'."
    }
    catch {
        Write-Log "Failed to assign permission on VM '$($VM.Name)': $_" "ERROR"
    }
}

#endregion

#region SSO Functions

function Ensure-SsoGroupExists {
    param(
        [string]$Domain,
        [string]$GroupName
    )

    try {
        $existingGroup = Get-SsoGroup -Domain $Domain -Name $GroupName -ErrorAction Stop
        if ($existingGroup) {
            Write-Log "SSO group '$Domain\$GroupName' already exists."
            return $true
        }
    }
    catch {
        # Proceed to create group if not found
    }

    try {
        New-SsoGroup -Name $GroupName -Description "Created by automation script" -ErrorAction Stop
        Write-Log "Created SSO group '$GroupName' (domain: '$Domain' not passed to New-SsoGroup)."
        return $true
    }
    catch [VMware.VimAutomation.SsoAdmin.Types.SsoAdminServerException] {
        Write-Log "SSO Admin Server error creating group '$GroupName': $_" "ERROR"
        return $false
    }
    catch {
        Write-Log "Unexpected error creating SSO group '$GroupName': $_" "ERROR"
        return $false
    }
}

#endregion
#region Excel Import Functions

function Import-ExcelCOM {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $excel = $null
    $workbook = $null
    $sheet = $null
    $data = @()

    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false

        $workbook = $excel.Workbooks.Open((Resolve-Path $Path).Path)

        $sheet = $workbook.Worksheets.Item(1)

        $usedRange = $sheet.UsedRange
        $rowCount = $usedRange.Rows.Count
        $colCount = $usedRange.Columns.Count

        $headers = @()
        for ($c = 1; $c -le $colCount; $c++) {
            $val = $sheet.Cells.Item(1, $c).Text
            if ([string]::IsNullOrWhiteSpace($val)) {
                $headers += "Column$c"
            }
            else {
                $headers += $val.Trim()
            }
        }

        for ($r = 2; $r -le $rowCount; $r++) {
            $rowObj = [PSCustomObject]@{}
            for ($c = 1; $c -le $colCount; $c++) {
                $cellValue = $sheet.Cells.Item($r, $c).Text
                $propName = $headers[$c - 1] -replace '\s+', '_'
                Add-Member -InputObject $rowObj -NotePropertyName $propName -NotePropertyValue $cellValue
            }
            $data += $rowObj
        }

        return $data
    }
    catch {
        Write-Log "Failed to read Excel file via COM: $_" "ERROR"
        throw
    }
    finally {
        if ($workbook) { $workbook.Close($false) }
        if ($excel) {
            $excel.Quit()
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

function Get-ValueNormalized {
    param(
        [psobject]$Row,
        [string]$ColumnName
    )
    $normalizedCol = $ColumnName.ToLower().Replace("_","").Replace(" ","")
    foreach ($prop in $Row.psobject.Properties) {
        $propNameNorm = $prop.Name.ToLower().Replace("_","").Replace(" ","")
        if ($propNameNorm -eq $normalizedCol) {
            return $prop.Value
        }
    }
    return $null
}
#endregion

# ------------------- MAIN SCRIPT -------------------

try {
    # Import VMware.vSphere.SsoAdmin module for SSO group management (version 1.4+ recommended)
    # Import-Module VMware.vSphere.SsoAdmin -ErrorAction Stop

    try {
        Write-Log "Connecting to vCenter server '$vCenterServer'..."
        Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
        Write-Log "Connected to vCenter server '$vCenterServer'."
    }
    catch {
        Write-Log "Failed to connect to vCenter server '$vCenterServer': $_" "ERROR"
        exit 1
    }

    try {
        Write-Log "Connecting to vCenter SSO for group management..."
        Connect-SsoAdminServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
        Write-Log "Connected to vCenter SSO."
    }
    catch {
        Write-Log "Failed to connect to vCenter SSO server '$vCenterServer': $_" "ERROR"
        Disconnect-VIServer -Server $vCenterServer -Confirm:$false -ErrorAction SilentlyContinue
        exit 1
    }

    if ($CheckPSCReplication) {
        if (-not (Test-VCenterPSCReplicationStatus -vCenterServer $vCenterServer)) {
            Write-Log "vCenter PSC replication status is not OK. Aborting script." "ERROR"
            Disconnect-SsoAdminServer -ErrorAction SilentlyContinue
            Disconnect-VIServer -Server $vCenterServer -Confirm:$false -ErrorAction SilentlyContinue
            exit 1
        }
    }
    else {
        Write-Log "PSC replication check skipped (parameter -CheckPSCReplication not specified)."
    }

    Write-Log "Importing Excel data from '$ExcelFilePath'..."
    $excelData = Import-ExcelCOM -Path $ExcelFilePath

    if (-not $excelData -or $excelData.Count -eq 0) {
        Write-Log "Excel file is empty or unreadable." "ERROR"
        throw "Empty or unreadable Excel file"
    }

    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $scriptDir) { $scriptDir = Get-Location }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputLogPath = Join-Path -Path $scriptDir -ChildPath ("TagPermissionsOutput_{0}.csv" -f $timestamp)

    # Cache all VMs upfront to improve performance
    try {
        $allVMs = Get-VM -ErrorAction Stop | Where-Object { $_.Name -notmatch '^(vCLS|VLC)' }
        Write-Log "Retrieved $($allVMs.Count) VMs (excluding vCLS and VLC VMs)."
    }
    catch {
        Write-Log "Failed to retrieve VMs: $_" "ERROR"
        $allVMs = @()
    }

    # Process Excel rows: create categories, tags, assign permissions on VMs with those tags
    foreach ($row in $excelData) {
        $tagCategoryName = Get-ValueNormalized -Row $row -ColumnName "TagCategory"
        $tagName = Get-ValueNormalized -Row $row -ColumnName "TagName"
        $roleName = Get-ValueNormalized -Row $row -ColumnName "RoleName"
        $securityGroupDomain = Get-ValueNormalized -Row $row -ColumnName "SecurityGroupDomain"
        $securityGroupName = Get-ValueNormalized -Row $row -ColumnName "SecurityGroupName"

        if ([string]::IsNullOrWhiteSpace($tagCategoryName) -or
            [string]::IsNullOrWhiteSpace($tagName) -or
            [string]::IsNullOrWhiteSpace($roleName) -or
            [string]::IsNullOrWhiteSpace($securityGroupDomain) -or
            [string]::IsNullOrWhiteSpace($securityGroupName)) {
            Write-Log "Skipping row with missing required data: TagCategory='$tagCategoryName', TagName='$tagName', RoleName='$roleName', SecurityGroupDomain='$securityGroupDomain', SecurityGroupName='$securityGroupName'" "WARN"
            continue
        }

        $category = Ensure-TagCategory -CategoryName $tagCategoryName
        if (-not $category) {
            Write-Log "Skipping row due to failure creating or getting category '$tagCategoryName'." "ERROR"
            continue
        }

        $tag = Ensure-Tag -TagName $tagName -Category $category
        if (-not $tag) {
            Write-Log "Skipping row due to failure creating or getting tag '$tagName'." "ERROR"
            continue
        }

        try {
            $vmsWithTag = Get-VM -Tag $tag -ErrorAction Stop | Where-Object { $_.Name -notmatch '^(vCLS|VLC)' }
        }
        catch {
            Write-Log "Failed to retrieve VMs with tag '$($tag.Name)': $_" "ERROR"
            $vmsWithTag = @()
        }

        $role = Get-RoleIfExists -RoleName $roleName
        if (-not $role) {
            Write-Log "Role '$roleName' does not exist. Attempting to create by cloning 'Support Admin Template'."
            $role = Clone-RoleFromSupportAdminTemplate -NewRoleName $roleName
            if (-not $role) {
                Write-Log "Skipping permission assignment for role '$roleName' due to role creation failure." "ERROR"
                continue
            }
        }

        foreach ($vm in $vmsWithTag) {
            if (-not (Ensure-SsoGroupExists -Domain $securityGroupDomain -GroupName $securityGroupName)) {
                Write-Log "Failed to ensure SSO group '$securityGroupDomain\$securityGroupName' exists. Skipping permission assignment on VM '$($vm.Name)'." "ERROR"
                continue
            }
            $principal = "$securityGroupDomain\$securityGroupName"
            Assign-PermissionIfNeeded -VM $vm -Principal $principal -RoleName $role.Name
        }
    }

    # Domain Controller VMs special tagging and permissions
    Write-Log "Processing Domain Controller VMs in category '$FunctionCategoryName'."
    $functionCategory = Get-TagCategoryIfExists -Name $FunctionCategoryName
    if (-not $functionCategory) {
        Write-Log "Function category '$FunctionCategoryName' not found. Skipping Domain Controller processing." "WARN"
    }
    else {
        $domainControllerTag = Get-TagIfExists -TagName "Domain Controller" -CategoryName $FunctionCategoryName
        if (-not $domainControllerTag) {
            Write-Log "'Domain Controller' tag not found in category '$FunctionCategoryName'. Skipping Domain Controller processing." "WARN"
        }
        else {
            try {
                $dcVMs = Get-VM -Tag $domainControllerTag -ErrorAction Stop | Where-Object { $_.Name -notmatch '^(vCLS|VLC)' }
                Write-Log "Found $($dcVMs.Count) Domain Controller VMs (excluding vCLS/VLC)."
            }
            catch {
                Write-Log "Failed to retrieve Domain Controller VMs: $_" "ERROR"
                $dcVMs = @()
            }

            if ($dcVMs.Count -gt 0) {
                $dcTagsFromExcel = $excelData | Where-Object {
                    $t = Get-ValueNormalized -Row $_ -ColumnName "TagName"
                    $t -and ($t -imatch "domain-controller")
                } | Select-Object -Unique

                foreach ($row in $dcTagsFromExcel) {
                    $dcTagName = Get-ValueNormalized -Row $row -ColumnName "TagName"
                    $dcTagCategoryName = Get-ValueNormalized -Row $row -ColumnName "TagCategory"
                    $dcRoleName = Get-ValueNormalized -Row $row -ColumnName "RoleName"
                    $dcSecurityGroupDomain = Get-ValueNormalized -Row $row -ColumnName "SecurityGroupDomain"
                    $dcSecurityGroupName = Get-ValueNormalized -Row $row -ColumnName "SecurityGroupName"

                    if (-not $dcTagName -or -not $dcTagCategoryName) {
                        Write-Log "Skipping domain-controller Excel row with missing TagName or TagCategory." "WARN"
                        continue
                    }

                    $dcTagCategory = Ensure-TagCategory -CategoryName $dcTagCategoryName
                    if (-not $dcTagCategory) {
                        Write-Log "Failed to get or create tag category '$dcTagCategoryName' for domain-controller tag '$dcTagName'." "ERROR"
                        continue
                    }

                    $dcTag = Ensure-Tag -TagName $dcTagName -Category $dcTagCategory
                    if (-not $dcTag) {
                        Write-Log "Failed to get or create tag '$dcTagName' in category '$dcTagCategoryName'." "ERROR"
                        continue
                    }

                    foreach ($vm in $dcVMs) {
                        $existingTags = Get-TagAssignment -Entity $vm
                        if ($existingTags.Name -contains $dcTagName) {
                            Write-Log "VM '$($vm.Name)' already has tag '$dcTagName'."
                        }
                        else {
                            try {
                                New-TagAssignment -Entity $vm -Tag $dcTag -ErrorAction Stop
                                Write-Log "Tagged Domain Controller VM '$($vm.Name)' with tag '$dcTagName'."
                            }
                            catch {
                                Write-Log "Failed to tag VM '$($vm.Name)' with tag '$dcTagName': $_" "ERROR"
                            }
                        }
                    }

                    if (-not $dcRoleName -or -not $dcSecurityGroupDomain -or -not $dcSecurityGroupName) {
                        Write-Log "Skipping permission assignment for domain-controller tag '$dcTagName' due to missing RoleName or SecurityGroupDomain/Name." "WARN"
                        continue
                    }

                    $dcRole = Get-RoleIfExists -RoleName $dcRoleName
                    if (-not $dcRole) {
                        Write-Log "Role '$dcRoleName' does not exist. Attempting to create by cloning 'Support Admin Template'."
                        $dcRole = Clone-RoleFromSupportAdminTemplate -NewRoleName $dcRoleName
                        if (-not $dcRole) {
                            Write-Log "Skipping permission assignment for role '$dcRoleName' due to role creation failure." "ERROR"
                            continue
                        }
                    }

                    foreach ($vm in $dcVMs) {
                        if (-not (Ensure-SsoGroupExists -Domain $dcSecurityGroupDomain -GroupName $dcSecurityGroupName)) {
                            Write-Log "Failed to ensure SSO group '$dcSecurityGroupDomain\$dcSecurityGroupName' exists. Skipping permission assignment on VM '$($vm.Name)'." "ERROR"
                            continue
                        }
                        $principal = "$dcSecurityGroupDomain\$dcSecurityGroupName"
                        Assign-PermissionIfNeeded -VM $vm -Principal $principal -RoleName $dcRole.Name
                    }
                }
            }
            else {
                Write-Log "No Domain Controller VMs found to process."
            }
        }
    }

    # OS tagging based on guest OS
    $osCategory = Ensure-TagCategory -CategoryName $OsCategoryName
    if (-not $osCategory) {
        Write-Log "Failed to ensure OS category '$OsCategoryName'. Exiting." "ERROR"
        throw "OS category missing"
    }

    $osTagPatterns = @{
        "Windows-server"  = '(?i)(Windows Server|Windows_Server|WinSrv|Microsoft Windows Server)'
        "Redhat-linux"    = '(?i)(Red Hat Enterprise Linux|RedHat|RHEL)'
        "Ubuntu-linux"    = '(?i)(Ubuntu)'
        "Centos"          = '(?i)(CentOS)'
        "Debian-linux"    = '(?i)(Debian)'
        "Suse-linux"      = '(?i)(SUSE|SLES|opensuse|openSUSE)'
        "Unix-server"     = '(?i)(Unix|Solaris|AIX|HP-UX|bsd|FreeBSD|NetBSD|OpenBSD)'
        "Photon"          = '(?i)(Photon|VMware Photon OS)'
        "Windows-desktop" = '(?i)(Windows 10|Windows 11|Win10|Win11)'
    }

    # Tag by OS pattern
    foreach ($tagName in $osTagPatterns.Keys) {
        $pattern = $osTagPatterns[$tagName]
        $tag = Ensure-Tag -TagName $tagName -Category $osCategory
        if (-not $tag) { continue }

        foreach ($vm in $allVMs) {
            $guestFullName = ""
            $toolsStatus = $null
            if ($vm.ExtensionData -and $vm.ExtensionData.Guest) {
                $guestFullName = $vm.ExtensionData.Guest.GuestFullName
                $toolsStatus = $vm.ExtensionData.Guest.ToolsStatus
            }

            if ([string]::IsNullOrWhiteSpace($guestFullName) -or ($toolsStatus -notin @("toolsOk","toolsOld"))) {
                continue
            }

            if ($guestFullName -imatch $pattern) {
                $existingTags = Get-TagAssignment -Entity $vm
                if ($existingTags.Name -contains $tagName) { continue }
                try {
                    New-TagAssignment -Entity $vm -Tag $tag -ErrorAction Stop
                    Write-Log "Tagged VM '$($vm.Name)' with '$tagName'."
                }
                catch {
                    Write-Log "Failed to tag VM '$($vm.Name)' with '$tagName': $_" "ERROR"
                }
            }
        }
    }

    # Tag VMs with no guest OS info or bad VMware Tools as NO OS
    $noOsTagName = "NO OS"
    $noOsTag = Ensure-Tag -TagName $noOsTagName -Category $osCategory

    foreach ($vm in $allVMs) {
        $guestFullName = ""
        $toolsStatus = $null
        if ($vm.ExtensionData -and $vm.ExtensionData.Guest) {
            $guestFullName = $vm.ExtensionData.Guest.GuestFullName
            $toolsStatus = $vm.ExtensionData.Guest.ToolsStatus
        }

        if ([string]::IsNullOrWhiteSpace($guestFullName) -or ($toolsStatus -notin @("toolsOk","toolsOld"))) {
            $existingTags = Get-TagAssignment -Entity $vm
            if ($existingTags.Name -contains $noOsTagName) { continue }
            try {
                New-TagAssignment -Entity $vm -Tag $noOsTag -ErrorAction Stop
                Write-Log "Tagged VM '$($vm.Name)' with '$noOsTagName' due to missing guest OS info or VMware Tools not OK."
            }
            catch {
                Write-Log "Failed to tag VM '$($vm.Name)' with '$noOsTagName': $_" "ERROR"
            }
        }
    }
}
catch {
    Write-Log "An error occurred: $_" "ERROR"
}
finally {
    try {
        $outputLog | Export-Csv -Path $outputLogPath -NoTypeInformation -Encoding UTF8
        Write-Log "Exported log to '$outputLogPath'."
    }
    catch {
        Write-Log "Failed to export log to CSV: $_" "ERROR"
    }

    try {
        Disconnect-SsoAdminServer -ErrorAction SilentlyContinue
        Write-Log "Disconnected from vCenter SSO."
    }
    catch {
        Write-Log "Failed to disconnect from vCenter SSO: $_" "ERROR"
    }

    try {
        Disconnect-VIServer -Server $vCenterServer -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Disconnected from vCenter server '$vCenterServer'."
    }
    catch {
        Write-Log "Failed to disconnect from vCenter server '$vCenterServer': $_" "ERROR"
    }
}
