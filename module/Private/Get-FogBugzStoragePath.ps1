function Get-FogBugzStoragePath {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [switch]$CreateIfMissing
    )

    $dir = [IO.Path]::GetFullPath($WorkingDirectory)
    $visited = @{}
    while ($dir -and -not $visited.ContainsKey($dir)) {
        $visited[$dir] = $true

        # If this directory is itself a symlink/junction (e.g. a "source"
        # folder mapped to another drive), switch to its real target before
        # testing for .fogbugz or walking further up. Otherwise the walk can
        # continue past the link into an unrelated ancestor (such as the
        # user's home directory) that only shares a path prefix because of
        # the link, not because it is a true ancestor of the working directory.
        $dir = Resolve-FogBugzReparseTarget -Path $dir

        $candidate = Join-Path $dir '.fogbugz'
        if (Test-Path -LiteralPath $candidate -PathType Container) { return $candidate }

        $parent = Split-Path -Parent $dir
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) { break }
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
