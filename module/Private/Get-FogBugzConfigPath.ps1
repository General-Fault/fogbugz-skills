function Get-FogBugzConfigPath {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $storagePath = Get-FogBugzStoragePath -WorkingDirectory $WorkingDirectory
    if (-not $storagePath) { return $null }

    $path = Join-Path $storagePath 'config.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $path
}

