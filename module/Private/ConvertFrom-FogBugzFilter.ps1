function ConvertFrom-FogBugzFilter {
    param(
        [Parameter(Mandatory)]
        $InputObject
    )

    if ($InputObject -isnot [xml]) {
        return @($InputObject)
    }

    $nodes = $InputObject.SelectNodes('//filter')
    $filters = foreach ($node in $nodes) {
        $id = Get-FogBugzResponseValue -InputObject $node -Name 'sFilter'
        if ([string]::IsNullOrWhiteSpace([string]$id)) {
            $id = Get-FogBugzResponseValue -InputObject $node -Name 'ixFilter'
        }
        if ([string]::IsNullOrWhiteSpace([string]$id)) {
            $id = Get-FogBugzResponseValue -InputObject $node -Name 'id'
        }

        $name = $null
        foreach ($child in $node.ChildNodes) {
            if ($child.LocalName -ieq 'sFilter') {
                $name = $child.InnerText
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$name)) {
            $name = $node.InnerText
        }
        if ([string]::IsNullOrWhiteSpace([string]$name)) {
            $name = Get-FogBugzResponseValue -InputObject $node -Name 'name'
        }
        if ([string]::IsNullOrWhiteSpace([string]$name)) {
            $name = Get-FogBugzResponseValue -InputObject $node -Name 'sFilter'
        }

        [pscustomobject]@{
            Id   = $id
            Name = [string]$name
            Raw  = $node
        }
    }

    @($filters)
}

