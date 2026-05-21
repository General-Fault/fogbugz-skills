function Write-FogBugzConfig {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    $path = Join-Path ([IO.Path]::GetFullPath($WorkingDirectory)) '.fogbugz'
    @{ BaseUri = $BaseUri.Trim() } | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
}

