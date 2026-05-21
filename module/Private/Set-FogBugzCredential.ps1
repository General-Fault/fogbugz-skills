function Set-FogBugzCredential {
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [string]$UserName,

        [Parameter(Mandatory)]
        [string]$Token
    )

    [FogBugzCredentialStore]::Write("FogBugz:$($BaseUri.Trim())", $UserName, $Token)
}

