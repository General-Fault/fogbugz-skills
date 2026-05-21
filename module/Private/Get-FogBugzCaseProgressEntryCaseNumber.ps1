function Get-FogBugzCaseProgressEntryCaseNumber {
    param(
        [Parameter(Mandatory)]
        [object]$CaseProgress
    )

    $caseNumber = [string](Get-FogBugzResponseValue -InputObject $CaseProgress -Name 'CaseNumber')
    if ([string]::IsNullOrWhiteSpace($caseNumber)) {
        $caseNumber = [string](Get-FogBugzResponseValue -InputObject $CaseProgress -Name 'Id')
    }
    if ([string]::IsNullOrWhiteSpace($caseNumber)) {
        $caseData = Get-FogBugzResponseValue -InputObject $CaseProgress -Name 'Case'
        if ($null -ne $caseData) {
            $caseNumber = [string](Get-FogBugzResponseValue -InputObject $caseData -Name 'Id')
        }
    }

    $caseNumber
}
