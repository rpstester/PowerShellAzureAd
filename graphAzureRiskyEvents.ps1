#Requires -Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Reports
<#
.SYNOPSIS
 Use MS Graph to collected successful Azure logins that are risky
.DESCRIPTION
 Gets Azure Risk Detections in the last several hours
 Then gets the matching login audit log for more details
 Then exports to a CSV
.NOTES
 Roger P Seekell, Nov. 2021, Dec. 2021
#>
$exportPath = "$env:OneDrive\Reports\Azure"
$exportFile = "$exportPath\azureRiskEvents_$(Get-Date -Format "yyyy-MM-dd").csv"
$goBackHours = 24 #how many hours to go backwards
$totalRiskItems = 10000 #maximum items returned
#email vars
Import-Module GraphHelper 
$emailRecipients = "who@something.us"
$emailSubject = "Azure Risk Alerts (successful) last $goBackHours hours"
$emailFrom = "whom@something.us"

Select-MgProfile "beta" #we are using beta data here

#now using cert-based authentiation (non-interactive)!
$appid = ''
$tenid = ''
$certThumb = ''
$cert = Get-ChildItem Cert:\CurrentUser\My\$certThumb
Connect-MgGraph -ClientId $appid -TenantId $tenid -Certificate $cert
#Get-MgContext

#go back this many hours
$asOfDate = (Get-Date).AddHours(-$goBackHours)
$allRisksToday = Get-MgRiskDetection -Top $totalRiskItems -Filter "riskState ne 'Remediated' and riskState ne 'Dismissed' and activityDateTime ge $(Get-Date -Date $asOfDate -Format "yyyy-MM-ddTHH:mm:ssZ")" | Select-Object *

$allRisksToday | ForEach-Object { #have to get the matching sign-in audit log for more details
    $signin = Get-MgAuditLogSignIn -Filter "UserPrincipalName eq '$($_.UserPrincipalName)' and id eq '$($_.RequestId)'"
    $_ | Add-Member -MemberType NoteProperty -Name "Status" -Value $signin.Status.ErrorCode -PassThru | 
         Add-Member -MemberType NoteProperty -Name "LocationCity" -Value $signin.Location.City -PassThru |
         Add-Member -MemberType NoteProperty -Name "LocationState" -Value $signin.Location.State -PassThru |
         Add-Member -MemberType NoteProperty -Name "LocationCountry" -Value $signin.Location.CountryOrRegion -PassThru |
         Add-Member -MemberType NoteProperty -Name "AuthRequirement" -Value $signin.AuthenticationRequirement -PassThru |
        #Add-Member -MemberType NoteProperty -Name "FailureReason" -Value $signin.Status.FailureReason -PassThru |
         Add-Member -MemberType NoteProperty -Name "isStudent" -Value ($_.UserPrincipalName -like "*@stu.*" ) -PassThru
} | Where-Object Status -eq 0 | #this means successful login, no failure or interruption
    Select-Object activity, activityDateTime, IPaddress, LastUpdatedDateTime, RiskEventType, RiskType, Source, UserDisplayname, UserPrincipalName, Status, isStudent, Location*, authrequi* -ExcludeProperty Location |
    Export-Csv -NoTypeInformation -Path $exportFile


#prepare to send email
$emailBody = "The last up to $totalRiskItems active risky logins that were successful in the last $goBackHours hours"
Send-MailMessageWithGraph -Subject $emailSubject -BodyAsText $emailBody -To $emailRecipients -From $emailFrom -attachmentPath $exportFile

#cleanup
Disconnect-MgGraph