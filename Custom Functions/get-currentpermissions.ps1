$report = Get-VIPermission |

Select Principal,Role,@{n='Entity';E={$_.Entity.Name}},@{N='Entity Type';E={$_.EntityId.Split('-')[0]}},@{N='vCenter';E={$_.Uid.Split('@:')[1]}}

$report = foreach($row in $report){

    Get-VIRole -Name $row.Role | Select -ExpandProperty PrivilegeList | %{

        Add-Member -InputObject $row -MemberType NoteProperty -Name $_ -Value 'y'

    }

    $row

}

$report |

Sort-Object -Property {$_ | Get-Member | Measure-Object | Select -ExpandProperty Count} -Descending |

Export-Excel -Path C:\report.xlsx -WorksheetName Security