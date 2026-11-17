#################################################
# HelloID-Conn-Prov-Target-MultiBel-Permissions-JobCategories-List
# List job categories as permissions
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
    Write-Information 'Retrieving MultiBel job categories'
    $splatGetJobCategoriesParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/JobCategory"
        Method  = 'GET'
        Headers = @{
            'MB-ApiKey' = "$($actionContext.Configuration.ApiKey)"
        }
    }
    $response = Invoke-RestMethod @splatGetJobCategoriesParams
    # Skip empty items, so no permission with an empty reference is returned
    $retrievedJobCategories = @(@($response) | Where-Object { -not [string]::IsNullOrWhiteSpace("$($_.id)") })
    Write-Information "Retrieved [$($retrievedJobCategories.Count)] job categories"

    foreach ($jobCategory in $retrievedJobCategories) {
        if ("$($jobCategory.id)" -eq $actionContext.Configuration.DefaultJobCategoryId) {
            Write-Information "Skipping default job category [$($jobCategory.name)] - [$($jobCategory.id)]"
            continue
        }
        $outputContext.Permissions.Add(
            @{
                DisplayName    = "JobCategory - $($jobCategory.name)"
                Identification = @{
                    Reference = "$($jobCategory.id)"
                }
            }
        )
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MultiBelError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not retrieve MultiBel job categories. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not retrieve MultiBel job categories. Error: $($ex.Exception.Message)"
    }
}
