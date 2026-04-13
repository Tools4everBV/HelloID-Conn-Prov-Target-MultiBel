#################################################
# HelloID-Conn-Prov-Target-MultiBel-Create
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

function ConvertTo-MultiBelAccountObject {
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        $AccountObject

    )
    process {
        $returnObject = $AccountObject | Select-Object -Property $outputContext.Data.PSObject.Properties.Name
        if ($returnObject.PSObject.Properties.Name -contains 'jobCategories') {
            $returnObject.jobCategories = $returnObject.jobCategories.id -join ', '
        }
        return $returnObject
    }
}
#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'
    $headers = @{
        'MB-ApiKey' = "$($actionContext.Configuration.ApiKey)"
    }

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        Write-Information "Verifying if a MultiBel account exists where $correlationField is: [$correlationValue]"
        $splatGetUserParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Person?$correlationField=$($correlationValue)"
            Method  = 'GET'
            Headers = $headers
        }
        $correlatedAccount = (Invoke-RestMethod @splatGetUserParams)
    }

    if ([string]::IsNullOrWhiteSpace($correlatedAccount)) {
        $lifecycleProcess = 'CreateAccount'
    }
    else {
        $lifecycleProcess = 'CorrelateAccount'
    }

    # Process
    switch ($lifecycleProcess) {
        'CreateAccount' {
            # Adjust the body according to the API documentation.
            $body = $actionContext.Data.PSObject.Copy()
            $body.jobCategories = @(@{
                    id = $actionContext.Data.jobCategories
                })
            $body | Add-Member @{
                isActive = $false
            }
            $headers['Content-Type'] = 'application/json;charset=utf-8'
            $splatCreateParams = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Person"
                Method  = 'POST'
                Body    = ([System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 10)))
                Headers = $headers
            }
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information 'Creating and correlating MultiBel account'

                $createdAccount = Invoke-RestMethod @splatCreateParams
                $outputContext.Data = $createdAccount | ConvertTo-MultiBelAccountObject
                $outputContext.AccountReference = $createdAccount.multibelPersonId
            }
            else {
                Write-Information '[DryRun] Create and correlate MultiBel account, will be executed during enforcement'
            }
            $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating MultiBel account'
            $outputContext.Data = $correlatedAccount | ConvertTo-MultiBelAccountObject
            $outputContext.AccountReference = $correlatedAccount.multibelPersonId
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $lifecycleProcess
            Message = $auditLogMessage
            IsError = $false
        })
}
catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MultiBelError -ErrorObject $ex
        $auditLogMessage = "Could not create or correlate MultiBel account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not create or correlate MultiBel account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}