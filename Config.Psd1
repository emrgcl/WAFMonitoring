@{
    Subscriptions = @(
        # Subscription and resource groups to discover
        @{'2410b933-6fd3-4c5e-b532-f858f63f2f8b' = @('ContosoAll','ContosoNew')}
        @{'2e3600b2-7289-4d8f-bb01-06af4142c2ff' = @('ResouceGroup1')}
    )
    Settings = @{
        ExportPath = '.\Reports'
        LogfilePath = ".\AzureMonitoringPattern.log"
        ActivityLogDays=7
        
    }
}