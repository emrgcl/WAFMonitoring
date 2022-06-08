# WAF Reliability -  Monitoring Pattern Helper

Helper script to discover the resources and the related Metrics, Diagnostic Settings and Activity Log operations in the desired Subscription & Resource Groups. 

Before working on the **Azure Monitoring Pattern** you may want to run the script with the below steps and gather information about the Target Workload and start discussion with the customer.

## High Level Steps
1. Gather the Subscription and Resource Groups of the Target Workload. 
1. Update the Config.psd1 as below.
    ```PowerShell
    @{
        Subscriptions = @(
            # Subscription and resource groups to discover. 
            # You can add multiple resource groups per subscription and add as many subscription/resoucegroup key value pairs as desired.
            @{'c02646f3-6401-40c7-8543-69333821da9a' = @('ContosoAll')}
        )
        Settings = @{
            # Export the reports in to the below path.
            ExportPath = '.\Reports'
            # Log file if you need to troubleshoot. By default rotates daily.
            LogfilePath = ".\AzureMonitoringPattern.log"
            # Number of days to collect the activity log. 
            ActivityLogDays=7
        }
    }
    ```
1. Run the script 

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
1. Check the files under **ExportPath** which is set in **Config.psd1**. 
    ![Schema Sheet](/Images/reports.jpg)
    >**Note:** Please note that a CSV file created for each resource group.
1. Copy the desired Metric, Diagnostic Setting and Activity log information into the **Azure Monitoring Pattern** Excel sheet.

# Notes

- Script supports multiple subscription but for single tenant. 
- Discovers the resource types within the desired Subsription/resouce group pairs and then gathers metrics/activity log and diagnostic settings for the Resource Types.
- Logging is enabled by default. 
- Some Resource types dont have metrics therefore you will see errros in the logs for these resources, you can safely ignore.

# Requirements
 - Powershell : )
 - The following modules
    ```PowerShell
    #Requires -Module @{ModuleName='Az.Accounts';ModuleVersion ='2.7.1'},@{ModuleName='Az.Monitor';ModuleVersion ='2.7.0 '}
    ```
# Next Steps
- Script currently do not support tags. Next step would be to add tags instead of resource group based filtering as a secondary option.