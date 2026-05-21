function Get-FogBugzSelectedCase {
    param(
        [string]$WorkingDirectory = (Get-Location).Path
    )

    if ([string]::IsNullOrWhiteSpace($env:FOGBUGZ_SELECTED_CASE)) { return $null }
    $data = $env:FOGBUGZ_SELECTED_CASE | ConvertFrom-Json
    [pscustomobject]@{
        Id           = [string]$data.Id
        Title        = [string]$data.Title
        UpdatedAtUtc = [string]$data.UpdatedAtUtc
    }
}

