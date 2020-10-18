<#
.SYNOPSIS
	Retrieves information from MS Graph / MS Graph Beta
.DESCRIPTION
	Retrieves information from MS Graph / MS Graph Beta and returns JSON or CSV
.Notes
	AUTHOR: Ruben Zimmermann @ruben8z
	LASTEDIT: 2020-08-09
	REQUIRES: PowerShell Version 4, Windows Management Foundation 4, At least Windows 7 or Windows Server 2008 R2.	
REMARK:
This PS script comes with ABSOLUTELY NO WARRANTY; for details see gnu-gpl. This is free software, and you are welcome to redistribute it under certain conditions; see gnu-gpl for details.
	
#>
Param(
	[ValidateSet('text','list','json')]
	[string]$Format = "json",
	[string]$WebServiceUrl = '',
	[string]$GraphQry = '',
	[string]$ClientId = '',
	[string]$TenantId = '',
	[string]$ClientSecret = '',	
	[string]$SortedBy = '',
	[string]$FilteredBy = '',
	[string]$addVisualizationFlag = 'true',	
	[string]$SortDescending = '',	
	[string]$DisplayItemNumber = '',
	[string]$RefreshCycleMinutes
)

#$dbgFile = 'C:\Temp\graph.log.txt'

$api = New-Object -ComObject 'MOM.ScriptAPI'

$ErrorActionPreference = "stop"
$rtnMsg = ''

$cacheFilePath = "C:\Temp\GraphTmpFiles" 

if ($graphQry -match '\(') { 
  $graphQryName = ($graphQry -split '\(')[0]  
} else {
  $graphQryName = $graphQry
}


$cacheFileSuffix = $graphQryName -replace '/',''

$selectCheck = $false

if ($GraphQry -match '(?i)select') {
	$qryTmp      = $GraphQry -split 'select='
	$qryTmp      = $qryTmp[1] -split '&|$' 
	$qryTmp      = $qryTmp[0] -replace '&|$',''
	$qryTmp      = $qryTmp -as [string]		
	if ($qryTmp.Substring($qryTmp.Length -1,1) -eq ',') {
		$qryTmp = $qryTmp.Substring(0,$qryTmp.Length -1)
	}
	$qryTmpArr   = $qryTmp -split ','	
	$qryTmp      = $qryTmp -replace ',',''
	$cacheFileSuffix +=  '_' + $qryTmp
	$selectCheck = $true
}

	
$cacheFileName = 'Read-Graph_' + $cacheFileSuffix + '.json'

if (Test-Path -Path $cacheFilePath) {
  $foo = "directory already exists"
} else {  
  $tmpFil = ($cacheFilePath -split '\\')[-1]
  $tmpDir = $cacheFilePath.Substring(0,($cacheFilePath.Length - $tmpFil.Length) -1)
  New-Item -ItemType Directory -Path $tmpDir -Name $tmpFil -Force 
}

$cacheFile = Join-Path -Path $cacheFilePath -ChildPath $cacheFileName

$runQry = $false

if ($WebServiceUrl -match "(?i)http(s)?") {
	$foo = 'proceed'
} else {
	$rtnMsg = 'WebService not matching URL' + $WebServiceUrl
}

if ([guid]::TryParse($ClientId, $([ref][guid]::Empty))) {
	$foo = 'proceed'
} else {
	$rtnMsg = 'ClientId not matching GUID' + $ClientId
}

if ([guid]::TryParse($TenantId, $([ref][guid]::Empty))) {
	$foo = 'proceed'
} else {
	$rtnMsg = 'TenantId not matching GUID' + $TenantId
}

if ($ClientSecret.Length -gt 11) {
	$foo = 'proceed'
} else {
	$rtnMsg = 'ClientSecret too short. Use at least 12 characters! ' + $ClientSecret
}

if ($FilteredBy -match "{}") {
	$FilteredBy = $FilteredBy -replace ('{|}','')
} else {
	$foo = 'bar'
}

if ($GraphQry.Length -gt 11) {
	$foo = 'proceed'
} else {
	$rtnMsg = 'GraphQry appears to be invalid. Too short.' +  $GraphQry
}

if ($GraphQry.Substring(0,1) -eq "/") {
	$foo = 'proceed'
} else {
	$GraphQry = '/' +  $GraphQry
}

if ($GraphQry -match '&amp;') {
	$GraphQry = $GraphQry -replace '&amp;','&'    
	$GraphQry = $GraphQry -replace '`',''    
}

if ($DisplayItemNumber -match '\d') {
	$foo = 'bar'
} else {
	$rtnMsg = 'DisplayItemNumber is not a number. Invalid.' +  $DisplayItemNumber
}

if ($SortDescending -match '(?i)true|false|$true|$false') {
	$foo = 'bar'
} else {
	$rtnMsg = 'SortDescindg value is invalid.' +  $SortDescending
}

if ($RefreshCycleMinutes -match '\d') {
	$foo = 'bar'
} else {
	$rtnMsg = 'RefreshCycleMinutes is not a number. Invalid.' +  $RefreshCycleMinutes
}

if ([System.IO.File]::Exists($cacheFile)) {
  $cacheFileObj = Get-Item -Path $cacheFile
  $cacheFileLwt = $cacheFileObj.LastWriteTime 
  $timeDiff = (New-TimeSpan -Start $cacheFileLwt -End (Get-date)).TotalMinutes -as [int]
  if ($timeDiff -gt $RefreshCycleMinutes) {
	$runQry = $true
  } else {
	$runQry = $false
  }
} else {
  $runQry = $true
}


$api.LogScriptEvent('Get-MSGraphData.ps1',602,1,"URL $($WebServiceUrl), TenantID $($TenantId) ClientID $($ClientId) FilteredBy $($FilteredBy) Sortedby $($SortedBy) GraphQry $($GraphQry)")

# Construct URI
$uri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

# Construct Body
$body = @{
	client_id     = $ClientId
	scope         = "https://graph.microsoft.com/.default"
	client_secret = $ClientSecret
	grant_type    = "client_credentials"
}

# Get OAuth 2.0 Token
$tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing

# Access Token
$token  = ($tokenRequest.Content | ConvertFrom-Json).access_token

$uri = $WebServiceUrl + $GraphQry	

#"165"| Out-File -FilePath $dbgFile -Append
#$uri  | Out-File -FilePath $dbgFile -Append

$api.LogScriptEvent('Get-MSGraphData.ps1',602,2,"Qury URL: $($uri)")

if ($runQry) {

	try {	
		$query = Invoke-RestMethod -Method Get -Uri $uri -ContentType "application/json" -Headers @{Authorization = "Bearer $token"} -ErrorAction Stop -UseBasicParsing 
	} catch {	
		$rtnMsg  = 'Failure during InvokeWebRequest  ' + $Error
		$rtnMsg += 'URI: ' + $uri 
	}
  
	$query = $query.value

	if ($selectCheck) {
		$query | Select-Object -Property $qryTmpArr | ConvertTo-Json | Out-File -FilePath $cacheFile -Force 
	} else {
		$query | ConvertTo-Json | Out-File -FilePath $cacheFile -Force 
	}		

} else {

  $query =  Get-Content -Path $cacheFile | ConvertFrom-Json
  
} #end if($runQry)


#$query  | Out-File -FilePath $dbgFile -Append

$api.LogScriptEvent('Get-MSGraphData.ps1',606,1,"rtnMsg $($rtnMsg)")

$allElements = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

$elementCount = 0
$elementCount = $query.count

$query | ForEach-Object { $allElements.Add($_) }

$api.LogScriptEvent('Get-MSGraphData.ps1',602,1,"Answ Value $($query.count) ")

if ($elementCount -gt 1) {

	$FilteredNumber = 0

	if ($FilteredBy -ne '') {
		if ($FilteredBy -match '(?i)[a-zA-Z$_\.''" -]{1,}\s{1,}-(ieq|ine|eq|ne|gt|ge|lt|le|or|and|like|notlike|match|notmatch)\s{1,}[a-zA-Z$_\.''" -]{1,}')  {
			$FilterFor = $ExecutionContext.InvokeCommand.NewScriptBlock($FilteredBy)				
			$allElements = $allElements | Where-Object -FilterScript $FilterFor
			$FilteredNumber = $allElements.Count
			$api.LogScriptEvent('Get-MSGraphData.ps1',603,2,"regex passed for $FilteredBy")
		} else {
			$api.LogScriptEvent('Get-MSGraphData.ps1',603,2,"regex NOT passed for $FilteredBy")
		}
	}

	if ($SortedBy -match '(?i)\w{1,}') {
		$allElements = $allElements | Sort-Object -Property $SortedBy 	
		if ($SortDescending -match '(?i)true|false|$true|$false') {
			if ($SortDescending -match '(?i)true|$true') {
				$allElements = $allElements | Sort-Object -Property $SortedBy -Descending
			} 
		}
	}

	if ($DisplayItemNumber -match '\d' -and $DisplayItemNumber -gt 0) {
		$allElements = $allElements | Select-Object -First $DisplayItemNumber
	}	

	if ($addVisualizationFlag -ieq 'True') {	

		$allElementsVis = New-Object -TypeName 'System.Collections.Generic.List[psobject]'
	
		for ($i=0; $i -lt $allElements.Count; $i++) {

			if ($i % 2 -eq 0) {
				$itmElementFlagHash = @{'Counter' = "## $($i)"}
				$itmElementFlagHash.Add('TotalNumber', $elementCount)
				$itmElementFlagHash.Add('FilteredNumber', $FilteredNumber)
				$tmpObject = $allElements[$i] 
				$objMembers = $tmpObject.psobject.Members | Where-Object {$_.MemberType -eq 'NoteProperty'}
				for ($j = 0; $j -lt $objMembers.Count; $j++) {
					$itmElementFlagHash.Add($($objMembers[$j].Name), "## $($objMembers[$j].Value)")
				}            
			} else {
				$itmElementFlagHash = @{'Counter' = "$($i)"}      
				$itmElementFlagHash.Add('TotalNumber', $elementCount)
				$itmElementFlagHash.Add('FilteredNumber', $FilteredNumber)
				$tmpObject = $allElements[$i] 
				$objMembers = $tmpObject.psobject.Members | Where-Object {$_.MemberType -eq 'NoteProperty'}
				for ($j = 0; $j -lt $objMembers.Count; $j++) {
					$itmElementFlagHash.Add($($objMembers[$j].Name), "$($objMembers[$j].Value)")
				}
			}
		
			$itmElementFlagObj = New-Object -TypeName PSObject -Property $itmElementFlagHash
			$allElementsVis.Add($itmElementFlagObj)

		} #end for ($i=0; $i -lt $allElements.Count; $i++) {}

		$allElements = $null
		$allElements = $allElementsVis

	} else {

		$allElementsVis = New-Object -TypeName 'System.Collections.Generic.List[psobject]'
	
		for ($i=0; $i -lt $allElements.Count; $i++) {
			
			$itmElementFlagHash = @{'Counter' = "$($i)"}      
			$itmElementFlagHash.Add('TotalNumber', $elementCount)
			$itmElementFlagHash.Add('FilteredNumber', $FilteredNumber)
			$tmpObject = $allElements[$i] 
			$objMembers = $tmpObject.psobject.Members | Where-Object {$_.MemberType -eq 'NoteProperty'}
			for ($j = 0; $j -lt $objMembers.Count; $j++) {
				$itmElementFlagHash.Add($($objMembers[$j].Name), "$($objMembers[$j].Value)")
			}
			
		
			$itmElementFlagObj = New-Object -TypeName PSObject -Property $itmElementFlagHash
			$allElementsVis.Add($itmElementFlagObj)

		} #end for ($i=0; $i -lt $allElements.Count; $i++) {}

		$allElements = $null
		$allElements = $allElementsVis

	} 	#end if ($addVisualizationFlag -ieq 'True')

} elseif  ($elementCount -eq 1) {
	
	$foo = 'bar, just keeping allElements'

} #end  if ($elementCount -gt 1)



if ($Format -ieq 'text') {
	$allElements | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host
} elseif ($Format -ieq 'json') {
	$allElements | ConvertTo-Json | Out-String -Width 4096 | Write-Host
} elseif ($format -ieq 'list') {
	$allElements | Format-List | Out-String -Width 4096 | Write-Host
}

if ($Error) {
	$rtnMsg += " error count: $($Error.Count) "
	$rtnMsg += " --- "
	if ($Error.Count -gt 0) {
		for ($l = 0; $l -lt $($Error.count); $l++ ) {
			$rtnMsg += " Error No $l $($Error[$l]) " 
		}
	}
	$api.LogScriptEvent('Get-MSGraphData.ps1',607,1,$rtnMsg)
} else {
	$api.LogScriptEvent('Get-MSGraphData.ps1',607,4,"no error!")
}


# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
