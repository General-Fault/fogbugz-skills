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

