#################################################
# HelloID-Conn-Prov-Target-MultiBel-Permissions-JobCategories-Import
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
#endregion

try {
    Write-Information 'Starting MultiBel permission entitlement import'
    $headers = @{
        'MB-ApiKey' = "$($actionContext.Configuration.ApiKey)"
    }

    # Retrieve all job categories, so permissions without members are also known and the displayName matches the permissions script
    $splatGetJobCategoriesParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/JobCategory"
        Method  = 'GET'
        Headers = $headers
    }
    $jobCategories = @(Invoke-RestMethod @splatGetJobCategoriesParams)
    Write-Information "Retrieved [$($jobCategories.Count)] job categories"

    $membersByJobCategory = @{}
    foreach ($jobCategory in $jobCategories) {
        $membersByJobCategory["$($jobCategory.id)"] = [System.Collections.Generic.List[string]]::new()
    }

    # Retrieve all persons (20 per page) and group the persons by job category
    $page = 0
    do {
        $splatGetUsersParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/Persons?page=$page"
            Method  = 'GET'
            Headers = $headers
        }
        $response = (Invoke-RestMethod @splatGetUsersParams)
        foreach ($importedAccount in $response.personViewModels) {
            foreach ($assignedJobCategory in @($importedAccount.jobCategories | Where-Object { $null -ne $_ })) {
                $key = "$($assignedJobCategory.id)"
                if (-not $membersByJobCategory.ContainsKey($key)) {
                    $membersByJobCategory[$key] = [System.Collections.Generic.List[string]]::new()
                    $jobCategories += [PSCustomObject]@{
                        id   = $assignedJobCategory.id
                        name = $assignedJobCategory.name
                    }
                }
                $membersByJobCategory[$key].Add("$($importedAccount.multibelPersonId)")
            }
        }
        $page++
    } while ($response.personViewModels.count -gt 0 -and $actionContext.DryRun -eq $false)

    foreach ($jobCategory in $jobCategories) {
        $members = $membersByJobCategory["$($jobCategory.id)"]
        $permission = @{
            PermissionReference = @{
                Reference = "$($jobCategory.id)"
            }
            AccountReferences   = $null
        }

        # Split the members into batches of 500, the maximum number of account references per permission object
        $batchSize = 500
        for ($i = 0; $i -lt $members.Count; $i += $batchSize) {
            $permission.AccountReferences = [array]$members[$i..([Math]::Min($i + $batchSize - 1, $members.Count - 1))]
            Write-Output $permission
        }
    }
    Write-Information 'MultiBel permission entitlement import completed'
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MultiBelError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import MultiBel permission entitlements. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import MultiBel permission entitlements. Error: $($ex.Exception.Message)"
    }
}
