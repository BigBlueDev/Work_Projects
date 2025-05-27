# ValidateStructure.ps1
# Run this to validate your folder structure

param(
    [switch]$CreateMissing = $false,
    [switch]$Detailed = $false
)

$scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)

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
    "MainForm\App\Forms\Globals.ps1"
)

$optionalFiles = @(
    "MainForm\App\Forms\SubForm\EditParam.designer.ps1",
    "MainForm\App\Forms\SubForm\EditParam.ps1",
    "MainForm\App\Launch.ps1"
)

Write-Host "=== AI Gen Workflow Wrapper - Structure Validation ===" -ForegroundColor Green
Write-Host "Root Directory: $scriptRoot" -ForegroundColor Cyan

# Check folders
Write-Host "`n--- Checking Folders ---" -ForegroundColor Cyan
$folderIssues = 0
foreach ($folder in $expectedFolders) {
    $fullPath = Join-Path $scriptRoot $folder
    if (Test-Path $fullPath) {
        Write-Host "✓ $folder" -ForegroundColor Green
        if ($Detailed) {
            $itemCount = (Get-ChildItem -Path $fullPath -ErrorAction SilentlyContinue).Count
            Write-Host "  Contains $itemCount items" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ $folder (Missing)" -ForegroundColor Red
        $folderIssues++
        
        if ($CreateMissing) {
            try {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                Write-Host "  → Created folder: $folder" -ForegroundColor Yellow
            } catch {
                Write-Host "  → Failed to create: $folder - $_" -ForegroundColor Red
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
        Write-Host "✓ $file" -ForegroundColor Green
        if ($Detailed) {
            $fileSize = [math]::Round((Get-Item $fullPath).Length / 1KB, 2)
            Write-Host "  Size: $fileSize KB" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ $file (Missing)" -ForegroundColor Red
        $fileIssues++
    }
}

# Check optional files
Write-Host "`n--- Checking Optional Files ---" -ForegroundColor Cyan
$optionalIssues = 0
foreach ($file in $optionalFiles) {
    $fullPath = Join-Path $scriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "✓ $file" -ForegroundColor Green
        if ($Detailed) {
            $fileSize = [math]::Round((Get-Item $fullPath).Length / 1KB, 2)
            Write-Host "  Size: $fileSize KB" -ForegroundColor Gray
        }
    } else {
        Write-Host "⚠ $file (Optional - Missing)" -ForegroundColor Yellow
        $optionalIssues++
    }
}

# Summary
Write-Host "`n--- Validation Summary ---" -ForegroundColor Cyan
Write-Host "Folders: " -NoNewline
if ($folderIssues -eq 0) {
    Write-Host "All OK ($($expectedFolders.Count)/$($expectedFolders.Count))" -ForegroundColor Green
} else {
    Write-Host "$folderIssues issues found" -ForegroundColor Red
}

Write-Host "Required Files: " -NoNewline
if ($fileIssues -eq 0) {
    Write-Host "All OK ($($requiredFiles.Count)/$($requiredFiles.Count))" -ForegroundColor Green
} else {
    Write-Host "$fileIssues missing" -ForegroundColor Red
}

Write-Host "Optional Files: " -NoNewline
if ($optionalIssues -eq 0) {
    Write-Host "All present ($($optionalFiles.Count)/$($optionalFiles.Count))" -ForegroundColor Green
} else {
    Write-Host "$optionalIssues missing (non-critical)" -ForegroundColor Yellow
}

if ($folderIssues -eq 0 -and $fileIssues -eq 0) {
    Write-Host "`n✓ Project structure is valid!" -ForegroundColor Green
} else {
    Write-Host "`n⚠ Project structure needs attention" -ForegroundColor Yellow
    
    if ($folderIssues -gt 0) {
        Write-Host "Run with -CreateMissing to create missing folders" -ForegroundColor Cyan
    }
    
    if ($fileIssues -gt 0) {
        Write-Host "Missing required files need to be restored or recreated" -ForegroundColor Cyan
    }
}

Write-Host "`nTo run: .\Config\ValidateStructure.ps1 [-CreateMissing] [-Detailed]" -ForegroundColor Cyan
Write-Host "Validation Complete!" -ForegroundColor Green
