# Config/ValidateStructure.ps1
# Validation script for current flat structure

param(
    [switch]$CreateMissing = $false,
    [switch]$Detailed = $false
)

$scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)

$expectedFolders = @(
    "Config", 
    "Logs",
    "Data",
    "Resources"
)

$requiredFiles = @(
    "Launch.ps1",
    "AI_Gen_Workflow_Wrapper.designer.ps1",
    "AI_Gen_Workflow_Wrapper.ps1",
    "Globals.ps1"
)

$optionalFiles = @(
    "EditParam.designer.ps1",
    "EditParam.ps1"
)

Write-Host "=== AI Gen Workflow Wrapper - Structure Validation ===" -ForegroundColor Green
Write-Host "Root Directory: $scriptRoot" -ForegroundColor Cyan

# Check folders
Write-Host "`n--- Checking Folders ---" -ForegroundColor Cyan
$folderIssues = 0
foreach ($folder in $expectedFolders) {
    $fullPath = Join-Path $scriptRoot $folder
    if (Test-Path $fullPath) {
        Write-Host "? $folder" -ForegroundColor Green
        if ($Detailed) {
            $itemCount = (Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue).Count
            Write-Host "  Contains $itemCount items" -ForegroundColor Gray
        }
    } else {
        Write-Host "? $folder (Missing)" -ForegroundColor Red
        $folderIssues++
        
        if ($CreateMissing) {
            try {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                Write-Host "  ? Created folder: $folder" -ForegroundColor Yellow
            } catch {
                Write-Host "  ? Failed to create: $folder - $_" -ForegroundColor Red
            }
        }
    }
}

# Check required files
Write-Host "`n--- Checking Required Files ---" -ForegroundColor Cyan
$fileIssues = 0
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $scriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "? $file" -ForegroundColor Green
        if ($Detailed) {
            $fileSize = [math]::Round((Get-Item $fullPath).Length / 1KB, 2)
            Write-Host "  Size: $fileSize KB" -ForegroundColor Gray
        }
    } else {
        Write-Host "? $file (Missing)" -ForegroundColor Red
        $fileIssues++
    }
}

# Check optional files
Write-Host "`n--- Checking Optional Files ---" -ForegroundColor Cyan
foreach ($file in $optionalFiles) {
    $fullPath = Join-Path $scriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "? $file" -ForegroundColor Green
    } else {
        Write-Host "? $file (Optional - Missing)" -ForegroundColor Yellow
    }
}

if ($folderIssues -eq 0 -and $fileIssues -eq 0) {
    Write-Host "`n? Project structure is valid!" -ForegroundColor Green
} else {
    Write-Host "`n? Project structure needs attention" -ForegroundColor Yellow
}

Write-Host "`nTo run: .\Config\ValidateStructure.ps1 [-CreateMissing] [-Detailed]" -ForegroundColor Cyan
Write-Host "Validation Complete!" -ForegroundColor Green
