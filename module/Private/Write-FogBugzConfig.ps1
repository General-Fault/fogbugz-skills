function Write-FogBugzConfig {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    $storagePath = Get-FogBugzStoragePath -WorkingDirectory $WorkingDirectory -CreateIfMissing
    $path = Join-Path $storagePath 'config.json'
    @{ BaseUri = $BaseUri.Trim() } | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
}

