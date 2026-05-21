function Set-FogBugzSelectedCase {
    param(
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter(Mandatory)]
        [object]$Case
    )

    $caseId = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'Id')
    if ([string]::IsNullOrWhiteSpace($caseId)) {
        $caseId = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'ixBug')
    }
    if ([string]::IsNullOrWhiteSpace($caseId)) {
        throw 'Case.Id is required to store the current FogBugz selection.'
    }

    $caseTitle = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'Title')
    if ([string]::IsNullOrWhiteSpace($caseTitle)) {
        $caseTitle = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'sTitle')
    }

    $env:FOGBUGZ_SELECTED_CASE = [pscustomobject]@{
        Id           = $caseId
        Title        = $caseTitle
        UpdatedAtUtc = [datetime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Compress
}

