# Sample PowerCLI Script with Enhanced Error Handling
param(
    [string]$SourcevCenter,
    [string]$TargetvCenter,
    [PSCredential]$SourceCredential,
    [PSCredential]$TargetCredential
)

try {
    # Your script logic here
    Write-Output "Starting script execution..."
    
    # Example: Throw an error to test error reporting
    # Uncomment the line below to test error reporting
    # throw "This is a test error"
    
    # Example: Access a non-existent property to test error reporting
    # $null.Property
    
    Write-Output "Script completed successfully"
}
catch {
    # Detailed error output
    Write-Error "Error in script execution: $_"
    Write-Error "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Error "Stack Trace: $($_.ScriptStackTrace)"
    
    # Re-throw the error to ensure the job fails properly
    throw
}
finally {
    # Cleanup code here (always runs)
    Write-Output "Performing cleanup operations..."
}
