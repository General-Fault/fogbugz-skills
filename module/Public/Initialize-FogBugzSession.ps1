function Initialize-FogBugzSession {
    [CmdletBinding()]
    param(
        [string]$BaseUri = $env:FOGBUGZ_BASE_URI,

        [string]$WorkingDirectory = (Get-Location).Path,

        [pscredential]$Credential
    )

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)

    if ([string]::IsNullOrWhiteSpace($BaseUri)) {
        $config = Read-FogBugzConfig -WorkingDirectory $resolvedWorkingDirectory
        if ($config) { $BaseUri = $config.BaseUri }
    }

    if ([string]::IsNullOrWhiteSpace($BaseUri)) {
        $BaseUri = Read-Host 'Enter FogBugz tenant URI (example: https://yourtenant.fogbugz.com)'
    }

    if ([string]::IsNullOrWhiteSpace($BaseUri)) {
        throw 'BaseUri is required to initialize a FogBugz session.'
    }

    if ($null -eq $Credential) {
        $Credential = Get-Credential -Message 'Sign in to FogBugz'
    }

    $response = Invoke-FogBugzApi -BaseUri $BaseUri -Command 'logon' -Parameter @{
        email    = $Credential.UserName
        password = ConvertTo-FogBugzPlainText -SecureString $Credential.Password
    }

    $token = Get-FogBugzResponseValue -InputObject $response -Name 'Token'
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'FogBugz did not return a session token.'
    }

    Write-FogBugzConfig -WorkingDirectory $resolvedWorkingDirectory -BaseUri $BaseUri
    Set-FogBugzCredential -BaseUri $BaseUri -UserName $Credential.UserName -Token $token

    [pscustomobject]@{
        BaseUri          = $BaseUri
        Token            = $token
        UserName         = $Credential.UserName
        WorkingDirectory = $resolvedWorkingDirectory
    }
}

