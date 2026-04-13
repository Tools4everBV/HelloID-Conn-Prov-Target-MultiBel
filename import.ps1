#################################################
# HelloID-Conn-Prov-Target-MultiBel-Import
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-MultiBelError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            if ($errorDetailsObject.message) {
                $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.Code) - $($errorDetailsObject.message)".Trim().Trim('-')
            }
            else {
                $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            }
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            Write-Warning $_.Exception.Message
        }
        Write-Output $httpErrorObj
    }
}

function ConvertTo-MultiBelImportAccountObject {
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline)]
        $AccountObject

    )
    process {
        $returnObject = $AccountObject | Select-Object -Property $actionContext.ImportFields
        if ($returnObject.PSObject.Properties.Name -contains 'jobCategories') {
            $returnObject.jobCategories = $returnObject.jobCategories.id -join ', '
        }
        return $returnObject
    }
}
#endregion

try {
    Write-Information 'Starting MultiBel account entitlement import'
    $page = 0
    do {
        $splatGetUsersParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Persons?page=$page"
            Method  = 'GET'
            Headers = @{
                'MB-ApiKey' = "$($actionContext.Configuration.ApiKey)"
            }
        }
        $response = (Invoke-RestMethod @splatGetUsersParams)
        foreach ($importedAccount in $response.personViewModels) {
            $data = $importedAccount | ConvertTo-MultiBelImportAccountObject

            # Make sure the displayName has a value
            $displayName = "$($importedAccount.firstName) $($importedAccount.lastName)".trim()
            if ([string]::IsNullOrEmpty($displayName)) {
                $displayName = $importedAccount.multibelPersonId
            }

            # Make sure the emailAddress has a value
            $emailAddress = "$($importedAccount.emailAdress)"
            if ([string]::IsNullOrWhiteSpace($importedAccount.emailAdress)) {
                $emailAddress = "$($importedAccount.multibelPersonId)"
            }

            Write-Output @{
                AccountReference = $importedAccount.multibelPersonId
                DisplayName      = $displayName
                UserName         = $emailAddress
                Enabled          = $importedAccount.isActive
                Data             = $data
            }
        }
        $page++
    } while ($response.personViewModels.count -gt 0 -and $actionContext.DryRun -eq $false)
    Write-Information 'MultiBel account entitlement import completed'
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MultiBelError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import MultiBel account entitlements. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import MultiBel account entitlements. Error: $($ex.Exception.Message)"
    }
}
