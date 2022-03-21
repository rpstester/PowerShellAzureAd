<#
The following uses the Connect-MgGraph to make a report of all Conditional Access Policies and their various user/group/apps
Roger P Seekell, 2021-11-09
#>
#requires -Modules Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Users, Microsoft.Graph.Applications, Microsoft.Graph.Groups, Microsoft.Graph.Identity.Governance
$csvPath = "$env:OneDrive\Reports\Azure\ConditionalAccessPolicies_$(Get-Date -Format "yyyy-MM-dd").csv"
Select-MgProfile -Name "beta" #include preview features
Connect-MgGraph -Scopes "user.read.all", "policy.read.all", "application.read.all", "Agreement.Read.All"

$locations = Get-MgIdentityConditionalAccessNamedLocation -All
#takes the location ID and returns a Display Name
function convert-Location {
    if ($args -eq "All") {
        "Any Location"
    }
    else {
        ($locations | Where-Object Id -eq $args).DisplayName
    }
}

#takes the user ID and returns a Display Name
function convert-User {
    if ($args -eq "All") {
        "All users"
    }
    elseif ($args -eq "GuestsOrExternalUsers") {
        "All guest and external users"
    }
    else {
        $user = (Get-MgUser -UserId "$args")
        $user.DisplayName
    }
}

$applications = Get-MgApplication -All
#takes the application ID and returns a Display Name
function convert-Application {
    Param (
        [string]$appID
    )
    if ($appID -eq "All") {
        "All cloud apps"
    }
    elseif ($appID -eq "Office365") {
        "Office365"
    }
    elseif ($appID -eq "00000002-0000-0ff1-ce00-000000000000") {
        "Office 365 Exchange Online" #this is a legacy app
    }
    elseif ($appID -eq "00000003-0000-0ff1-ce00-000000000000") {
        "Office 365 SharePoint Online" #this is a legacy app
    }
    elseif ($appID -eq "925eb0d0-da50-4604-a19f-bd8de9147958") {
        "Office Groups" 
    }
    elseif ($appID -eq "d4ebce55-015a-49b5-a083-c84d1797ae8c") {
        "Microsoft Intune Enrollment" 
    }
    elseif ($appID -eq "d5e96d25-da6d-4e80-9526-b15c547ff978") {
        "RingCentral for Office 365"
    }    
    else {        
        $theapp = $applications | Where-Object appid -eq $appID
        if ($theapp) {
            $theapp.DisplayName
        }
        else {
            $appID
        }
    }
}

#makes the grant controls more concise and legible
function convert-GrantControls {
    $capGrantControls = $args
    if ($capGrantControls.BuiltInControls.count -gt 1) {
        $capGrantControls.BuiltInControls -join (" -" + $capGrantControls.Operator + "- ")
    }
    else {
        $capGrantControls.BuiltInControls
    }
}

#makes the sign-in frequency more concise and legible
function convert-SignInFrequency {
    $SIF = $args
    if ($SIF.IsEnabled) {
        "$($SIF.Value) $($SIF.Type)"
    }
}

Get-MgIdentityConditionalAccessPolicy | Select-Object displayname, state, createddatetime, modifieddatetime, description, 
    @{label="IncludeUsers"; e={($_.conditions.users.IncludeUsers | ForEach-Object {convert-User $_}) -join "`r`n"}}, 
    @{label="IncludeGroups";e={($_.conditions.users.IncludeGroups | ForEach-Object {Get-MgGroup -GroupId $_}).DisplayName -join "`r`n"}}, 
    @{label="IncludeRoles";e={$_.conditions.users.IncludeRoles -join "`r`n"}},
    @{label="ExcludeUsers"; e={($_.conditions.users.ExcludeUsers | ForEach-Object {convert-User $_}) -join "`r`n"}}, 
    @{label="ExcludeGroups";e={($_.conditions.users.ExcludeGroups | ForEach-Object {Get-MgGroup -GroupId $_}).DisplayName -join "`r`n"}}, 
    @{label="ExcludeRoles";e={$_.conditions.users.ExcludeRoles -join "`r`n"}},
    @{label="IncludeApplications";e={($_.Conditions.Applications.IncludeApplications | ForEach-Object {convert-Application $_}) -join "`r`n"}}, 
    @{label="ExcludeApplications";e={($_.Conditions.Applications.ExcludeApplications | ForEach-Object {convert-Application $_}) -join "`r`n"}}, 
    @{label="UserRiskLevels";e={$_.conditions.Userrisklevels -join " -AND- "}}, 
    @{label="SignInRiskLevels";e={$_.conditions.signinrisklevels -join " -AND- "}}, 
    @{label="IncludePlatforms";e={($_.conditions.Platforms.IncludePlatforms -join " -AND- ").replace("all","Any device")}}, 
    @{label="ExcludePlatforms";e={$_.conditions.Platforms.ExcludePlatforms -join " -NOR- "}}, 
    @{label="IncludeLocations";e={($_.Conditions.Locations.IncludeLocations | ForEach-Object {convert-Location $_}) -join "`r`n"}}, 
    @{label="ExcludeLocations";e={($_.Conditions.Locations.ExcludeLocations | ForEach-Object {convert-Location $_}) -join "`r`n"}}, 
    @{label="ClientAppTypes";e={$_.Conditions.ClientAppTypes -join "`r`n"}}, 
    @{label="IncludeDevices";e={$_.Conditions.Devices.IncludeDevices -join "`r`n"}},
    @{label="ExcludeDevices";e={$_.Conditions.Devices.ExcludeDevices -join "`r`n"}},
    <#the above are assignments, the below are access controls#>
    @{label="GrantControls";e={convert-GrantControls $_.GrantControls}},
    @{label="TermsOfUse";e={(Get-MgAgreement -AgreementId "$($_.GrantControls.TermsOfUse)").DisplayName}},
    @{label="RequireAppProtectionPolicy";e={$_.SessionControls.ApplicationEnforcedRestrictions.IsEnabled}},
    @{label="RequireApprovedClientApp";e={$_.SessionControls.CloudAppSecurity.IsEnabled}},
    @{label="PersistentBrowser";e={$_.SessionControls.PersistentBrowser.mode}},
    @{label="SessionTimeLimit";e={convert-SignInFrequency $_.SessionControls.SignInFrequency}} | 
    Export-Csv -NoTypeInformation -Path $csvPath

Disconnect-MgGraph
