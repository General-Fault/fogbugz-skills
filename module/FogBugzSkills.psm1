Set-StrictMode -Version Latest

if (-not ('FogBugzCredentialStore' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class FogBugzCredentialStore {
    private const uint CRED_TYPE_GENERIC     = 1;
    private const uint CRED_PERSIST_LOCAL_MACHINE = 2;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public uint  Flags;
        public uint  Type;
        public string TargetName;
        public string Comment;
        public long  LastWritten;
        public uint  CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint  Persist;
        public uint  AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredWrite([In] ref CREDENTIAL cred, uint flags);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredRead(string target, uint type, uint flags, out IntPtr ptr);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool CredFree(IntPtr ptr);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    public static void Write(string target, string userName, string secret) {
        if (secret == null) secret = string.Empty;
        byte[] blob = Encoding.Unicode.GetBytes(secret);
        IntPtr blobPtr = Marshal.AllocHGlobal(blob.Length);
        try {
            Marshal.Copy(blob, 0, blobPtr, blob.Length);
            var cred = new CREDENTIAL {
                Type               = CRED_TYPE_GENERIC,
                TargetName         = target,
                Comment            = "FogBugzSkills",
                CredentialBlobSize = (uint)blob.Length,
                CredentialBlob     = blobPtr,
                Persist            = CRED_PERSIST_LOCAL_MACHINE,
                UserName           = userName
            };
            if (!CredWrite(ref cred, 0))
                throw new InvalidOperationException("CredWrite failed: " + Marshal.GetLastWin32Error());
        } finally {
            Marshal.FreeHGlobal(blobPtr);
        }
    }

    public static string[] Read(string target) {
        IntPtr ptr = IntPtr.Zero;
        try {
            if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr)) return null;
            var cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            string secret = null;
            if (cred.CredentialBlob != IntPtr.Zero && cred.CredentialBlobSize > 0) {
                byte[] blob = new byte[cred.CredentialBlobSize];
                Marshal.Copy(cred.CredentialBlob, blob, 0, blob.Length);
                secret = Encoding.Unicode.GetString(blob).TrimEnd('\0');
            }
            return new[] { cred.UserName ?? string.Empty, secret ?? string.Empty };
        } finally {
            if (ptr != IntPtr.Zero) CredFree(ptr);
        }
    }

    public static void Delete(string target) {
        CredDelete(target, CRED_TYPE_GENERIC, 0);
    }
}
'@ -Language CSharp
}

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

# .fogbugz config file — stores BaseUri for the working directory tree
function Get-FogBugzConfigPath {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $dir = [IO.Path]::GetFullPath($WorkingDirectory)
    while ($dir) {
        $candidate = Join-Path $dir '.fogbugz'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $null
}

function Read-FogBugzConfig {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $path = Get-FogBugzConfigPath -WorkingDirectory $WorkingDirectory
    if (-not $path) { return $null }
    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    [pscustomobject]@{
        BaseUri = [string]$data.BaseUri
        Path    = $path
    }
}

function Write-FogBugzConfig {
    param(
        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    $path = Join-Path ([IO.Path]::GetFullPath($WorkingDirectory)) '.fogbugz'
    @{ BaseUri = $BaseUri.Trim() } | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
}

# Windows Credential Manager — stores UserName + Token keyed by FogBugz:<BaseUri>
function Set-FogBugzCredential {
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [string]$UserName,

        [Parameter(Mandatory)]
        [string]$Token
    )

    [FogBugzCredentialStore]::Write("FogBugz:$($BaseUri.Trim())", $UserName, $Token)
}

function Get-FogBugzCredential {
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    $result = [FogBugzCredentialStore]::Read("FogBugz:$($BaseUri.Trim())")
    if ($null -eq $result) { return $null }
    [pscustomobject]@{ UserName = $result[0]; Token = $result[1] }
}

function Remove-FogBugzCredential {
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri
    )

    [FogBugzCredentialStore]::Delete("FogBugz:$($BaseUri.Trim())")
}

function Set-FogBugzSelectedCase {
    param(
        [string]$WorkingDirectory = (Get-Location).Path,

        [Parameter(Mandatory)]
        [object]$Case
    )

    $caseId = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'Id')
    if ([string]::IsNullOrWhiteSpace($caseId)) {
        $caseId = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'ixBug')
    }
    if ([string]::IsNullOrWhiteSpace($caseId)) {
        throw 'Case.Id is required to store the current FogBugz selection.'
    }

    $caseTitle = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'Title')
    if ([string]::IsNullOrWhiteSpace($caseTitle)) {
        $caseTitle = [string](Get-FogBugzResponseValue -InputObject $Case -Name 'sTitle')
    }

    $env:FOGBUGZ_SELECTED_CASE = [pscustomobject]@{
        Id           = $caseId
        Title        = $caseTitle
        UpdatedAtUtc = [datetime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Compress
}

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

function Invoke-FogBugzApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [string]$Command,

        [string]$Token,

        [hashtable]$Parameter = @{}
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
    $response = [xml](Invoke-WebRequest -Uri $builder.Uri.AbsoluteUri -Method Get -ErrorAction Stop).Content
    $errorMessage = Get-FogBugzResponseValue -InputObject $response -Name 'Error'
    if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
        throw "FogBugz API error for cmd '$Command': $errorMessage"
    }

    $response
}

function Invoke-FogBugzMultipartApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [string]$Command,

        [string]$Token,

        [hashtable]$Parameter = @{},

        [object[]]$File = @()
    )

    $client = [System.Net.Http.HttpClient]::new()
    $multipart = [System.Net.Http.MultipartFormDataContent]::new()
    try {
        $multipart.Add([System.Net.Http.StringContent]::new($Command), 'cmd')

        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $multipart.Add([System.Net.Http.StringContent]::new($Token), 'token')
        }

        foreach ($key in ($Parameter.Keys | Sort-Object)) {
            $value = [string]$Parameter[$key]
            $multipart.Add([System.Net.Http.StringContent]::new($value), $key)
        }

        $index = 1
        foreach ($item in $File) {
            $fileInfo = [System.IO.FileInfo]$item
            $bytes = [System.IO.File]::ReadAllBytes($fileInfo.FullName)
            $fileContent = [System.Net.Http.ByteArrayContent]::new($bytes)
            $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/octet-stream')
            $multipart.Add($fileContent, "File$index", $fileInfo.Name)
            $index++
        }

        if ($File.Count -gt 0) {
            $multipart.Add([System.Net.Http.StringContent]::new([string]$File.Count), 'nFileCount')
        }

        $response = $client.PostAsync(([Uri]::new($BaseUri.TrimEnd('/') + '/api.asp')), $multipart).GetAwaiter().GetResult()
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw "FogBugz API error for cmd '$Command': $([int]$response.StatusCode) $($response.ReasonPhrase)"
        }

        $xml = [xml]$body
        $errorMessage = Get-FogBugzResponseValue -InputObject $xml -Name 'Error'
        if (-not [string]::IsNullOrWhiteSpace($errorMessage)) {
            throw "FogBugz API error for cmd '$Command': $errorMessage"
        }

        $xml
    }
    finally {
        if ($multipart) { $multipart.Dispose() }
        if ($client) { $client.Dispose() }
    }
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
        $nodes = $InputObject.SelectNodes('//*')
        foreach ($node in $nodes) {
            if ($node.LocalName -ieq $Name) {
                return $node.InnerText
            }
        }
    }

    if ($InputObject -is [System.Xml.XmlNode]) {
        foreach ($child in $InputObject.ChildNodes) {
            if ($child.LocalName -ieq $Name) {
                return $child.InnerText
            }
        }

        foreach ($attribute in $InputObject.Attributes) {
            if ($attribute.LocalName -ieq $Name) {
                return $attribute.Value
            }
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

function Get-FogBugzSavedFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session
    )

    $commands = @('savedfilters', 'listFilters')
    $lastError = $null

    foreach ($command in $commands) {
        try {
            $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command $command -Token $Session.Token
            return @(ConvertFrom-FogBugzFilter -InputObject $response)
        }
        catch {
            $lastError = $_
            $message = $_.Exception.Message
            if ($message -like '*No such API command*' -and $command -ne $commands[-1]) {
                continue
            }

            throw
        }
    }

    throw $lastError
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

    if ($matches.Count -eq 1) {
        return $matches[0]
    }

    $nameIndex = @(
        $Filter | ForEach-Object {
            [pscustomobject]@{
                Filter = $_
                Name   = [string](Get-FogBugzResponseValue -InputObject $_ -Name 'Name')
                Id     = [string](Get-FogBugzResponseValue -InputObject $_ -Name 'Id')
            }
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) }
    )

    if ($matches.Count -gt 1) {
        $choices = $matches | ForEach-Object {
            $name = Get-FogBugzResponseValue -InputObject $_ -Name 'Name'
            $id = Get-FogBugzResponseValue -InputObject $_ -Name 'Id'
            if ($id) { "$name ($id)" } else { $name }
        }
        throw "FogBugz filter '$FilterName' is ambiguous: $($choices -join ', ')."
    }

    $needle = $FilterName.Trim().ToLowerInvariant()
    $partialMatches = @(
        $nameIndex | Where-Object { $_.Name.Trim().ToLowerInvariant().Contains($needle) }
    )

    if ($partialMatches.Count -eq 1) {
        return $partialMatches[0].Filter
    }

    if ($partialMatches.Count -gt 1) {
        $choices = $partialMatches | ForEach-Object {
            if ($_.Id) { "$($_.Name) ($($_.Id))" } else { $_.Name }
        }
        throw "No exact filter named '$FilterName'. Similar filters: $($choices -join ', ')."
    }

    $suggestions = $nameIndex | Select-Object -First 5 | ForEach-Object { $_.Name }
    throw "No FogBugz filter named '$FilterName' was found. Available examples: $($suggestions -join ', ')."
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

    $parameters = @{
        cols = 'ixBug,sTitle,ixPriority,sStatus,fBlocked,dtLastUpdated,sFilter'
    }
    if (-not [string]::IsNullOrWhiteSpace($FilterName)) {
        $filters = @(Get-FogBugzSavedFilter -Session $Session)
        if ($filters.Count -eq 0) {
            throw 'FogBugz returned no saved filters for this account.'
        }
        $filter = Resolve-FogBugzFilter -FilterName $FilterName -Filter $filters
        $parameters.filter = Get-FogBugzResponseValue -InputObject $filter -Name 'Id'
        if ([string]::IsNullOrWhiteSpace([string]$parameters.filter)) {
            throw "FogBugz filter '$FilterName' is missing an ID and cannot be used for case search."
        }
    }

    $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command 'search' -Token $Session.Token -Parameter $parameters
    @(ConvertFrom-FogBugzCase -InputObject $response)
}

function Get-FogBugzCaseDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$CaseNumber,

        [pscustomobject]$Session,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    if ([string]::IsNullOrWhiteSpace($CaseNumber)) {
        throw 'CaseNumber is required.'
    }

    if ($null -eq $Session) {
        $Session = Connect-FogBugzSession -WorkingDirectory $WorkingDirectory
    }

    $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command 'search' -Token $Session.Token -Parameter @{
        q    = "ixBug:$CaseNumber"
        cols = 'ixBug,sTitle,ixPriority,sStatus,fBlocked,dtLastUpdated,sFilter,events,attachments'
    }

    $detailedCase = @(ConvertFrom-FogBugzCase -InputObject $response) | Select-Object -First 1
    if ($null -eq $detailedCase) {
        throw "FogBugz returned no details for case '$CaseNumber'."
    }

    $caseNode = $response.SelectSingleNode('//case')
    $comments = @()
    $attachments = @()
    $attachmentSeen = @{}

    if ($caseNode) {
        $eventNodes = $caseNode.SelectNodes('.//event')
        foreach ($eventNode in $eventNodes) {
            $eventId = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'ixBugEvent')
            $author = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'sPerson')
            if ([string]::IsNullOrWhiteSpace($author)) {
                $author = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'sBy')
            }

            $eventText = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 's')
            if ([string]::IsNullOrWhiteSpace($eventText)) {
                $eventText = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'sText')
            }
            if ([string]::IsNullOrWhiteSpace($eventText)) {
                $eventText = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'sChanges')
            }
            if ([string]::IsNullOrWhiteSpace($eventText)) {
                $eventText = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'evtDescription')
            }

            $eventTime = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'dt')
            if ([string]::IsNullOrWhiteSpace($eventTime)) {
                $eventTime = [string](Get-FogBugzResponseValue -InputObject $eventNode -Name 'dtWhen')
            }

            if (
                -not [string]::IsNullOrWhiteSpace($eventText) -or
                -not [string]::IsNullOrWhiteSpace($author) -or
                -not [string]::IsNullOrWhiteSpace($eventTime)
            ) {
                $comments += [pscustomobject]@{
                    EventId   = $eventId
                    Author    = $author
                    Timestamp = $eventTime
                    Text      = $eventText
                }
            }

            $eventAttachmentNodes = $eventNode.SelectNodes('.//attachment')
            foreach ($attachmentNode in $eventAttachmentNodes) {
                $attachmentId = [string](Get-FogBugzResponseValue -InputObject $attachmentNode -Name 'ixAttachment')
                if ([string]::IsNullOrWhiteSpace($attachmentId)) {
                    $attachmentId = [string](Get-FogBugzResponseValue -InputObject $attachmentNode -Name 'id')
                }

                $fileName = [string](Get-FogBugzResponseValue -InputObject $attachmentNode -Name 'sFileName')
                if ([string]::IsNullOrWhiteSpace($fileName)) {
                    $fileName = [string](Get-FogBugzResponseValue -InputObject $attachmentNode -Name 'filename')
                }
                if ([string]::IsNullOrWhiteSpace($fileName)) {
                    $fileName = [string](Get-FogBugzResponseValue -InputObject $attachmentNode -Name 'sDesc')
                }

                $url = [string](Get-FogBugzResponseValue -InputObject $attachmentNode -Name 'sURL')
                if ([string]::IsNullOrWhiteSpace($url)) {
                    $url = [string](Get-FogBugzResponseValue -InputObject $attachmentNode -Name 'url')
                }

                $key = "$attachmentId|$fileName|$url"
                if (-not $attachmentSeen.ContainsKey($key)) {
                    $attachmentSeen[$key] = $true
                    $attachments += [pscustomobject]@{
                        AttachmentId = $attachmentId
                        FileName     = $fileName
                        Url          = $url
                        EventId      = $eventId
                    }
                }
            }
        }
    }

    $result = [ordered]@{}
    foreach ($property in $detailedCase.PSObject.Properties) {
        $result[$property.Name] = $property.Value
    }

    $result['Comments'] = $comments
    $result['Attachments'] = $attachments
    $result['ContextSummary'] = "Loaded $($comments.Count) comments and $($attachments.Count) attachments."

    $caseDetails = [pscustomobject]$result
    Set-FogBugzSelectedCase -WorkingDirectory $WorkingDirectory -Case $caseDetails
    $caseDetails
}

function Select-FogBugzCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Case,

        [switch]$SelectTopOnEmpty
    )

    if ($Case.Count -eq 0) {
        throw 'No FogBugz cases were returned.'
    }

    for ($index = 0; $index -lt $Case.Count; $index++) {
        $item = $Case[$index]
        $display = '{0}. {1} | {2} | score {3} | {4}' -f ($index + 1), $item.Id, $item.Title, $item.Score, $item.Explanation
        Write-Host $display
    }

    $choice = Read-Host 'Choose a case number'
    if ([string]::IsNullOrWhiteSpace($choice)) {
        if ($SelectTopOnEmpty) {
            return $Case[0]
        }

        throw 'Selection is required. Enter a case number.'
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

        [string]$WorkingDirectory = (Get-Location).Path,

        [switch]$PromptForCredentials
    )

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)

    $config = Read-FogBugzConfig -WorkingDirectory $resolvedWorkingDirectory
    $resolvedBaseUri = if (-not [string]::IsNullOrWhiteSpace($BaseUri)) { $BaseUri } elseif ($config) { $config.BaseUri } else { $null }

    if (-not [string]::IsNullOrWhiteSpace($resolvedBaseUri)) {
        $cred = Get-FogBugzCredential -BaseUri $resolvedBaseUri
        if ($cred -and -not [string]::IsNullOrWhiteSpace($cred.Token)) {
            return [pscustomobject]@{
                BaseUri          = $resolvedBaseUri
                Token            = $cred.Token
                UserName         = $cred.UserName
                WorkingDirectory = $resolvedWorkingDirectory
            }
        }
    }

    if ($PromptForCredentials) {
        return Initialize-FogBugzSession -BaseUri $resolvedBaseUri -WorkingDirectory $resolvedWorkingDirectory
    }

    if ([string]::IsNullOrWhiteSpace($resolvedBaseUri)) {
        throw "No .fogbugz config found at or above '$resolvedWorkingDirectory'. Run Initialize-FogBugzSession (alias: fblogin)."
    }

    throw "No FogBugz credential found for '$resolvedBaseUri'. Run Initialize-FogBugzSession (alias: fblogin)."
}

function Initialize-FogBugzSession {
    [CmdletBinding()]
    param(
        [string]$BaseUri = $env:FOGBUGZ_BASE_URI,

        [string]$WorkingDirectory = (Get-Location).Path,

        [pscredential]$Credential
    )

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)

    if ([string]::IsNullOrWhiteSpace($BaseUri)) {
        $config = Read-FogBugzConfig -WorkingDirectory $resolvedWorkingDirectory
        if ($config) { $BaseUri = $config.BaseUri }
    }

    if ([string]::IsNullOrWhiteSpace($BaseUri)) {
        $BaseUri = Read-Host 'Enter FogBugz tenant URI (example: https://yourtenant.fogbugz.com)'
    }

    if ([string]::IsNullOrWhiteSpace($BaseUri)) {
        throw 'BaseUri is required to initialize a FogBugz session.'
    }

    if ($null -eq $Credential) {
        $Credential = Get-Credential -Message 'Sign in to FogBugz'
    }

    $response = Invoke-FogBugzApi -BaseUri $BaseUri -Command 'logon' -Parameter @{
        email    = $Credential.UserName
        password = ConvertTo-FogBugzPlainText -SecureString $Credential.Password
    }

    $token = Get-FogBugzResponseValue -InputObject $response -Name 'Token'
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'FogBugz did not return a session token.'
    }

    Write-FogBugzConfig -WorkingDirectory $resolvedWorkingDirectory -BaseUri $BaseUri
    Set-FogBugzCredential -BaseUri $BaseUri -UserName $Credential.UserName -Token $token

    [pscustomobject]@{
        BaseUri          = $BaseUri
        Token            = $token
        UserName         = $Credential.UserName
        WorkingDirectory = $resolvedWorkingDirectory
    }
}

function Find-FogBugzCase {
    [CmdletBinding()]
    param(
        [string]$BaseUri = $env:FOGBUGZ_BASE_URI,

        [Parameter(Position = 0)]
        [string]$FilterName,

        [int]$Top = 5,

        [switch]$Interactive,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    $session = Connect-FogBugzSession -BaseUri $BaseUri -WorkingDirectory $WorkingDirectory
    $cases = @(Get-FogBugzCaseFeed -Session $session -FilterName $FilterName)
    if ($cases.Count -eq 0) {
        throw 'No FogBugz cases matched the selected criteria.'
    }
    $ranked = Get-FogBugzRankedCase -Case $cases | Select-Object -First $Top

    if ($Interactive) {
        $selected = Select-FogBugzCase -Case $ranked
        return Get-FogBugzCaseDetails -Session $session -CaseNumber ([string]$selected.Id)
    }

    $ranked
}

function Resolve-FogBugzAttachmentPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$AttachmentPath
    )

    $resolved = New-Object System.Collections.Generic.List[object]
    $seen = @()

    foreach ($path in $AttachmentPath) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        $item = Get-Item -LiteralPath $path -ErrorAction Stop
        if ($item.PSIsContainer) {
            Write-Warning "Directory attachment '$($item.FullName)' will upload top-level files only."
            $children = @(Get-ChildItem -LiteralPath $item.FullName -File -Force -ErrorAction Stop)
            $excluded = @(
                $children | Where-Object {
                    (([int]$_.Attributes -band [int][System.IO.FileAttributes]::Hidden) -ne 0) -or
                    (([int]$_.Attributes -band [int][System.IO.FileAttributes]::System) -ne 0)
                }
            )
            if ($excluded.Count -gt 0) {
                Write-Warning "Skipping $($excluded.Count) hidden or system file(s) in '$($item.FullName)'."
            }

            foreach ($child in $children) {
                if (
                    (([int]$child.Attributes -band [int][System.IO.FileAttributes]::Hidden) -ne 0) -or
                    (([int]$child.Attributes -band [int][System.IO.FileAttributes]::System) -ne 0)
                ) {
                    continue
                }

                if ($seen -notcontains $child.FullName) {
                    $seen += $child.FullName
                    $resolved.Add($child)
                }
            }
            continue
        }

        if ($seen -notcontains $item.FullName) {
            $seen += $item.FullName
            $resolved.Add($item)
        }
    }

    if ($resolved.Count -eq 0) {
        throw 'No uploadable attachments were found.'
    }

    $resolved.ToArray()
}

function Add-FogBugzCaseComment {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Comment,

        [string]$CaseNumber,

        [Alias('Attachments')]
        [string[]]$AttachmentPath,

        [pscustomobject]$Session,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    if ([string]::IsNullOrWhiteSpace($Comment)) {
        throw 'Comment is required.'
    }

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    if ($null -eq $Session) {
        $Session = Connect-FogBugzSession -WorkingDirectory $resolvedWorkingDirectory
    }

    $targetCase = $null
    if (-not [string]::IsNullOrWhiteSpace($CaseNumber)) {
        $targetCase = Get-FogBugzCaseDetails -Session $Session -CaseNumber $CaseNumber -WorkingDirectory $resolvedWorkingDirectory
    }
    else {
        $targetCase = Get-FogBugzSelectedCase -WorkingDirectory $resolvedWorkingDirectory
        if ($null -eq $targetCase) {
            throw "No current FogBugz case is selected for '$resolvedWorkingDirectory'. Run fbpick or pass -CaseNumber."
        }
    }

    $attachmentFiles = @()
    if ($AttachmentPath) {
        $attachmentFiles = @(Resolve-FogBugzAttachmentPath -AttachmentPath $AttachmentPath)
    }

    $targetLabel = "case $($targetCase.Id)"
    if (-not [string]::IsNullOrWhiteSpace([string]$targetCase.Title)) {
        $targetLabel += " - $($targetCase.Title)"
    }

    if (-not $PSCmdlet.ShouldProcess($targetLabel, 'Post FogBugz comment')) {
        return
    }

    $parameter = @{
        ixBug      = [string]$targetCase.Id
        sEvent     = $Comment
        fRichText  = '0'
    }

    $response = Invoke-FogBugzMultipartApi -BaseUri $Session.BaseUri -Command 'edit' -Token $Session.Token -Parameter $parameter -File $attachmentFiles
    $updatedCase = @(ConvertFrom-FogBugzCase -InputObject $response) | Select-Object -First 1
    if ($updatedCase) {
        Set-FogBugzSelectedCase -WorkingDirectory $resolvedWorkingDirectory -Case $updatedCase
    }
    else {
        Set-FogBugzSelectedCase -WorkingDirectory $resolvedWorkingDirectory -Case $targetCase
    }

    [pscustomobject]@{
        CaseNumber      = [string]$targetCase.Id
        Title           = [string]$targetCase.Title
        Comment         = $Comment
        AttachmentCount = $attachmentFiles.Count
        Attachments     = @($attachmentFiles | ForEach-Object { $_.Name })
    }
}

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
        & git branch --list "cases/$CaseNumber-*"
        | ForEach-Object { $_.Trim().TrimStart('*').Trim() }
        | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
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

Set-Alias -Name fblogin -Value Initialize-FogBugzSession
Set-Alias -Name fbconnect -Value Connect-FogBugzSession
Set-Alias -Name fbpick -Value Find-FogBugzCase
Set-Alias -Name fbcomment -Value Add-FogBugzCaseComment
Set-Alias -Name fbscore -Value Get-FogBugzCaseScore
Set-Alias -Name fbrank -Value Get-FogBugzRankedCase
Set-Alias -Name fbcase -Value Get-FogBugzCaseDetails
Set-Alias -Name fbfilter -Value Resolve-FogBugzFilter
Set-Alias -Name fbselect -Value Select-FogBugzCase

Export-ModuleMember -Function Add-FogBugzCaseComment, Connect-FogBugzSession, Find-FogBugzCase, Get-FogBugzCaseDetails, Get-FogBugzCaseScore, Get-FogBugzRankedCase, Initialize-FogBugzSession, New-FogBugzCaseBranch, Resolve-FogBugzFilter, Select-FogBugzCase -Alias fblogin, fbconnect, fbpick, fbcomment, fbscore, fbrank, fbcase, fbfilter, fbselect
