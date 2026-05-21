function Select-FogBugzCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Case,

        [switch]$SelectTopOnEmpty
    )

    if ($Case.Count -eq 0) {
        throw 'No FogBugz cases were returned.'
    }

    for ($index = 0; $index -lt $Case.Count; $index++) {
        $item = $Case[$index]
        $display = '{0}. {1} | {2} | score {3} | {4}' -f ($index + 1), $item.Id, $item.Title, $item.Score, $item.Explanation
        Write-Host $display
    }

    $choice = Read-Host 'Choose a case number'
    if ([string]::IsNullOrWhiteSpace($choice)) {
        if ($SelectTopOnEmpty) {
            return $Case[0]
        }

        throw 'Selection is required. Enter a case number.'
    }

    $selected = 0
    if (-not [int]::TryParse($choice, [ref]$selected) -or $selected -lt 1 -or $selected -gt $Case.Count) {
        throw "Invalid case selection '$choice'."
    }

    $Case[$selected - 1]
}

