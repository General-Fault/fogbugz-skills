function Get-FogBugzCredential {
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    $result = [FogBugzCredentialStore]::Read("FogBugz:$($BaseUri.Trim())")
    if ($null -eq $result) { return $null }
    [pscustomobject]@{ UserName = $result[0]; Token = $result[1] }
}

