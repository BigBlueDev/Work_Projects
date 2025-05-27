# Requires VMware PowerCLI module
# This script loops through a DataTable of tag categories and tags,
# creates missing categories and tags, verifies creation,
# and assigns roles and security groups to each tag.
# Includes error checking and terminal output.

# Sample DataTable structure assumed:
# Columns: TagCategory, TagName, RoleName, SecurityGroupName
# You should replace this with your actual DataTable source.

# Example DataTable creation (for testing):
$dt = New-Object System.Data.DataTable
$dt.Columns.Add("TagCategory") | Out-Null
$dt.Columns.Add("TagName") | Out-Null
$dt.Columns.Add("RoleName") | Out-Null
$dt.Columns.Add("SecurityGroupName") | Out-Null
$row = $dt.NewRow()
$row.TagCategory = "App-team"
$row.TagName = "Production"
$row.RoleName = "VM Administrator"
$row.SecurityGroupName = "VMwareAdmins"
$dt.Rows.Add($row)

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# Connect to vCenter before running this script
# Connect-VIServer -Server your_vcenter_server

# Validate PowerCLI module loaded
if (-not (Get-Module -Name VMware.PowerCLI)) {
    Write-Log "VMware.PowerCLI module is not loaded. Please load it before running this script." "ERROR"
    exit 1
}

# Validate DataTable input
param (
    [Parameter(Mandatory)]
    [System.Data.DataTable]$TagDataTable
)

# Helper function to check if a tag category exists
function Get-TagCategoryIfExists {
    param (
        [string]$CategoryName
    )
    try {
        $cat = Get-TagCategory -Name $CategoryName -ErrorAction Stop
        return $cat
    }
    catch {
        return $null
    }
}

# Helper function to check if a tag exists in a category
function Get-TagIfExists {
    param (
        [string]$TagName,
        [string]$CategoryName
    )
    try {
        $tag = Get-Tag -Name $TagName -Category $CategoryName -ErrorAction Stop
        return $tag
    }
    catch {
        return $null
    }
}

# Helper function to assign role and security group to a tag
function Assign-RoleAndGroupToTag {
    param (
        [VMware.VimAutomation.ViCore.Impl.V1.Tagging.TagImpl]$Tag,
        [string]$RoleName,
        [string]$SecurityGroupName
    )

    # Validate Role
    $role = Get-VIRole -Name $RoleName -ErrorAction SilentlyContinue
    if (-not $role) {
        Write-Log "Role '$RoleName' does not exist. Skipping assignment for tag '$($Tag.Name)'." "WARNING"
        return
    }

    # Validate Security Group
    # Security groups are usually AD groups or local groups on vCenter.
    # We can check local groups via Get-VMHostAccount or AD groups via AD cmdlets if available.
    # Here, we will just check if the group string is non-empty.
    if ([string]::IsNullOrWhiteSpace($SecurityGroupName)) {
        Write-Log "Security group name is empty for tag '$($Tag.Name)'. Skipping assignment." "WARNING"
        return
    }

    # Assign permissions
    # Permissions are assigned to objects. Tags themselves are not objects you can assign permissions on.
    # Usually, permissions are assigned on vCenter inventory objects.
    # However, you can assign permissions on the Tag Category or Tag objects via the vSphere API.
    # PowerCLI does not directly support assigning permissions on tags.
    # As a workaround, we assign permissions on the Tag Category object.

    try {
        # Get the Tag Category object reference
        $category = Get-TagCategory -Id $Tag.CategoryId -ErrorAction Stop

        # Check if permission already exists for this principal and role on the category
        $existingPerms = Get-VIPermission -Entity $category | Where-Object {
            $_.Principal -eq $SecurityGroupName -and $_.Role -eq $RoleName
        }

        if ($existingPerms) {
            Write-Log "Permission for '$SecurityGroupName' with role '$RoleName' already exists on category '$($category.Name)'." "INFO"
        }
        else {
            # Assign permission
            New-VIPermission -Entity $category -Principal $SecurityGroupName -Role $RoleName -Propagate $false -ErrorAction Stop
            Write-Log "Assigned role '$RoleName' to security group '$SecurityGroupName' on category '$($category.Name)'." "INFO"
        }
    }
    catch {
        Write-Log "Failed to assign role '$RoleName' to security group '$SecurityGroupName' on tag category '$($Tag.CategoryName)': $_" "ERROR"
    }
}

# Main processing loop
foreach ($row in $TagDataTable.Rows) {
    $categoryName = $row.TagCategory
    $tagName = $row.TagName
    $roleName = $row.RoleName
    $securityGroupName = $row.SecurityGroupName

    if ([string]::IsNullOrWhiteSpace($categoryName)) {
        Write-Log "TagCategory is empty in row, skipping." "WARNING"
        continue
    }
    if ([string]::IsNullOrWhiteSpace($tagName)) {
        Write-Log "TagName is empty in row for category '$categoryName', skipping." "WARNING"
        continue
    }

    Write-Log "Processing category '$categoryName' and tag '$tagName'."

    # Check if category exists
    $category = Get-TagCategoryIfExists -CategoryName $categoryName
    if (-not $category) {
        Write-Log "Category '$categoryName' does not exist. Creating..."
        try {
            $category = New-TagCategory -Name $categoryName -Cardinality Single -EntityType VirtualMachine -ErrorAction Stop
            Write-Log "Category '$categoryName' created successfully."
        }
        catch {
            Write-Log "Failed to create category '$categoryName': $_" "ERROR"
            continue
        }
    }
    else {
        Write-Log "Category '$categoryName' already exists."
    }

    # Check if tag exists
    $tag = Get-TagIfExists -TagName $tagName -CategoryName $categoryName
    if (-not $tag) {
        Write-Log "Tag '$tagName' does not exist in category '$categoryName'. Creating..."
        try {
            $tag = New-Tag -Name $tagName -Category $category -ErrorAction Stop
            Write-Log "Tag '$tagName' created successfully in category '$categoryName'."
        }
        catch {
            Write-Log "Failed to create tag '$tagName' in category '$categoryName': $_" "ERROR"
            continue
        }
    }
    else {
        Write-Log "Tag '$tagName' already exists in category '$categoryName'."
    }

    # Verify tag creation
    $verifyTag = Get-TagIfExists -TagName $tagName -CategoryName $categoryName
    if (-not $verifyTag) {
        Write-Log "Verification failed: Tag '$tagName' does not exist after creation attempt." "ERROR"
        continue
    }
    else {
        Write-Log "Verified tag '$tagName' exists."
    }

    # Assign role and security group to tag (actually to category as explained)
    Assign-RoleAndGroupToTag -Tag $verifyTag -RoleName $roleName -SecurityGroupName $securityGroupName
}

Write-Log "Script completed."