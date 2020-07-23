<#
.SYNOPSIS
    Get Compupter Updatime
.DESCRIPTION
    This script enumerates processes and outputs formatted text
.Notes
	AUTHOR: Ruben Zimmermann @ruben8z
	LASTEDIT: 2020-01-22
	REQUIRES: PowerShell Version 2, Windows Management Foundation 4, At least Windows 7 or Windows Server 2008 R2.	
REMARK:
This PS script comes with ABSOLUTELY NO WARRANTY; for details see gnu-gpl. This is free software, and you are welcome to redistribute it under certain conditions; see gnu-gpl for details.
    
#>
Param(
    [ValidateSet('text','list','json')]
    [string]$Format = "json",
	[string]$WebServiceUrl,
	[string]$ContentType = 'application/soap+xml',
	[string]$Headers,
	[string]$XMLNodeName,
	[string]$UserName,
	[string]$PassWord,
	[string]$SortedByXMLNode,
	[string]$FilterForXMLNode,
	[string] $addVisualizationFlag = 'true'	
)


$api = New-Object -ComObject 'MOM.ScriptAPI'

#region PREWORK Disabling the certificate validations
if ("TrustAllCertsPolicy" -as [type]) {
	$foo = 'already exist'
} else {
add-type -TypeDefinition @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
}
#endregion PREWORK

$ErrorActionPreference = "stop"
$rtnMsg = ''

if ($WebServiceUrl -match "(?i)http(s)?") {
	$foo = 'proceed'
} else {
	$rtnMsg = 'WebService not matching URL' + $WebServiceUrl
}

if ($ContentType -match "(?i)application|soap|xml") {
	$foo = 'proceed'
} else {
	$rtnMsg = 'ContentType not matching URL' + $WebServiceUrl
}

if ($XMLNodeName -match "'\//.?'") {
	$foo = 'proceed'
} else {
	$XMLNodeName = '//' + $XMLNodeName 
}

if ($FilterForXMLNode -match "{}") {
	$FilterForXMLNode = $FilterForXMLNode -replace ('{|}','')
} else {
	$foo = 'bar'
}


$api.LogScriptEvent('Get-RemoteSOAPServiceInfo.ps1',602,1,"URL $($WebServiceUrl), User $($UserName + $PassWord)  Contenttype $($ContentType) FilterForXMLNode $FilterForXMLNode Sortby $SortedByXMLNode")


<#
if ($Headers -match '\//.?') {
	$foo = 'proceed'
} else {
	$rtnMsg = 'WebService not matching URL' + $WebServiceUrl
}

HEADER verification and handling is still required, now just focus on PI.
SortedByXMLNode
#>


$header   = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UserName+":"+ $PassWord))}

try {
	
	$reqAnsw = Invoke-WebRequest -Uri $WebServiceUrl -UseBasicParsing -Headers $header -ContentType $ContentType
	
} catch {
	
	$rtnMsg = 'Failure during InvokeWebRequest' + $Error.ToString()
}

[xml]$content = $reqAnsw.Content
$elementList  = $content.DocumentElement.SelectNodes($XMLNodeName)

$allElements = New-Object -TypeName 'System.Collections.Generic.List[PSObject]'

$elementList | ForEach-Object {
  
	$tmpString = $_ | Out-String  
	$tmpEntry  = $tmpString -Split("`r`n")  
	$tmpObj    = New-Object -TypeName PSObject

	$tmpEntry | ForEach-Object {  

		if ($_ -match '[a-zA-Z0-9]') {
			$tmpEntryItm = $_ -Split("\s{1}\:\s{1}")   
			$tmpItmLeft  = $tmpEntryItm[0] -Replace("\s","")
			$tmpItmRight = $tmpEntryItm[1] -Replace("\s","")
			if ($tmpItmRight -match '\s{1,}' -or $tmpItmRight -eq '') {
				$tmpItmRight = '.'
			}
			Add-Member -InputObject $tmpObj -MemberType NoteProperty -Name $tmpItmLeft -Value $tmpItmRight        
		}  
		
	} #end $tmpEntry | ForEach-Object {}

	$allElements.Add($tmpObj)

} #end $elementList | ForEach-Object {}

if ($FilterForXMLNode -ne '') {
	if ($FilterForXMLNode -match '(?i)[a-zA-Z$_\.''" -]{1,}\s{1,}-(ieq|ine|eq|ne|gt|ge|lt|le|or|and|like|notlike|match|notmatch)\s{1,}[a-zA-Z$_\.''" -]{1,}')  {
		$FilterForXML = $ExecutionContext.InvokeCommand.NewScriptBlock($FilterForXMLNode)				
		$allElements = $allElements | Where-Object -FilterScript $FilterForXML
		$api.LogScriptEvent('Get-RemoteSOAPServiceInfo.ps1',603,2,"regex passed for $FilterForXMLNode")

	} else {
		$api.LogScriptEvent('Get-RemoteSOAPServiceInfo.ps1',603,2,"regex NOT passed for $FilterForXMLNode")
	}
}

if ($SortedByXMLNode -match '(?i)\w{1,}') {
	$allElements = $allElements | Sort-Object -Property $SortedByXMLNode
}

$addVisualizationFlag = 'True'

if ($addVisualizationFlag -ieq 'True') {	

	$allElementsVis = New-Object -TypeName 'System.Collections.Generic.List[psobject]'
	
	for ($i=0; $i -lt $allElements.Count; $i++) {

		if ($i % 2 -eq 0) {
			$itmElementFlagHash = @{'Counter' = "## $($i)"}           
			$tmpObject = $allElements[$i] 
			$objMembers = $tmpObject.psobject.Members | Where-Object {$_.MemberType -eq 'NoteProperty'}
			for ($j = 0; $j -lt $objMembers.Count; $j++) {
				$itmElementFlagHash.Add($($objMembers[$j].Name), "## $($objMembers[$j].Value)")
			}            
		} else {
			$itmElementFlagHash = @{'Counter' = "$($i)"}      
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

} #end if ($addVisualizationFlag -ieq 'True')


if ($Format -eq 'text') {
    $allElements | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host
} elseif ($Format -eq 'json') {
    $allElements | ConvertTo-Json | Out-String -Width 4096 | Write-Host
} elseif ($format -eq 'list') {
    $allElements | Format-List | Out-String -Width 4096 | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
