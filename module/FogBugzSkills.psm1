Set-StrictMode -Version Latest

function ConvertTo-FogBugzPlainText {
    param(
        [Parameter(Mandatory)]
        [Security.SecureString]$SecureString
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Get-FogBugzSessionCachePath {
    param(
        [string]$CachePath
    )

    if (-not [string]::IsNullOrWhiteSpace($CachePath)) {
        return $CachePath
    }

    $root = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { $HOME }
    Join-Path $root 'FogBugzSkills\session.xml'
}

function Invoke-FogBugzApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [string]$Command,

        [string]$Token,

        [hashtable]$Parameter
    )

    $builder = [System.UriBuilder]::new($BaseUri.TrimEnd('/') + '/api.asp')
    $queryParts = @("cmd=$([uri]::EscapeDataString($Command))")

    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $queryParts += "token=$([uri]::EscapeDataString($Token))"
    }

    foreach ($key in ($Parameter.Keys | Sort-Object)) {
        $value = [string]$Parameter[$key]
        $queryParts += "$([uri]::EscapeDataString($key))=$([uri]::EscapeDataString($value))"
    }

    $builder.Query = $queryParts -join '&'
    [xml](Invoke-WebRequest -Uri $builder.Uri.AbsoluteUri -Method Get -ErrorAction Stop).Content
}

function Get-FogBugzResponseValue {
    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [xml]) {
        $node = $InputObject.SelectSingleNode("//$Name")
        if ($node) {
            return $node.InnerText
        }
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

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
        [pscustomobject]@{
            Id   = $node.ixFilter
            Name = $node.sFilter
            Raw  = $node
        }
    }

    @($filters)
}

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
        [pscustomobject]@{
            Id         = $node.ixBug
            Title      = $node.sTitle
            Priority   = $node.ixPriority
            Status     = $node.sStatus
            IsBlocked  = [bool]$node.fBlocked
            Updated    = $node.dtLastUpdated
            FilterName = $node.sFilter
            Raw        = $node
        }
    }

    @($cases)
}

function Get-FogBugzSavedFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session
    )

    $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command 'savedfilters' -Token $Session.Token
    ConvertFrom-FogBugzFilter -InputObject $response
}

function Resolve-FogBugzFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilterName,

        [Parameter(Mandatory)]
        [object[]]$Filter
    )

    $matches = @(
        $Filter | Where-Object {
            $name = Get-FogBugzResponseValue -InputObject $_ -Name 'Name'
            -not [string]::IsNullOrWhiteSpace($name) -and $name.Trim() -ieq $FilterName.Trim()
        }
    )

    switch ($matches.Count) {
        0 {
            throw "No FogBugz filter named '$FilterName' was found."
        }
        1 {
            return $matches[0]
        }
        default {
            $choices = $matches | ForEach-Object {
                $name = Get-FogBugzResponseValue -InputObject $_ -Name 'Name'
                $id = Get-FogBugzResponseValue -InputObject $_ -Name 'Id'
                if ($id) { "$name ($id)" } else { $name }
            }
            throw "FogBugz filter '$FilterName' is ambiguous: $($choices -join ', ')."
        }
    }
}

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

function Get-FogBugzCaseFeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session,

        [string]$FilterName
    )

    $parameters = @{}
    if (-not [string]::IsNullOrWhiteSpace($FilterName)) {
        $filters = Get-FogBugzSavedFilter -Session $Session
        $filter = Resolve-FogBugzFilter -FilterName $FilterName -Filter $filters
        $parameters.filter = Get-FogBugzResponseValue -InputObject $filter -Name 'Id'
    }

    $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command 'search' -Token $Session.Token -Parameter $parameters
    ConvertFrom-FogBugzCase -InputObject $response
}

function Select-FogBugzCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Case
    )

    if ($Case.Count -eq 0) {
        throw 'No FogBugz cases were returned.'
    }

    for ($index = 0; $index -lt $Case.Count; $index++) {
        $item = $Case[$index]
        $display = '{0}. {1} | {2} | score {3} | {4}' -f ($index + 1), $item.Id, $item.Title, $item.Score, $item.Explanation
        Write-Host $display
    }

    $choice = Read-Host 'Choose a case number or press Enter to take the top ranked case'
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $Case[0]
    }

    $selected = 0
    if (-not [int]::TryParse($choice, [ref]$selected) -or $selected -lt 1 -or $selected -gt $Case.Count) {
        throw "Invalid case selection '$choice'."
    }

    $Case[$selected - 1]
}

function Connect-FogBugzSession {
    [CmdletBinding()]
    param(
        [string]$BaseUri = $env:FOGBUGZ_BASE_URI,

        [string]$CachePath
    )

    if ([string]::IsNullOrWhiteSpace($BaseUri)) {
        throw 'BaseUri is required to connect to FogBugz.'
    }

    $resolvedCachePath = Get-FogBugzSessionCachePath -CachePath $CachePath
    if (Test-Path -LiteralPath $resolvedCachePath -PathType Leaf) {
        $cached = Import-Clixml -LiteralPath $resolvedCachePath
        if ($cached -and $cached.Token) {
            return $cached
        }
    }

    $credential = Get-Credential -Message 'Sign in to FogBugz'
    $response = Invoke-FogBugzApi -BaseUri $BaseUri -Command 'logon' -Parameter @{
        email    = $credential.UserName
        password = ConvertTo-FogBugzPlainText -SecureString $credential.Password
    }

    $token = Get-FogBugzResponseValue -InputObject $response -Name 'Token'
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'FogBugz did not return a session token.'
    }

    $session = [pscustomobject]@{
        BaseUri   = $BaseUri
        Token     = $token
        UserName  = $credential.UserName
        CachePath = $resolvedCachePath
    }

    $cacheDir = Split-Path -Parent $resolvedCachePath
    if (-not (Test-Path -LiteralPath $cacheDir -PathType Container)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    $session | Export-Clixml -LiteralPath $resolvedCachePath
    $session
}

function Find-FogBugzCase {
    [CmdletBinding()]
    param(
        [string]$BaseUri = $env:FOGBUGZ_BASE_URI,

        [string]$CachePath,

        [string]$FilterName,

        [int]$Top = 5,

        [switch]$Interactive
    )

    $session = Connect-FogBugzSession -BaseUri $BaseUri -CachePath $CachePath
    $cases = Get-FogBugzCaseFeed -Session $session -FilterName $FilterName
    $ranked = Get-FogBugzRankedCase -Case $cases | Select-Object -First $Top

    if ($Interactive) {
        return Select-FogBugzCase -Case $ranked
    }

    $ranked
}

Export-ModuleMember -Function Connect-FogBugzSession, Find-FogBugzCase, Get-FogBugzCaseScore, Get-FogBugzRankedCase, Resolve-FogBugzFilter, Select-FogBugzCase
