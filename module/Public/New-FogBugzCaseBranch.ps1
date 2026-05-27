function New-FogBugzCaseBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$CaseNumber,

        [Parameter(Mandatory, Position = 1)]
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($CaseNumber)) {
        throw 'CaseNumber is required.'
    }

    if ([string]::IsNullOrWhiteSpace($Description)) {
        throw 'Description is required.'
    }

    $branchDescription = ($Description.Trim() -replace '\s+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($branchDescription)) {
        throw 'Description must contain at least one branch-safe token.'
    }

    $branchName = "cases/$CaseNumber-$branchDescription"

    & git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Run this function from inside a git repository.'
    }

    & git check-ref-format --branch $branchName *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Invalid git branch name: $branchName"
    }

    $currentBranch = [string](& git branch --show-current)
    $matchingBranches = @(
        & git branch --list "cases/$CaseNumber-*" |
            ForEach-Object { $_.Trim().TrimStart('*').Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    if (-not [string]::IsNullOrWhiteSpace($currentBranch) -and $currentBranch -like "cases/$CaseNumber-*") {
        $matchingBranches += $currentBranch
    }
    $matchingBranches = @($matchingBranches | Sort-Object -Unique)

    if ($matchingBranches -contains $branchName) {
        throw "Branch already exists: $branchName"
    }

    if ($matchingBranches.Count -gt 0) {
        throw "Another branch already exists for case ${CaseNumber}: $($matchingBranches -join ', ')"
    }

    & git switch -c $branchName
    if ($LASTEXITCODE -ne 0) {
        throw "git switch -c $branchName failed."
    }

    [pscustomobject]@{
        CaseNumber  = [string]$CaseNumber
        Description = $branchDescription
        BranchName  = $branchName
    }
}
