function Connect-FogBugzSession {
    [CmdletBinding()]
    param(
        [string]$BaseUri = $env:FOGBUGZ_BASE_URI,

        [string]$WorkingDirectory = (Get-Location).Path,

        [switch]$PromptForCredentials
    )

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)

    $config = Read-FogBugzConfig -WorkingDirectory $resolvedWorkingDirectory
    $resolvedBaseUri = if (-not [string]::IsNullOrWhiteSpace($BaseUri)) { $BaseUri } elseif ($config) { $config.BaseUri } else { $null }

    if (-not [string]::IsNullOrWhiteSpace($resolvedBaseUri)) {
        $cred = Get-FogBugzCredential -BaseUri $resolvedBaseUri
        if ($cred -and -not [string]::IsNullOrWhiteSpace($cred.Token)) {
            return [pscustomobject]@{
                BaseUri          = $resolvedBaseUri
                Token            = $cred.Token
                UserName         = $cred.UserName
                WorkingDirectory = $resolvedWorkingDirectory
            }
        }
    }

    if ($PromptForCredentials) {
        return Initialize-FogBugzSession -BaseUri $resolvedBaseUri -WorkingDirectory $resolvedWorkingDirectory
    }

    if ([string]::IsNullOrWhiteSpace($resolvedBaseUri)) {
        throw "No .fogbugz config found at or above '$resolvedWorkingDirectory'. Run Initialize-FogBugzSession (alias: fblogin)."
    }

    throw "No FogBugz credential found for '$resolvedBaseUri'. Run Initialize-FogBugzSession (alias: fblogin)."
}

