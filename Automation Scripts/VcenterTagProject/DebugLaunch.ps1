# Debugging Launch Script

# Set execution policy if needed
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Import required modules
Import-Module VMware.VimAutomation.Core
Import-Module VMware.VimAutomation.Common
Import-Module VMware.VimAutomation.Sdk

# Define parameters
$Environment = "DEV"
$vCenterServer = "daisv0tp231.dir.ad.dla.mil"

# Load credentials securely
$credPath = "C:\Scripts\Credentials\vCenter_Cred.xml"
$Credential = Import-CliXml -Path $credPath

# Debugging parameters
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# Path to your main script
$ScriptPath = "C:\Temp\Scripts\VcenterTagProject\set-vCenterTagPermissions.ps1"

# Splat parameters
$ScriptParams = @{
    Environment = $Environment
    vCenterServer = $vCenterServer
    Credential = $Credential
    LogOnly = $false
    Verbose = $true
    Debug = $true
}

# Run the script
& $ScriptPath @ScriptParams
