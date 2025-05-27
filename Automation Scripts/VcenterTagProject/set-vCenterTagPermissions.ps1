#region A) PARAMETERS
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true, HelpMessage="vCenter Server name or IP")]
    [string]$vCenterServer,

    [Parameter(Mandatory=$true, HelpMessage="Credential object for vCenter and SSO")]
    [pscredential]$Credential,

    [Parameter(Mandatory=$true, HelpMessage="Path to the Excel file containing tag and permission data")]
    [string]$ExcelFilePath,

    [Parameter(Mandatory=$true, HelpMessage="Environment (e.g., DEV, PROD, KLEB, ICS, VDI) to determine category names")]
    [ValidateSet('DEV', 'PROD', 'KLEB', 'ICS', 'VDI')] # Updated valid environments
    [string]$Environment,

    # Reverted parameter name to avoid conflict with common -Debug parameter
    [Parameter(HelpMessage="Enable detailed script debug logging")]
    [switch]$EnableScriptDebug # Changed back from -Debug
)

# Global variables for logging and connection status
$global:outputLog = @()
$global:logFolder = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "Logs"
$global:ssoConnected = $false
# Add a global flag for script-specific debug logging, set based on -EnableScriptDebug
$global:ScriptDebugEnabled = $false # Initialize, will be set in main execution

# Configuration for environment-specific category names
# Updated based on user input
$EnvironmentCategoryConfig = @{
    'DEV' = @{ App = 'vCenter-DEV-App-team'; Function = 'vCenter-DEV-Function'; OS = 'vCenter-DEV-OS' };
    'PROD' = @{ App = 'vCenter-PROD-App-team'; Function = 'vCenter-PROD-Function'; OS = 'vCenter-PROD-OS' };
    'KLEB' = @{ App = 'vCenter-KLEB-App-team'; Function = 'vCenter-KLEB-Function'; OS = 'vCenter-KLEB-OS' };
    'ICS' = @{ App = 'vCenter-ICS-App-team'; Function = 'vCenter-ICS-Function'; OS = 'vCenter-ICS-OS' };
    'VDI' = @{ App = 'vCenter-VDI-App-team'; Function = 'vCenter-VDI-Function'; OS = 'vCenter-VDI-OS' };
}

# Static mapping of OS patterns to target TagNames
# This defines which OS names map to which *potential* OS tags.
# The script will only apply these tags if the target TagName is also listed in the Excel sheet
# under the OS category AND exists in vCenter.
$StaticOSPatterns = @{
    # Windows Server
    "Microsoft Windows Server 2012.*" = "Windows-server";
    "Microsoft Windows Server 2016.*" = "Windows-server";
    "Microsoft Windows Server 2019.*" = "Windows-server";
    "Microsoft Windows Server 2022.*" = "Windows-server";
    "Microsoft Windows Server.*" = "Windows-server"; # Generic fallback for other server versions

    # Windows Client
    "Microsoft Windows 10.*" = "Windows-client";
    "Microsoft Windows 11.*" = "Windows-client";
    "Microsoft Windows.*" = "Windows-client"; # Generic fallback for other client versions

    # Linux
    "Ubuntu Linux.*" = "Ubuntu Linux";
    "CentOS Linux.*" = "CentOS Linux";
    "Red Hat Enterprise Linux.*" = "RHEL";
    "SUSE Linux Enterprise Server.*" = "SLES";
    "VMware Photon OS.*" = "Photon OS";
    ".*Linux.*" = "Linux"; # Generic fallback for other Linux distros

    # Other OS types (Add as needed)
    "VMware ESXi.*" = "ESXi"; # Note: Tagging ESXi hosts might require different cmdlets
}
#endregion


#region B) LOGGING
# Ensure log folder exists
if (-not (Test-Path $global:logFolder)) {
    try {
        New-Item -Path $global:logFolder -ItemType Directory -Force | Out-Null
        # Fallback log for this specific action if Write-Log isn't ready
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO ] Log folder created: $($global:logFolder)" -ForegroundColor Green
    }
    catch {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] Failed to create log folder $($global:logFolder): $_" -ForegroundColor Red
        # If log folder creation fails, subsequent logging might also fail.
        # The script will continue, but logs will only go to console.
    }
}

# Fallback logging function if main logging fails or isn't initialized
function Write-FallbackLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    # Simple console output with timestamp and ERROR level
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] (Fallback) $($Message)" -ForegroundColor Red
}

# Main logging function
function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Determine if this log level should be written
    $writeThisLog = $false
    switch ($Level.ToUpper()) {
        "INFO" { $writeThisLog = $true }
        "WARN" { $writeThisLog = $true }
        "ERROR" { $writeThisLog = $true }
        "DEBUG" {
            # Check the script's specific debug flag set by the -EnableScriptDebug parameter
            if ($global:ScriptDebugEnabled) {
                 $writeThisLog = $true
            }
        }
    }

    if ($writeThisLog) {
        $logEntry = [PSCustomObject]@{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Level     = $Level.ToUpper()
            Message   = $Message
        }
        # Add to in-memory log
        $global:outputLog += $logEntry

        # Write to host for immediate feedback (optional, but good for debugging)
        $hostColor = switch ($Level.ToUpper()) {
            "INFO" { "Green" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            "DEBUG" { "Gray" }
            Default { "White" }
        }
        Write-Host "$($logEntry.Timestamp) [$($logEntry.Level.PadRight(5))] $($logEntry.Message)" -ForegroundColor $hostColor
    }
}

# Function to clean up old log files
function Cleanup-OldLogs {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$LogFolder,

        [Parameter(Mandatory=$true)]
        [int]$MaxLogsToKeep
    )

    Write-Log "Cleaning up old logs in '$($LogFolder)', keeping $($MaxLogsToKeep) most recent." "DEBUG"

    try {
        # Get log files, sort by last write time (newest first)
        $logFiles = Get-ChildItem -Path $LogFolder -Filter "*.log" -File | Sort-Object LastWriteTime -Descending

        # Identify files to remove (all except the newest $MaxLogsToKeep)
        if ($logFiles.Count -gt $MaxLogsToKeep) {
            $filesToRemove = $logFiles | Select-Object -Skip $MaxLogsToKeep

            Write-Log "Found $($filesToRemove.Count) old log files to remove." "DEBUG"

            foreach ($file in $filesToRemove) {
                Write-Log "Removing old log file: $($file.FullName)" "DEBUG"
                try {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    Write-Log "  Successfully removed $($file.Name)." "DEBUG"
                }
                catch {
                    Write-Log "  Failed to remove old log file $($file.FullName): $_" "WARN"
                }
            }
        } else {
            Write-Log "No old log files to remove (found $($logFiles.Count), keeping $($MaxLogsToKeep))." "DEBUG"
        }
    }
    catch {
        Write-Log "Error during log cleanup: $_" "WARN"
        Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
    }
}

Write-Log "Script started." "INFO"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "DEBUG"
Write-Log "PowerCLI Module Info:" "DEBUG"
try {
    Get-Module -Name VMware.PowerCLI -ErrorAction Stop | Select-Object Name, Version, Path | Format-List | Out-String | ForEach-Object { Write-Log "  $_" "DEBUG" }
}
catch {
    Write-Log "  VMware.PowerCLI module not found or error getting info: $_" "WARN"
}

# Initial log cleanup (before main execution starts)
Cleanup-OldLogs -LogFolder $global:logFolder -MaxLogsToKeep 5
#endregion


#region C) EXCEL IMPORT FUNCTION
function Import-ExcelCOM {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    Write-Log "Attempting to import data from Excel file: $($Path)" "DEBUG"

    if (-not (Test-Path $Path)) {
        Write-Log "Excel file not found at path: $($Path)" "ERROR"
        throw "Excel file not found."
    }

    $excel = $null
    try {
        # Create Excel COM object
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        Write-Log "  Excel COM object created." "DEBUG"

        # Open the workbook
        $workbook = $excel.Workbooks.Open($Path)
        $worksheet = $workbook.Sheets.Item(1) # Assuming data is on the first sheet
        Write-Log "  Workbook opened. Using first sheet." "DEBUG"

        # Find the used range
        $usedRange = $worksheet.UsedRange
        $rows = $usedRange.Rows.Count
        $cols = $usedRange.Columns.Count
        Write-Log "  Used range found: $($rows) rows, $($cols) columns." "DEBUG"

        if ($rows -le 1) {
            Write-Log "  Excel sheet contains only headers or is empty." "WARN"
            $workbook.Close()
            $excel.Quit()
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
            Remove-Variable excel -ErrorAction SilentlyContinue
            return @() # Return empty array
        }

        # Get headers (first row)
        $headerRow = $usedRange.Rows.Item(1)
        $headers = @()
        for ($i = 1; $i -le $cols; $i++) {
            $header = $headerRow.Cells.Item(1, $i).Value2
             # Handle potential null or empty headers
            if ([string]::IsNullOrWhiteSpace($header)) {
                $header = "Column$i" # Assign a default name if header is empty
                Write-Log "    Warning: Empty header found in column $i. Using '$($header)'." "WARN"
            } else {
                 # Sanitize headers: remove spaces and special characters, make unique
                $header = $header -replace '[^a-zA-Z0-9_]', ''
                # Ensure uniqueness if needed, though for this script simple sanitization is likely enough
            }
            $headers += $header
        }
        Write-Log "  Headers identified: $($headers -join ', ')" "DEBUG"

        # Get data rows
        $data = @()
        for ($i = 2; $i -le $rows; $i++) { # Start from row 2 (after headers)
            $rowObject = New-Object pscustomobject
            $dataRow = $usedRange.Rows.Item($i)
            for ($j = 1; $j -le $cols; $j++) {
                $cellValue = $dataRow.Cells.Item(1, $j).Value2
                # Add property to the object using sanitized header name
                $rowObject | Add-Member -Type NoteProperty -Name $headers[$j-1] -Value $cellValue -Force
            }
            $data += $rowObject
        }

        Write-Log "  Successfully read $($data.Count) data rows from Excel." "DEBUG"

        return $data

    } catch {
        Write-Log "Error importing Excel file '$($Path)': $_" "ERROR"
        Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        # Clean up COM object in case of error
        if ($workbook) { $workbook.Close($false) } # Close without saving
        if ($excel) { $excel.Quit() }
        if ($excel) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null }
        Remove-Variable excel -ErrorAction SilentlyContinue
        throw "Failed to import Excel data."
    } finally {
        # Ensure COM object is released even on success
        if ($workbook) { $workbook.Close($false) } # Close without saving
        if ($excel) { $excel.Quit() }
        # Use a loop to ensure release, sometimes needed
        $releaseAttempts = 0
        while ([System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) -gt 0 -and $releaseAttempts -lt 10) {
            $releaseAttempts++
            Start-Sleep -Milliseconds 100
        }
        Remove-Variable excel -ErrorAction SilentlyContinue
        Write-Log "  Excel COM object cleanup attempted." "DEBUG"
    }
}
#endregion

#region D) SSO HELPER FUNCTIONS

function Test-SsoModuleAvailable {
    Write-Log "Checking for VMware.VimAutomation.SsoAdministration module..." "DEBUG"
    try {
        # Use -ListAvailable to avoid loading the module just for the check
        $module = Get-Module -Name VMware.VimAutomation.SsoAdministration -ListAvailable -ErrorAction Stop
        if ($module) {
            Write-Log "  VMware.VimAutomation.SsoAdministration module found." "DEBUG"
            # Attempt to import the module if found but not loaded
            if (-not (Get-Module -Name VMware.VimAutomation.SsoAdministration)) {
                 Write-Log "  Importing VMware.VimAutomation.SsoAdministration module..." "DEBUG"
                 Import-Module VMware.VimAutomation.SsoAdministration -ErrorAction Stop | Out-Null
                 Write-Log "  Module imported." "DEBUG"
            }
            return $true
        } else {
            Write-Log "  VMware.VimAutomation.SsoAdministration module not found." "DEBUG"
            return $false
        }
    } catch {
        Write-Log "  Error checking/importing SSO module: $_" "WARN"
        Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $false
    }
}

function Connect-SsoAdmin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Server,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential
    )
    Write-Log "Attempting to connect to SSO Admin server '$($Server)'..." "DEBUG"
    $global:ssoConnected = $false # Assume failure initially

    try {
        # Connect to the SSO Admin server
        # This cmdlet handles the connection based on the vCenter server address
        Connect-SsoAdminServer -Server $Server -Credential $Credential -ErrorAction Stop | Out-Null
        $global:ssoConnected = $true
        Write-Log "  Successfully connected to SSO Admin server." "DEBUG"
        return $true

    } catch {
        Write-Log "  Failed to connect to SSO Admin server '$($Server)': $_" "ERROR"
        Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        $global:ssoConnected = $false
        return $false
    }
}

function Test-SsoGroupExistsSimple {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Domain,
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )
    # Ensure SSO is connected before attempting to check
    if (-not $global:ssoConnected) {
        Write-Log "    SSO is not connected. Cannot check existence of group '$($Domain)\$($GroupName)'." "WARN"
        return $false
    }

    # Construct the principal name in the format expected by Get-SsoGroup
    # Get-SsoGroup expects "GroupName@Domain" for domain groups
    $principalName = "$GroupName@$Domain"
    Write-Log "    Checking SSO group existence for principal name '$($principalName)'..." "DEBUG"

    try {
        # Attempt to retrieve the group. If it doesn't exist, Get-SsoGroup throws an error.
        # Using -ErrorAction Stop inside try/catch is the standard way to handle this.
        $ssoGroup = Get-SsoGroup -Name $GroupName -Domain $Domain -ErrorAction Stop

        # If we reach here, the group was found
        Write-Log "    SSO group '$($principalName)' found." "DEBUG"
        return $true

    } catch {
        # If an error occurred, the group was not found or there was another SSO issue
        Write-Log "    SSO group '$($principalName)' not found or check failed: $($_.Exception.Message)" "ERROR"
        Write-Log "    Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $false
    }
}

#endregion


#region E) HELPER FUNCTIONS

function Get-ValueNormalized {
    param(
        [pscustomobject]$Row,
        [string]$ColumnName
    )
    # Attempt to get value by exact column name first
    $value = $null
    if ($Row.PSObject.Properties.Match($ColumnName).Count -gt 0) {
        $value = $Row.$ColumnName
    } else {
        # If not found, try case-insensitive match
        $prop = $Row.PSObject.Properties | Where-Object { $_.Name -ieq $ColumnName } | Select-Object -First 1
        if ($prop) {
            $value = $prop.Value
        }
    }

    # Handle potential null or empty values and trim whitespace
    if ($value -is [string]) {
        return $value.Trim()
    } elseif ($value -ne $null) {
        # Convert non-string values to string, then trim
        return ($value.ToString()).Trim()
    } else {
        return "" # Return empty string for null values
    }
}

function Get-TagCategoryIfExists {
    param([string]$CategoryName)
    Write-Log "  Checking if tag category '$($CategoryName)' exists (case-insensitive)..." "DEBUG" # Updated log message
    try {
        # Get all categories and filter by name case-insensitively
        $cat = Get-TagCategory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $CategoryName } | Select-Object -First 1
        if ($cat) {
            Write-Log "    Category '$($CategoryName)' found (case-insensitive match)." "DEBUG" # Updated log message
            return $cat
        } else {
            Write-Log "    Category '$($CategoryName)' not found." "DEBUG"
            return $null
        }
    } catch {
        Write-Log "    Error checking for category '$($CategoryName)': $_" "WARN"
        return $null
    }
}

function Ensure-TagCategory {
    param(
        [string]$CategoryName,
        [string]$Description = "Managed by script",
        [string]$Cardinality = "MULTIPLE", # "SINGLE", "MULTIPLE"
        [string[]]$EntityType = @("VirtualMachine") # e.g., @("VirtualMachine", "Datastore")
    )
    Write-Log "  Ensuring tag category '$($CategoryName)' exists (case-insensitive check)..." "DEBUG" # Updated log message

    # Check if category already exists (case-insensitively)
    try {
        $existingCat = Get-TagCategory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $CategoryName } | Select-Object -First 1

        if ($existingCat) {
            Write-Log "    Category '$($CategoryName)' already exists (case-insensitive match)." "DEBUG" # Updated log message
            return $existingCat
        }
    } catch {
        Write-Log "    Error checking for existing category '$($CategoryName)': $_" "WARN"
        # Continue to attempt creation if check fails
    }


    # If category doesn't exist, create it
    Write-Log "    Category '$($CategoryName)' not found, creating..." "DEBUG"
    try {
        # Use the exact case from $CategoryName for creation
        $newCat = New-TagCategory -Name $CategoryName -Description $Description -Cardinality $Cardinality -EntityType $EntityType -ErrorAction Stop
        Write-Log "    Category '$($CategoryName)' created successfully." "DEBUG"
        return $newCat
    } catch {
        Write-Log "    Failed to create category '$($CategoryName)': $_" "ERROR"
        Write-Log "    Error details: $($_.Exception.Message)" "DEBUG"
        return $null
    }
}

function Get-TagIfExists {
    param(
        [string]$TagName,
        [string]$CategoryName
    )
    Write-Log "  Checking if tag '$($TagName)' exists in category '$($CategoryName)' (case-insensitive)..." "DEBUG" # Updated log message
    try {
        # Get the category object first (using the case-insensitive helper)
        $cat = Get-TagCategoryIfExists -CategoryName $CategoryName
        if ($cat) {
            # Get all tags in the category and filter by name case-insensitively
            $tag = Get-Tag -Category $cat -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $TagName } | Select-Object -First 1
            if ($tag) {
                Write-Log "    Tag '$($TagName)' found (case-insensitive match)." "DEBUG" # Updated log message
                return $tag
            } else {
                Write-Log "    Tag '$($TagName)' not found in category '$($CategoryName)'." "DEBUG"
                return $null
            }
        } else {
            Write-Log "    Category '$($CategoryName)' not found." "DEBUG"
            return $null
        }
    } catch {
        Write-Log "    Error checking for tag '$($TagName)' in category '$($CategoryName)': $_" "WARN"
        return $null
    }
}

function Ensure-Tag {
    param(
        [string]$TagName,
        [VMware.VimAutomation.ViCore.Types.V1.Tagging.TagCategory]$Category # Accept category object
    )
    Write-Log "  Ensuring tag '$($TagName)' exists in category '$($Category.Name)' (case-insensitive check)..." "DEBUG" # Updated log message

    # Check if tag already exists (case-insensitively)
    try {
        # Get all tags in the category and filter by name case-insensitively
        $existingTag = Get-Tag -Category $Category -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $TagName } | Select-Object -First 1

        if ($existingTag) {
            Write-Log "    Tag '$($TagName)' already exists (case-insensitive match)." "DEBUG" # Updated log message
            return $existingTag
        }
    } catch {
         Write-Log "    Error checking for existing tag '$($TagName)' in category '$($Category.Name)': $_" "WARN"
         # Continue to attempt creation if check fails
    }

    # If tag doesn't exist, create it
    Write-Log "    Tag '$($TagName)' not found, creating..." "DEBUG"
    try {
        # Use the exact case from $TagName for creation
        $newTag = New-Tag -Name $TagName -Category $Category -Description "Managed by script" -ErrorAction Stop
        Write-Log "    Tag '$($TagName)' created successfully." "DEBUG"
        return $newTag
    } catch {
        Write-Log "    Failed to create tag '$($TagName)' in category '$($Category.Name)': $_" "ERROR"
        Write-Log "    Error details: $($_.Exception.Message)" "DEBUG"
        return $null
    }
}

#endregion

#region F) ROLE MANAGEMENT FUNCTIONS

function Get-RoleIfExists {
    param([string]$RoleName)
    Write-Log "  Checking if role '$($RoleName)' exists (case-insensitive)..." "DEBUG" # Updated log message
    try {
        # Get all roles and filter by name case-insensitively
        $role = Get-VIRole -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $RoleName } | Select-Object -First 1
        if ($role) {
            Write-Log "    Role '$($RoleName)' found (case-insensitive match)." "DEBUG" # Updated log message
            return $role
        } else {
            Write-Log "    Role '$($RoleName)' not found." "DEBUG"
            return $null
        }
    } catch {
        Write-Log "    Error checking for role '$($RoleName)': $_" "WARN"
        return $null
    }
}

function Clone-RoleFromSupportAdminTemplate {
    param([string]$NewRoleName)
    Write-Log "  Attempting to clone role from template for '$($NewRoleName)'..." "DEBUG"
    try {
        # Get the template role (assuming "SupportAdmin" exists)
        # Use case-insensitive lookup for the template role name
        $templateRole = Get-VIRole -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq "SupportAdmin" } | Select-Object -First 1

        if (-not $templateRole) {
            Write-Log "    Template role 'SupportAdmin' not found. Cannot clone role." "ERROR"
            return $null
        }

        # Clone the role using the exact case for the new role name
        $newRole = New-VIRole -Name $NewRoleName -Privilege (Get-Privilege -Role $templateRole) -ErrorAction Stop
        Write-Log "    Role '$($NewRoleName)' cloned successfully from 'SupportAdmin'." "DEBUG"
        return $newRole
    } catch {
        Write-Log "    Failed to clone role for '$($NewRoleName)': $_" "ERROR"
        Write-Log "    Error details: $($_.Exception.Message)" "DEBUG"
        return $null
    }
}

#endregion

#region G) PERMISSION ASSIGNMENT FUNCTION

function Assign-PermissionIfNeeded {
    param(
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachine]$VM,
        [string]$Principal, # e.g., "DOMAIN\Group" or "user@domain"
        [string]$RoleName
    )
    Write-Log "    Checking permissions for '$($Principal)' on VM '$($VM.Name)' with role '$($RoleName)'..." "DEBUG"

    try {
        # Get the role object (case-insensitive lookup handled by Get-RoleIfExists)
        $role = Get-RoleIfExists -RoleName $RoleName
        if (-not $role) {
            Write-Log "      Role '$($RoleName)' not found or could not be created. Cannot assign permission for '$($Principal)' on '$($VM.Name)'." "ERROR"
            return $false
        }

        # Check if the permission already exists (case-insensitive principal and role name comparison)
        $existingPermission = Get-VIPermission -Entity $VM -Principal $Principal -ErrorAction SilentlyContinue |
                              Where-Object { $_.Role -ieq $RoleName -and $_.Principal -ieq $Principal } # Ensure both match case-insensitively

        if ($existingPermission) {
            Write-Log "      Permission for '$($Principal)' with role '$($RoleName)' already exists on VM '$($VM.Name)', skipping." "DEBUG"
            return $true
        }

        # Assign the permission
        Write-Log "      Assigning permission for '$($Principal)' with role '$($RoleName)' on VM '$($VM.Name)'..." "DEBUG"
        New-VIPermission -Entity $VM -Principal $Principal -Role $role -Propagate:$false -ErrorAction Stop # Do not propagate to children by default
        Write-Log "      Permission assigned successfully." "DEBUG"
        return $true

    } catch {
        Write-Log "    Failed to assign permission for '$($Principal)' with role '$($RoleName)' on VM '$($VM.Name)': $_" "ERROR"
        Write-Log "    Error details: $($_.Exception.Message)" "DEBUG"
        return $false
    }
}

#endregion

#region H) TAGGING FUNCTIONS

# Note: Ensure-TagCategory, Get-TagIfExists, Ensure-Tag are defined in Region E and handle case-insensitivity

# Tagging logic is primarily within the main execution block (Region I)
# using the helper functions from Region E.

#endregion

#region I) MAIN EXECUTION
try {
    # Set the global script debug flag based on the parameter
    $global:ScriptDebugEnabled = $EnableScriptDebug.IsPresent # Use .IsPresent for switch parameters

    #— Preflight
    Write-Log "Starting preflight checks..." "DEBUG"

    if (-not $vCenterServer) {
        Write-Log "vCenterServer parameter is empty" "DEBUG"
        throw "vCenterServer is empty."
    }

    # Look up Category Names based on Environment
    Write-Log "Looking up category names for environment: $($Environment)..." "DEBUG"
    if ($EnvironmentCategoryConfig.ContainsKey($Environment)) {
        $config = $EnvironmentCategoryConfig[$Environment]
        $AppCategoryName = $config.App
        $FunctionCategoryName = $config.Function
        $OsCategoryName = $config.OS # This is the expected OS category name from Excel
        Write-Log "  Category names set for $($Environment): App='$($AppCategoryName)', Function='$($FunctionCategoryName)', OS='$($OsCategoryName)'" "INFO"
    } else {
        Write-Log "Configuration for environment '$($Environment)' not found." "ERROR"
        throw "Invalid Environment specified or configuration missing."
    }

    Write-Log "Testing connectivity to $($vCenterServer):443" "INFO"
    Write-Log "  Executing Test-NetConnection..." "DEBUG"
    $test = Test-NetConnection $vCenterServer -Port 443 -ErrorAction Stop

    if (-not $test.TcpTestSucceeded) {
        Write-Log "  Connection test failed: $($test | ConvertTo-Json -Depth 1)" "DEBUG"
        throw "Cannot reach vCenter."
    }

    Write-Log "Connectivity OK." "INFO"
    Write-Log "  Connection test details: TcpTestSucceeded=$($test.TcpTestSucceeded), RemoteAddress=$($test.RemoteAddress)" "DEBUG"

    #— Clear any existing sessions
    Write-Log "Checking for existing vCenter sessions..." "DEBUG"
    if ($global:DefaultVIServers.Count -gt 0) {
        Write-Log "  Found $($global:DefaultVIServers.Count) existing sessions" "DEBUG"
        foreach ($server in $global:DefaultVIServers) {
            Write-Log "  Existing connection: $($server.Name) (User: $($server.User))" "DEBUG"
        }

        Write-Log "Disconnecting existing vCenter sessions" "INFO"
        Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction SilentlyContinue
        Write-Log "  Disconnection command executed" "DEBUG"
    } else {
        Write-Log "  No existing vCenter sessions found" "DEBUG"
    }

    #— Connect to vCenter
    Write-Log "Setting PowerCLI certificate handling..." "DEBUG"
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
    Write-Log "  Certificate handling set to Ignore" "DEBUG"

    Write-Log "Connecting to vCenter $($vCenterServer)..." "DEBUG"
    $vc = Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
    Write-Log "Connected to vCenter (v$($vc.Version))." "INFO"
    Write-Log "  Connection details: Name=$($vc.Name), User=$($vc.User), Port=$($vc.Port), ServiceUri=$($vc.ServiceUri)" "DEBUG"

    #— Connect SSO if available
    Write-Log "Attempting to connect to SSO Admin service..." "DEBUG"
    $ssoModulePresent = Test-SsoModuleAvailable
    if ($ssoModulePresent) {
        $ssoConnectSuccess = Connect-SsoAdmin -Server $vCenterServer -Credential $Credential
        if (-not $ssoConnectSuccess) {
            Write-Log "SSO Admin connection failed. SSO-related features (like checking group existence) will be skipped." "WARN"
        } else {
            Write-Log "SSO connection established." "INFO"
        }
    } else {
        Write-Log "SSO Admin module not available. SSO-related features will be skipped." "WARN"
        $global:ssoConnected = $false
    }


    #— Import Excel
    Write-Log "Preparing to import Excel data..." "DEBUG"
    $rows = Import-ExcelCOM -Path $ExcelFilePath

    if ($rows.Count -eq 0) {
        Write-Log "  Excel import returned no data" "ERROR"
        throw "Excel returned no data."
    }

    Write-Log "Successfully imported $($rows.Count) rows from Excel" "DEBUG"

    #— Ensure Categories exist (App, Function, OS)
    Write-Log "Ensuring App category exists: '$($AppCategoryName)'..." "DEBUG"
    $appCat = Ensure-TagCategory -CategoryName $AppCategoryName

    Write-Log "Ensuring Function category exists: '$($FunctionCategoryName)'..." "DEBUG"
    $functionCat = Ensure-TagCategory -CategoryName $FunctionCategoryName

    Write-Log "Ensuring OS category exists: '$($OsCategoryName)'..." "DEBUG"
    $osCat = Ensure-TagCategory -CategoryName $OsCategoryName

    if (-not $appCat) { Write-Log "Failed to ensure App category '$($AppCategoryName)'. App tag rows will be skipped." "ERROR" } else { Write-Log "App category '$($AppCategoryName)' ready." "DEBUG" }
    if (-not $functionCat) { Write-Log "Failed to ensure Function category '$($FunctionCategoryName)'. Function tag checks will be skipped." "ERROR" } else { Write-Log "Function category '$($FunctionCategoryName)' ready." "DEBUG" }
    if (-not $osCat) { Write-Log "Failed to ensure OS category '$($OsCategoryName)'. OS tag rows and OS tagging will be skipped." "ERROR" } else { Write-Log "OS category '$($OsCategoryName)' ready." "DEBUG" }


    #— Check for Domain Controller tag existence in Function category (DO NOT CREATE)
    # Get-TagIfExists handles case-insensitive lookup
    $dcTag = $null # Initialize $dcTag
    if ($functionCat) { # Only check if Function category was successfully ensured
        Write-Log "Checking for Domain Controller tag existence in Function category '$($functionCat.Name)' (will NOT create if missing)..." "DEBUG"
        $dcTag = Get-TagIfExists -TagName "Domain Controller" -CategoryName $functionCat.Name

        if ($dcTag) {
            Write-Log "Found Domain Controller tag in Function category '$($functionCat.Name)'" "INFO"
            Write-Log "  DC Tag details: Name=$($dcTag.Name), Category=$($dcTag.Category), ID=$($dcTag.Id))" "DEBUG"
        } else {
            Write-Log "Domain Controller tag not found in '$($functionCat.Name)' category" "WARN"
            Write-Log "  This means DC detection for permissions and OS tagging based on Function tag will be skipped." "DEBUG"
        }
    } else {
         Write-Log "Function category failed to ensure, cannot check for Domain Controller tag existence." "WARN"
    }

    # Initialize the list of valid OS tags found/created from Excel
    $ExcelValidOSTags = @{} # Dictionary to store TagName -> TagObject for valid OS tags from Excel

    #— Process each row
    Write-Log "Beginning to process Excel rows..." "DEBUG"
    $rowIndex = 0

    foreach ($row in $rows) {
        $rowIndex++
        Write-Log "Processing row $($rowIndex) of $($rows.Count)..." "DEBUG"

        try {
            # Normalize columns (Get-ValueNormalized is already case-insensitive for column names)
            Write-Log "  Normalizing column values..." "DEBUG"
            $tagCategoryName = Get-ValueNormalized $row 'TagCategory'
            $tagName = Get-ValueNormalized $row 'TagName' # This is the tag name from Excel
            $roleName = Get-ValueNormalized $row 'RoleName'
            $secDomain = Get-ValueNormalized $row 'SecurityGroupDomain'
            $secGroup = Get-ValueNormalized $row 'SecurityGroupName'
            if ([string]::IsNullOrWhiteSpace($secGroup)) {
                $secGroup = Get-ValueNormalized $row 'Principal' # Fallback to Principal if GroupName is empty
                # Need to parse domain/group from Principal if used as fallback
                if (-not ([string]::IsNullOrWhiteSpace($secGroup)) -and ([string]::IsNullOrWhiteSpace($secDomain))) {
                     if ($secGroup -match "^(.+)\\( .+)$") { # DOMAIN\Group format
                         $secDomain = $Matches[1]
                         $secGroup = $Matches[2]
                         Write-Log "    Parsed Domain='$($secDomain)', Group='$($secGroup)' from Principal '$($secGroup)' (DOMAIN\Group format)." "DEBUG"
                     } elseif ($secGroup -match "^(.+)@(.+)$") { # Group@Domain format
                         $secGroup = $Matches[1]
                         $secDomain = $Matches[2]
                         Write-Log "    Parsed Group='$($secGroup)', Domain='$($secDomain)' from Principal '$($secGroup)' (Group@Domain format)." "DEBUG"
                     } else {
                          Write-Log "    Warning: Could not parse Principal '$($secGroup)' into Domain and Group. Skipping row." "WARN"
                          continue # Skip this row as principal format is unknown
                     }
                }
            }

            Write-Log "  Normalized values: Category='$($tagCategoryName)', Tag='$($tagName)', Role='$($roleName)', Domain='$($secDomain)', Group='$($secGroup)'" "DEBUG"

            # --- Handle App-team rows (permissions) ---
            if ($tagCategoryName -ieq $AppCategoryName) { # Use -ieq for robust comparison
                Write-Log "  Processing row for App-team permissions..." "DEBUG"

                # Skip incomplete rows for permissions
                if ([string]::IsNullOrWhiteSpace($tagName) -or [string]::IsNullOrWhiteSpace($roleName) -or [string]::IsNullOrWhiteSpace($secDomain) -or [string]::IsNullOrWhiteSpace($secGroup)) {
                    Write-Log "Skipping incomplete App-team row for permissions: $($row | Out-String -NoNewline)" "WARN"
                    Write-Log "  One or more required fields (TagName, RoleName, SecurityGroupDomain/Principal, SecurityGroupName/Principal) are missing." "DEBUG"
                    continue
                }

                Write-Log "Row for Permissions: Cat='$($tagCategoryName)' Tag='$($tagName)' Role='$($roleName)' Principal='$($secDomain)\$($secGroup)'" "INFO"

                # Ensure App category exists (checked earlier, but double-check object)
                if (-not $appCat) {
                     Write-Log "  App category '$($AppCategoryName)' failed to ensure earlier. Cannot process App tag '$($tagName)' for permissions." "WARN"
                     Write-Log "  Moving to next row" "DEBUG"
                     continue
                }

                # --- Ensure App tag exists in vCenter (CREATE IF MISSING) ---
                # Ensure-Tag handles case-insensitive lookup and creation if missing
                Write-Log "  Ensuring App tag '$($tagName)' from Excel exists in category '$($appCat.Name)' (will create if missing)..." "DEBUG"
                $tagObj = Ensure-Tag -TagName $tagName -Category $appCat # Use the category object

                if (-not $tagObj) {
                    Write-Log "Failed to ensure App tag '$($tagName)' in category '$($appCat.Name)'. Skipping permission assignment for this row." "ERROR"
                    Write-Log "  Row details: $($row | Out-String -NoNewline)" "DEBUG"
                    Write-Log "  Moving to next row" "DEBUG"
                    continue # Skip to the next row
                }
                Write-Log "  App tag '$($tagName)' is ready (found or created). Using tag object $($tagObj.Id)." "DEBUG"
                # --- END App tag ensure ---


                # Find VMs (excluding system VMs) with the *current App tag* ($tagObj is the object, case is not an issue here)
                Write-Log "  Finding VMs with App tag '$($tagObj.Name)'..." "DEBUG"
                $allVms = Get-VM -Tag $tagObj -ErrorAction Stop
                Write-Log "  Found $($allVms.Count) VMs with tag '$($tagObj.Name)' before filtering system VMs." "DEBUG"

                $vms = $allVms | Where-Object Name -notmatch '^(vCLS|VLC)'
                Write-Log "Found $($vms.Count) VMs for App tag '$($tagObj.Name)' (filtered system VMs)." "INFO"

                if ($vms.Count -gt 0) {
                     Write-Log "  VM list for tag '$($tagObj.Name)': $($vms.Name -join ', ')" "DEBUG"
                } else {
                     Write-Log "  No VMs found with App tag '$($tagObj.Name)' after filtering." "DEBUG"
                }


                # Ensure role exists (Get-RoleIfExists and Clone-RoleFromSupportAdminTemplate use case-insensitive check/template lookup)
                Write-Log "  Checking if role exists: '$($roleName)'" "DEBUG"
                $roleObj = Get-RoleIfExists -RoleName $roleName

                if (-not $roleObj) {
                    Write-Log "  Role '$($roleName)' doesn't exist, attempting to clone/create..." "DEBUG"
                    # Clone-RoleFromSupportAdminTemplate creates the new role with the exact case of $RoleName
                    $roleObj = Clone-RoleFromSupportAdminTemplate -NewRoleName $roleName

                    if (-not $roleObj) {
                        Write-Log "  Failed to create role '$($roleName)', skipping permission assignment for this row." "ERROR"
                        Write-Log "  Moving to next row" "DEBUG"
                        continue
                    }
                }

                # Assign permissions per VM
                $proc = 0; $skipped = 0
                Write-Log "  Beginning permission assignment for $($vms.Count) VMs with App tag '$($tagObj.Name)'..." "DEBUG"

                foreach ($vm in $vms) {
                    Write-Log "  Processing VM: $($vm.Name) for permissions" "DEBUG"
                    $principal = "$secDomain\$secGroup"

                    # Skip Windows-server permissions on DC-tagged VMs (using the Function DC tag)
                    # $tagObj.Name comparison is case-insensitive due to -ieq
                    # This check relies on $dcTag being the *object* of the Function DC tag, which was fetched earlier
                    if ($tagObj.Name -ieq 'Windows-server' -and $dcTag) {
                        Write-Log "    Checking if VM '$($vm.Name)' is a domain controller (has Function DC tag)..." "DEBUG"
                        # Get-TagAssignment uses the tag object, case is not an issue here
                        $hasDC = Get-TagAssignment -Entity $vm -Tag $dcTag -ErrorAction SilentlyContinue
                        if ($hasDC -ne $null -and $hasDC.Count -gt 0) {
                            Write-Log "Skipping Windows-server permission for DC VM '$($vm.Name)'." "INFO"
                            Write-Log "    VM '$($vm.Name)' has Function category Domain Controller tag, skipping permission assignment." "DEBUG"
                            $skipped++
                            continue
                        } else {
                            Write-Log "    VM '$($vm.Name)' is not a domain controller (does not have Function DC tag), proceeding with permission assignment." "DEBUG"
                        }
                    }

                    # SSO group check (only if SSO is connected) - Test-SsoGroupExistsSimple handles domain/group case
                    if ($global:ssoConnected) {
                        Write-Log "    Checking if SSO group exists: '$($principal)'..." "DEBUG"
                        if (-not (Test-SsoGroupExistsSimple -Domain $secDomain -GroupName $secGroup)) {
                            Write-Log "SSO group not found or check failed: '$($principal)'. Skipping permission assignment for VM '$($vm.Name)'." "ERROR"
                            Write-Log "    SSO group check failed, skipping VM." "DEBUG"
                            $skipped++
                            continue
                        }
                    } else {
                         Write-Log "    SSO not connected, skipping SSO group existence check for '$($principal)'." "WARN"
                    }


                    # Assign-PermissionIfNeeded uses case-insensitive check for existing permission
                    Write-Log "    Assigning permission '$($roleObj.Name)' for '$($principal)' on '$($vm.Name)'..." "DEBUG"
                    Assign-PermissionIfNeeded -VM $vm -Principal $principal -RoleName $roleObj.Name
                    $proc++
                }

                Write-Log "Row done (Permissions): Processed VMs=$($proc) Skipped VMs=$($skipped)" "INFO"
                Write-Log "  App-team row processing complete." "DEBUG"

            } # --- End Handle App-team rows ---

            # --- Handle OS rows (tag creation for whitelist) ---
            elseif ($tagCategoryName -ieq $OsCategoryName) { # Use -ieq for robust comparison
                 Write-Log "  Processing row for OS tag whitelist creation..." "DEBUG"

                 $osTagName = Get-ValueNormalized $row 'TagName'
                 if ([string]::IsNullOrWhiteSpace($osTagName)) {
                     Write-Log "    Skipping OS row due to missing TagName: $($row | Out-String -NoNewline)" "WARN"
                     continue
                 }

                 # Ensure OS category exists (checked earlier, but double-check object)
                 if (-not $osCat) {
                      Write-Log "  OS category '$($OsCategoryName)' failed to ensure earlier. Cannot process OS tag '$($osTagName)' for whitelist." "WARN"
                      Write-Log "  Moving to next row" "DEBUG"
                      continue
                 }

                 # --- Ensure OS tag exists in vCenter (CREATE IF MISSING) ---
                 # Ensure-Tag handles case-insensitive lookup and creation if missing
                 Write-Log "    Ensuring OS tag '$($osTagName)' from Excel exists in category '$($osCat.Name)' (will create if missing)..." "DEBUG"
                 $tagObj = Ensure-Tag -TagName $osTagName -Category $osCat

                 if ($tagObj) {
                     Write-Log "    OS tag '$($osTagName)' is ready (found or created). Adding to valid OS tag list." "DEBUG"
                     # Store the tag object using the exact case from Ensure-Tag (or use -ieq for key lookup later)
                     # Using the exact name returned by Ensure-Tag as the key is safest
                     $ExcelValidOSTags[$tagObj.Name] = $tagObj
                 } else {
                     Write-Log "    Failed to ensure OS tag '$($osTagName)' in category '$($osCat.Name)'. This tag will NOT be added to the valid list and will not be applied." "ERROR"
                     Write-Log "    Row details: $($row | Out-String -NoNewline)" "DEBUG"
                 }
            } # --- End Handle OS rows ---

            # --- Handle Function rows (SKIP TAG CREATION) ---
            elseif ($tagCategoryName -ieq $FunctionCategoryName) { # Use -ieq for robust comparison
                 Write-Log "  Skipping row from Function category '$($tagCategoryName)' for tag creation (Function tags are not created from Excel)." "INFO"
                 Write-Log "  Moving to next row" "DEBUG"
                 continue
            } # --- End Handle Function rows ---

            # --- Handle any other categories ---
            else {
                 Write-Log "  Skipping row from unrecognized category '$($tagCategoryName)'." "INFO"
                 Write-Log "  Moving to next row" "DEBUG"
                 continue
            } # --- End Handle any other categories ---

        } # End try processing row
        catch {
            Write-Log "Error processing row $($rowIndex): $_" "ERROR"
            Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        }
    } # End foreach row

    Write-Log "Finished processing all Excel rows." "INFO"
    Write-Log "Number of valid OS tags from Excel/vCenter for pattern matching: $($ExcelValidOSTags.Count)" "DEBUG"
    if ($ExcelValidOSTags.Count > 0) {
         Write-Log "Valid OS tags: $($ExcelValidOSTags.Keys -join ', ')" "DEBUG"
    }


    # --- Begin OS-based tagging section ---

    Write-Log "Applying OS-based tags based on patterns and valid OS tag list..." "INFO"

    # This section uses the $ExcelValidOSTags list populated during the row processing loop above.
    # It also relies on the $osCat object being successfully ensured earlier.

    if (-not $osCat) {
        Write-Log "OS category '$($OsCategoryName)' failed to ensure earlier. Skipping all OS tagging." "ERROR"
    }
    elseif ($ExcelValidOSTags.Count -eq 0) {
        Write-Log "No valid OS tags found/created from Excel/vCenter. Skipping general OS tagging based on patterns." "INFO"
    }
    else {
        Write-Log "Proceeding with general OS tagging for VMs based on patterns and the following valid OS tags: $($ExcelValidOSTags.Keys -join ', ')" "DEBUG"

        # Get all VMs (excluding system VMs)
        Write-Log "  Getting all VMs for OS pattern matching..." "DEBUG"
        $allVms = Get-VM | Where-Object Name -notmatch '^(vCLS|VLC)'
        Write-Log "  Found $($allVms.Count) VMs to check for OS patterns." "DEBUG"

        # Loop through each VM and apply matching tags from the valid list
        Write-Log "  Beginning OS pattern matching and tagging for VMs..." "DEBUG"
        $vmCount = 0
        foreach ($vm in $allVms) {
            $vmCount++
            Write-Log "  Processing VM $($vmCount) of $($allVms.Count): $($vm.Name)" "DEBUG"

            # Get OS Full Name with fallback
            $osFull = $null
            Write-Log "    Attempting to get Guest.OSFullName for VM '$($vm.Name)'..." "DEBUG"
            $osFull = $vm.Guest.OSFullName
            if ([string]::IsNullOrWhiteSpace($osFull)) {
                 Write-Log "      VM '$($vm.Name)': Standard Guest.OSFullName is empty. Attempting Get-View fallback." "DEBUG"
                 try {
                     $vmView = $vm | Get-View -ErrorAction SilentlyContinue
                     if ($vmView -and $vmView.Summary -and $vmView.Summary.Config) {
                         $osFull = $vmView.Summary.Config.GuestFullName
                     }
                     if ([string]::IsNullOrWhiteSpace($osFull)) {
                          Write-Log "      VM '$($vm.Name)': Get-View GuestFullName is also empty or Get-View failed." "DEBUG"
                     } else {
                          Write-Log "      VM '$($vm.Name)': Successfully got OS Full Name from Get-View: '$($osFull)'." "DEBUG"
                     }
                 } catch {
                     Write-Log "      VM '$($vm.Name)': Error getting OS Full Name via Get-View: $($_.Exception.Message)" "DEBUG"
                     $osFull = $null
                 }
            } else {
                 Write-Log "      VM '$($vm.Name)': Successfully got OS Full Name from standard property: '$($osFull)'." "DEBUG"
            }

            # If OS Full Name is available, check against static patterns
            if ([string]::IsNullOrWhiteSpace($osFull)) {
                 Write-Log "    VM '$($vm.Name)' has no usable Guest.OSFullName from either method, cannot apply OS pattern tags." "WARN"
                 continue # Skip to next VM
            }

            Write-Log "    Checking OS '$($osFull)' against static patterns..." "DEBUG"
            $appliedTagsForVM = @() # Track tags applied to this VM in this section

            # Loop through static patterns (Pattern -> Target TagName)
            # Use GetEnumerator() to iterate over hashtable key-value pairs
            foreach ($patternEntry in $StaticOSPatterns.GetEnumerator()) {
                $osPattern = $patternEntry.Key
                $targetTagName = $patternEntry.Value

                # Check if the VM's OS matches the pattern
                # Regex matching is case-sensitive by default unless (?i) is used in pattern
                # If you need case-insensitive OS pattern matching, modify the pattern string itself
                if ($osFull -match $osPattern) {
                    Write-Log "      VM OS '$($osFull)' matches pattern '$($osPattern)' (target tag: '$($targetTagName)')." "DEBUG"

                    # Check if this targetTagName is one of the valid tags from Excel/vCenter (case-insensitive check against keys)
                    $validTagKey = $ExcelValidOSTags.Keys | Where-Object { $_ -ieq $targetTagName } | Select-Object -First 1

                    if ($validTagKey) {
                        $tagToApply = $ExcelValidOSTags[$validTagKey] # Get the actual tag object using the found key
                        Write-Log "      Target tag '$($targetTagName)' is valid and exists in vCenter. Proceeding to check/apply tag '$($tagToApply.Name)'." "DEBUG"

                        # Check if VM already has this tag
                        # Get-TagAssignment uses the tag object, case is not an issue here
                        $existing = Get-TagAssignment -Entity $vm -Tag $tagToApply -ErrorAction SilentlyContinue
                        if (-not $existing) {
                            Write-Log "Tagging '$($vm.Name)' with OS tag '$($tagToApply.Name)' (matched pattern '$($osPattern)')." "INFO"
                            try {
                                # Ensure we have a valid VM object reference before tagging
                                $vmToTag = Get-VM -Id $vm.Id -ErrorAction Stop
                                $assignment = New-TagAssignment -Entity $vmToTag -Tag $tagToApply -ErrorAction Stop
                                Write-Log "        OS tag '$($tagToApply.Name)' assigned successfully to $($vmToTag.Name)." "DEBUG"
                                $appliedTagsForVM += $tagToApply.Name # Add to list for this VM
                            }
                            catch {
                                Write-Log "        Failed to assign OS tag '$($tagToApply.Name)' to '$($vm.Name)': $_" "WARN"
                                Write-Log "        Error details: $($_.Exception.Message)" "DEBUG"
                            }
                        }
                        else {
                            Write-Log "      VM '$($vm.Name)' already has OS tag '$($tagToApply.Name)' in category '$($osCat.Name)', skipping." "DEBUG"
                        }
                    } else {
                        Write-Log "      Target tag '$($targetTagName)' derived from pattern '$($osPattern)' is NOT in the list of valid OS tags from Excel/vCenter. Skipping application." "DEBUG"
                    }
                }
            } # End foreach pattern

            if ($appliedTagsForVM.Count -gt 0) {
                 Write-Log "    Finished checking patterns for VM '$($vm.Name)'. Applied tags: $($appliedTagsForVM -join ', ')" "DEBUG"
            } else {
                 Write-Log "    Finished checking patterns for VM '$($vm.Name)'. No new OS tags applied from patterns." "DEBUG"
            }

        } # End foreach VM
    } # End if osCat and ExcelValidOSTags > 0

# --- Part 2: Specific Domain Controller OS Tagging (based on Function DC tag) ---
    # This section remains separate as it's triggered by the Function tag, not an OS row in Excel.
    # It ensures a SPECIFIC hardcoded OS tag ("Domain-Controller") exists and applies it.
    # This logic doesn't read the target tag name from an OS row's TagName column in Excel
    # for THIS specific logic part, so we still use Ensure-Tag here if you want it created.
    # If you want "Domain Controller" OS tag ONLY applied if it's in the Excel list and exists,
    # you would remove this section and rely solely on Part 1 with "Domain-Controller" in Excel.
    # Keeping it separate as requested previously.
    Write-Log "  Processing specific Domain Controller OS tagging based on Function DC tag..." "INFO"

    # This check relies on $dcTag being the *object* of the Function DC tag, which was fetched earlier using Get-TagIfExists
    if (-not $dcTag) {
        Write-Log "  Function category 'Domain Controller' tag was not found during check. Skipping specific DC OS tagging based on Function tag." "INFO"
    }
    elseif (-not $osCat) {
         Write-Log "  OS category failed to ensure. Cannot apply OS 'Domain-Controller' tag to DCs." "ERROR"
    }
    else {
        Write-Log "  Function category 'Domain Controller' tag found. Proceeding with DC OS tagging." "DEBUG"

        # Define the specific OS tag name for DCs.
        # *** CORRECTED: Use the hyphenated name "Domain-Controller" here ***
        $osDcTagName = "Domain-Controller" # <--- This is a hardcoded target tag name

        # Ensure the specific OS DC tag exists within the OS category.
        # We use Ensure-Tag here because this tag name is hardcoded in the script for this
        # specific DC-to-OS tagging logic, and you want OS tags to be created if missing.
        Write-Log "    Ensuring OS tag '$($osDcTagName)' exists in category '$($osCat.Name)' for DC tagging (will create if missing)..." "DEBUG"
        $osDcTag = Ensure-Tag -TagName $osDcTagName -Category $osCat

        if (-not $osDcTag) {
            Write-Log "    Failed to ensure OS DC tag '$($osDcTagName)'. Cannot tag DCs based on Function tag." "ERROR"
        } else {
            Write-Log "    OS DC tag '$($osDcTag.Name)' is ready for assignment." "DEBUG"

            # Find VMs that have the Function category Domain Controller tag ($dcTag is the object)
            Write-Log "    Finding VMs with Function category tag '$($dcTag.Name)'..." "DEBUG"
            # Get-TagAssignment uses the tag object, case is not an issue here
            $dcVMs = Get-TagAssignment -Tag $dcTag -ErrorAction SilentlyContinue |
                     Select-Object -ExpandProperty Entity |
                     Where-Object { $_.Name -notmatch '^(vCLS|VLC)' } # Exclude system VMs

            Write-Log "    Found $($dcVMs.Count) VMs with Function category DC tag that need OS DC tag." "DEBUG"

            if ($dcVMs.Count > 0) {
                Write-Log "    DC VM list needing OS tag: $($dcVMs.Name -join ', ')" "DEBUG"
            } else {
                Write-Log "    No VMs found with Function category DC tag needing OS DC tag." "DEBUG"
            }

            foreach ($vm in $dcVMs) {
                 Write-Log "    Checking existing tags on DC VM $($vm.Name) for OS DC tag '$($osDcTag.Name)'..." "DEBUG"
                 # Get-TagAssignment uses the tag object, case is not an issue here
                 $existing = Get-TagAssignment -Entity $vm -Tag $osDcTag -ErrorAction SilentlyContinue
                 if (-not $existing) {
                    Write-Log "Tagging DC VM '$($vm.Name)' with OS tag '$($osDcTag.Name)'." "INFO"
                    try {
                        $vmToTag = Get-VM -Id $vm.Id -ErrorAction Stop # Refresh VM object
                        $assignment = New-TagAssignment -Entity $vmToTag -Tag $osDcTag -ErrorAction Stop
                        Write-Log "      OS DC tag assigned successfully to $($vmToTag.Name)." "DEBUG"
                        }
                    catch {
                        Write-Log "      Failed to assign OS DC tag '$($osDcTag.Name)' to '$($vm.Name)': $_" "WARN"
                        Write-Log "      Error details: $($_.Exception.Message)" "DEBUG"
                    }
                 }
                 else {
                    Write-Log "    DC VM '$($vm.Name)' already has OS DC tag '$($osDcTag.Name)' in category '$($osCat.Name)', skipping." "DEBUG"
                 }
            }
        }
    }

    # --- End OS-based tagging section ---


    #— Export Log to Text File
    try {
        Write-Log "Preparing to export log to text file..." "DEBUG"

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        # Use .log extension
        $logFile = Join-Path $global:logFolder ("TagPermissions_{0}.log" -f $timestamp)

        Write-Log "  Exporting log to: $($logFile)" "DEBUG"

        # Format output objects to string lines and use Out-File
        $global:outputLog | ForEach-Object {
            "$($_.Timestamp) [$($_.Level.PadRight(5))] $($_.Message)"
        } | Out-File $logFile -Encoding UTF8 -ErrorAction Stop # Use UTF8 encoding

        Write-Log "Log exported to '$($logFile)'" "INFO"
        Write-Log "  Log export successful" "DEBUG"

        # Clean up old logs (Cleanup-OldLogs function filters for *.log)
        Cleanup-OldLogs -LogFolder $global:logFolder -MaxLogsToKeep 5
    }
    catch {
        Write-Log "Log export failed: $_" "ERROR"
        Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        Write-FallbackLog "Log export failed: $_"
    }
}
catch {
    Write-Log "FATAL error: $_" "ERROR"
    Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
    Write-FallbackLog "FATAL: $_"
    throw
}
finally {
    Write-Log "Cleanup start" "INFO"
    Write-Log "  Beginning cleanup operations..." "DEBUG"

    if ($global:ssoConnected) {
        Write-Log "  SSO is connected, attempting to disconnect..." "DEBUG"

        try {
            Disconnect-SsoAdminServer -ErrorAction Stop
            $global:ssoConnected=$false
            Write-Log "SSO disconnected" "INFO"
            Write-Log "    SSO disconnect successful" "DEBUG"
        }
        catch {
            Write-Log "SSO disconnect failed: $_" "WARN"
            Write-Log "    Stack trace: $($_.ScriptStackTrace)" "DEBUG"
            Write-FallbackLog "SSO disconnect failed: $_"
        }
    } else {
        Write-Log "  SSO not connected, skipping disconnect" "DEBUG"
    }

    try {
        Write-Log "  Checking for vCenter connections..." "DEBUG"

        if ($global:DefaultVIServers.Count -gt 0) {
            Write-Log "    Found $($global:DefaultVIServers.Count) vCenter connections" "DEBUG"

            Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction Stop
            Write-Log "vCenter disconnected" "INFO"
            Write-Log "    vCenter disconnect successful" "DEBUG"
        } else {
            Write-Log "    No vCenter connections found" "DEBUG"
        }
    }
    catch {
        Write-Log "vCenter disconnect failed: $_" "WARN"
        Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        Write-FallbackLog "vCenter disconnect failed: $_"
    }

    try {
        Write-Log "  Resetting PowerCLI certificate handling..." "DEBUG"
        Set-PowerCLIConfiguration -InvalidCertificateAction Warn -Confirm:$false | Out-Null
        Write-Log "    Certificate handling reset successful" "DEBUG"
    }
    catch {
        Write-Log "Failed to reset certificate policy: $_" "WARN"
        Write-Log "  Stack trace: $($_.ScriptStackTrace)" "DEBUG"
    }

    Write-Log "Cleanup complete" "INFO"
    Write-Log "Script execution finished" "DEBUG"
}
#endregion






