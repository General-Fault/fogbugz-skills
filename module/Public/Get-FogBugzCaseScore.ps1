function Get-FogBugzCaseScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Case
    )

    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]

    $blocked = $false
    if ($Case.PSObject.Properties.Match('IsBlocked').Count -gt 0) {
        $blocked = [bool]$Case.IsBlocked
    }

    if ($blocked) {
        $score -= 100
        $reasons.Add('blocked (-100)')
    }
    else {
        $score += 25
        $reasons.Add('unblocked (+25)')
    }

    $priorityValue = 0
    $priorityText = $null
    if ($Case.PSObject.Properties.Match('Priority').Count -gt 0) {
        $priorityText = [string]$Case.Priority
    }
    elseif ($Case.PSObject.Properties.Match('ixPriority').Count -gt 0) {
        $priorityText = [string]$Case.ixPriority
    }

    if (-not [string]::IsNullOrWhiteSpace($priorityText) -and [int]::TryParse($priorityText, [ref]$priorityValue)) {
        $priorityScore = [math]::Max(0, 6 - $priorityValue) * 10
        $score += $priorityScore
        $reasons.Add("priority $priorityValue (+$priorityScore)")
    }

    [datetime]$updatedValue = [datetime]::MinValue
    $updatedText = $null
    if ($Case.PSObject.Properties.Match('Updated').Count -gt 0) {
        $updatedText = [string]$Case.Updated
    }
    elseif ($Case.PSObject.Properties.Match('dtLastUpdated').Count -gt 0) {
        $updatedText = [string]$Case.dtLastUpdated
    }

    if (-not [string]::IsNullOrWhiteSpace($updatedText) -and [datetime]::TryParse($updatedText, [ref]$updatedValue)) {
        $ageDays = ([datetime]::UtcNow - $updatedValue.ToUniversalTime()).TotalDays
        if ($ageDays -le 1) {
            $score += 15
            $reasons.Add('updated in the last day (+15)')
        }
        elseif ($ageDays -le 3) {
            $score += 8
            $reasons.Add('updated in the last 3 days (+8)')
        }
    }

    [pscustomobject]@{
        Case        = $Case
        Score       = $score
        Explanation = ($reasons -join '; ')
    }
}

