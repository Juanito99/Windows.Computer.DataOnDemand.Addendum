<#
.SYNOPSIS
    Get Compupter Last Changes
.DESCRIPTION
    This script gets some last changes such as last installed SW or logged on user.
.Notes
	AUTHOR: Ruben Zimmermann @ruben8z
	LASTEDIT: 2019-12-25
	REQUIRES: PowerShell Version 2, Windows Management Foundation 4, At least Windows 7 or Windows Server 2008 R2.	
REMARK:
This PS script comes with ABSOLUTELY NO WARRANTY; for details see gnu-gpl. This is free software, and you are welcome to redistribute it under certain conditions; see gnu-gpl for details.
    
#>
Param(
    [ValidateSet("text","csv","json", "list")]
    [string] $Format = "csv"
)


$ErrorActionPreference = "stop"


$regPat         = '[0-9]{8}'
$bootInfo       = wmic os get lastbootuptime
$bootDateNumber = Select-String -InputObject $bootInfo -Pattern $regPat | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$bootDate       = ([DateTime]::ParseExact($bootDateNumber,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture))
$lastBootTime   = $bootDate | Get-Date -Format 'yyyy-MM-dd'

$timeSpan       = New-TimeSpan -Start $lastBootTime -End (Get-Date)
$UpTimeInDays   = [math]::Round($timeSpan.TotalDays,1)

		
$soft32All       = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.Publisher -notlike "*Microsoft*" } | Select-Object DisplayName, Publisher, InstallDate
$soft32Filtered  = $soft32All | Select-Object DisplayName, Publisher, @{Name='RealDate';Expression={([DateTime]::ParseExact($_.InstallDate,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture)) `
							  | Get-Date -Format 'yyyy-MM-dd'}}   

$lastInstalled32Sofware             = $soft32Filtered | Sort-Object -Property RealDate -Descending | Select-Object -First 1
$lastInstalled32SoftwareInstallDate = $lastInstalled32Sofware.RealDate | Get-Date -Format 'yyyy-MM-dd'
$lastInstalled32SoftwareName        = $lastInstalled32Sofware.DisplayName
  
$soft64All       = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.Publisher -notlike "*Microsoft*" } | `
									Select-Object DisplayName, Publisher, InstallDate

$soft64Filtered  = $soft64All | Select-Object DisplayName, Publisher, @{Name='RealDate';Expression={([DateTime]::ParseExact($_.InstallDate,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture)) `
							  | Get-Date -Format 'yyyy-MM-dd'}}   

$lastInstalled64Sofware              = $soft64Filtered | Sort-Object -Property RealDate -Descending | Select-Object -First 1
$lastInstalled64SoftwareInstallDate  = $lastInstalled64Sofware.RealDate | Get-Date -Format 'yyyy-MM-dd'
$lastInstalled64SoftwareName         = $lastInstalled64Sofware.DisplayName
  
if ($lastInstalled32SoftwareInstallDate -gt $lastInstalled64SoftwareInstallDate) {
	$lastInstalledSoftwareInstallDate = $lastInstalled32SoftwareInstallDate
	$lastInstalledSoftwareName        = $lastInstalled32SoftwareName		
} else {
	$lastInstalledSoftwareInstallDate = $lastInstalled64SoftwareInstallDate
	$lastInstalledSoftwareName        = $lastInstalled64SoftwareName		
}		


$regPat                         = 'KB[0-9]{7}'
$Session                        = New-Object -ComObject "Microsoft.Update.Session"
$Searcher                       = $Session.CreateUpdateSearcher()
$historyCount                   = $Searcher.GetTotalHistoryCount()
$allHotfixes                    = $Searcher.QueryHistory(0, $historyCount) | Select-Object Date, @{Name='KBNo';Expression={(Select-String -InputObject $_.Title -Pattern $regPat | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value)}}
$lastHotfix                     = $allHotfixes | Sort-Object -Descending -Property Date | Sort-Object -Descending -Property KBNo | Select-Object -First 1

$lastInstalledHotfixInstallDate = $lastHotfix.Date | Get-Date -Format 'yyyy-MM-dd'
$lastInstalledHotfixName        = $lastHotfix.KBNo


$noOfDaysDiff = (New-TimeSpan -Start $lastBootTime -End $lastInstalledHotfixInstallDate).Days
if($noOfDaysDiff -gt 1) {
	$patchBootPending = "Yes, for $noOfDaysDiff Days"
} else {
	$patchBootPending = "No."
}	


$profilesDir          = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' | Select-Object -ExpandProperty ProfilesDirectory
$lastLoggedOnInfo     = Get-ChildItem -Path $profilesDir | Select-Object Name, LastWriteTime | Sort-Object -Property LastwriteTime -Descending | Select-Object -First 1
$lastLoggedOnUserId   = $($lastLoggedOnInfo.Name).ToUpper()
$lastLoggedOnUserDate = $lastLoggedOnInfo.LastWriteTime | Get-Date -Format 'yyyy-MM-dd'



$myComputerDescHash = @{'Last Boot / UpTime (days)' = $($lastBootTime + ' / ' + $UpTimeInDays)}
$myComputerDescHash.Add('Last Interactive Logon', $($lastLoggedOnUserId + ' / ' + $lastLoggedOnUserDate))
$myComputerDescHash.Add('Last Software Install', $($lastInstalledSoftwareName + ' / ' + $lastInstalledSoftwareInstallDate))
$myComputerDescHash.Add('Last Hotfix Install', $($lastInstalledHotfixName + ' / ' + $lastInstalledHotfixInstallDate))
$myComputerDescHash.Add('Patch-Boot pending', $($patchBootPending))

$myComputerDescObj = New-Object -TypeName PSObject -Property $myComputerDescHash


if ($Format -eq 'text') {
    $myComputerDescObj | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host
} elseif ($Format -eq 'csv') {
    $myComputerDescObj | ConvertTo-Csv -NoTypeInformation | Out-String -Width 4096 | Write-Host
} elseif ($Format -eq 'json') {
    $myComputerDescObj | ConvertTo-Json | Out-String -Width 4096 | Write-Host
} elseif ($format -eq 'list') {
    $myComputerDescObj | Format-List | Out-String -Width 4096 | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
