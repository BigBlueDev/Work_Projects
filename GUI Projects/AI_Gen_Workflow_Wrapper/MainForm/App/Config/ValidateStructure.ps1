# ValidateStructure.ps1
# Run this to validate your folder structure

$expectedFolders = @(
    "MainForm",
    "MainForm\App", 
    "MainForm\App\Forms",
    "MainForm\App\Forms\SubForm",
    "Resources",
    "Config", 
    "Logs",
    "Data"
)

$requiredFiles = @(
    "Launch.ps1",
    "MainForm\App\Forms\AI_Gen_Workflow_Wrapper.designer.ps1",
    "MainForm\App\Forms\AI_Gen_Workflow_Wrapper.ps1", 
    "MainForm\App\Forms\Globals.ps1",
    "MainForm\App\Forms\SubForm\EditParam.designer.ps1",
    "MainForm\App\Forms\SubForm\EditParam.ps1"
)

Write-Host "=== Folder Structure Validation ===" -ForegroundColor Green

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Check folders
Write-Host "`nChecking Folders:" -ForegroundColor Cyan
foreach ($folder in $expectedFolders) {
    $fullPath = Join-Path $scriptRoot $folder
    if (Test-Path $fullPath) {
        Write-Host "? $folder" -ForegroundColor Green
    } else {
        Write-Host "? $folder (Missing)" -ForegroundColor Red
        # Create missing folder
        try {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            Write-Host "  ? Created folder: $folder" -ForegroundColor Yellow
        } catch {
            Write-Host "  ? Failed to create: $folder" -ForegroundColor Red
        }
    }
}

# Check files
Write-Host "`nChecking Required Files:" -ForegroundColor Cyan
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $scriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "? $file" -ForegroundColor Green
    } else {
        Write-Host "? $file (Missing)" -ForegroundColor Red
    }
}

Write-Host "`nValidation Complete!" -ForegroundColor Green
