Set-StrictMode -Version Latest

foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File | Sort-Object Name)) {
    . $file.FullName
}

foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File | Sort-Object Name)) {
    . $file.FullName
}

Set-Alias -Name fblogin -Value Initialize-FogBugzSession
Set-Alias -Name fbconnect -Value Connect-FogBugzSession
Set-Alias -Name fbpick -Value Find-FogBugzCase
Set-Alias -Name fbcomment -Value Add-FogBugzCaseComment
Set-Alias -Name fbscore -Value Get-FogBugzCaseScore
Set-Alias -Name fbrank -Value Get-FogBugzRankedCase
Set-Alias -Name fbcase -Value Get-FogBugzCaseDetails
Set-Alias -Name fbfilter -Value Resolve-FogBugzFilter
Set-Alias -Name fbselect -Value Select-FogBugzCase

Export-ModuleMember -Function Add-FogBugzCaseComment, Connect-FogBugzSession, Find-FogBugzCase, Get-FogBugzCaseDetails, Get-FogBugzCaseScore, Get-FogBugzRankedCase, Initialize-FogBugzSession, New-FogBugzCaseBranch, Resolve-FogBugzFilter, Select-FogBugzCase -Alias fblogin, fbconnect, fbpick, fbcomment, fbscore, fbrank, fbcase, fbfilter, fbselect

