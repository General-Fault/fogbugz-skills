function Resolve-FogBugzFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilterName,

        [Parameter(Mandatory)]
        [object[]]$Filter
    )

    $matches = @(
        $Filter | Where-Object {
            $name = Get-FogBugzResponseValue -InputObject $_ -Name 'Name'
            -not [string]::IsNullOrWhiteSpace($name) -and $name.Trim() -ieq $FilterName.Trim()
        }
    )

    if ($matches.Count -eq 1) {
        return $matches[0]
    }

    $nameIndex = @(
        $Filter | ForEach-Object {
            [pscustomobject]@{
                Filter = $_
                Name   = [string](Get-FogBugzResponseValue -InputObject $_ -Name 'Name')
                Id     = [string](Get-FogBugzResponseValue -InputObject $_ -Name 'Id')
            }
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) }
    )

    if ($matches.Count -gt 1) {
        $choices = $matches | ForEach-Object {
            $name = Get-FogBugzResponseValue -InputObject $_ -Name 'Name'
            $id = Get-FogBugzResponseValue -InputObject $_ -Name 'Id'
            if ($id) { "$name ($id)" } else { $name }
        }
        throw "FogBugz filter '$FilterName' is ambiguous: $($choices -join ', ')."
    }

    $needle = $FilterName.Trim().ToLowerInvariant()
    $partialMatches = @(
        $nameIndex | Where-Object { $_.Name.Trim().ToLowerInvariant().Contains($needle) }
    )

    if ($partialMatches.Count -eq 1) {
        return $partialMatches[0].Filter
    }

    if ($partialMatches.Count -gt 1) {
        $choices = $partialMatches | ForEach-Object {
            if ($_.Id) { "$($_.Name) ($($_.Id))" } else { $_.Name }
        }
        throw "No exact filter named '$FilterName'. Similar filters: $($choices -join ', ')."
    }

    $suggestions = $nameIndex | Select-Object -First 5 | ForEach-Object { $_.Name }
    throw "No FogBugz filter named '$FilterName' was found. Available examples: $($suggestions -join ', ')."
}

