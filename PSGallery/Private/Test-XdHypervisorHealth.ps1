function Test-XdHypervisorHealth {
    <#   
.SYNOPSIS   
    Checks the Status of the Environmental Tests Passed In
.DESCRIPTION 
    Checks the Status of the Environmental Tests Passed In
.PARAMETER AdminAddress
    Current Broker
.NOTES
    Current Version:        1.0
    Creation Date:          22/02/2018
.CHANGE CONTROL
    Name                    Version         Date                Change Detail
    Adam Yarborough         1.0             21/03/2018          Function Creation
    Adam Yarborough         1.1             07/06/2018          Update for object model.
.EXAMPLE
    None Required
#>

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]$AdminAddress
    )

    #Create array with results
    $Results = @()
    $Errors = @()

    Write-Verbose "XdHypervisor Check started"
    $HypervisorConnections = Get-HypScopedObject -AdminAddress $AdminAddress
    Write-Verbose "Initialize Test Variables"

    $Health = $true
        
    foreach ($Connection in $HypervisorConnections) {
        Write-Verbose "Testing $($Connection.Name)"
        
        $TestTarget = New-EnvTestDiscoveryTargetDefinition -AdminAddress $AdminAddress -TargetIdType "HypervisorConnection" -TestSuiteId "HypervisorConnection" -TargetId $Connection.HypHypervisorConnectionUid
        $TestResults = Start-EnvTestTask -AdminAddress $AdminAddress -InputObject $TestTarget -RunAsynchronously 
        foreach ( $Result in $TestResults.TestResults ) {
            foreach ( $Component in $Result.TestComponents ) {
                Write-Verbose "$($Connection.Name) - $($Component.TestID) - $($Component.TestComponentStatus)"
                if ( ($Component.TestComponentStatus -ne "CompletePassed") -and ($Component.TestComponentStatus -ne "NotRun") ) {
                    $Errors += "$($Connection.Name) - $($Component.TestID) - $($Component.TestComponentStatus)" 
                    $Health = $false
                }
            }

        }       
       
        Write-Verbose "Testing associated resources"

        $HypervisorResources = Get-ChildItem XDHyp:\HostingUnits\* -AdminAddress $AdminAddress | Where-Object HypervisorConnection -like $Connection.Name

        # Check the resources
        foreach ($Resource in $HypervisorResources ) {
            $Status = "Passed"
            $TestTarget = New-EnvTestDiscoveryTargetDefinition -AdminAddress $AdminAddress -TargetIdType "HostingUnit" -TestSuiteId "HostingUnit" -TargetId $Resource.HostingUnitUid
            $TestResults = Start-EnvTestTask -AdminAddress $AdminAddress -InputObject $TestTarget -RunAsynchronously 
            foreach ( $Result in $TestResults.TestResults ) {
                Write-Verbose "$($Connection.Name) - $($Resource.HostingUnitName) - $($Component.TestID) - $($Component.TestComponentStatus)"
                foreach ( $Component in $Result.TestComponents ) {
                    if ( ($Component.TestComponentStatus -ne "CompletePassed") -and ($Component.TestComponentStatus -ne "NotRun") ) {
                        $Errors += "$($Connection.Name) - $($Resource.HostingUnitName) - $($Component.TestID) - $($Component.TestComponentStatus)"    
                        $Health = $false
                    }
                }
            }
        }
    }
    
    if ( $Health ) {
        return $true
    }
    else { 
        $Results += $Errors
        return $Results
    }
}
