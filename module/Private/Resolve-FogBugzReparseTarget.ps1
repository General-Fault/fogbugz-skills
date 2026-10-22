function Resolve-FogBugzReparseTarget {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.LinkType)) {
        return $Path
    }

    $target = $null
    if ($item.PSObject.Properties['Target']) {
        $target = @($item.Target) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    }

    if ([string]::IsNullOrWhiteSpace($target)) {
        return $Path
    }

    # Some junctions (notably volume mount points) resolve to a bare
    # "Volume{guid}\" target rather than a drive-letter path. Map that back
    # to a drive letter when possible so ancestor-walk output stays readable,
    # and fall back to the raw volume device path otherwise.
    if ($target -match '^Volume\{[0-9a-fA-F-]+\}\\?$') {
        $volumeId = "\\?\$($target.TrimEnd('\'))\"
        $volume = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.UniqueId -ieq $volumeId }
        if ($volume -and -not [string]::IsNullOrWhiteSpace($volume.DriveLetter)) {
            return "$($volume.DriveLetter):\"
        }
        return $volumeId
    }

    [IO.Path]::GetFullPath($target)
}
