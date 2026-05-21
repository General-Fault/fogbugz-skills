function Get-FogBugzRankedCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Case
    )

    $ranked = foreach ($item in $Case) {
        $score = Get-FogBugzCaseScore -Case ([pscustomobject]$item)
        [pscustomobject]@{
            Id          = Get-FogBugzResponseValue -InputObject $item -Name 'Id'
            Title       = Get-FogBugzResponseValue -InputObject $item -Name 'Title'
            Priority    = Get-FogBugzResponseValue -InputObject $item -Name 'Priority'
            Status      = Get-FogBugzResponseValue -InputObject $item -Name 'Status'
            IsBlocked   = [bool](Get-FogBugzResponseValue -InputObject $item -Name 'IsBlocked')
            Updated     = Get-FogBugzResponseValue -InputObject $item -Name 'Updated'
            FilterName  = Get-FogBugzResponseValue -InputObject $item -Name 'FilterName'
            Score       = $score.Score
            Explanation = $score.Explanation
            Raw         = $item
        }
    }

    $ranked | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Updated'; Descending = $true }, 'Id'
}

