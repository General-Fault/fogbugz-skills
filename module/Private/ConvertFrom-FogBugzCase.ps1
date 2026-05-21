function ConvertFrom-FogBugzCase {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    if ($InputObject -isnot [xml]) {
        return @($InputObject | ForEach-Object {
            [pscustomobject]@{
                Id         = Get-FogBugzResponseValue -InputObject $_ -Name 'Id'
                Title      = Get-FogBugzResponseValue -InputObject $_ -Name 'Title'
                Priority   = Get-FogBugzResponseValue -InputObject $_ -Name 'Priority'
                Status     = Get-FogBugzResponseValue -InputObject $_ -Name 'Status'
                IsBlocked  = [bool](Get-FogBugzResponseValue -InputObject $_ -Name 'IsBlocked')
                Updated    = Get-FogBugzResponseValue -InputObject $_ -Name 'Updated'
                FilterName = Get-FogBugzResponseValue -InputObject $_ -Name 'FilterName'
                Raw        = $_
            }
        })
    }

    $nodes = $InputObject.SelectNodes('//case')
    $cases = foreach ($node in $nodes) {
        $id = Get-FogBugzResponseValue -InputObject $node -Name 'ixBug'
        if ([string]::IsNullOrWhiteSpace([string]$id)) {
            $id = Get-FogBugzResponseValue -InputObject $node -Name 'id'
        }

        $title = Get-FogBugzResponseValue -InputObject $node -Name 'sTitle'
        if ([string]::IsNullOrWhiteSpace([string]$title)) {
            $title = Get-FogBugzResponseValue -InputObject $node -Name 'title'
        }

        $priority = Get-FogBugzResponseValue -InputObject $node -Name 'ixPriority'
        if ([string]::IsNullOrWhiteSpace([string]$priority)) {
            $priority = Get-FogBugzResponseValue -InputObject $node -Name 'priority'
        }

        $status = Get-FogBugzResponseValue -InputObject $node -Name 'sStatus'
        if ([string]::IsNullOrWhiteSpace([string]$status)) {
            $status = Get-FogBugzResponseValue -InputObject $node -Name 'status'
        }

        $isBlockedValue = Get-FogBugzResponseValue -InputObject $node -Name 'fBlocked'
        if ([string]::IsNullOrWhiteSpace([string]$isBlockedValue)) {
            $isBlockedValue = Get-FogBugzResponseValue -InputObject $node -Name 'isBlocked'
        }

        $updated = Get-FogBugzResponseValue -InputObject $node -Name 'dtLastUpdated'
        if ([string]::IsNullOrWhiteSpace([string]$updated)) {
            $updated = Get-FogBugzResponseValue -InputObject $node -Name 'updated'
        }

        $filterName = Get-FogBugzResponseValue -InputObject $node -Name 'sFilter'
        if ([string]::IsNullOrWhiteSpace([string]$filterName)) {
            $filterName = Get-FogBugzResponseValue -InputObject $node -Name 'filterName'
        }

        [pscustomobject]@{
            Id         = $id
            Title      = $title
            Priority   = $priority
            Status     = $status
            IsBlocked  = [bool]$isBlockedValue
            Updated    = $updated
            FilterName = $filterName
            Raw        = $node
        }
    }

    @($cases)
}

