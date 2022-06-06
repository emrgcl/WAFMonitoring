# WAF Monitoring

Private repository to minimize manual effort for the azure monitoring pattern excell sheet using powershell. 

# Scoping
- Metrics in the sheet needs to be per class
- Ignore the non existing metric exceptions (Aggreed)
- Check if you can find some 

Running script
```
[1.92 mi] C:\Repos\WAFMonitoring> .\MonitoringPatternHelper.ps1 -ConfigPath '.\Config.Psd1' -Verbose   
VERBOSE: [06/06/2022 20:28:34][MonitoringPatternHelper.ps1] Script Started.
VERBOSE: [06/06/2022 20:28:34][MonitoringPatternHelper.ps1] Found 1 number of subscriptions. SubscriptionIds: 'c02646f3-6401-40c7-8543-69333821da9a'
VERBOSE: [06/06/2022 20:28:34][MonitoringPatternHelper.ps1] Started Working on Subscription  with id 'c02646f3-6401-40c7-8543-69333821da9a'
VERBOSE: [06/06/2022 20:28:48][MonitoringPatternHelper.ps1] Started working on 'ContosoAll' in Subscription:'c02646f3-6401-40c7-8543-69333821da9a'
VERBOSE: [06/06/2022 20:28:48][MonitoringPatternHelper.ps1] 'ContosoAll': Found 245 resources. These resources are instances of 31 unique Resource types.
VERBOSE: [06/06/2022 20:28:48][MonitoringPatternHelper.ps1] 'ContosoAll': Selected 31 resources for sampling.
VERBOSE: [06/06/2022 20:28:49][Get-MetricsForResource] microsoft.insights/workbooks is not a supported platform metric namespace, supported ones are Microsoft.AnalysisServices/servers,Microsoft.Web/staticSites,Microsoft.Web/serverFarms,Microsoft.Web/sites,Microsoft.Web/sites/slots,Microsoft.Web/hostingEnvironments,Microsoft.Web/hostingEnvironments/multiRolePools,Microsoft.Web/hostingEnvironments/workerPools,Microsoft.Web/connections,Microsoft.IoTCentral/IoTApps,Microsoft.ServiceBus/namespaces,Microsoft.HealthcareApis/services,Microsoft.HealthcareApis/workspaces
.
.
.
.
VERBOSE: [06/06/2022 20:29:39][MonitoringPatternHelper.ps1] Finished working on 'ContosoAll' in Subscription:'c02646f3-6401-40c7-8543-69333821da9a'
VERBOSE: [06/06/2022 20:29:39][MonitoringPatternHelper.ps1] Finished Working on Subscription  with id 'c02646f3-6401-40c7-8543-69333821da9a'
VERBOSE: [06/06/2022 20:29:39][MonitoringPatternHelper.ps1] Script ended. Duration 65 seconds.
```

# 

# Types
 - Resource
```
 Name        MemberType   Definition
----        ----------   ----------
Equals      Method       bool Equals(System.Object obj)
GetHashCode Method       int GetHashCode()
GetType     Method       type GetType()
ToString    Method       string ToString()
id          NoteProperty string id=/subscriptions/c02646f3-6401-40c7-8543-69333821da9a/resourceGroups/ContosoAll/providers/microsoft.insights/workbooks/82ab8601-967d-4ee2-b3c6-e40b4ed4716c
identity    NoteProperty System.Management.Automation.PSCustomObject identity=@{type=None}
kind        NoteProperty string kind=shared
location    NoteProperty string location=eastus
name        NoteProperty string name=82ab8601-967d-4ee2-b3c6-e40b4ed4716c
tags        NoteProperty System.Management.Automation.PSCustomObject tags=@{hidden-title=Workbook 2}
type        NoteProperty string type=microsoft.insights/workbooks
 ```
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

get List of activity logs for the subscription

```PowerShell
    $StartDate = (((Get-Date).AddDays(-1*$DaysOld)).ToUniversalTime()).GetDAteTimeFormats('o')
    $Filter = "eventTimestamp ge '$StartDate'"
    $ActivitLogURI = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Insights/eventtypes/management/values?api-version=$ApiVersion&`$filter=$filter"
    (Invoke-RestMethod -Method Get -Uri $ActivitLogURI -Headers $AuthHeader).Value
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