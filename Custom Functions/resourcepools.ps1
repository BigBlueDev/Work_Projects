$clusterName = "DLA_Dayton_Dev"
$rp_created = 0
$i = 0

$csv = Import-Csv rp-export.csv -UseCulture
$rp_total = $csv.name.count

foreach($row in $csv){


    Write-Progress -PercentComplete ($i*100/$rp_total) -Activity "Status: getting cluster list"
    write-host "Status: getting cluster list"
    Write-Progress -Activity "Status: getting cluster list" -Status "$i of $rp_total"

    $skip = $false
    $cl = Get-Cluster -Name $clustername -ErrorAction SilentlyContinue
    if(-not $cl){
      write-Progress -Activity "cluster name error"
      write-host "cluster name error"
      start-sleep -Seconds 10
      $skip = $true
    }
    if(-not($skip)){
        write-host "$i of $rp_total"

        Try {
          write-host "cluster name: $cl"
          $location = Get-ResourcePool -Name $row.name -Location $cl -ErrorAction Stop
          write-Progress -Activity "Checking for existing resource pool" -status "$row.name error"
          write-host -NoNewline "`t$row.name error"

        }
        Catch {
            $sPool = @{
              Location = $Location
              Name = $row.name
              CpuSharesLevel = "Custom"
              NumCpuShares = [int]($row.NumCpuShares)
              CpuReservationMHz = [long]($row.CpuReservationMHz)
              CpuExpandableReservation = ([System.Convert]::ToBoolean($row.CpuExpandableReservation))
              CpuLimitMHz = [long]($row.CpuLimitMHz)
              MemSharesLevel = "Custom"
              NumMemShares = [int]($row.NumMemShares)
              MemReservationMB = [long]($row.MemReservationMB)
              MemExpandableReservation = ([System.Convert]::ToBoolean($row.MemExpandableReservation))
              MemLimitMB = [long]($row.MemLimitMB)
            }
            $details = $spool | format-table
            write-host $details
            $rp = New-ResourcePool @spool -verbose
            if ($rp) {$rp_created++}
            write-progress -Status "creating resource pool" -activity "$row.name"

            start-sleep -Milliseconds 2
            $i++
        }
      }
   write-progress -completed -Activity " "}