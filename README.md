# WAF Monitoring

Private repository to minimize manual effort for the azure monitoring pattern excell sheet using powershell. 


## working with Rest

```PowerShell
Connect-AzAccount

$SubscriptionID = 'c02646f3-6401-40c7-8543-69333821da9a'
$ResourceGroup = 'ContosoAll'
$ApiVersion  = '2021-04-01'
```
- Add the following function to your code

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

# Working with several providers.

```PowerShell
$authHeader = Get-AuthHeader -SubscriptionID $SubscriptionID
$ResourceListUri = "https://management.azure.com/subscriptions/$SubscriptionID/resourceGroups/$ResourceGroup/resources?api-version=$ApiVersion"
$ResourceURI = "https://management.azure.com/subscriptions/c02646f3-6401-40c7-8543-69333821da9a/resourceGroups/ContosoAll/providers/Microsoft.Compute/virtualMachines/emreg-web01?api-version=$ApiVersion"
$ResourceID = '/subscriptions/c02646f3-6401-40c7-8543-69333821da9a/resourceGroups/CONTOSOALL/providers/Microsoft.Compute/virtualMachines/emreg-web01'
$MetricURI = "https://management.azure.com$ResourceID/providers/Microsoft.Insights/metrics?api-version=$ApiVersion"

$ResourceList = Invoke-RestMethod -URI $URI -Method Get -Headers $authHeader
$Resource = Invoke-RestMethod -Method get -URI  $ResourceURI -Headers $authHeader
$Metrics = Invoke-RestMethod -Method get -Uri $MetricURI -Headers $authHeader
$Resource.resources

$Results.value.Count
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