function Get-FogBugzCaseFeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session,

        [string]$FilterName
    )

    $parameters = @{
        cols = 'ixBug,sTitle,ixPriority,sStatus,fBlocked,dtLastUpdated,sFilter'
    }
    if (-not [string]::IsNullOrWhiteSpace($FilterName)) {
        $filters = @(Get-FogBugzSavedFilter -Session $Session)
        if ($filters.Count -eq 0) {
            throw 'FogBugz returned no saved filters for this account.'
        }
        $filter = Resolve-FogBugzFilter -FilterName $FilterName -Filter $filters
        $parameters.filter = Get-FogBugzResponseValue -InputObject $filter -Name 'Id'
        if ([string]::IsNullOrWhiteSpace([string]$parameters.filter)) {
            throw "FogBugz filter '$FilterName' is missing an ID and cannot be used for case search."
        }
    }

    $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command 'search' -Token $Session.Token -Parameter $parameters
    @(ConvertFrom-FogBugzCase -InputObject $response)
}

