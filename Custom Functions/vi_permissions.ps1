#Load PowerCLI Modules
Import-module VMware.PowerCLI
$pscred = Get-Credential -UserName "svc_VPM_Powershell@DLA-Test-Dev.local"
#Get the Credentials

#Connect to vCenter
Connect-VIServer -Server $creds.host -Credential $pscred -Force

#Tags
$DataTable =  @()
     

$Support_Cat = [PSCustomObject]@{ 
    Category = "Support-Teams"
    Valid = $null
    Tags= @(
        [PSCustomObject]@{
            Tag = "Exchange-Admin-Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Enterprise Exchange Team"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DIR\ServerAdmin_RBAC-M_J64 Directory Services Exchange Team"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Windows-Server-Admin-Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Windows Server Team"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DLA-TEST-DEV.LOCAL\Windows Server Team"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "ACAS-Admin-Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "ACAS_Admin_Team"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DIR\svc_acas_gscan"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Storage_Admin_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "NetBackup Management"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DIR\J64 TFS Storage Management Admins"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "IO_Test_Center_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Enterprise Test Center IO Admins"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DLA-TEST-DEV.LOCAL\Enterprise Test Center IO Admins"
                            Valid = $null
                        }
                    ) 
                }
            )
        },
        [PSCustomObject]@{
            Category = "NTS-WAN_Admin_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Enterprise - NTS WAN Management"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DIR\ServerAdmin_RBAC_M_J64 NTS LAN Management"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "SCOM_Admin_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Enterprise SCOM Team"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DLA-Test-Dev.local\Enterprise SCOM Team"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Backup_Admin_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "NetBackup Management"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DLA-Test-Dev.local\NetBackup Management"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Unix_Admin_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Unix Server Team"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DIR\ServerAdmin_RBAC_M_J64 Unix Administrators"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Domain_Services_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Enterprise AD Server Team"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DIR\ServerAdmin_RBAC_M_J64 Directory Services"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Cert_Response_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Enterprise CERT Incident Response Team"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DLA-Test-Dev.local\Enterprise CERT Incident Response Team"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Database_Admin_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Database Administrators"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DLA-Test-Dev.local\Database Administrators"
                            Valid = $null
                        }
                    )
                }
            )
        },
        [PSCustomObject]@{
            Category = "Domain_Admin_Team"
            Valid = $null
            Roles = @(
                [PSCustomObject]@{
                    Role = "Enterprise DC Admin Team-temp"
                    Valid = $null
                    Permissions = @(
                        [PSCustomObject]@{
                            Right = "DLA-Test-Dev.local\Database Administrators"
                            Valid = $null
                        }
                    )
                }
            )
        }
    )
}

$DataTable += $Support_Cat




#$VMs = Get-VM
$VerbosePreference =  "Ignore"
try {
    foreach ($category in $Categories) 
    {            
        if (-not($null -eq $Category)){
            write-host "Category: $($category.name)"
            try{
                $Category_Check = Get-TagCategory -name $Category.Name -ErrorAction SilentlyContinue
                $category.valid = $true
                write-host "`tSource:`t$($Category.Name.ToString())"
                write-host "`tTarget:`t$($Category_Check.Name)"
            }
            catch{
                $category.Valid = $false 
                Write-warning "Unable to collect Current Tags"
            }
            Write-host "`tCategory Valid: `t$($Category.name)"
        }
        Else
        {
            Write-host "`tSource: Category Not found: `t$($Category.name)"
            Write-host "`ttarget: Category Does not match: `t$($Category_Check.Name)"
            break
        }
        foreach ($tag in $category){

            
        }
        {

            if ($item.role)
            {write-host "Role:"
                try{
                    $Role_check = Get-VIRole -name $str_Role -ErrorAction SilentlyContinue
                    $str_Role = $item.Role.ToString()
                    Write-host "`tSource:`t$($str_Role)"
                    Write-host "`tTarget:`t$($Role_check.Name)"
                    $role = $true
                }
                catch{
                    $role = $false
                    Write-warning "`tRole not assigned: `t$($item.Tag)"
                }
                Write-host "`tRole Valid:`t$($Role)"
            }
            Else
            {
                Write-host "`tSource: Role Not found: `t$($str_Role)"
                Write-host "`tTarget: Role Does not match: `t$($Role_check.Name)"
            }
            if ($item.Tag) 
            {write-host "Tag:"
                try{
                    $Tag_check = Get-Tag -Name $item.Tag.ToString -ErrorAction SilentlyContinue
                    $tag = $true
                    Write-host "`tSource: `t$($item.Tag.ToString())"
                    Write-host "`tTarget: `t$($Tag_check.Name)"
                }
                catch{
                    $tag = $false
                    Write-warning "Tag not found: `t$($item.Tag)"
                }
                Write-host "`tTag Valid: `t$($tag)"
            }
            Else
            {
                Write-host "`tSource: Tag not found: `t$($item.Tag)"
                Write-host "`tTarget: Tag Does not match: `t$($Tag_check.Name)"
            }
            if ($item.Principal) 
            {write-host "Principal:"
                try{
                    $Principal_check = Get-VIPermission -Principal $item.Principal -ErrorAction SilentlyContinue
                    Write-host "`tSource: `t$($item.Principal.ToString())"
                    Write-host "`tTarget: `t$($Principal_check)"
                    $Principal = $true
                }
                catch{
                    $Principal = $false
                    Write-warning "Principal Permision not found: `t$($item.Tag)"
                }
                Write-host "`tPrincipal Valid: `t$($Principal)"
            }
            Else
            {
                Write-host "`tSource: Principal Not found: `t$($item.Principal)"
                Write-host "`tTarget: Principal Does not match: `t$($Principal_check)"
            }
        }
    }
}
catch {

}
#$TAGS = Get-TagAssignment -Entity $VM | Select @{l='SupportTeam';e={('{0}/{1}' -f $_.tag.category, $_.tag.name)}}, Entity

#If ($TAGS.SupportTeam -contains $dbaT)  {New-VIPermission -Principal $dbaG -Role $dbaR -Entity $vm.name} Else {Get-VIPermission -Entity $vm.Name -Principal $dbaG | Remove-VIPermission -Confirm:$false}