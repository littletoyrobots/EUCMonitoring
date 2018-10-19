Function Test-XdSessionInfo {
    <#   
.SYNOPSIS   
    Returns Stats of the XenDesktop Sessions
.DESCRIPTION 
    Returns Stats of the XenDesktop Sessions
.PARAMETER Broker 
    XenDesktop Broker to use for the checks

.NOTES
    Current Version:        1.0
    Creation Date:          29/03/2018
.CHANGE CONTROL
    Name                    Version         Date                Change Detail
    David Brett             1.0             29/03/2018          Function Creation
    Adam Yarborough         1.1             07/06/2018          Update to new object model
    Adam Yarborough         1.2             20/06/2018          Session Information
.EXAMPLE
    None Required
#>
    Param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$Broker
    )

    Begin { 
        $ctxsnap = Add-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Broker.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Error "XenDesktop Powershell Snapin Load Failed"
            Write-Error "Cannot Load XenDesktop Powershell SDK"
            Return 
        }
        else {
            Write-Verbose "XenDesktop Powershell SDK Snapin Loaded"
        }

        $ctxsnap = Add-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue
        $ctxsnap = Get-PSSnapin Citrix.Configuration.Admin.* -ErrorAction SilentlyContinue

        if ($null -eq $ctxsnap) {
            Write-Error "XenDesktop Powershell Snapin Load Failed"
            Write-Error "Cannot Load XenDesktop Powershell SDK"
            Return 
        }
        else {
            Write-Verbose "XenDesktop Powershell SDK Snapin Loaded"
        }
    }

    Process { 
        $Results = @()
        $Errors = @()
        
        $SiteName = (Get-BrokerSite -AdminAddress $Broker).Name
        $ZoneNames = (Get-ConfigZone -AdminAddress $Broker).Name
        $CatalogNames = (Get-BrokerCatalog -AdminAddress $Broker).Name
        $DeliveryGroups = (Get-BrokerDesktopGroup -AdminAddress $Broker).Name
        Foreach ($ZoneName in $ZoneNames) {
            Foreach ($CatalogName in $CatalogNames) {
                Foreach ($DeliveryGroupName in $DeliveryGroups) {
                    Write-Verbose "Getting session details: $ZoneName / $CatalogName / $DeliveryGroupName"
                    $params = @{
                        AdminAddress     = $Broker;
                        CatalogName      = $CatalogName;
                        DesktopGroupName = $DeliveryGroupName;
                        #SessionState     = "Active";
                        Maxrecordcount   = 99999
                    }
                    $TotalSessions = (Get-BrokerSession @params).Count
                 

                    $params = @{
                        AdminAddress     = $Broker;
                        CatalogName      = $CatalogName;
                        DesktopGroupName = $DeliveryGroupName;
                        SessionState     = "Active";
                        Maxrecordcount   = 99999
                    }
                    $Sessions = Get-BrokerSession @params

                    $params = @{
                        AdminAddress     = $Broker;
                        CatalogName      = $CatalogName;
                        DesktopGroupName = $DeliveryGroupName;
                        ZoneName         = $ZoneName;
                        Maxrecordcount   = 99999
                    }
                    $Machines = Get-BrokerMachine @params

                    if ($null -ne $Sessions) {
                        
                        $ActiveSessions = ($Sessions | Where-Object IdleDuration -lt 00:00:01).Count
                        $IdleSessions = ($Sessions | Where-Object IdleDuration -gt 00:00:00).Count
                        $params = @{
                            AdminAddress     = $Broker;
                            DesktopGroupName = $DeliveryGroupName;
                            SessionState     = "Disconnected";
                            Maxrecordcount   = 99999
                        }
                        $DisconnectedSessions = (Get-BrokerSession @params).Count
                        
                        Write-Verbose "TotalSessions            = $TotalSessions"
                        Write-Verbose "ActiveSessions           = $ActiveSessions"
                        Write-Verbose "IdleSessions             = $IdleSessions"
                        Write-Verbose "DisconnectedSessions     = $DisconnectedSessions"
                        # Add Session Totals to Results
                        $Results += [PSCustomObject]@{
                            'SiteName'             = $SiteName   
                            'ZoneName'             = $ZoneName
                            'CatalogName'          = $CatalogName
                            'DeliveryGroupName'    = $DeliveryGroupName
                            'TotalSessions'        = $TotalSessions
                            'ActiveSessions'       = $ActiveSessions
                            'IdleSessions'         = $IdleSessions
                            'DisconnectedSessions' = $DisconnectedSessions
                            'Errors'               = $Errors
                        }

                        $BrokeringDurationAvg = ($Sessions | `
                                Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                                Select-Object -ExpandProperty BrokeringDuration | Measure-Object -Average).Average
                        $BrokeringDurationMax = ($Sessions | `
                                Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                                Select-Object -ExpandProperty BrokeringDuration | Measure-Object -Maximum).Maximum
                        $EstablishmentDurationAvg = ($Sessions | `
                                Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                                Select-Object -ExpandProperty EstablishmentDuration | Measure-Object -Average).Average
                        $EstablishmentDurationMax = ($Sessions | `
                                Where-Object BrokeringTime -gt ((get-date) + (New-TimeSpan -Hours -1)) | `
                                Select-Object -ExpandProperty EstablishmentDuration | Measure-Object -Maximum).Maximum
                    
                        # If one gets a value, all should.  
                        if ($null -ne $BrokeringDurationAvg) {
                            Write-Verbose "BrokeringDurationAvg     = $BrokeringDurationAvg"
                            Write-Verbose "BrokeringDurationMax     = $BrokeringDurationMax"
                            Write-Verbose "EstablishmentDurationAvg = $EstablishmentDurationAvg"
                            Write-Verbose "EstablishmentDurationMax = $EstablishmentDurationMax"

                            $Results += [PSCustomObject]@{
                                'SiteName'                 = $SiteName   
                                'ZoneName'                 = $ZoneName
                                'CatalogName'              = $CatalogName
                                'DeliveryGroupName'        = $DeliveryGroupName
                                'BrokeringDurationAvg'     = $BrokeringDurationAvg
                                'BrokeringDurationMax'     = $BrokeringDurationMax
                                'EstablishmentDurationAvg' = $EstablishmentDurationAvg
                                'EstablishmentDurationMax' = $EstablishmentDurationMax
                                'Errors'                   = $Errors
                            }
                        }
                    }
                    
               
                    if ($null -ne $Machines) {                                
                        $LoadIndexAvg = ($Machines.LoadIndex | Measure-Object -Average).Average
                        $LoadIndexMax = ($Machines.LoadIndex | Measure-Object -Maximum).Maximum
                    
                        Write-Verbose "LoadIndexAvg             = $LoadIndexAvg"
                        Write-Verbose "LoadIndexMax             = $LoadIndexMax"
                        $LoadIndexAvg = ($Machines.LoadIndex | Measure-Object -Average).Average
                        $LoadIndexMax = ($Machines.LoadIndex | Measure-Object -Maximum).Maximum

                        $Results += [PSCustomObject]@{
                            'SiteName'          = $SiteName   
                            'ZoneName'          = $ZoneName
                            'CatalogName'       = $CatalogName
                            'DeliveryGroupName' = $DeliveryGroupName
                            'LoadIndexAvg'      = $LoadIndexAvg
                            'LoadIndexMax'      = $LoadIndexMax
                            'Errors'            = $Errors
                        }
                    }
    
                }
            }
        }
        return $Results
    }

    End { }
}