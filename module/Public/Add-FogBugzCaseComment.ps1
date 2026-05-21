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

