function Remove-FogBugzCaseProgress {
    [CmdletBinding()]
    param(
        [string]$CaseNumber,

        [switch]$All,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    if ($All -and -not [string]::IsNullOrWhiteSpace($CaseNumber)) {
        throw 'Specify either -CaseNumber or -All, not both.'
    }
    if (-not $All -and [string]::IsNullOrWhiteSpace($CaseNumber)) {
        throw 'CaseNumber is required unless -All is specified.'
    }

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    $entries = @(Read-FogBugzCaseProgressData -WorkingDirectory $resolvedWorkingDirectory)
    if ($entries.Count -eq 0) {
        throw "No local case progress entries found for '$resolvedWorkingDirectory'."
    }

    if ($All) {
        Write-FogBugzCaseProgressData -WorkingDirectory $resolvedWorkingDirectory -CaseProgress @()
        return [pscustomobject]@{
            RemovedCaseNumber = $null
            RemovedCount      = $entries.Count
            RemainingCount    = 0
        }
    }

    $remaining = @(
        $entries | Where-Object {
            [string](Get-FogBugzCaseProgressEntryCaseNumber -CaseProgress $_) -ne [string]$CaseNumber
        }
    )
    $removedCount = $entries.Count - $remaining.Count
    if ($removedCount -eq 0) {
        throw "No saved local progress found for case '$CaseNumber'."
    }

    Write-FogBugzCaseProgressData -WorkingDirectory $resolvedWorkingDirectory -CaseProgress $remaining
    [pscustomobject]@{
        RemovedCaseNumber = [string]$CaseNumber
        RemovedCount      = $removedCount
        RemainingCount    = $remaining.Count
    }
}
