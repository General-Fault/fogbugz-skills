function Get-FogBugzCaseProgress {
    [CmdletBinding()]
    param(
        [string]$CaseNumber,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    $entries = @(Read-FogBugzCaseProgressData -WorkingDirectory $resolvedWorkingDirectory)
    if ($entries.Count -eq 0) {
        return @()
    }

    if ([string]::IsNullOrWhiteSpace($CaseNumber)) {
        return @($entries | Sort-Object -Property UpdatedAtUtc -Descending)
    }

    $entry = @(
        $entries | Where-Object {
            [string](Get-FogBugzCaseProgressEntryCaseNumber -CaseProgress $_) -eq [string]$CaseNumber
        } | Select-Object -First 1
    )

    if ($entry.Count -eq 0) {
        throw "No saved local progress found for case '$CaseNumber'."
    }

    $entry[0]
}
