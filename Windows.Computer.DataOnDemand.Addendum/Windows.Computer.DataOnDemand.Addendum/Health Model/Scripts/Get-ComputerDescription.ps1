<#
.SYNOPSIS
	Get Compupter Description
.DESCRIPTION
	This script gets the local description and the one from Active Directory
.Notes
	AUTHOR: Ruben Zimmermann @ruben8z
	LASTEDIT: 2020-09-30
	REQUIRES: PowerShell Version 4, Windows Management Foundation 4, At least Windows 7 or Windows Server 2008 R2.	
REMARK:
This PS script comes with ABSOLUTELY NO WARRANTY; for details see gnu-gpl. This is free software, and you are welcome to redistribute it under certain conditions; see gnu-gpl for details.
	
#>
Param(
	[ValidateSet("text","csv","json", "list")]
	[string] $Format = "csv"
)


$ErrorActionPreference = "stop"

try {
	$computerDescription = Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters | Select-Object -ExpandProperty srvcomment -ErrorAction Stop
} catch {
	$foo = 'swallowException'
}

if (([string]::IsNullOrEmpty($computerDescription))) {
	$computerDescription = 'Not-Maintained'
} else {
	$computerDescription = $computerDescription.Trim()
	$noActionRequired  = 'Keep description'
}


$objADSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objADSearcher.Filter = "(&(objectCategory=computer)(cn=$env:computername))"
$myComputerInAD = $objADSearcher.FindOne()
$myComputerInADAllProps = $myComputerInAD | Select-Object -ExpandProperty Properties

try {
  [string]$myComputerInADDescritpion = $myComputerInADAllProps.Item('description')
  [string]$myComputerInWhenCreated = $myComputerInADAllProps.Item('whenCreated')
} catch {
  $foo = 'swallowException'
}


if (([string]::IsNullOrEmpty($myComputerInADDescritpion))) {
	$myComputerInADDescritpion = 'Not-Maintained'
} else {
	$noActionRequired  = 'Keep description'
	$myComputerInADDescritpion = $myComputerInADDescritpion.Trim()
}

 
if (([string]::IsNullOrEmpty($myComputerInWhenCreated))) {
	$myComputerInWhenCreated = 'Not-Queryable'
} else {
	$noActionRequired  = 'Keep Information'
	$myComputerInWhenCreated = $myComputerInWhenCreated.Trim()
}

try {
	$myMemoryInGB = ((get-wmiobject -class "win32_physicalmemory" -namespace "root\CIMV2"  | Measure-Object -Property capacity -Sum) | Select-Object -ExpandProperty Sum) / 1GB
	$myMemoryInGB = $myMemoryInGB.ToString() + ' GB'
} catch {
	$myMemoryInGB = 'N/A'
}

try {
	$myCPUName    = Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty Name
	$tmpCoreCount = (Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty NumberOfCores).count
	
	if ($tmpCoreCount -gt 1) {
		$myCPUNoCores = ((Get-WmiObject -Class Win32_Processor | Select-Object -Property Name, NumberOfCores) | Select-Object -ExpandProperty NumberOfCores) -join ' / '
	} else {
		$myCPUNoCores = (Get-WmiObject -Class Win32_Processor | Select-Object -Property Name, NumberOfCores) | Select-Object -ExpandProperty NumberOfCores
	}
} catch {
	$myCPUName    = 'N/A'
	$myCPUNoCores = 'N/A'
}


$myComputerDescHash = @{'Local Info' = $computerDescription}
$myComputerDescHash.Add('AD Info', $myComputerInADDescritpion)
$myComputerDescHash.Add('AD Creation', $myComputerInWhenCreated)
$myComputerDescHash.Add('RAM Size', $myMemoryInGB)
$myComputerDescHash.Add('CPU Name', $myCPUName)
$myComputerDescHash.Add('CPU Cores', $myCPUNoCores)

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
