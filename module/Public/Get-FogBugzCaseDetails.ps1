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

