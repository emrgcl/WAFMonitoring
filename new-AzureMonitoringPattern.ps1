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
function Get-Subscriptions {
    param (
        $Config
    )
    $Config.Subscriptions
    
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
    (Invoke-RestMethod -Method Get -Uri $ActivitLogURI -Headers $AuthHeader).Value
}



#region Main
$Config = Import-PowerShellDataFile -Path $ConfigPath
#log file will rotate daily by default - please refer write-log function
$LogFilePath = $Config.Settings.LogfilePath
Write-Log "Script Started."
$Subscriptions = Get-Subscriptions -Config $Config
Foreach ($Subscription  in $Subscriptions) {

    
}

#endregion