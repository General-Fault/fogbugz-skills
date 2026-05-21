function Read-FogBugzConfig {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $path = Get-FogBugzConfigPath -WorkingDirectory $WorkingDirectory
    if (-not $path) { return $null }
    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    [pscustomobject]@{
        BaseUri = [string]$data.BaseUri
        Path    = $path
    }
}

