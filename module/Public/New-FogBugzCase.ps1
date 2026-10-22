function New-FogBugzCase {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Title,

        [Parameter(Position = 1)]
        [string]$Description,

        [string]$Project,

        [string]$Area,

        [string]$Category,

        [int]$Priority,

        [Alias('AssignedTo')]
        [string]$AssignTo,

        [string[]]$Tags,

        [datetime]$DueDate,

        [Alias('Attachments')]
        [string[]]$AttachmentPath,

        [pscustomobject]$Session,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw 'Title is required.'
    }

    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    if ($null -eq $Session) {
        $Session = Connect-FogBugzSession -WorkingDirectory $resolvedWorkingDirectory
    }

    $attachmentFiles = @()
    if ($AttachmentPath) {
        $attachmentFiles = @(Resolve-FogBugzAttachmentPath -AttachmentPath $AttachmentPath)
    }

    $parameter = @{
        sTitle = $Title
    }

    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $parameter['sEvent'] = $Description
    }
    if (-not [string]::IsNullOrWhiteSpace($Project)) {
        $parameter['sProject'] = $Project
    }
    if (-not [string]::IsNullOrWhiteSpace($Area)) {
        $parameter['sArea'] = $Area
    }
    if (-not [string]::IsNullOrWhiteSpace($Category)) {
        $parameter['sCategory'] = $Category
    }
    if (-not [string]::IsNullOrWhiteSpace($AssignTo)) {
        $parameter['sPersonAssignedTo'] = $AssignTo
    }
    if ($PSBoundParameters.ContainsKey('Priority')) {
        $parameter['ixPriority'] = [string]$Priority
    }
    if ($Tags) {
        $parameter['sTags'] = ($Tags -join ',')
    }
    if ($PSBoundParameters.ContainsKey('DueDate')) {
        $parameter['dtDue'] = $DueDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    $targetLabel = "'$Title'"
    if (-not [string]::IsNullOrWhiteSpace($Project)) {
        $targetLabel += " in project '$Project'"
    }

    if (-not $PSCmdlet.ShouldProcess($targetLabel, 'Create FogBugz case')) {
        return
    }

    if ($attachmentFiles.Count -gt 0) {
        $response = Invoke-FogBugzMultipartApi -BaseUri $Session.BaseUri -Command 'new' -Token $Session.Token -Parameter $parameter -File $attachmentFiles
    }
    else {
        $response = Invoke-FogBugzApi -BaseUri $Session.BaseUri -Command 'new' -Token $Session.Token -Parameter $parameter
    }

    $newCaseId = Get-FogBugzResponseValue -InputObject $response -Name 'ixBug'
    if ([string]::IsNullOrWhiteSpace([string]$newCaseId)) {
        throw 'FogBugz did not return a case number for the new case.'
    }

    Get-FogBugzCaseDetails -Session $Session -CaseNumber $newCaseId -WorkingDirectory $resolvedWorkingDirectory
}
