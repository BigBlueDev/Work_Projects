# ModuleManager.ps1
# Handles module installation, import, and tracking for AI Gen Workflow Wrapper

#region Module Management Class
class ModuleManager {
    static [hashtable] $ModuleCache = @{}
    static [string] $CacheFile = ""
    static [bool] $IsInitialized = $false
    
    # Initialize the module manager
    static [void] Initialize([string]$CacheDirectory) {
        if ([ModuleManager]::IsInitialized) { return }
        
        [ModuleManager]::CacheFile = Join-Path $CacheDirectory "module_cache.json"
        [ModuleManager]::LoadModuleCache()
        [ModuleManager]::IsInitialized = $true
        
        Write-Host "ModuleManager: Initialized with cache file: $([ModuleManager]::CacheFile)" -ForegroundColor Cyan
    }
    
    # Load module cache from file
    static [void] LoadModuleCache() {
        if (Test-Path ([ModuleManager]::CacheFile)) {
            try {
                $cacheContent = Get-Content ([ModuleManager]::CacheFile) -Raw | ConvertFrom-Json -AsHashtable
                [ModuleManager]::ModuleCache = $cacheContent
                Write-Host "ModuleManager: Loaded cache with $($cacheContent.Count) entries" -ForegroundColor Green
            } catch {
                Write-Warning "ModuleManager: Failed to load cache, starting fresh: $_"
                [ModuleManager]::ModuleCache = @{}
            }
        } else {
            [ModuleManager]::ModuleCache = @{}
            Write-Host "ModuleManager: No existing cache found, starting fresh" -ForegroundColor Yellow
        }
    }
    
    # Save module cache to file
    static [void] SaveModuleCache() {
        try {
            $cacheDir = Split-Path ([ModuleManager]::CacheFile) -Parent
            if (-not (Test-Path $cacheDir)) {
                New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            }
            
            [ModuleManager]::ModuleCache | ConvertTo-Json -Depth 10 | Set-Content ([ModuleManager]::CacheFile) -Encoding UTF8
            Write-Host "ModuleManager: Cache saved successfully" -ForegroundColor Green
        } catch {
            Write-Warning "ModuleManager: Failed to save cache: $_"
        }
    }
    
    # Check if a module is available (installed and importable)
    static [hashtable] CheckModule([string]$ModuleName, [string]$MinVersion = "", [bool]$UseCache = $true) {
        $cacheKey = "$ModuleName|$MinVersion"
        $currentTime = Get-Date
        
        # Check cache first (if enabled and entry is less than 24 hours old)
        if ($UseCache -and [ModuleManager]::ModuleCache.ContainsKey($cacheKey)) {
            $cacheEntry = [ModuleManager]::ModuleCache[$cacheKey]
            $cacheAge = $currentTime - [DateTime]$cacheEntry.LastChecked
            
            if ($cacheAge.TotalHours -lt 24) {
                Write-Host "ModuleManager: Using cached result for $ModuleName" -ForegroundColor Gray
                return $cacheEntry
            }
        }
        
        # Perform actual module check
        $result = @{
            ModuleName = $ModuleName
            MinVersion = $MinVersion
            IsInstalled = $false
            IsImported = $false
            InstalledVersion = $null
            ImportedVersion = $null
            LastChecked = $currentTime
            Source = "Unknown"
            CanImport = $false
        }
        
        try {
            # Check if module is installed
            $installedModule = Get-Module -Name $ModuleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            
            if ($installedModule) {
                $result.IsInstalled = $true
                $result.InstalledVersion = $installedModule.Version.ToString()
                $result.Source = if ($installedModule.ModuleBase -like "*Program Files*") { "System" } else { "User" }
                
                # Check version requirement
                if ([string]::IsNullOrEmpty($MinVersion) -or $installedModule.Version -ge [Version]$MinVersion) {
                    $result.CanImport = $true
                }
            }
            
            # Check if module is currently imported
            $importedModule = Get-Module -Name $ModuleName
            if ($importedModule) {
                $result.IsImported = $true
                $result.ImportedVersion = $importedModule.Version.ToString()
            }
            
        } catch {
            Write-Warning "ModuleManager: Error checking module $ModuleName`: $_"
        }
        
        # Update cache
        [ModuleManager]::ModuleCache[$cacheKey] = $result
        [ModuleManager]::SaveModuleCache()
        
        return $result
    }
    
    # Install a module if not available
    static [bool] EnsureModule([string]$ModuleName, [string]$MinVersion = "", [string]$Scope = "CurrentUser") {
        $moduleInfo = [ModuleManager]::CheckModule($ModuleName, $MinVersion, $true)
        
        # If module is already available and importable, just import it
        if ($moduleInfo.CanImport) {
            return [ModuleManager]::ImportModule($ModuleName)
        }
        
        # If module is not installed or doesn't meet version requirement, install it
        if (-not $moduleInfo.IsInstalled -or -not $moduleInfo.CanImport) {
            Write-Host "ModuleManager: Installing module $ModuleName..." -ForegroundColor Yellow
            
            try {
                $installParams = @{
                    Name = $ModuleName
                    Scope = $Scope
                    Force = $true
                    AllowClobber = $true
                }
                
                if (-not [string]::IsNullOrEmpty($MinVersion)) {
                    $installParams.MinimumVersion = $MinVersion
                }
                
                Install-Module @installParams
                Write-Host "ModuleManager: Successfully installed $ModuleName" -ForegroundColor Green
                
                # Clear cache for this module to force recheck
                $cacheKey = "$ModuleName|$MinVersion"
                if ([ModuleManager]::ModuleCache.ContainsKey($cacheKey)) {
                    [ModuleManager]::ModuleCache.Remove($cacheKey)
                }
                
                # Try to import the newly installed module
                return [ModuleManager]::ImportModule($ModuleName)
                
            } catch {
                Write-Error "ModuleManager: Failed to install module $ModuleName`: $_"
                return $false
            }
        }
        
        return $false
    }
    
    # Import a module
    static [bool] ImportModule([string]$ModuleName) {
        try {
            $moduleInfo = [ModuleManager]::CheckModule($ModuleName, "", $false)  # Skip cache for import check
            
            if ($moduleInfo.IsImported) {
                Write-Host "ModuleManager: Module $ModuleName is already imported (v$($moduleInfo.ImportedVersion))" -ForegroundColor Gray
                return $true
            }
            
            if ($moduleInfo.IsInstalled) {
                Write-Host "ModuleManager: Importing module $ModuleName..." -ForegroundColor Yellow
                Import-Module -Name $ModuleName -Force
                Write-Host "ModuleManager: Successfully imported $ModuleName" -ForegroundColor Green
                return $true
            } else {
                Write-Warning "ModuleManager: Cannot import $ModuleName - module is not installed"
                return $false
            }
            
        } catch {
            Write-Error "ModuleManager: Failed to import module $ModuleName`: $_"
            return $false
        }
    }
    
    # Get module status report
    static [hashtable[]] GetModuleReport([string[]]$ModuleNames) {
        $report = @()
        
        foreach ($moduleName in $ModuleNames) {
            $moduleInfo = [ModuleManager]::CheckModule($moduleName, "", $true)
            $report += $moduleInfo
        }
        
        return $report
    }
    
    # Clear module cache
    static [void] ClearCache() {
        [ModuleManager]::ModuleCache = @{}
        if (Test-Path ([ModuleManager]::CacheFile)) {
            Remove-Item ([ModuleManager]::CacheFile) -Force
        }
        Write-Host "ModuleManager: Cache cleared" -ForegroundColor Yellow
    }
}
#endregion

#region Convenience Functions
function Initialize-ModuleManager {
    param([string]$CacheDirectory = (Join-Path $env:TEMP "AI_Gen_Workflow_Wrapper"))
    [ModuleManager]::Initialize($CacheDirectory)
}

function Test-ModuleAvailable {
    param(
        [string]$ModuleName,
        [string]$MinVersion = ""
    )
    $result = [ModuleManager]::CheckModule($ModuleName, $MinVersion, $true)
    return $result.CanImport
}

function Install-RequiredModule {
    param(
        [string]$ModuleName,
        [string]$MinVersion = "",
        [string]$Scope = "CurrentUser"
    )
    return [ModuleManager]::EnsureModule($ModuleName, $MinVersion, $Scope)
}

function Import-RequiredModule {
    param([string]$ModuleName)
    return [ModuleManager]::ImportModule($ModuleName)
}

function Get-ModuleStatus {
    param([string[]]$ModuleNames)
    return [ModuleManager]::GetModuleReport($ModuleNames)
}

function Clear-ModuleCache {
    [ModuleManager]::ClearCache()
}
#endregion

# Functions are available globally when dot-sourced (no Export-ModuleMember needed)
Write-Host "ModuleManager: Functions loaded successfully" -ForegroundColor Green
