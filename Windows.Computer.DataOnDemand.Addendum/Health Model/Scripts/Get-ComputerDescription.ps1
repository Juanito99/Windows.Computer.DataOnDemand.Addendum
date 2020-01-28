<#
.SYNOPSIS
    Get Compupter Description
.DESCRIPTION
    This script gets the local description and the one from Active Directory
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

$myComputerDescHash = @{'Local Computer Description' = $computerDescription}
$myComputerDescHash.Add('AD Computer Description', $myComputerInADDescritpion)
$myComputerDescHash.Add('AD Computer CreationDate', $myComputerInWhenCreated)
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
