function Get-FogBugzSavedFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session
    )

    $commands = @('savedfilters', 'listFilters')
    $lastError = $null

    foreach ($command in $commands) {
        try {
            $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command $command -Token $Session.Token
            return @(ConvertFrom-FogBugzFilter -InputObject $response)
        }
        catch {
            $lastError = $_
            $message = $_.Exception.Message
            if ($message -like '*No such API command*' -and $command -ne $commands[-1]) {
                continue
            }

            throw
        }
    }

    throw $lastError
}

