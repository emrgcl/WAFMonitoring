[CmdletBinding()]
Param(

    [Parameter(Mandatory =$true)]
    [ValidateScript({test-path $_})]
    [string]$ConfigPath
)
function Get-SubscriptionIds {
    param (
        $Config
    )
    $Config.Subscriptions.Keys
    
}
Function Write-Log {

    [CmdletBinding()]
    Param(
    
    
    [Parameter(Mandatory = $True)]
    [string]$Message,
    [string]$LogFilePath = "$($env:TEMP)\log_$((New-Guid).Guid).txt",
    [Switch]$DoNotRotateDaily
    )
    
    if ($DoNotRotateDaily) {

        
        $LogFilePath = if ($Script:LogFilePath) {$Script:LogFilePath} else {$LogFilePath}
            
    } else {
        if ($Script:LogFilePath) {

        $LogFilePath = $Script:LogFilePath
        $DayStamp = (Get-Date -Format 'yMMdd').Tostring()
        $Extension = ($LogFilePath -split '\.')[-1]
        $LogFilePath -match "(?<Main>.+)\.$extension`$" | Out-Null
        $LogFilePath = "$($Matches.Main)_$DayStamp.$Extension"
        
    } else {$LogFilePath}
    }
    $Log = "[$(Get-Date -Format G)][$((Get-PSCallStack)[1].Command)] $Message"
    
    Write-Verbose $Log
    $Log | Out-File -FilePath $LogFilePath -Append -Force
    
}
Function Get-AuthHeader {
    [CmdletBinding()]
    Param(
    
        [string]$SubscriptionID
    
    )
    # requires az.accounts
    $AzContext = Set-AzContext -Subscription $SubscriptionID
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'='Bearer ' + $token.AccessToken
    }
    $authHeader
    }

Function Get-AzActivityLogs {
    [CmdletBinding()]
    Param(
        [string]$subscriptionId,
        $AuthHeader,
        [int32]$DaysOld = 7,
        [string]$ResourceGroup,
        [string]$ApiVersion = '2015-04-01' 
    )
    
    # need to set datetime to utc and then to json format which is iso8601 basically
    $StartDate = (((Get-Date).AddDays(-1*$DaysOld)).ToUniversalTime()).GetDAteTimeFormats('o')
    $Filter = "eventTimestamp ge '$StartDate' and resourceGroupName eq $ResourceGroup"
    $ActivitLogURI = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Insights/eventtypes/management/values?api-version=$ApiVersion&`$filter=$filter"
    (Invoke-RestMethod -Method Get -Uri $ActivitLogURI -Headers $AuthHeader -verbose:$false).Value
}

function Get-ResourcesInResourceGroup {
    [CmdletBinding()]
    param (
        $SubscriptionID,
        $ResouceGroup,
        $authHeader,
        $ApiVersion ='2021-04-01'      
    )
    $ResourceListUri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/resources?api-version=$ApiVersion"
    (Invoke-RestMethod -URI $ResourceListUri -Method Get -Headers $authHeader -verbose:$false).Value
}
function Get-SubscriptionResourceGroups {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline= $true)]
        [hashtable]$Config,
        [string]$SubscriptionID        
    )
    Process {
    $Config.Subscriptions.$SubscriptionID
    }
}
function Get-MetricsForResource {
    [CmdletBinding()]
    param (
        $SelectedResources,
        [hashtable]$AuthHeader,
        $ApiVersion ='2018-01-01'   
    )
    
        Foreach ($SelectedResource in $SelectedResources){
        try {
        $MetricDefinitionURI = "https://management.azure.com$($SelectedResource.id)/providers/Microsoft.Insights/metricDefinitions?api-version=$ApiVersion"
        $Metrics = (Invoke-RestMethod -URI $MetricDefinitionURI -Method Get -Headers $AuthHeader -verbose:$false -ErrorAction stop).Value
        Foreach ($Metric in $Metrics){
        [PSCustomObject]@{
        ResourceID = $SelectedResource.id
        ResourceType = $SelectedResource.type
        Name = $Metric.Name.value
        Description = $Metric.Name.LocalizedValue 
        }
        }
        }

        Catch [Microsoft.PowerShell.Commands.HttpResponseException]{
            Write-log -Message "$($_.Exception.Response.ReasonPhrase)"
        }
        Catch {
            Write-log -Message "$($_.Exception.Message)"
        }
    }   
    
    
}
function Get-DiagnosticSettingsForResource {
    [CmdletBinding()]
    param (
        $SelectedResources,
        [hashtable]$AuthHeader,
        $ApiVersion ='2021-05-01-preview'   
    )
    
        Foreach ($SelectedResource in $SelectedResources){
        try {
        $DiagnosticSettingsURI = "https://management.azure.com/$($SelectedResource.Id)/providers/Microsoft.Insights/diagnosticSettingsCategories?api-version=$ApiVersion"
        $DiagnosticSettings= (Invoke-RestMethod -URI $DiagnosticSettingsURI -Method Get -Headers $AuthHeader -verbose:$false -ErrorAction stop).Value
        Foreach ($DiagnosticSetting in $DiagnosticSettings){
        [PSCustomObject]@{
        ResourceID = $SelectedResource.id
        ResourceType = $SelectedResource.type
        Name = $DiagnosticSetting.Name
        CategoryType = $DiagnosticSetting.properties.CategoryType
        }
            }
        }

        Catch [Microsoft.PowerShell.Commands.HttpResponseException]{
            Write-log -Message "Error: '$($_.Exception.Response.ReasonPhrase)' for Resource: '$($SelectedResource.id)' "
        }
        Catch {
            Write-log -Message "Error: '$($_.Exception.Message)' for Resource: '$($SelectedResource.id)'"
        }
    }   
    
    
}
Function Select-ResourceSample {
    [CmdletBinding()]
    Param(
        [string[]]$ResourceTypes,
        [PsCustomObject[]]$Resources
    )
    Foreach ($Type in $ResourceTypes) {
        
        $Resources | Where-Object {$_.type -eq $Type} | Select-Object -first 1
        
    }
}
#region Main
$ScriptStart = Get-Date
$WarningPreference = 'SilentlyContinue'
try {
$Config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction stop -Verbose:$false
# create export folder if needed
if (-not (test-path -Path $Config.Settings.ExportPath)){
    New-Item $Config.Settings.ExportPath -ItemType directory -ErrorAction stop
}
}
Catch {
throw "Could not intialize script. Please check Configuration is valid or export path can be created."
}

# log file will rotate daily by default - please refer write-log function
$LogFilePath = $Config.Settings.LogfilePath
Write-Log "Script Started."
$SubscriptionIDs = @(Get-SubscriptionIds -Config $Config)
Write-log "Found $($SubscriptionIDs.Count) number of subscriptions. SubscriptionIds: '$($SubscriptionIDs -join ',')'"

Foreach ($SubscriptionID  in $SubscriptionIDs) {
    Write-Log "Started Working on Subscription  with id '$SubscriptionID'"
    $AuthHeader = Get-AuthHeader -SubscriptionID $SubscriptionID
    $ResourceGroups = @($Config | Get-SubscriptionResourceGroups -SubscriptionID $SubscriptionID)  
    Foreach ($ResourceGroup in $ResourceGroups){
        Write-log "Started working on '$ResourceGroup' in Subscription:'$SubscriptionID'"
        $Resources = Get-ResourcesInResourceGroup -SubscriptionID $SubscriptionID -ResouceGroup $ResourceGroup -authHeader $AuthHeader
        $UniqueResourceTypes = $Resources.type | Select-Object -Unique
        Write-log "'$Resourcegroup': Found $($Resources.Count) resources. These resources are instances of $($UniqueResourceTypes.Count) unique Resource types."
        $SelectedResources = Select-ResourceSample -ResourceTypes $UniqueResourceTypes -Resources $Resources
        Write-log "'$Resourcegroup': Selected $($SelectedResources.Count) resources for sampling."
        # get and export metrics to csv
        Get-MetricsForResource -SelectedResources $SelectedResources -AuthHeader $AuthHeader -verbose | Export-Csv -Path "$($Config.Settings.ExportPath)\$SubscriptionID`_$ResourceGroup`_Metrics.csv" -NoTypeInformation
        # get and export activity logs to csv
        Get-AzActivityLogs -subscriptionId $SubscriptionID -AuthHeader $AuthHeader -DaysOld $Config.Settings.ActivityLogDays -ResourceGroup $ResourceGroup `
            | Select-Object -Property @{Name='ResourceType';Expression={$_.ResourceType.Value}}, @{Name='Operation';Expression={$_.OperationName.Value}}, @{Name='Category';Expression={$_.properties.eventCategory}} `
            | Select-Object -Property ResourceType,Operation,Category -Unique | Sort-Object -Property ResourceType `
            | Export-Csv -Path "$($Config.Settings.ExportPath)\$SubscriptionID`_$ResourceGroup`_ActivityLog.csv" -NoTypeInformation
        # get and export metrics to csv
        Get-DiagnosticSettingsForResource -SelectedResources $SelectedResources -AuthHeader $AuthHeader -verbose | Export-Csv -Path "$($Config.Settings.ExportPath)\$SubscriptionID`_$ResourceGroup`_DiagnosticSettings.csv" -NoTypeInformation
        Write-log "Finished working on '$ResourceGroup' in Subscription:'$SubscriptionID'"
    }
        
        Write-Log "Finished Working on Subscription  with id '$SubscriptionID'"
}

$ScriptDurationSeconds = [Math]::Round(((Get-Date) - $ScriptStart).TotalSeconds)
Write-Log "Script ended. Duration $ScriptDurationSeconds seconds."
#endregion