# WAF Monitoring

Private repository to minimize manual effort for the azure monitoring pattern excell sheet using powershell. 


## Working with Rest


 - settingm some variables first
```PowerShell
Connect-AzAccount

$SubscriptionID = 'c02646f3-6401-40c7-8543-69333821da9a'
$ResourceGroup = 'ContosoAll'
$ApiVersion  = '2021-04-01'
```
- Add the following function to your code for getting the auth header.

```PowerShell
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
```

# Working with Microsoft.Insights provider

Get the header first for rest authentication/authorization
```PowerShell
$authHeader = Get-AuthHeader -SubscriptionID $SubscriptionID
```

Get the resources per Subscription/resource group
```PowerShell
$ResourceListUri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/resources?api-version=$ApiVersion"
$ResourceList = Invoke-RestMethod -URI $URI -Method Get -Headers $authHeader
```

Get the metric defionions per resouce
```PowerShell
$MetricDefinitionURI = "https://management.azure.com$ResourceID/providers/Microsoft.Insights/metricDefinitions?api-version=2018-01-01"
$ResourceList = Invoke-RestMethod -URI $MetricDefinitionURI -Method Get -Headers $authHeader
```

Get the resource details using the resourceid from the metric list.
```PowerShell
$ResourceURI = "https://management.azure.com/subscriptions/c02646f3-6401-40c7-8543-69333821da9a/resourceGroups/ContosoAll/providers/Microsoft.Compute/virtualMachines/emreg-web01?api-version=$ApiVersion"
$ResourceID = '/subscriptions/c02646f3-6401-40c7-8543-69333821da9a/resourceGroups/CONTOSOALL/providers/Microsoft.Compute/virtualMachines/emreg-web01'
$Resource = Invoke-RestMethod -Method get -URI  $ResourceURI -Headers $authHeader

```


# error handling


 - Authentication token expires, try to catch and reauth if needed using below examples
 ``` PowerShell
<#

[6.5 ms] C:\Windows\system32> $Metrics = Invoke-RestMethod -Method get -Uri $MetricURI -Headers $authHeader
Invoke-RestMethod : {"error":{"code":"AuthorizationFailed","message":"The client 'emreg@microsoft.com' with object id 'f8cb4735-3214-4381-b0e0-337e81b6bd7c' does not have authorization to perform action 'Microsoft.Insights/metrics/read' over scope 
'/providers/Microsoft.Insights' or the scope is invalid. If access was recently granted, please refresh your credentials."}}
At line:1 char:12
+ $Metrics = Invoke-RestMethod -Method get -Uri $MetricURI -Headers $au ...
+            ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (System.Net.HttpWebRequest:HttpWebRequest) [Invoke-RestMethod], WebException
    + FullyQualifiedErrorId : WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeRestMethodCommand



#>
# Catch webexception and if 403 reauthenticate with Azure : )
$Error[1].Exception.Response.StatusCode.value__
```