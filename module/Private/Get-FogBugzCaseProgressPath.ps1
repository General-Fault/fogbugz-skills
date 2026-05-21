function Get-FogBugzCaseProgressPath {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [switch]$CreateIfMissing
    )

    $storagePath = Get-FogBugzStoragePath -WorkingDirectory $WorkingDirectory -CreateIfMissing:$CreateIfMissing
    if (-not $storagePath) { return $null }
    Join-Path $storagePath 'case-progress.json'
}
