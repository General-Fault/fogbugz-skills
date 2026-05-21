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

