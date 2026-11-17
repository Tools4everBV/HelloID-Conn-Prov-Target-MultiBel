#################################################
# HelloID-Conn-Prov-Target-MultiBel-RevokePermission-JobCategory
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

function ConvertTo-MultiBelUpdateBody {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $AccountObject,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]
        $JobCategories
    )
    process {
        $body = $AccountObject.PSObject.Copy()

        # Required to keep the PUT call from failing and losing existing phoneNumbers
        for ($i = 1; $i -le 10; $i++) {
            $phone = $body."phoneNumber$($i)"
            if ([string]::IsNullOrWhiteSpace($phone.number) -or [string]::IsNullOrWhiteSpace($phone.countryCode)) {
                $body.PSObject.Properties.Remove("phoneNumber$($i)") | Out-Null
            }
        }

        # The PUT call expects [Category] objects (id, externalCategoryId) instead of the [CategoryGet] objects returned by the GET call
        $body.jobCategories = [array]($JobCategories | ForEach-Object {
                [PSCustomObject]@{
                    id                 = [int]$_.id
                    externalCategoryId = "$($_.externalCategoryId)"
                }
            })
        if ($null -eq $body.jobCategories) {
            $body.jobCategories = @()
        }
        Write-Output $body
    }
}
#endregion

# Begin
try {
    # Verify if [accountReference] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    $headers = @{
        'MB-ApiKey' = "$($actionContext.Configuration.ApiKey)"
    }
    $permissionReference = "$($actionContext.References.Permission.Reference)"

    Write-Information 'Verifying if a MultiBel account exists'
    $splatGetUserParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Person?MultiBelPersonId=$($actionContext.References.Account)"
        Method  = 'GET'
        Headers = $headers
    }
    $correlatedAccount = (Invoke-RestMethod @splatGetUserParams)

    if ([string]::IsNullOrWhiteSpace($correlatedAccount)) {
        $lifecycleProcess = 'NotFound'
    }
    elseif ((@($correlatedAccount.jobCategories).id | ForEach-Object { "$_" }) -contains $permissionReference) {
        $lifecycleProcess = 'RevokePermission'
    }
    else {
        $lifecycleProcess = 'NoChanges'
    }

    # Process
    switch ($lifecycleProcess) {
        'RevokePermission' {
            $newJobCategories = [array]@($correlatedAccount.jobCategories | Where-Object { $null -ne $_ -and "$($_.id)" -ne $permissionReference })
            $body = ConvertTo-MultiBelUpdateBody -AccountObject $correlatedAccount -JobCategories $newJobCategories

            $headers['Content-Type'] = 'application/json;charset=utf-8'
            $splatUpdateParams = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Person"
                Method  = 'PUT'
                Body    = ([System.Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 10)))
                Headers = $headers
            }

            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Revoking MultiBel job category: [$($actionContext.PermissionDisplayName)] - [$permissionReference]"
                $null = Invoke-RestMethod @splatUpdateParams
            }
            else {
                Write-Information "[DryRun] Revoke MultiBel job category: [$($actionContext.PermissionDisplayName)] - [$permissionReference], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Revoke permission [$($actionContext.PermissionDisplayName)] was successful"
                    IsError = $false
                })
            break
        }

        'NoChanges' {
            Write-Information "Job category: [$($actionContext.PermissionDisplayName)] is not assigned to MultiBel account: [$($actionContext.References.Account)]"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Skipped revoking permission [$($actionContext.PermissionDisplayName)]. Reason: Permission is already revoked."
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "MultiBel account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Skipped revoking permission [$($actionContext.PermissionDisplayName)]. Reason: MultiBel account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $false
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
        $auditLogMessage = "Could not revoke MultiBel permission [$($actionContext.PermissionDisplayName)] for account: [$($actionContext.References.Account)]. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not revoke MultiBel permission [$($actionContext.PermissionDisplayName)] for account: [$($actionContext.References.Account)]. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}
