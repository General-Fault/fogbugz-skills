function Get-FogBugzConfigPath {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $dir = [IO.Path]::GetFullPath($WorkingDirectory)
    while ($dir) {
        $candidate = Join-Path $dir '.fogbugz'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $null
}

