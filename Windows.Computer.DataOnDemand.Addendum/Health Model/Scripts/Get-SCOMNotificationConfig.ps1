<#
.SYNOPSIS
    Get-SCOMNotificationConfig
.DESCRIPTION
    This script exports SCOM's notification configuration.
.Notes
	AUTHOR: Ruben Zimmermann @ruben8z
	LASTEDIT: 2020-01-13
	REQUIRES: PowerShell Version 4, Windows Management Foundation 4, At least Windows 7 or Windows Server 2008 R2.	
REMARK:
This PS script comes with ABSOLUTELY NO WARRANTY; for details see gnu-gpl. This is free software, and you are welcome to redistribute it under certain conditions; see gnu-gpl for details.
    
#>
Param(
    [ValidateSet("text","csv","json", "list")] 
    [string] $Format = "json",
	[string] $hideDisabled = 'true',
	[string] $hideChannelInfo = 'true',
	[string] $addVisualizationFlag = 'true',
	[string] $sortedByColumn = 'DisplayName'
)


$ErrorActionPreference = "stop"

Import-Module OperationsManager


$subScriptionList = New-Object -TypeName 'System.Collections.Generic.List[psobject]'

$subScriptions    = Get-SCOMNotificationSubscription

foreach ($subScript in $subScriptions) {

    $monitor = $null
    $rule = $null
    $Instance = $null
    $Desc = $null
    $monClassIDs  = $null
    $monGroupIDs  = $null
    $tmpClassName = $null
    $tmpGroupName = $null


    $subScriptHash = @{'Enabled' = $($subScript.Enabled)}
    $subScriptHash.Add('DisplayName', $($subScript.DisplayName))
    $subScriptHash.Add('Description', $($subScript.Description))
        
    $subSriptCriteria = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $subSriptCriteriaDetailed = New-Object -TypeName 'System.Collections.Generic.List[string]' 
    
    $criteriaVals  = Select-Xml -Content $subScript.Configuration.Criteria -XPath '//Value' `
                         | foreach {$_.node.InnerXML}        

    $criteriaProps = Select-Xml -Content $subScript.Configuration.Criteria -XPath '//Property' `
                         | foreach {$_.node.InnerXML}        

     for ($i=0; $i -lt $criteriaProps.Length; $i++) {

        if ($criteriaProps[$i] -eq 'ProblemId') {
            $monitorTmp     = (Get-SCOMMonitor -Id $criteriaVals[$i]) | Select-Object -Property DisplayName, Name
            $monitorDisplay = $monitorTmp.DisplayName
            $monitorName    = $monitorTmp.Name
            $subSriptCriteria.Add("$monitorDisplay; ")
            $subSriptCriteriaDetailed.Add("$monitorDisplay - $monitorName; ")
        }

        if ($criteriaProps[$i] -eq 'RuleId') {
            $ruleTmp       = (Get-SCOMRule -Id $criteriaVals[$i]) | Select-Object -Property DisplayName, Name
            $ruleDisplay = $ruleTmp.DisplayName
            $ruleName    = $ruleTmp.Name
            $subSriptCriteria.Add("$ruleDisplay; ")            
            $subSriptCriteriaDetailed.Add("$ruleDisplay - $ruleName; ")
        }

        if ($criteriaProps[$i] -eq 'BaseManagedEntityId') {
            $Instance = (Get-SCOMClassInstance -Id $criteriaVals[$i]).DisplayName
            $subSriptCriteria.Add("$Instance;" )
            $subSriptCriteriaDetailed.Add("$Instance;" )                        
        }

        if ($criteriaProps[$i] -eq 'Severity') {            
            $subSriptCriteriaDetailed.Add("Severity: $($criteriaVals[$i]); ")                 
        }

        if ($criteriaProps[$i] -eq 'Priority') {
            $subSriptCriteriaDetailed.Add("Priority: $($criteriaVals[$i]); ")                           
        }

	    if ($criteriaProps[$i] -eq 'ResolutionState') {
            $subSriptCriteriaDetailed.Add("ResolutionState: $($criteriaVals[$i]); ")               
        }

        if($criteriaProps[$i] -eq "AlertDescription") {
            $Desc = " $($criteriaProps[$i]) : $($criteriaVals[$i])"
            $subSriptCriteria.Add($Desc)
            $subSriptCriteriaDetailed.Add($Desc)               
        }

    } #end for($i=0; $i -lt $criteriaProps.Length; $i++){}


    $subScriptHash.Add('Criteria', $($subSriptCriteria))
    $subScriptHash.Add('CriteriaDetailed', $($subSriptCriteriaDetailed))

    $monClassIDs = $subScript.Configuration.MonitoringClassIds
    $monGroupIDs = $subScript.Configuration.MonitoringObjectGroupIds

    $subSriptMonInfo = New-Object -TypeName 'System.Collections.Generic.List[string]'
      
    if ($monClassIDs) { 
        if ($monClassIDs.count -gt 1) {
            foreach ($monID in $monClassIDs) {
                $tmpClassName = Get-SCOMClass -Id $monID | Select-Object -ExpandProperty DisplayName
                $subSriptMonInfo.Add($tmpClassName)
            }
        } else {
            $tmpClassName = Get-SCOMClass -Id $monClassIDs | Select-Object -ExpandProperty DisplayName
            $subSriptMonInfo.Add($tmpClassName)
        }        
    }
    
    if ($monGroupIDs) {
        if ($monClassIDs.count -gt 1) {
            foreach ($groupId in $monGroupIDs) {
                $tmpGroupName = Get-SCOMGroup -Id $groupId | Select-Object -ExpandProperty DisplayName
                $subSriptMonInfo.Add($tmpGroupName)
            }
        } else {
            $tmpGroupName = Get-SCOMGroup -Id $monGroupIDs | Select-Object -ExpandProperty DisplayName
            $subSriptMonInfo.Add($tmpGroupName)
        }                        
    }

    $subScriptHash.Add('MonitoringInfo', $($subSriptMonInfo))

    $subSriptChannelInfo = New-Object -TypeName 'System.Collections.Generic.List[string]'

    foreach ($subAction in $subScript.Actions) {        
        $subSriptChannelInfo.Add("From: $($subAction.From)")
        $subSriptChannelInfo.Add("Subject: $($subAction.Subject)")
        $subSriptChannelInfo.Add("Body: $($subAction.Body)")
        $subSriptChannelInfo.Add("EndPoint: $($subAction.EndPoint.Name)")
        $subSriptChannelInfo.Add("DisplayName: $($subAction.DisplayName)")
        $subSriptChannelInfo.Add("Description: $($subAction.Description)")
    }

    $subScriptHash.Add('ChannelInfo', $($subSriptChannelInfo))
    
    $subScriptRecptInfo = New-Object -TypeName 'System.Collections.Generic.List[string]'
      
    $subScriptRecptInfo.Add($($subScript.ToRecipients.Name))
    $subScriptRecptInfo.Add($($subScript.ToRecipients.Devices.Name))
    
    $noOfScheduleEntries = ($subScript.ToRecipients.ScheduleEntries).Count
    $scheduleDays = ''    
    $schedDetails = ''

    for ($j=0; $j -lt $noOfScheduleEntries; $j++) {
        $schedDetails = ''
        $scheduleDays = ($subScript.ToRecipients.ScheduleEntries)[$j].ScheduledDays.ToString()
        [string]$dailyStart = ($subScript.ToRecipients.ScheduleEntries)[$j].DailyStartTime.Hour
        $dailyStart += ':' 
        $dailyStart += ($subScript.ToRecipients.ScheduleEntries)[$j].DailyStartTime.Minute
        [string]$dailyEnd = ($subScript.ToRecipients.ScheduleEntries)[$j].DailyEndTime.Hour
        $dailyEnd += ':' 
        $dailyEnd += ($subScript.ToRecipients.ScheduleEntries)[$j].DailyEndTime.Minute
        $startEnd = $dailyStart + ' - ' + $dailyEnd
        $entryType = ($subScript.ToRecipients.ScheduleEntries)[$j].ScheduleEntryType
        $timeZnTmp  = (($subScript.ToRecipients.ScheduleEntries)[$j].TimeZone).split('|')
        $timeZone = $timeZnTmp[1]
        $schedDetails = $scheduleDays + '; ' + $startEnd + '; ' + $timeZone + '; ' + $entryType
        $subScriptRecptInfo.Add("Details: $($schedDetails)")     
    }

    $subScriptHash.Add('RecptInfo', $($subScriptRecptInfo))
    $subScriptObj = New-Object -TypeName PSObject -Property $subScriptHash
    $subScriptionList.Add($subScriptObj)

}

$rtnList = $null

if ($hideDisabled -ieq 'True') {
    $rtnList = $subScriptionList | Where-Object {$_.Enabled -eq $true} | Sort-Object -Property DisplayName
}

if ($hideChannelInfo -ieq 'True') {
    if ($rtnList) {
		$rtnList = $rtnList | Select-Object -Property DisplayName, Description, Criteria, CriteriaDetailed, RecptInfo, Enabled, MonitoringInfo | Sort-Object -Property DisplayName
	} else {
		$rtnList = $subScriptionList | Select-Object -Property DisplayName, Description, Criteria, CriteriaDetailed, RecptInfo, Enabled, MonitoringInfo | Sort-Object -Property DisplayName
	}
}

if ($sortedByColumn -match '(?i)(Enabled|DisplayName|Description|Criteria|CriteriaDetailed|MonitoringInfo|ChannelInfo|RecptInfo)') {
	$rtnList = $rtnList | Sort-Object -Property $sortedByColumn
}


if ($addVisualizationFlag -ieq 'True') {	

	$subScriptionListFlagged = New-Object -TypeName 'System.Collections.Generic.List[psobject]'
	
	for ($k=0; $k -lt $rtnList.Count; $k++) {

		if ($k % 2 -eq 0) {
			$subScriptFlagHash = @{'Enabled' = "## $($rtnList[$k].Enabled)"}
			$subScriptFlagHash.Add('DisplayName', "## $($rtnList[$k].DisplayName)")
			$subScriptFlagHash.Add('Description', "## $($rtnList[$k].Description)")
			$subScriptFlagHash.Add('Criteria', "## $($rtnList[$k].Criteria)")
            $subScriptFlagHash.Add('CriteriaDetailed', "## $($rtnList[$k].CriteriaDetailed)")
			$subScriptFlagHash.Add('MonitoringInfo', "## $($rtnList[$k].MonitoringInfo)")
			$subScriptFlagHash.Add('ChannelInfo', "## $($rtnList[$k].ChannelInfo)")
			$subScriptFlagHash.Add('RecptInfo', "## $($rtnList[$k].RecptInfo)")
		} else {
			$subScriptFlagHash = @{'Enabled' = "$($rtnList[$k].Enabled)"}
			$subScriptFlagHash.Add('DisplayName', "$($rtnList[$k].DisplayName)")
			$subScriptFlagHash.Add('Description', "$($rtnList[$k].Description)")
			$subScriptFlagHash.Add('Criteria', "$($rtnList[$k].Criteria)")
            $subScriptFlagHash.Add('CriteriaDetailed', "$($rtnList[$k].CriteriaDetailed)")
			$subScriptFlagHash.Add('MonitoringInfo', "$($rtnList[$k].MonitoringInfo)")
			$subScriptFlagHash.Add('ChannelInfo', "$($rtnList[$k].ChannelInfo)")
			$subScriptFlagHash.Add('RecptInfo', "$($rtnList[$k].RecptInfo)")
		}
		
		$subScriptFlagObj = New-Object -TypeName PSObject -Property $subScriptFlagHash
		$subScriptionListFlagged.Add($subScriptFlagObj)

	} # end for ($k=0; $k -lt $subScriptionList.Count; $k++) {}
	
	$rtnList = $subScriptionListFlagged

} # end if ($addVisualizationFlag -ieq 'True')



if ($Format -eq 'text') {
    $rtnList | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host
} elseif ($Format -eq 'csv') {
    $rtnList | ConvertTo-Csv -NoTypeInformation | Out-String -Width 4096 | Write-Host
} elseif ($Format -eq 'json') {
    $rtnList | ConvertTo-Json | Out-String -Width 4096 | Write-Host
} elseif ($format -eq 'list') {
    $rtnList | Format-List | Out-String -Width 4096 | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
