function Write-FogBugzCaseProgressData {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CaseProgress
    )

    $path = Get-FogBugzCaseProgressPath -WorkingDirectory $WorkingDirectory -CreateIfMissing
    @{ Cases = @($CaseProgress) } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
}
