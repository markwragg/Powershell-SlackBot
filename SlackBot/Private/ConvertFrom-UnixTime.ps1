Function ConvertFrom-UnixTime {
<#
.SYNOPSIS
  ConvertFrom-UnixTime converts Unix timestamps to a PowerShell datetime object.
.PARAMETER UnixTime
  And integer representing the unix formatted time.
.EXAMPLE
  1489664257 | ConvertFrom-UnixTime
.EXAMPLE
  ConvertFrom-UnixTime -UnixTime 1489664257
.LINK
  https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
#>  
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Int32]$UnixTime
    )

    BEGIN {
        $StartDate = Get-Date –Date '01/01/1970' 
    }
    PROCESS {
        $TimeSpan = New-Timespan -Seconds $UnixTime
        $StartDate + $TimeSpan
    }
}