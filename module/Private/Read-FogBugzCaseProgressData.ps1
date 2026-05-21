function Read-FogBugzCaseProgressData {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $path = Get-FogBugzCaseProgressPath -WorkingDirectory $WorkingDirectory
    if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return @()
    }

    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($null -eq $data) {
        return @()
    }

    if ($data.PSObject.Properties.Match('Cases').Count -gt 0) {
        return @($data.Cases)
    }

    @()
}
