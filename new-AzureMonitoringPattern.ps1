[CmdletBinding()]
Param(

    [Parameter(Mandatory =$true)]
    [ValidateScript({test-path $_})]
    [string]$ConfigPath
)
Function New-ExcelObject {
    [CmdletBinding()]
    Param(
        [Switch]$Visible
    )

    $ExcelObject = New-Object -ComObject Excel.Application
    $ExcelObject.Visible = $Visible
    $ExcelObject
}
Function new-ExcelWorkbook {
    Param(
        $ExcelObject,
        $WorkbookName
    )
    
}
Function Add-ExcelSheet {
    [CmdletBinding()]
    Param(
        $ExcelObject,
        $SheetName,
        $Titles
    )

}
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
        [string]$ApiVersion = '2015-04-01' 
    )
    
    # need to set datetime to utc and then to json format which is iso8601 basically
    $StartDate = (((Get-Date).AddDays(-1*$DaysOld)).ToUniversalTime()).GetDAteTimeFormats('o')
    $Filter = "eventTimestamp ge '$StartDate'"
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
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias('id')]
        [string]$ResouceID,
        [hashtable]$AuthHeader,
        $ApiVersion ='2021-04-01'   
    )
    
   
    process {
    
        $MetricDefinitionURI = "https://management.azure.com$ResourceID/providers/Microsoft.Insights/metricDefinitions?api-version=2018-01-01"
        (Invoke-RestMethod -URI $MetricDefinitionURI -Method Get -Headers -verbose:$false).Value
        
    }
    
}
function Get-MetricsForResourceAsync {
    [CmdletBinding()]
    param (
        
        [string[]]$ResouceIDs,
        $ApiVersion ='2018-01-01',
        [int32]$ThrottleLimit = 10,
        [string]$SubscriptionID
    )
   
            $ResouceIDS | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            $_
            $MetricDefinitionURI = "https://management.azure.com$($_)/providers/Microsoft.Insights/metricDefinitions?api-version=2018-01-01"
            $AzContext = Set-AzContext -Subscription $using:SubscriptionID
            $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
            $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
            $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
            $authHeader = @{
                'Content-Type'='application/json'
                'Authorization'='Bearer ' + $token.AccessToken
            }
            (Invoke-RestMethod -URI $MetricDefinitionURI -Method Get -Headers $AuthHeader -verbose:$false).Value
        }
}
Function Get-ResourceType {
    [CmdletBinding()]
    Param(
        $Resources
    )
    $Resources.Type | Select-Object -Property Type -Unique
}
Function Select-ResourceSample {
    [CmdletBinding()]
    Param(
        [string[]]$ResourceTypes,
        [PsCustomObject[]]$Resources
    )
    Foreach ($Type in $ReouceTypes) {
        
        $Resources | Where-Object {$_.type -eq $Type} | Select-Object -first 1
        
    }
}
#region Main
$ScriptStart = Get-Date
$WarningPreference = 'SilentlyContinue'

try {
$Config = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction stop -Verbose:$false

}
Catch {
throw "Configuration is not valid in '$ConfigPath'. Please verify the configuration and try again."
}

#log file will rotate daily by default - please refer write-log function
$LogFilePath = $Config.Settings.LogfilePath
Write-Log "Script Started."
$SubscriptionIDs = Get-SubscriptionIds -Config $Config
Write-log "Found $($SubscriptionIDs.Count) number of subscriptions. SubscriptionIds: '$($SubscriptionIDs -join ',')'"

Foreach ($SubscriptionID  in $SubscriptionIDs) {
    Write-Log "Started Working on Subscription  with id '$SubscriptionID'"
    $AuthHeader = Get-AuthHeader -SubscriptionID $SubscriptionID
    $ResourceGroups = $Config | Get-SubscriptionResourceGroups -SubscriptionID $SubscriptionID  
    Foreach ($ResourceGroup in $ResourceGroups){
        $Resources = Get-ResourcesInResourceGroup -SubscriptionID $SubscriptionID -ResouceGroup $ResourceGroup -authHeader $AuthHeader
        $UniqueResourceTypes = $Resources.type | Select-Object -Unique
        Write-log "'$Resourcegroup': Found $($Resources.Count) resources. These resources are instances of $($UniqueResourceTypes.Count) unique Resource types."
        $SelectedResources = Select-ResourceSample -ResourceTypes $UniqueResourceTypes -Resources $Resources
        $ResoruceIds = $SelectedResources.id
        Get-MetricsForResourceAsync -ResouceIDs $ResoruceIds -ThrottleLimit $Config.Settings.ThrottleLimit -SubscriptionID $SubscriptionID
    }
  
}

$ScriptDurationSeconds = [Math]::Round(((Get-Date) - $ScriptStart).TotalSeconds)
Write-Log "Script ended. Duration $ScriptDurationSeconds seconds."
#endregion