@{
    Subscriptions = @(
        # Subscription and resource groups to discover
        @{'c02646f3-6401-40c7-8543-69333821da9a' = @('ContosoAll')}
    )
    Settings = @{
        ExcelPath = ''
        LogfilePath = ".\AzureMonitoringPattern.log"
        ThrottleLimit = 10
        ApiVersion  = ''
        
    }
}