function Save-FogBugzCaseProgress {
    [CmdletBinding()]
    param(
        [string]$CaseNumber,

        [string]$Title,

        [string]$Status,

        [string]$Branch,

        [Parameter(Mandatory)]
        [string]$WorkSummary,

        [object[]]$Changes = @(),

        [object[]]$TestsRun = @(),

        [string[]]$OpenQuestions = @(),

        [string[]]$NextSteps = @(),

        [string[]]$Artifacts = @(),

        [string]$WorkingDirectory = (Get-Location).Path
    )

    if ([string]::IsNullOrWhiteSpace($WorkSummary)) {
        throw 'WorkSummary is required.'
    }

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    $selectedCase = Get-FogBugzSelectedCase -WorkingDirectory $resolvedWorkingDirectory
    if ([string]::IsNullOrWhiteSpace($CaseNumber) -and $null -ne $selectedCase) {
        $CaseNumber = [string]$selectedCase.Id
    }
    if ([string]::IsNullOrWhiteSpace($Title) -and $null -ne $selectedCase) {
        $Title = [string]$selectedCase.Title
    }

    if ([string]::IsNullOrWhiteSpace($CaseNumber)) {
        throw 'CaseNumber is required. Run fbpick/fbcase first or pass -CaseNumber.'
    }

    if ([string]::IsNullOrWhiteSpace($Branch)) {
        $branchName = (& git -C $resolvedWorkingDirectory rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -eq 0) {
            $Branch = [string]$branchName
        }
    }

    $entry = [pscustomobject]@{
        CaseNumber    = [string]$CaseNumber
        Title         = [string]$Title
        Status        = [string]$Status
        Branch        = [string]$Branch
        WorkSummary   = [string]$WorkSummary
        Changes       = @($Changes)
        TestsRun      = @($TestsRun)
        OpenQuestions = @($OpenQuestions)
        NextSteps     = @($NextSteps)
        Artifacts     = @($Artifacts)
        UpdatedAtUtc  = [datetime]::UtcNow.ToString('o')
    }

    $existing = @(Read-FogBugzCaseProgressData -WorkingDirectory $resolvedWorkingDirectory)
    $remaining = @(
        $existing | Where-Object {
            [string](Get-FogBugzCaseProgressEntryCaseNumber -CaseProgress $_) -ne [string]$CaseNumber
        }
    )
    Write-FogBugzCaseProgressData -WorkingDirectory $resolvedWorkingDirectory -CaseProgress (@($entry) + $remaining)
    $entry
}
