# Sample PowerCLI script to connect to vCenter servers
param(
    [string]$SourcevCenter,
    [string]$TargetvCenter,
    [PSCredential]$SourceCredential,
    [PSCredential]$TargetCredential
)

Write-Output "Connecting to source vCenter: $SourcevCenter"
Connect-VIServer -Server $SourcevCenter -Credential $SourceCredential -ErrorAction Stop

Write-Output "Connecting to target vCenter: $TargetvCenter"
Connect-VIServer -Server $TargetvCenter -Credential $TargetCredential -ErrorAction Stop

Write-Output "Successfully connected to both vCenter servers"
