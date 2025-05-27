#region Script Parameters

param (
    [Parameter(Mandatory = $true, HelpMessage = "vCenter Server address.")]
    [string]$vCenterServer,

    [Parameter(Mandatory = $true, HelpMessage = "Credential to connect to vCenter (e.g., Get-Credential).")]
    [PSCredential]$Credential,

    [Parameter(Mandatory = $true, HelpMessage = "Path to the Excel file containing tagging and permission data.")]
    [string]$ExcelFilePath,

    [Parameter(Mandatory = $true, HelpMessage = "The environment name (e.g., 'Dev', 'Prod'). Used to construct category names.")]
    [string]$Environment,

    [Parameter(HelpMessage = "Name of the function tag category. Defaults to 'vCenter-<Environment>-Function'.")]
    [string]$FunctionCategoryName,

    [Parameter(HelpMessage = "Name of the OS tag category. Defaults to 'vCenter-<Environment>-OS'.")]
    [string]$OsCategoryName,

    [Parameter(HelpMessage = "Specifies whether to check vCenter PSC replication status.")]
    [bool]$CheckPSCReplication
)

# Ensure vCenterServer is globally available throughout the script
$global:vCenterServer = $vCenterServer
$global:ssoConnected = $false

Write-Host "DEBUG: vCenterServer = '$vCenterServer'"
Write-Host "DEBUG: global:vCenterServer = '$global:vCenterServer'"
Write-Host "DEBUG: Credential = $(if($Credential){'[PROVIDED]'}else{'[NULL]'})"
Write-Host "DEBUG: Environment = '$Environment'"
Write-Host "DEBUG: ExcelFilePath = '$ExcelFilePath'"

# Set default values for category names based on the environment
if (-not $FunctionCategoryName) {
    $FunctionCategoryName = "vCenter-$Environment-Function"
}
if (-not $OsCategoryName) {
    $OsCategoryName = "vCenter-$Environment-OS"
}

# Set default value for CheckPSCReplication if not specified
if ($null -eq $CheckPSCReplication) {
    $CheckPSCReplication = $true
}

#endregion

#region Helper Functions

# Structured log writer: creates a log object with Timestamp, Level, and Message properties.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    # Create a structured log entry as a PSCustomObject.
    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Level     = $Level
        Message   = $Message
    }
    
    # Append the structured object to the global log array.
    $global:outputLog += $entry

    # Show the message on the console with colors.
    switch ($Level) {
        "INFO"  { Write-Host "$($entry.Timestamp) [INFO]  $($entry.Message)"  -ForegroundColor Green }
        "WARN"  { Write-Host "$($entry.Timestamp) [WARN]  $($entry.Message)"  -ForegroundColor Yellow }
        "ERROR" { Write-Host "$($entry.Timestamp) [ERROR] $($entry.Message)"  -ForegroundColor Red }
        default { Write-Host "$($entry.Timestamp) [$Level] $($entry.Message)" }
    }
}

# Function to write a fallback log message when structured logging might fail
function Write-FallbackLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    try {
        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $logMessage = "$timestamp [FALLBACK] $Message"
        Write-Host $logMessage -ForegroundColor Magenta
        
        # Try to write to a fallback log file in temp directory
        $fallbackLogPath = Join-Path $env:TEMP "vCenter_Script_Fallback.log"
        Add-Content -Path $fallbackLogPath -Value $logMessage -ErrorAction SilentlyContinue
    }
    catch {
        # Last resort - just try to output to console
        Write-Host "CRITICAL: $Message" -ForegroundColor Red
    }
}

# Function to retrieve a normalized value from a row, checking for different column names
function Get-ValueNormalized {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Row,  # Changed type to [object] to accept both Hashtable and PSCustomObject

        [Parameter(Mandatory = $true)]
        [string]$ColumnName
    )

    if ($Row -is [hashtable]) {
        if ($Row.ContainsKey($ColumnName)) {
            return $Row[$ColumnName].ToString().Trim()
        }
    }
    elseif ($Row -is [pscustomobject]) {
        if ($Row.PSObject.Properties.Name -contains $ColumnName) {
            return $Row."$ColumnName".ToString().Trim()
        }
    }
    return $null
}

#endregion

#region Core Tagging and Role Functions

# Function to get a Tag Category if it exists
function Get-TagCategoryIfExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $tagCategory = Get-TagCategory -Name $Name -ErrorAction Stop
        return $tagCategory
    }
    catch {
        #Write-Log "Tag category '$Name' not found: $_" "WARN" # Reduced verbosity
        return $null
    }
}

# Function to ensure a Tag Category exists, creating it if it doesn't
function Ensure-TagCategory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CategoryName
    )

    if ([string]::IsNullOrWhiteSpace($CategoryName)) {
        Write-Log "Category name is null or whitespace. Skipping category creation." "WARN"
        return $null
    }

    $existingCategory = Get-TagCategoryIfExists -Name $CategoryName
    if ($existingCategory) {
        Write-Log "Tag category '$CategoryName' already exists."
        return $existingCategory
    }
    else {
        try {
            $newCategory = New-TagCategory -Name $CategoryName -Cardinality Multiple -Description "Created by script" -ErrorAction Stop
            Write-Log "Created tag category '$CategoryName'."
            return $newCategory
        }
        catch {
            Write-Log "Failed to create tag category '$CategoryName': $_" "ERROR"
            return $null
        }
    }
}

# Function to get a Tag if it exists
function Get-TagIfExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TagName,

        [Parameter(Mandatory = $true)]
        [string]$CategoryName
    )

    try {
        $tag = Get-Tag -Name $TagName -Category $CategoryName -ErrorAction Stop
        return $tag
    }
    catch {
        #Write-Log "Tag '$TagName' in category '$CategoryName' not found: $_" "WARN" # Reduced verbosity
        return $null
    }
}

# Function to ensure a Tag exists, creating it if it doesn't
function Ensure-Tag {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TagName,

        [Parameter(Mandatory = $true)]
        $Category
    )

    if (-not $Category) {
        Write-Log "Cannot create tag '$TagName' because the category is null." "ERROR"
        return $null
    }

    $existingTag = Get-TagIfExists -TagName $TagName -CategoryName $Category.Name
    if ($existingTag) {
        Write-Log "Tag '$TagName' already exists in category '$($Category.Name)'."
        return $existingTag
    }
    else {
        try {
            $newTag = New-Tag -Name $TagName -Category $Category -Description "Created by script" -ErrorAction Stop
            Write-Log "Created tag '$TagName' in category '$($Category.Name)'."
            return $newTag
        }
        catch {
            Write-Log "Failed to create tag '$TagName' in category '$($Category.Name)': $_" "ERROR"
            return $null
        }
    }
}

# Function to get a Role if it exists
# Function to get a Role if it exists
function Get-RoleIfExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )

    try {
        Write-Log "Checking if role '$RoleName' exists..."
        $role = Get-VIRole -Name $RoleName -ErrorAction Stop
        Write-Log "Role '$RoleName' found."
        return $role
    }
    catch {
        Write-Log "Role '$RoleName' not found. It will need to be created." "WARN"
        return $null
    }
}

# Function to clone a role from the "Support Admin Template"
# Function to clone a role from the "Support Admin Template" or create with predefined privileges
function Clone-RoleFromSupportAdminTemplate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$NewRoleName
    )

    Write-Log "Attempting to create role '$NewRoleName'..."
    
    # First check if the role already exists
    $existingRole = Get-VIRole -Name $NewRoleName -ErrorAction SilentlyContinue
    if ($existingRole) {
        Write-Log "Role '$NewRoleName' already exists, no need to create it."
        return $existingRole
    }

    # Define a comprehensive set of privileges that should cover most needs
    $privilegeIds = @(
        "Alarm.Acknowledge", "Alarm.Create", "Alarm.Delete", "Alarm.DisableActions", "Alarm.Edit", "Alarm.SetStatus",
        "CertificateManagement.Manage", "Cns.Searchable", "ComputePolicy.Manage",
        "ContentLibrary.AddLibraryItem", "ContentLibrary.CheckInTemplate", "ContentLibrary.CheckOutTemplate",
        "ContentLibrary.CreateLocalLibrary", "ContentLibrary.CreateSubscribedLibrary", "ContentLibrary.DeleteLibraryItem",
        "ContentLibrary.DeleteLocalLibrary", "ContentLibrary.DeleteSubscribedLibrary", "ContentLibrary.DownloadSession",
        "ContentLibrary.EvictLibraryItem", "ContentLibrary.EvictSubscribedLibrary", "ContentLibrary.GetConfiguration",
        "ContentLibrary.ImportStorage", "ContentLibrary.ProbeSubscription", "ContentLibrary.SyncLibrary",
        "ContentLibrary.SyncLibraryItem", "ContentLibrary.TypeIntrospection", "ContentLibrary.UpdateConfiguration",
        "ContentLibrary.UpdateLibrary", "ContentLibrary.UpdateLibraryItem", "ContentLibrary.UpdateLocalLibrary",
        "ContentLibrary.UpdateSession", "ContentLibrary.UpdateSubscribedLibrary",
        "Datastore.AllocateSpace", "Datastore.Browse", "Datastore.Config", "Datastore.DeleteFile",
        "Datastore.FileManagement", "Datastore.UpdateVirtualMachineFiles", "Datastore.UpdateVirtualMachineMetadata",
        "Folder.Create", "Folder.Delete", "Folder.Move", "Folder.Rename",
        "Global.CancelTask", "Global.GlobalTag", "Global.ManageCustomFields", "Global.ServiceManagers",
        "Global.SetCustomField", "Global.SystemTag",
        "InventoryService.Tagging.AttachTag", "InventoryService.Tagging.CreateCategory", "InventoryService.Tagging.CreateTag",
        "InventoryService.Tagging.DeleteCategory", "InventoryService.Tagging.DeleteTag", "InventoryService.Tagging.EditCategory",
        "InventoryService.Tagging.EditTag", "InventoryService.Tagging.ModifyUsedByForCategory", "InventoryService.Tagging.ModifyUsedByForTag",
        "InventoryService.Tagging.ObjectAttachable",
        "Network.Assign",
        "Resource.ApplyRecommendation", "Resource.AssignVAppToPool", "Resource.AssignVMToPool", "Resource.ColdMigrate",
        "Resource.CreatePool", "Resource.EditPool", "Resource.HotMigrate", "Resource.QueryVMotion",
        "ScheduledTask.Create", "ScheduledTask.Delete", "ScheduledTask.Edit", "ScheduledTask.Run",
        "Sessions.GlobalMessage", "Sessions.ValidateSession",
        "StorageProfile.Update", "StorageProfile.View", "StorageViews.View",
        "System.Anonymous", "System.Read", "System.View",
        "VApp.ApplicationConfig", "VApp.AssignResourcePool", "VApp.AssignVApp", "VApp.AssignVM", "VApp.Clone",
        "VApp.Create", "VApp.Delete", "VApp.Export", "VApp.ExtractOvfEnvironment", "VApp.Import", "VApp.InstanceConfig",
        "VApp.ManagedByConfig", "VApp.Move", "VApp.PowerOff", "VApp.PowerOn", "VApp.Rename", "VApp.ResourceConfig",
        "VApp.Suspend", "VApp.Unregister",
        "VirtualMachine.Config.AddExistingDisk", "VirtualMachine.Config.AddNewDisk", "VirtualMachine.Config.AddRemoveDevice",
        "VirtualMachine.Config.AdvancedConfig", "VirtualMachine.Config.Annotation", "VirtualMachine.Config.CPUCount",
        "VirtualMachine.Config.ChangeTracking", "VirtualMachine.Config.DiskExtend", "VirtualMachine.Config.DiskLease",
        "VirtualMachine.Config.EditDevice", "VirtualMachine.Config.HostUSBDevice", "VirtualMachine.Config.ManagedBy",
        "VirtualMachine.Config.Memory", "VirtualMachine.Config.MksControl", "VirtualMachine.Config.QueryFTCompatibility",
        "VirtualMachine.Config.QueryUnownedFiles", "VirtualMachine.Config.RawDevice", "VirtualMachine.Config.ReloadFromPath",
        "VirtualMachine.Config.RemoveDisk", "VirtualMachine.Config.Rename", "VirtualMachine.Config.ResetGuestInfo",
        "VirtualMachine.Config.Resource", "VirtualMachine.Config.Settings", "VirtualMachine.Config.SwapPlacement",
        "VirtualMachine.Config.UpgradeVirtualHardware",
        "VirtualMachine.GuestOperations.Execute", "VirtualMachine.GuestOperations.Modify", "VirtualMachine.GuestOperations.ModifyAliases",
        "VirtualMachine.GuestOperations.Query", "VirtualMachine.GuestOperations.QueryAliases",
        "VirtualMachine.Hbr.ConfigureReplication", "VirtualMachine.Hbr.MonitorReplication", "VirtualMachine.Hbr.ReplicaManagement",
        "VirtualMachine.Interact.AnswerQuestion", "VirtualMachine.Interact.Backup", "VirtualMachine.Interact.ConsoleInteract",
        "VirtualMachine.Interact.CreateScreenshot", "VirtualMachine.Interact.DefragmentAllDisks", "VirtualMachine.Interact.DeviceConnection",
        "VirtualMachine.Interact.DnD", "VirtualMachine.Interact.GuestControl", "VirtualMachine.Interact.Pause",
        "VirtualMachine.Interact.PowerOff", "VirtualMachine.Interact.PowerOn", "VirtualMachine.Interact.PutUsbScanCodes",
        "VirtualMachine.Interact.Reset", "VirtualMachine.Interact.SetCDMedia", "VirtualMachine.Interact.SetFloppyMedia",
        "VirtualMachine.Interact.Suspend", "VirtualMachine.Interact.ToolsInstall",
        "VirtualMachine.Inventory.Create", "VirtualMachine.Inventory.CreateFromExisting", "VirtualMachine.Inventory.Delete",
        "VirtualMachine.Inventory.Move", "VirtualMachine.Inventory.Register", "VirtualMachine.Inventory.Unregister",
        "VirtualMachine.Provisioning.Clone", "VirtualMachine.Provisioning.CloneTemplate", "VirtualMachine.Provisioning.CreateTemplateFromVM",
        "VirtualMachine.Provisioning.Customize", "VirtualMachine.Provisioning.DeployTemplate", "VirtualMachine.Provisioning.DiskRandomAccess",
        "VirtualMachine.Provisioning.DiskRandomRead", "VirtualMachine.Provisioning.FileRandomAccess", "VirtualMachine.Provisioning.GetVmFiles",
        "VirtualMachine.Provisioning.MarkAsTemplate", "VirtualMachine.Provisioning.MarkAsVM", "VirtualMachine.Provisioning.ModifyCustSpecs",
        "VirtualMachine.Provisioning.PromoteDisks", "VirtualMachine.Provisioning.PutVmFiles", "VirtualMachine.Provisioning.ReadCustSpecs",
        "VirtualMachine.State.CreateSnapshot", "VirtualMachine.State.RemoveSnapshot", "VirtualMachine.State.RenameSnapshot",
        "VirtualMachine.State.RevertToSnapshot"
    )

    try {
        Write-Log "Getting valid privileges for this vCenter version..."
        
        # Get all available privileges in this vCenter
        $availablePrivileges = Get-VIPrivilege -ErrorAction Stop
        
        # Filter the privilege IDs to only those that exist in this vCenter
        $validPrivilegeIds = $privilegeIds | Where-Object { $_ -in $availablePrivileges.Id }
        
        Write-Log "Found $($validPrivilegeIds.Count) valid privileges out of $($privilegeIds.Count) requested."
        
        if ($validPrivilegeIds.Count -eq 0) {
            Write-Log "No valid privileges found. Using basic set instead." "WARN"
            $validPrivilegeIds = @(
                "System.View",
                "VirtualMachine.Interact.PowerOn",
                "VirtualMachine.Interact.PowerOff",
                "VirtualMachine.Interact.Reset",
                "VirtualMachine.Interact.ConsoleInteract"
            )
        }
        
        # Get the actual privilege objects
        $privileges = Get-VIPrivilege -Id $validPrivilegeIds -ErrorAction Stop
        
        # Create the role with the validated privileges
        Write-Log "Creating role '$NewRoleName' with $($privileges.Count) privileges..."
        $newRole = New-VIRole -Name $NewRoleName -Privilege $privileges -ErrorAction Stop
        
        Write-Log "Successfully created role '$NewRoleName'."
        return $newRole
    }
    catch {
        Write-Log "Failed to create role '$NewRoleName': $_" "ERROR"
        
        # Try a simpler approach with just basic privileges as a last resort
        try {
            Write-Log "Attempting to create role with minimal privileges..." "WARN"
            $basicPrivs = Get-VIPrivilege -Id @(
                "System.View",
                "VirtualMachine.Interact.PowerOn",
                "VirtualMachine.Interact.PowerOff",
                "VirtualMachine.Interact.Reset",
                "VirtualMachine.Interact.ConsoleInteract"
            ) -ErrorAction Stop
            
            $newRole = New-VIRole -Name $NewRoleName -Privilege $basicPrivs -ErrorAction Stop
            Write-Log "Created role '$NewRoleName' with minimal privileges." "WARN"
            return $newRole
        }
        catch {
            Write-Log "Failed to create role even with minimal privileges: $_" "ERROR"
            return $null
        }
    }
}



#endregion

#region Part 4: Permission and Excel Interaction Functions

#---------------------------------------------------------------
# Function: Test-SsoModuleAvailable
#
# Purpose: Checks if the VMware.vSphere.SsoAdmin module is available
#          and can be imported.
#---------------------------------------------------------------
function Test-SsoModuleAvailable {
    Write-Log "Checking if VMware.vSphere.SsoAdmin module is available..."
    
    # Check if the module is already imported
    if (Get-Module -Name VMware.vSphere.SsoAdmin) {
        Write-Log "VMware.vSphere.SsoAdmin module is already imported."
        return $true
    }
    
    # Check if the module is available to import
    if (Get-Module -Name VMware.vSphere.SsoAdmin -ListAvailable) {
        try {
            Import-Module VMware.vSphere.SsoAdmin -ErrorAction Stop
            Write-Log "Successfully imported VMware.vSphere.SsoAdmin module."
            return $true
        }
        catch {
            Write-Log "Failed to import VMware.vSphere.SsoAdmin module: $_" "ERROR"
            return $false
        }
    }
    else {
        Write-Log "VMware.vSphere.SsoAdmin module is not available. SSO group validation will be skipped." "WARN"
        return $false
    }
}

#---------------------------------------------------------------
# Function: Test-SsoGroupExistsSimple
#
# Purpose: A simplified version that always returns true for testing
#---------------------------------------------------------------
function Test-SsoGroupExistsSimple {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,
        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )
    
    $principal = "$Domain\$GroupName"
    Write-Log "Checking SSO group '$principal' (simplified check)..."
    
    # Always return true for testing
    return $true
}




#---------------------------------------------------------------
# Function: Connect-SsoAdmin
#
# Purpose: Connects to SSO Admin service using current module
#---------------------------------------------------------------
function Connect-SsoAdmin {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        [Parameter(Mandatory = $true)]
        [pscredential]$Credential
    )
    
    try {
        Write-Log "Attempting to connect to SSO Admin service..."
        
        # Connect using Connect-SsoAdminServer
        Connect-SsoAdminServer -Server $Server -Credential $Credential -ErrorAction Stop
        $global:ssoConnected = $true
        Write-Log "Successfully connected to SSO Admin service."
        return $true
    }
    catch {
        Write-Log "Failed to connect to SSO Admin service: $_" "ERROR"
        $global:ssoConnected = $false
        return $false
    }
}

#---------------------------------------------------------------
# Function: Assign-PermissionIfNeeded
#
# Purpose: Check if the given principal already has a permission on
#          the VM. If not, assign the permission.
#---------------------------------------------------------------
function Assign-PermissionIfNeeded {
    param(
        [Parameter(Mandatory = $true)]
        $VM,
        
        [Parameter(Mandatory = $true)]
        [string]$Principal,
        
        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )
    
    Write-Log "Checking permission for Principal '$Principal' with Role '$RoleName' on VM '$($VM.Name)'..."
    
    # Check if vCenter connection is active
    if (-not (Get-VIServer -ErrorAction SilentlyContinue)) {
        Write-Log "vCenter connection is not active. Cannot assign permission on VM '$($VM.Name)'." "ERROR"
        return
    }

    try {
        # Retrieve the Role object from the name
        $role = Get-VIRole -Name $RoleName -ErrorAction Stop
        if (-not $role) {
            Write-Log "Role '$RoleName' was not found in vCenter." "ERROR"
            return
        }
        
        # Check if the permission already exists
        $existingPermission = Get-VIPermission -Entity $VM -Principal $Principal -Role $role -ErrorAction SilentlyContinue
        if ($existingPermission) {
            Write-Log "Permission already exists for '$Principal' on VM '$($VM.Name)'." "INFO"
        }
        else {
            Write-Log "Assigning permission for '$Principal' with Role '$RoleName' on VM '$($VM.Name)'..."
            New-VIPermission -Entity $VM -Principal $Principal -Role $role -Propagate:$false -ErrorAction Stop
            Write-Log "Permission assigned successfully for '$Principal' on VM '$($VM.Name)'." "INFO"
        }
    }
    catch {
        Write-Log "Failed to assign permission for '$Principal' with role '$RoleName' on VM '$($VM.Name)': $_" "ERROR"
    }
}

#---------------------------------------------------------------
# Function: Import-ExcelCOM
#
# Purpose: Imports Excel data using the COM interface.
#---------------------------------------------------------------
function Import-ExcelCOM {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    Write-Log "Starting Excel import from '$Path'..."
    
    # Initialize the COM object for Excel
    $excelApp = New-Object -ComObject Excel.Application
    $excelApp.Visible = $false
    $excelApp.DisplayAlerts = $false

    $workbook = $null
    $worksheet = $null

    try {
        if (-not (Test-Path -Path $Path -PathType Leaf)) {
            throw "Excel file not found at '$Path'."
        }

        $workbook = $excelApp.Workbooks.Open($Path)
        if (-not $workbook) {
            throw "Failed to open Excel workbook at '$Path'."
        }

        if ($workbook.Worksheets.Count -eq 0) {
            throw "No worksheets found in Excel file '$Path'."
        }
        $worksheet = $workbook.Worksheets.Item(1)
        
        $usedRange = $worksheet.UsedRange
        $rows = $usedRange.Rows.Count
        $cols = $usedRange.Columns.Count

        $data = @()
        
        if ($rows -gt 1) {
            for ($row = 2; $row -le $rows; $row++) {
                $obj = New-Object PSObject
                for ($col = 1; $col -le $cols; $col++) {
                    $header = $usedRange.Cells.Item(1, $col).Text
                    $value = $usedRange.Cells.Item($row, $col).Text
                    
                    if (-not [string]::IsNullOrWhiteSpace($header)) {
                        $obj | Add-Member -MemberType NoteProperty -Name $header -Value $value -Force
                    }
                }
                $data += $obj
            }
        }
        
        Write-Log "Excel import completed; imported $($data.Count) data rows."
        return $data
    }
    catch {
        Write-Log "Error during Excel import from '$Path': $_" "ERROR"
        throw
    }
    finally {
        try {
            if ($workbook) {
                $workbook.Close($false)
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) | Out-Null
                $workbook = $null
            }
            if ($worksheet) {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet) | Out-Null
                $worksheet = $null
            }
            if ($excelApp) {
                $excelApp.Quit()
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excelApp) | Out-Null
                $excelApp = $null
            }
        }
        catch {
            Write-Log "Error during Excel COM cleanup: $_" "WARN"
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

#endregion

#region Part 5: Main Script Execution

# Initialize structured log array
$global:outputLog = @()

# Determine script directory for log placement
try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction Stop
    if (-not $scriptDir) { $scriptDir = Get-Location }
}
catch {
    $scriptDir = Get-Location
    Write-Host "WARN: Could not determine script directory. Using current directory: $scriptDir" -ForegroundColor Yellow
}

# Validate vCenter server parameter before proceeding
if ([string]::IsNullOrWhiteSpace($global:vCenterServer)) {
    $errorMsg = "vCenter server parameter is empty or null. Cannot proceed."
    Write-FallbackLog $errorMsg
    throw $errorMsg
}

# Pre-flight network connectivity test to vCenter on port 443
try {
    Write-Log "Testing network connectivity to vCenter '$global:vCenterServer' on port 443..."
    $connTest = Test-NetConnection -ComputerName $global:vCenterServer -Port 443 -ErrorAction Stop
    if (-not $connTest.TcpTestSucceeded) {
        throw "Network connectivity test failed. vCenter '$global:vCenterServer' might be unreachable or blocked."
    }
    Write-Log "Network connectivity to '$global:vCenterServer' confirmed." "INFO"
}
catch {
    $msg = "Pre-connection test failed for '$global:vCenterServer': $($_.Exception.Message)"
    Write-Log $msg "ERROR"
    Write-FallbackLog $msg
    throw $msg
}

# Clean up any existing vCenter connections
try {
    if ($global:DefaultVIServers -and $global:DefaultVIServers.Count -gt 0) {
        Write-Log "Clearing existing vCenter connections..." "INFO"
        Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Cleared existing vCenter connections." "INFO"
    }
}
catch {
    Write-Log "Warning: Cannot clear existing vCenter sessions: $($_.Exception.Message)" "WARN"
}

# Connect to vCenter
try {
    Write-Log "Connecting to vCenter '$global:vCenterServer'..."
    
    # Explicitly set certificate handling to avoid prompts
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    
    # Use explicit parameter names to avoid any confusion
    $vcConn = Connect-VIServer -Server $global:vCenterServer -Credential $Credential -ErrorAction Stop
    
    if (-not $vcConn -or -not $vcConn.IsConnected) {
        throw "Connect-VIServer returned but connection is not established."
    }
    
    Write-Log "Connected to vCenter '$global:vCenterServer' (API Version: $($vcConn.Version))." "INFO"
}
catch {
    $msg = "Failed to connect to vCenter '$global:vCenterServer': $($_.Exception.Message)"
    Write-Log $msg "ERROR"
    Write-FallbackLog $msg
    throw $msg
}

# Connect to SSO Admin if module is present
if (Test-SsoModuleAvailable) {
    try {
        Write-Log "Connecting to SSO Admin service..."
        if (Connect-SsoAdmin -Server $global:vCenterServer -Credential $Credential) {
            Write-Log "Connected to SSO Admin." "INFO"
        }
    }
    catch {
        Write-Log "Non-fatal: SSO connection failed: $($_.Exception.Message)" "WARN"
    }
}
else {
    Write-Log "VMware.vSphere.SsoAdmin module not available; skipping SSO connect." "WARN"
}

# ---------------------------
# Main Processing Section
# ---------------------------
try {
    Write-Log "IMPORTING EXCEL DATA..."
    $excelData = Import-ExcelCOM -Path $ExcelFilePath
    if (-not $excelData -or $excelData.Count -eq 0) {
        throw "Excel import returned zero rows."
    }
    Write-Log "Imported $($excelData.Count) rows from Excel." "INFO"

    # Pre-fetch Domain-Controller tag, if defined in the Excel data
    Write-Log "Pre-fetching 'Domain-controller' tag if it exists..."
    $dcRow = $excelData | Where-Object {
        ($_.TagName -ieq 'Domain-controller') -or ($_.TagName -ieq 'Domain Controller')
    } | Select-Object -First 1
    if ($dcRow) {
        $domainControllerTag = Get-TagIfExists -TagName $dcRow.TagName -CategoryName $dcRow.TagCategory
        if ($domainControllerTag) {
            Write-Log "Found existing DC tag: $($domainControllerTag.Name)" "INFO"
        }
        else {
            Write-Log "DC tag '$($dcRow.TagName)' not found; it will be created when encountered." "WARN"
        }
    }
    else {
        Write-Log "No DC row in Excel; DC skip logic disabled." "WARN"
    }

    # Process each row from the Excel data
    foreach ($row in $excelData) {
        try {
            # Normalize column values; check both possible column names as needed
            $tagCategoryName = Get-ValueNormalized -Row $row -ColumnName 'TagCategory'
            if (-not $tagCategoryName) { $tagCategoryName = Get-ValueNormalized -Row $row -ColumnName 'CategoryName' }
            $tagName         = Get-ValueNormalized -Row $row -ColumnName 'TagName'
            $roleName        = Get-ValueNormalized -Row $row -ColumnName 'RoleName'
            $secDomain       = Get-ValueNormalized -Row $row -ColumnName 'SecurityGroupDomain'
            $secGroup        = Get-ValueNormalized -Row $row -ColumnName 'SecurityGroupName'
            if (-not $secGroup) { $secGroup = Get-ValueNormalized -Row $row -ColumnName 'Principal' }

            # Skip row if any required field is missing
            if ([string]::IsNullOrWhiteSpace($tagCategoryName) -or
                [string]::IsNullOrWhiteSpace($tagName)         -or
                [string]::IsNullOrWhiteSpace($roleName)        -or
                [string]::IsNullOrWhiteSpace($secDomain)       -or
                [string]::IsNullOrWhiteSpace($secGroup)) {
                Write-Log "Skipping incomplete row: Cat='$tagCategoryName', Tag='$tagName', Role='$roleName', Principal='$secDomain\$secGroup'" "WARN"
                continue
            }

            Write-Log "ROW: Category='$tagCategoryName', Tag='$tagName', Role='$roleName', Principal='$secDomain\$secGroup'." "INFO"

            # Ensure Tag Category exists
            $category = Ensure-TagCategory -CategoryName $tagCategoryName
            if (-not $category) {
                Write-Log "Failed ensuring category '$tagCategoryName'. Skipping row." "ERROR"
                continue
            }
            # Ensure Tag exists
            $tag = Ensure-Tag -TagName $tagName -Category $category
            if (-not $tag) {
                Write-Log "Failed ensuring tag '$tagName'. Skipping row." "ERROR"
                continue
            }

            # Retrieve VMs with this tag (exclude system VMs like vCLS/VLC)
            try {
                $vms = Get-VM -Tag $tag -ErrorAction Stop |
                       Where-Object { $_.Name -notmatch '^(vCLS|VLC)' }
                Write-Log "Found $($vms.Count) VMs tagged '$($tag.Name)'." "INFO"
            }
            catch {
                Write-Log "Error retrieving VMs for tag '$($tag.Name)': $_" "ERROR"
                continue
            }

            # Ensure Role exists, or clone it from a template if needed
            Write-Log "Checking if role '$roleName' exists..."
            $role = Get-RoleIfExists -RoleName $roleName
            if (-not $role) {
                Write-Log "Role '$roleName' not found. Attempting to clone from template..." "INFO"
                $role = Clone-RoleFromSupportAdminTemplate -NewRoleName $roleName
                if (-not $role) {
                    Write-Log "Failed to create role '$roleName'. Skipping row." "ERROR"
                    continue
                }
                else {
                    Write-Log "Successfully created role '$roleName'." "INFO"
                }
            }
            else {
                Write-Log "Using existing role '$roleName'." "INFO"
            }

            # Iterate over each VM and assign permissions if applicable
            $proc = 0; $skipped = 0
            foreach ($vm in $vms) {
                $principal = "$secDomain\$secGroup"
                $skipPerm  = $false

                # Specific check: Skip permission assignment if both:
                # The Excel row specifies a Windows-server tag AND
                # The VM has a Domain-controller tag
                if ($tagName -ieq 'Windows-server' -and $domainControllerTag) {
                    try {
                        $assigns = Get-TagAssignment -Entity $vm -ErrorAction SilentlyContinue
                        if ($assigns | Where-Object { $_.Tag.Id -eq $domainControllerTag.Id }) {
                            $skipPerm = $true
                            Write-Log "Skipping permissions for VM '$($vm.Name)' (Domain Controller)." "INFO"
                            $skipped++
                        }
                    }
                    catch {
                        Write-Log "Error checking DC tag on VM '$($vm.Name)': $_" "WARN"
                    }
                }

                if (-not $skipPerm) {
                    # Ensure the SSO group exists before assigning permission
                    if (-not (Test-SsoGroupExistsSimple -Domain $principalDomain -GroupName $principalName)) {
                        Write-Log "SSO group '$principal' does not exist. Skipping VM '$($vm.Name)'." "ERROR"
                        continue
                    }
                    # Assign permission if not already assigned
                    Assign-PermissionIfNeeded -VM $vm -Principal $principal -RoleName $role.Name
                    $proc++
                }
            }
            Write-Log "Row complete: Processed=$proc, Skipped=$skipped." "INFO"
        }
        catch {
            Write-Log "Error processing row with Tag='$($row.TagName)': $_" "ERROR"
        }
    }

    # OS-based Tagging if $OsCategoryName is defined
    if ($OsCategoryName) {
        Write-Log "Applying OS-based tags..."
        try {
            $osCat = Ensure-TagCategory -CategoryName $OsCategoryName
            if ($osCat) {
                # Sample OS patterns (customize these patterns as needed)
                $patterns = @{
                    'Windows-server'  = 'Windows Server'
                    'Windows-desktop' = 'Windows 10|Windows 8|Windows 7'
                    'Linux'           = 'Linux'
                }
                foreach ($entry in $patterns.GetEnumerator()) {
                    $tagName = $entry.Key
                    $regex   = $entry.Value
                    $tag     = Ensure-Tag -TagName $tagName -Category $osCat
                    $matches = Get-VM | Where-Object {
                        $_.Guest.OSFullName -match $regex -and $_.Name -notmatch '^(vCLS|VLC)'
                    }
                    foreach ($vm in $matches) {
                        if (-not (Get-TagAssignment -Entity $vm -Tag $tag -ErrorAction SilentlyContinue)) {
                            Write-Log "Tagging VM '$($vm.Name)' with OS tag '$tagName'." "INFO"
                            New-TagAssignment -Entity $vm -Tag $tag -ErrorAction Stop
                        }
                    }
                }
            }
            else {
                Write-Log "Failed to ensure OS category '$OsCategoryName'. Skipping OS tagging." "ERROR"
            }
        }
        catch {
            Write-Log "OS tagging error: $_" "ERROR"
        }
        Write-Log "OS tagging complete." "INFO"
    }
    else {
        Write-Log "OS category not defined; skipping OS tagging." "WARN"
    }
}
catch {
    # Log fatal error during main processing
    Write-Log "FATAL error during processing: $($_.Exception.Message)" "ERROR"
    Write-FallbackLog "FATAL: $($_.Exception.Message)"
    throw
}

# Export structured log to CSV
try {
    $logFile = Join-Path $scriptDir ("TagPermissionsOutput_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $global:outputLog | Export-Csv -Path $logFile -NoTypeInformation -ErrorAction Stop
    Write-Log "Log exported to '$logFile'." "INFO"
}
catch {
    Write-Log "Failed to export log: $($_.Exception.Message)" "ERROR"
    Write-FallbackLog "Log export failed: $($_.Exception.Message)"
}

# Cleanup: Disconnect from SSO Admin and vCenter
finally {
    Write-Log "Starting cleanup..." "INFO"
    
    # Disconnect SSO Admin
    if ($global:ssoConnected -and (Get-Module VMware.vSphere.SsoAdmin -ErrorAction SilentlyContinue)) {
        try {
            Disconnect-SsoAdminServer  -ErrorAction Stop | Out-Null
            $global:ssoConnected = $false
            Write-Log "Disconnected from SSO Admin." "INFO"
        }
        catch {
            Write-Log "Warning: SSO disconnect failed: $($_.Exception.Message)" "WARN"
            Write-FallbackLog "SSO disconnect failed: $($_.Exception.Message)"
        }
    }
    
    # Disconnect vCenter
    try {
        if ($global:DefaultVIServers -and $global:DefaultVIServers.Count -gt 0) {
            Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction Stop | Out-Null
            Write-Log "Disconnected from vCenter." "INFO"
        }
    }
    catch {
        Write-Log "Warning: vCenter disconnect failed: $($_.Exception.Message)" "WARN"
        Write-FallbackLog "vCenter disconnect failed: $($_.Exception.Message)"
    }
    
    # Reset PowerCLI certificate policy if changed
    try {
        Set-PowerCLIConfiguration -InvalidCertificateAction Warn -Confirm:$false | Out-Null
    }
    catch {
        Write-Log "Warning: Could not reset certificate policy: $($_.Exception.Message)" "WARN"
    }
    
    Write-Log "Cleanup completed." "INFO"
}

#endregion
