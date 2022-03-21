function Send-MailMessageWithGraph {
<#
.SYNOPSIS
 Use the Graph to send an email from your account!
.DESCRIPTION
 It acts like send-mailmessage, but behind the scenes, it is using the PowerShell MgGraph module
 Simply add to/cc, subject, body as text/html, etc. and your email will send
 Uses your current authentication to send
.NOTES
 Author: Roger P Seekell
 Date: 6-28-21
.PARAMETER Subject
 The subject line of your email, defaults to "Graph Test Message"
.PARAMETER BodyAsHtml
 If you want to use HTML formatting in your message, use this to write the body of your email. 
.PARAMETER BodyAsText
 If you want a text-only message, use this to write the body of your email. 
.PARAMETER To
 A comma-separated list of email addresses - can use either TO or CC or both
.PARAMETER Cc
 A comma-separated list of email addresses - can use either TO or CC or both
.PARAMETER attachmentPath
 The file path to the attachment you want to include on the email
.EXAMPLE
 Send-MailMessageWithGraph -Subject "First Test Message" -BodyAsText "Hello there" -To "roger.seekell@something.com"
.EXAMPLE
 Send-MailMessageWithGraph -Subject "Second Test Message" -BodyAsHTML "This is a <i>formatted</i> email <em>test</em> by <br /><b>Yours Truly</b>" `
    -To "roger.seekell@something.com" -Importance Low
.EXAMPLE
 Send-MailMessageWithGraph -Subject "Important Test Message" -BodyAsText "Hello there" -To "roger.seekell@something.com" -Cc "roger.seekell@something.com" -Importance High
.EXAMPLE
 Send-MailMessageWithGraph -Subject "Test attachment" -BodyAsText "Behold, the attachment!" -To "roger.Seekell@something.com" -attachmentPath 'C:\users\rps\Downloads\ApplicationSignIns_2020-11-09_2020-11-16.csv'
#>

[CmdletBinding()]
param (
    [Parameter()]    [string]    $Subject = "Graph Test Message",    
    [Parameter()]    [string]    $BodyAsText, 
    [Parameter()]    [string]    $BodyAsHTML, 
    [Parameter()]    [string[]]    $To,
    [Parameter()]    [string[]]    $Cc,
    [Parameter()]    [string]    $attachmentPath = "",
    [Parameter()] [ValidateSet("High","Normal","Low")]   [string]    $Importance
)

#connect to MS Graph first
Connect-MgGraph -Scopes "mail.send" 
$currentUser = (Get-MgContext).Account
#not sure how to send as someone else

#build out recipients
$ToRecipientTable = @()
foreach ($rep in $To) {
    $ToRecipientTable += @{ 
        emailAddress = @{
            name = "User"; #this name doesn't apparently matter
            address = $rep
        }
    }
}#end foreach

#build out recipients
$CcRecipientTable = @()
foreach ($rep in $Cc) {
    $CcRecipientTable += @{ 
        emailAddress = @{
            name = "User"; #this name doesn't apparently matter
            address = $rep
        }
    }
}#end foreach

#build out the body of message
if ($BodyAsText -ne "") {
    $BodyTable = @{
        contentType = "Text";
        content = $BodyAsText
    }
}
elseif ($BodyAsHtml -ne "") {
    $BodyTable = @{
        contentType = "HTML";
        content = $BodyAsHtml
    }
}

#build out the message
$Message = @{
    subject = $Subject;
    toRecipients = $ToRecipientTable;
    ccRecipients = $CcRecipientTable;
    body = $BodyTable;    
}

if ($Importance -eq "High" -or $Importance -eq "Low") {
    $Message += @{Importance = $Importance}
}

#handle attachments (whoa!)
if ($attachmentPath -ne "") {
    $attachmentCollection = @()
    #Get File Name and Base64 string
    $FileName=(Get-Item -Path $attachmentPath).name
    $base64string = [Convert]::ToBase64String([IO.File]::ReadAllBytes($attachmentPath))
    <#
    [byte[]]$contentBytes = [System.IO.File]::ReadAllBytes($attachmentPath)
    [string]$contentType = "text"
    #>
    $attachmentCollection += @{
        "@odata.type" = "#microsoft.graph.fileAttachment";
        contentBytes = $base64string;
        contentType = "text/plain";        
        name = "$FileName"
    }
    $Message += @{attachments = $attachmentCollection}
    #>
}#end attachment section

#this is the goal...
Send-MgUserMail -userid $currentUser -BodyParameter @{message = $Message}

}#end function
