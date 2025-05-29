# MigrateToNestedStructure.ps1
# Migrates existing Config and Logs folders into Data folder

param(
    [switch]$WhatIf = $false,
    [switch]$BackupFirst = $true
)

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "=== Migrating to Nested Folder Structure ===" -ForegroundColor Green
Write-Host "Root Directory: $rootDir" -ForegroundColor Cyan

# Create backup if requested
if ($BackupFirst) {
    $backupDir = Join-Path $rootDir "Backup_BeforeMigration_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "Creating backup: $backupDir" -ForegroundColor Yellow
    
    if (-not $WhatIf) {
        try {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            
            # Backup existing folders
            @('Config', 'Logs', 'Data') | ForEach-Object {
                $sourcePath = Join-Path $rootDir $_
                if (Test-Path $sourcePath) {
                    $destPath = Join-Path $backupDir $_
                    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
                    Write-Host "  ? Backed up: $_" -ForegroundColor Green
                }
            }
        } catch {
            Write-Error "Backup failed: $_"
            exit 1
        }
    } else {
        Write-Host "  [WhatIf] Would create backup at: $backupDir" -ForegroundColor Gray
    }
}

# Migration plan
$migrations = @(
    @{
        Source = Join-Path $rootDir "Config"
        Destination = Join-Path $rootDir "Data\Config"
        Description = "Move Config folder into Data"
    },
    @{
        Source = Join-Path $rootDir "Logs" 
        Destination = Join-Path $rootDir "Data\Logs"
        Description = "Move Logs folder into Data"
    }
)

# Ensure Data directory exists
$dataDir = Join-Path $rootDir "Data"
if (-not (Test-Path $dataDir)) {
    Write-Host "Creating Data directory: $dataDir" -ForegroundColor Yellow
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
}

# Perform migrations
foreach ($migration in $migrations) {
    Write-Host "`n--- $($migration.Description) ---" -ForegroundColor Cyan
    
    if (Test-Path $migration.Source) {
        Write-Host "Source exists: $($migration.Source)" -ForegroundColor Green
        
        # Check if destination already exists
        if (Test-Path $migration.Destination) {
            Write-Host "? Destination already exists: $($migration.Destination)" -ForegroundColor Yellow
            
            if ($WhatIf) {
                Write-Host "  [WhatIf] Would merge contents" -ForegroundColor Gray
            } else {
                # Merge contents
                Write-Host "  Merging contents..." -ForegroundColor Yellow
                try {
                    Get-ChildItem -Path $migration.Source -Recurse | ForEach-Object {
                        $relativePath = $_.FullName.Substring($migration.Source.Length + 1)
                        $destFile = Join-Path $migration.Destination $relativePath
                        $destDir = Split-Path -Parent $destFile
                        
                        if (-not (Test-Path $destDir)) {
                            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                        }
                        
                        if ($_.PSIsContainer) {
                            if (-not (Test-Path $destFile)) {
                                New-Item -ItemType Directory -Path $destFile -Force | Out-Null
                            }
                        } else {
                            Copy-Item -Path $_.FullName -Destination $destFile -Force
                            Write-Host "    Merged: $relativePath" -ForegroundColor Gray
                        }
                    }
                    
                    # Remove original after successful merge
                    Remove-Item -Path $migration.Source -Recurse -Force
                    Write-Host "  ? Migration completed successfully" -ForegroundColor Green
                    
                } catch {
                    Write-Error "  ? Migration failed: $_"
                }
            }
        } else {
            # Simple move
            if ($WhatIf) {
                Write-Host "  [WhatIf] Would move to: $($migration.Destination)" -ForegroundColor Gray
            } else {
                try {
                    # Ensure destination directory exists
                    $destParent = Split-Path -Parent $migration.Destination
                    if (-not (Test-Path $destParent)) {
                        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
                    }
                    
                    Move-Item -Path $migration.Source -Destination $migration.Destination -Force
                    Write-Host "  ? Moved successfully" -ForegroundColor Green
                } catch {
                    Write-Error "  ? Move failed: $_"
                }
            }
        }
    } else {
        Write-Host "Source not found: $($migration.Source)" -ForegroundColor Gray
        Write-Host "  (Nothing to migrate)" -ForegroundColor Gray
    }
}

# Validate new structure
Write-Host "`n--- Validating New Structure ---" -ForegroundColor Cyan
$expectedDirs = @(
    'Data',
    'Data\Config', 
    'Data\Logs',
    'Data\Temp',
    'Data\Scripts',
    'Data\Exports',
    'Data\Imports',
    'Data\Backups',
    'Data\Reports',
    'Data\Cache',
    'Resources'
)

foreach ($dir in $expectedDirs) {
    $fullPath = Join-Path $rootDir $dir
    if (Test-Path $fullPath) {
        Write-Host "  ? $dir" -ForegroundColor Green
    } else {
        Write-Host "  ? $dir (Missing)" -ForegroundColor Red
        if (-not $WhatIf) {
            try {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                Write-Host "    ? Created" -ForegroundColor Yellow
            } catch {
                Write-Host "    ? Failed to create: $_" -ForegroundColor Red
            }
        }
    }
}

if ($WhatIf) {
    Write-Host "`n=== WhatIf Summary ===" -ForegroundColor Yellow
    Write-Host "No actual changes were made. Run without -WhatIf to perform migration." -ForegroundColor Yellow
} else {
    Write-Host "`n=== Migration Complete ===" -ForegroundColor Green
    Write-Host "Folder structure has been updated to use nested directories." -ForegroundColor Green
    Write-Host "You can now delete the backup folder if everything is working correctly." -ForegroundColor Cyan
}
