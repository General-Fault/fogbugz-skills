function Remove-FogBugzCredential {
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    [FogBugzCredentialStore]::Delete("FogBugz:$($BaseUri.Trim())")
}

