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
$lastInstallFlag       = 'Fine'

$regPat         = '[0-9]{8}'
$bootInfo       = wmic os get lastbootuptime
$bootDateNumber = Select-String -InputObject $bootInfo -Pattern $regPat | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$bootDate       = ([DateTime]::ParseExact($bootDateNumber,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture))
$lastBootTime   = $bootDate | Get-Date -Format 'yyyy-MM-dd'

$timeSpan       = New-TimeSpan -Start $lastBootTime -End (Get-Date)
$UpTimeInDays   = [math]::Round($timeSpan.TotalDays,1)

try {
	$soft32All       = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.Publisher -notlike "*Microsoft*" } | Select-Object DisplayName, Publisher, InstallDate
	$soft32Filtered  = $soft32All | Select-Object DisplayName, Publisher, @{Name='RealDate';Expression={([DateTime]::ParseExact($_.InstallDate,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture)) `
							  | Get-Date -Format 'yyyy-MM-dd'}}   

	$lastInstalled32Sofware             = $soft32Filtered | Sort-Object -Property RealDate -Descending | Select-Object -First 1
	$lastInstalled32SoftwareInstallDate = $lastInstalled32Sofware.RealDate | Get-Date -Format 'yyyy-MM-dd'
	$lastInstalled32SoftwareName        = $lastInstalled32Sofware.DisplayName
} catch {
	$lastInstalled32SoftwareInstallDate = 'Not Available'
	$lastInstalled32SoftwareName        = 'Not Available'
	$lastInstallFlag                     = 'Error'
}
  
try {
	$soft64All       = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.Publisher -notlike "*Microsoft*" } | `
										Select-Object DisplayName, Publisher, InstallDate

	$soft64Filtered  = $soft64All | Select-Object DisplayName, Publisher, @{Name='RealDate';Expression={([DateTime]::ParseExact($_.InstallDate,'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture)) `
								  | Get-Date -Format 'yyyy-MM-dd'}}   

	$lastInstalled64Sofware              = $soft64Filtered | Sort-Object -Property RealDate -Descending | Select-Object -First 1
	$lastInstalled64SoftwareInstallDate  = $lastInstalled64Sofware.RealDate | Get-Date -Format 'yyyy-MM-dd'
	$lastInstalled64SoftwareName         = $lastInstalled64Sofware.DisplayName
} catch{
	$lastInstalled64SoftwareInstallDate  = 'Not Available'
	$lastInstalled64SoftwareName         = 'Not Available'
	$lastInstallFlag                     = 'Error'
}

if ($lastInstallFlag -eq 'Fine')  {
	if ($lastInstalled32SoftwareInstallDate -gt $lastInstalled64SoftwareInstallDate) {
		$lastInstalledSoftwareInstallDate = $lastInstalled32SoftwareInstallDate
		$lastInstalledSoftwareName        = $lastInstalled32SoftwareName		
	} else {
		$lastInstalledSoftwareInstallDate = $lastInstalled64SoftwareInstallDate
		$lastInstalledSoftwareName        = $lastInstalled64SoftwareName		
	}		
} else {
	$lastInstalledSoftwareInstallDate = 'Not Available'
	$lastInstalledSoftwareName        = 'Not Available'
}

try {
	$regPat                         = 'KB[0-9]{7}'
	$Session                        = New-Object -ComObject "Microsoft.Update.Session"
	$Searcher                       = $Session.CreateUpdateSearcher()
	$historyCount                   = $Searcher.GetTotalHistoryCount()
	$allHotfixes                    = $Searcher.QueryHistory(0, $historyCount) | Select-Object Date, @{Name='KBNo';Expression={(Select-String -InputObject $_.Title -Pattern $regPat | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value)}}
	$lastHotfix                     = $allHotfixes | Sort-Object -Descending -Property Date | Sort-Object -Descending -Property KBNo | Select-Object -First 1

	$lastInstalledHotfixInstallDate = $lastHotfix.Date | Get-Date -Format 'yyyy-MM-dd'
	$lastInstalledHotfixName        = $lastHotfix.KBNo
} catch{
	$lastInstalledHotfixInstallDate = 'Not Available'
	$lastInstalledHotfixName        = 'Not Available'
}


try {
	$noOfDaysDiff = (New-TimeSpan -Start $lastBootTime -End $lastInstalledHotfixInstallDate).Days
	if($noOfDaysDiff -gt 1) {
		$patchBootPending = "Yes, for $noOfDaysDiff Days"
	} else {
		$patchBootPending = "No."
	}
} catch {
	$patchBootPending = 'Not Available'
}
		

try {
	$profilesDir          = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' | Select-Object -ExpandProperty ProfilesDirectory
	$lastLoggedOnInfo     = Get-ChildItem -Path $profilesDir | Select-Object Name, LastWriteTime | Sort-Object -Property LastwriteTime -Descending | Select-Object -First 1
	$lastLoggedOnUserId   = $($lastLoggedOnInfo.Name).ToUpper()
	$lastLoggedOnUserDate = $lastLoggedOnInfo.LastWriteTime | Get-Date -Format 'yyyy-MM-dd'
} catch{
	$lastLoggedOnUserId   = 'Not Available'
	$lastLoggedOnUserDate = 'Not Available'
}


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
