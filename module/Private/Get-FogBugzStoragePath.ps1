function Get-FogBugzStoragePath {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [switch]$CreateIfMissing
    )

    $dir = [IO.Path]::GetFullPath($WorkingDirectory)
    while ($dir) {
        $candidate = Join-Path $dir '.fogbugz'
        if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    if ($CreateIfMissing) {
        $storagePath = Join-Path ([IO.Path]::GetFullPath($WorkingDirectory)) '.fogbugz'
        if (-not (Test-Path -LiteralPath $storagePath -PathType Container)) {
            [void](New-Item -Path $storagePath -ItemType Directory -Force)
        }
        return $storagePath
    }

    $null
}
