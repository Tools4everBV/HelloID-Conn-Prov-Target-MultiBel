#################################################
# HelloID-Conn-Prov-Target-MultiBel-Update
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
        [parameter(ValueFromPipeline)]
        $AccountObject

    )
    process {
        $returnObject = $AccountObject | Select-Object -Property $outputContext.Data.PSObject.Properties.Name
        # Only keep countryCode and number of the phone numbers, as used in the field mapping
        foreach ($property in @($returnObject.PSObject.Properties | Where-Object { $_.Name -match '^phoneNumber([1-9]|10)$' })) {
            $property.Value = [PSCustomObject]@{
                countryCode = "$($property.Value.countryCode)"
                number      = "$($property.Value.number)"
            }
        }
        return $returnObject
    }
}
#endregion

try {
    # Verify if [accountReference] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    # Initial Assignments
    $headers = @{
        'MB-ApiKey' = "$($actionContext.Configuration.ApiKey)"
    }

    Write-Information 'Verifying if a MultiBel account exists'
    $splatGetUserParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Person?MultiBelPersonId=$($actionContext.References.Account)"
        Method  = 'GET'
        Headers = $headers
    }
    $correlatedAccount = (Invoke-RestMethod @splatGetUserParams)

    if (-not [string]::IsNullOrWhiteSpace($correlatedAccount)) {
        $outputContext.PreviousData = $correlatedAccount | ConvertTo-MultiBelAccountObject

        # Phone numbers are nested objects and are compared separately
        $phoneNumberProperties = @($actionContext.Data.PSObject.Properties.Name | Where-Object { $_ -match '^phoneNumber([1-9]|10)$' })
        $splatCompareProperties = @{
            ReferenceObject  = @($outputContext.PreviousData.PSObject.Properties | Where-Object { $_.Name -notin $phoneNumberProperties })
            DifferenceObject = @($actionContext.Data.PSObject.Properties | Where-Object { $_.Name -notin $phoneNumberProperties })
        }
        $propertiesChanged = @(Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' })

        # A phone number with an empty number in the field mapping is cleared in MultiBel.
        # MultiBel only accepts an empty number when the countryCode is also empty
        $desiredPhoneNumbers = @{}
        $phoneNumbersChanged = @(foreach ($phoneNumberProperty in $phoneNumberProperties) {
                $desiredPhoneNumber = [PSCustomObject]@{
                    countryCode = "$($actionContext.Data.$phoneNumberProperty.countryCode)".Trim()
                    number      = "$($actionContext.Data.$phoneNumberProperty.number)".Trim()
                }
                if ([string]::IsNullOrEmpty($desiredPhoneNumber.number)) {
                    $desiredPhoneNumber.countryCode = ''
                }
                elseif ([string]::IsNullOrEmpty($desiredPhoneNumber.countryCode)) {
                    throw "The field mapping [$phoneNumberProperty.countryCode] is empty while [$phoneNumberProperty.number] has a value. MultiBel requires both values"
                }
                $desiredPhoneNumbers[$phoneNumberProperty] = $desiredPhoneNumber

                $currentPhoneNumber = $outputContext.PreviousData.$phoneNumberProperty
                if ($desiredPhoneNumber.countryCode -ne "$($currentPhoneNumber.countryCode)" -or
                    $desiredPhoneNumber.number -ne "$($currentPhoneNumber.number)") {
                    $phoneNumberProperty
                }
            })

        $propertiesChangedNames = @(@($propertiesChanged | ForEach-Object { $_.Name }) + $phoneNumbersChanged)
        if ($propertiesChangedNames.Count -gt 0) {
            $lifecycleProcess = 'UpdateAccount'
        }
        else {
            $lifecycleProcess = 'NoChanges'
        }
    }
    else {
        $lifecycleProcess = 'NotFound'
    }

    # Process
    switch ($lifecycleProcess) {
        'UpdateAccount' {
            Write-Information "Account property(s) required to update: $($propertiesChangedNames -join ', ')"

            $body = $correlatedAccount.PSObject.Copy()

            foreach ($property in $propertiesChanged) {
                $body.$($property.Name) = $actionContext.Data.$($property.Name)
            }

            foreach ($phoneNumberProperty in $phoneNumbersChanged) {
                $body | Add-Member -NotePropertyName $phoneNumberProperty -NotePropertyValue $desiredPhoneNumbers[$phoneNumberProperty] -Force
            }


            $headers['Content-Type'] = 'application/json;charset=utf-8'
            $splatUpdateParams = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Person"
                Method  = 'PUT'
                Body    = ([System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 10)))
                Headers = $headers
            }


            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Updating MultiBel account with accountReference: [$($actionContext.References.Account)]"
                $null = Invoke-RestMethod @splatUpdateParams
            }
            else {
                Write-Information "[DryRun] Update MultiBel account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            if ($outputContext.Data.PSObject.Properties.Name -Contains 'multibelPersonId') {
                $outputContext.Data.multibelPersonId = $actionContext.References.Account
            }
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Update account was successful, Account property(s) updated: [$($propertiesChangedNames -join ',')]"
                    IsError = $false
                })
            break
        }

        'NoChanges' {
            Write-Information "No changes to MultiBel account with accountReference: [$($actionContext.References.Account)]"
            $outputContext.Data = $correlatedAccount | ConvertTo-MultiBelAccountObject
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Skipped updating MultiBel account with AccountReference: [$($actionContext.References.Account)]. Reason: No changes."
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "MultiBel account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "MultiBel account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $true
                })
            break
        }
    }
}
catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MultiBelError -ErrorObject $ex
        $auditLogMessage = "Could not update MultiBel account: [$($actionContext.References.Account)]. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not update MultiBel account: [$($actionContext.References.Account)]. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}
