function Find-FogBugzCase {
    [CmdletBinding()]
    param(
        [string]$BaseUri = $env:FOGBUGZ_BASE_URI,

        [Parameter(Position = 0)]
        [string]$FilterName,

        [int]$Top = 5,

        [switch]$Interactive,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    $session = Connect-FogBugzSession -BaseUri $BaseUri -WorkingDirectory $WorkingDirectory
    $cases = @(Get-FogBugzCaseFeed -Session $session -FilterName $FilterName)
    if ($cases.Count -eq 0) {
        throw 'No FogBugz cases matched the selected criteria.'
    }
    $ranked = Get-FogBugzRankedCase -Case $cases | Select-Object -First $Top

    if ($Interactive) {
        $selected = Select-FogBugzCase -Case $ranked
        return Get-FogBugzCaseDetails -Session $session -CaseNumber ([string]$selected.Id)
    }

    $ranked
}

