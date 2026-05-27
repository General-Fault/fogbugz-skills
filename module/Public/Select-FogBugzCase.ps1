function Select-FogBugzCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Case,

        [switch]$SelectTopOnEmpty,

        [int]$PageSize = 5
    )

    if ($Case.Count -eq 0) {
        throw 'No FogBugz cases were returned.'
    }

    $offset = 0

    while ($true) {
        $pageEnd  = [Math]::Min($offset + $PageSize, $Case.Count) - 1
        $page     = $Case[$offset..$pageEnd]
        $hasMore  = ($offset + $PageSize) -lt $Case.Count
        $moreNum  = $page.Count + 1

        for ($i = 0; $i -lt $page.Count; $i++) {
            $item    = $page[$i]
            $display = '{0}. {1} | {2} | score {3} | {4}' -f ($i + 1), $item.Id, $item.Title, $item.Score, $item.Explanation
            Write-Host $display
        }

        if ($hasMore) {
            Write-Host ('{0}. more...' -f $moreNum)
        }

        $choice = Read-Host 'Choose a case number'

        if ([string]::IsNullOrWhiteSpace($choice)) {
            if ($SelectTopOnEmpty -and $offset -eq 0) {
                return $Case[0]
            }

            throw 'Selection is required. Enter a case number.'
        }

        $selected = 0
        if (-not [int]::TryParse($choice, [ref]$selected)) {
            throw "Invalid case selection '$choice'."
        }

        if ($hasMore -and $selected -eq $moreNum) {
            $offset += $PageSize
            continue
        }

        if ($selected -lt 1 -or $selected -gt $page.Count) {
            throw "Invalid case selection '$choice'."
        }

        return $Case[$offset + $selected - 1]
    }
}

