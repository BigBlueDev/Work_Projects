# Requires VMware PowerCLI module
# Requires ImportExcel module: Install-Module -Name ImportExcel

# Import required modules
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Write-Host "VMware.PowerCLI module is not installed. Please install it before running this script." -ForegroundColor Red
    exit 1
}
Import-Module VMware.PowerCLI -ErrorAction Stop

if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "ImportExcel module is not installed. Install it using: Install-Module -Name ImportExcel" -ForegroundColor Red
    exit 1
}
Import-Module ImportExcel -ErrorAction Stop

# Path to your Excel file - update this path accordingly
$excelFilePath = "C:\Temp\TagDataSource.xlsx"

# Path to output CSV log file
$outputLogFile = "C:\Temp\TagPermissions_Results.csv"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# Import Excel data
try {
    $excelData = Import-Excel -Path $excelFilePath -ErrorAction Stop
    if (-not $excelData) {
        Write-Log "Excel file is empty or could not be read." "ERROR"
        exit 1
    }
    Write-Log "Successfully imported Excel data from $excelFilePath"
}
catch {
    Write-Log "Failed to import Excel file: $_" "ERROR"
    exit 1
}

# Validate required columns exist
$requiredColumns = @("TagCategory", "TagName", "RoleName", "SecurityGroupName")
foreach ($col in $requiredColumns) {
    if (-not $excelData.PSObject.Properties.Name.Contains($col)) {
        Write-Log "Excel file missing required column '$col'. Please check the spreadsheet." "ERROR"
        exit 1
    }
}

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

# Assign permissions on Tag Category (tags themselves do not support permissions)
function Assign-RoleAndGroupToTagCategory {
    param (
        $TagCategory,
        [string]$RoleName,
        [string]$SecurityGroupName
    )

    # Check if the role exists, create if missing
    $role = Get-VIRole -Name $RoleName -ErrorAction SilentlyContinue
    if (-not $role) {
        Write-Log "Role '$RoleName' does not exist. Attempting to create it..."

        # Define privileges for a Trusted Admin level role (includes broad privileges)
        # These are typical Trusted Admin privileges related to tagging and VM management.
        $privileges = @(
            "System.Anonymous",
            "System.View",
            "System.Read",
            "System.Modify",
            "System.Administrate",
            "VirtualMachine.Interact.PowerOn",
            "VirtualMachine.Interact.PowerOff",
            "VirtualMachine.Interact.Suspend",
            "VirtualMachine.Inventory.Create",
            "VirtualMachine.Inventory.Delete",
            "VirtualMachine.Inventory.Modify",
            "VirtualMachine.Config.AddNewDisk",
            "VirtualMachine.Config.RemoveDisk",
            "VirtualMachine.Config.AddNewNic",
            "VirtualMachine.Config.RemoveNic",
            "VirtualMachine.Config.Memory",
            "VirtualMachine.Config.CPU",
            "VirtualMachine.Config.Settings",
            "Datastore.AllocateSpace",
            "Datastore.Browse",
            "Resource.AssignVMToPool",
            "Network.Assign",
            "Host.Inventory.Modify",
            "Host.Config.Network",
            "Folder.Create",
            "Folder.Delete",
            "Folder.Modify",
            "Tagging.Category.Create",
            "Tagging.Category.Delete",
            "Tagging.Category.Modify",
            "Tagging.Tag.Create",
            "Tagging.Tag.Delete",
            "Tagging.Tag.Modify",
            "License.Inspect",
            "Schedule.Create",
            "Schedule.Delete",
            "Schedule.Modify"
        )

        try {
            $role = New-VIRole -Name $RoleName -Privilege $privileges -ErrorAction Stop
            Write-Log "Trusted Admin role '$RoleName' created successfully."
        }
        catch {
            Write-Log "Failed to create role '$RoleName': $_" "ERROR"
            return $false
        }
    }

    if ([string]::IsNullOrWhiteSpace($SecurityGroupName)) {
        Write-Log "Security group name is empty for category '$($TagCategory.Name)'. Skipping assignment." "WARNING"
        return $false
    }

    try {
        # Check if permission already exists for this principal and role on the category
        $existingPerms = Get-VIPermission -Entity $TagCategory | Where-Object {
            $_.Principal -eq $SecurityGroupName -and $_.Role -eq $RoleName
        }

        if ($existingPerms) {
            Write-Log "Permission for '$SecurityGroupName' with role '$RoleName' already exists on category '$($TagCategory.Name)'." "INFO"
            return "AlreadyExists"
        }
        else {
            # Assign permission on the Tag Category
            New-VIPermission -Entity $TagCategory -Principal $SecurityGroupName -Role $RoleName -Propagate $false -ErrorAction Stop
            Write-Log "Assigned role '$RoleName' to security group '$SecurityGroupName' on category '$($TagCategory.Name)'." "INFO"
            return "Created"
        }
    }
    catch {
        Write-Log "Failed to assign role '$RoleName' to security group '$SecurityGroupName' on tag category '$($TagCategory.Name)': $_" "ERROR"
        return $false
    }
}

# Prepare output log array
$outputLog = @()

# Main processing loop
foreach ($row in $excelData) {
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

    $categoryStatus = ""
    $tagStatus = ""
    $permStatus = ""

    # Check if category exists
    $category = Get-TagCategoryIfExists -CategoryName $categoryName
    if (-not $category) {
        Write-Log "Category '$categoryName' does not exist. Creating..."
        try {
            $category = New-TagCategory -Name $categoryName -Cardinality Single -EntityType VirtualMachine -ErrorAction Stop
            Write-Log "Category '$categoryName' created successfully."
            $categoryStatus = "Created"
        }
        catch {
            Write-Log "Failed to create category '$categoryName': $_" "ERROR"
            $categoryStatus = "Failed"
            # Log and skip to next row
            $outputLog += [PSCustomObject]@{
                TagCategory       = $categoryName
                TagName           = $tagName
                RoleName          = $roleName
                SecurityGroupName = $securityGroupName
                CategoryStatus    = $categoryStatus
                TagStatus         = "Skipped"
                PermissionStatus  = "Skipped"
                Notes             = "Failed to create category"
            }
            continue
        }
    }
    else {
        Write-Log "Category '$categoryName' already exists."
        $categoryStatus = "AlreadyExists"
    }

    # Check if tag exists
    $tag = Get-TagIfExists -TagName $tagName -CategoryName $categoryName
    if (-not $tag) {
        Write-Log "Tag '$tagName' does not exist in category '$categoryName'. Creating..."
        try {
            $tag = New-Tag -Name $tagName -Category $category -ErrorAction Stop
            Write-Log "Tag '$tagName' created successfully in category '$categoryName'."
            $tagStatus = "Created"
        }
        catch {
            Write-Log "Failed to create tag '$tagName' in category '$categoryName': $_" "ERROR"
            $tagStatus = "Failed"
            # Log and skip permission assignment
            $outputLog += [PSCustomObject]@{
                TagCategory       = $categoryName
                TagName           = $tagName
                RoleName          = $roleName
                SecurityGroupName = $securityGroupName
                CategoryStatus    = $categoryStatus
                TagStatus         = $tagStatus
                PermissionStatus  = "Skipped"
                Notes             = "Failed to create tag"
            }
            continue
        }
    }
    else {
        Write-Log "Tag '$tagName' already exists in category '$categoryName'."
        $tagStatus = "AlreadyExists"
    }

    # Verify tag creation
    $verifyTag = Get-TagIfExists -TagName $tagName -CategoryName $categoryName
    if (-not $verifyTag) {
        Write-Log "Verification failed: Tag '$tagName' does not exist after creation attempt." "ERROR"
        $tagStatus = "VerificationFailed"
        $outputLog += [PSCustomObject]@{
            TagCategory       = $categoryName
            TagName           = $tagName
            RoleName          = $roleName
            SecurityGroupName = $securityGroupName
            CategoryStatus    = $categoryStatus
            TagStatus         = $tagStatus
            PermissionStatus  = "Skipped"
            Notes             = "Tag verification failed"
        }
        continue
    }
    else {
        Write-Log "Verified tag '$tagName' exists."
    }

    # Assign role and security group permissions on the Tag Category
    $permResult = Assign-RoleAndGroupToTagCategory -TagCategory $category -RoleName $roleName -SecurityGroupName $securityGroupName

    switch ($permResult) {
        "Created"       { $permStatus = "Created" }
        "AlreadyExists" { $permStatus = "AlreadyExists" }
        $false          { $permStatus = "Failed" }
        default         { $permStatus = "Unknown" }
    }

    # Add row to output log
    $outputLog += [PSCustomObject]@{
        TagCategory       = $categoryName
        TagName           = $tagName
        RoleName          = $roleName
        SecurityGroupName = $securityGroupName
        CategoryStatus    = $categoryStatus
        TagStatus         = $tagStatus
        PermissionStatus  = $permStatus
        Notes             = ""
    }
}

# Export output log to CSV
try {
    $outputLog | Export-Csv -Path $outputLogFile -NoTypeInformation -Encoding UTF8
    Write-Log "Output log exported to $outputLogFile"
}
catch {
    Write-Log "Failed to export output log to CSV: $_" "ERROR"
}

Write-Log "Script completed."
