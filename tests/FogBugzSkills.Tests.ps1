$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '..\module\FogBugzSkills.psd1') -Force

Describe 'FogBugzSkills' {
    Context 'Resolve-FogBugzFilter' {
        It 'returns the exact filter match' {
            $filters = @(
                [pscustomobject]@{ Id = 1; Name = 'Open Bugs' }
                [pscustomobject]@{ Id = 2; Name = 'Closed Bugs' }
            )

            (Resolve-FogBugzFilter -FilterName 'Open Bugs' -Filter $filters).Id | Should -Be 1
        }

        It 'returns a single partial match when exact match is missing' {
            $filters = @(
                [pscustomobject]@{ Id = 1; Name = 'Open Bugs' }
                [pscustomobject]@{ Id = 2; Name = 'Closed Bugs' }
            )

            (Resolve-FogBugzFilter -FilterName 'Open' -Filter $filters).Id | Should -Be 1
        }

        It 'throws when the filter name is ambiguous' {
            $filters = @(
                [pscustomobject]@{ Id = 1; Name = 'Open Bugs' }
                [pscustomobject]@{ Id = 2; Name = 'Open Bugs' }
            )

            { Resolve-FogBugzFilter -FilterName 'Open Bugs' -Filter $filters } | Should -Throw
        }
    }

    Context 'Get-FogBugzCaseScore' {
        It 'scores blocked cases lower than unblocked cases' {
            $blocked = Get-FogBugzCaseScore -Case ([pscustomobject]@{ IsBlocked = $true; Priority = 1 })
            $open = Get-FogBugzCaseScore -Case ([pscustomobject]@{ IsBlocked = $false; Priority = 1 })

            $blocked.Score | Should -BeLessThan $open.Score
            $blocked.Explanation | Should -Match 'blocked'
        }
    }

    Context 'Get-FogBugzRankedCase' {
        It 'orders cases by score descending' {
            $cases = @(
                [pscustomobject]@{ Id = 1; Title = 'Slow task'; Priority = 5; IsBlocked = $false; Updated = '2024-01-01' }
                [pscustomobject]@{ Id = 2; Title = 'Urgent task'; Priority = 1; IsBlocked = $false; Updated = '2024-01-02' }
            )

            $ranked = Get-FogBugzRankedCase -Case $cases

            $ranked[0].Id | Should -Be 2
            $ranked[0].Explanation | Should -Match 'priority 1'
        }
    }

    Context 'FogBugz XML compatibility' {
        It 'parses listFilters XML where sFilter is the ID and text is the name' {
            InModuleScope FogBugzSkills {
                $xml = [xml]@'
<response>
  <filters>
    <filter type="saved" sFilter="1329"><![CDATA[4.5 Active assigned to me]]></filter>
    <filter type="builtin" sFilter="ez">My Cases</filter>
  </filters>
</response>
'@
                $filters = ConvertFrom-FogBugzFilter -InputObject $xml
                $filters.Count | Should -Be 2
                $filters[0].Id | Should -Be '1329'
                $filters[0].Name | Should -Be '4.5 Active assigned to me'
                $filters[1].Id | Should -Be 'ez'
                $filters[1].Name | Should -Be 'My Cases'
            }
        }

        It 'parses lowercase case field names without property errors' {
            InModuleScope FogBugzSkills {
                $xml = [xml]@'
<response>
  <cases>
    <case>
      <ixbug>321</ixbug>
      <stitle>Lowercase title</stitle>
      <ixpriority>2</ixpriority>
      <sstatus>Active</sstatus>
      <fblocked>false</fblocked>
      <dtlastupdated>2026-01-01T00:00:00Z</dtlastupdated>
    </case>
  </cases>
</response>
'@
                $cases = ConvertFrom-FogBugzCase -InputObject $xml
                $cases.Count | Should -Be 1
                $cases[0].Title | Should -Be 'Lowercase title'
            }
        }

        It 'handles API calls when parameter hash is omitted' {
            InModuleScope FogBugzSkills {
                Mock Invoke-WebRequest {
                    [pscustomobject]@{ Content = '<response><ok>true</ok></response>' }
                }

                { Invoke-FogBugzApi -BaseUri 'https://example.fogbugz.com' -Command 'savedfilters' -Token 'abc' } | Should -Not -Throw
            }
        }
    }

    Context 'Select-FogBugzCase' {
        It 'requires explicit case selection by default' {
            InModuleScope FogBugzSkills {
                Mock Read-Host { '' }

                $cases = @(
                    [pscustomobject]@{ Id = 10; Title = 'Top'; Score = 9; Explanation = 'good' }
                    [pscustomobject]@{ Id = 11; Title = 'Second'; Score = 8; Explanation = 'fine' }
                )

                { Select-FogBugzCase -Case $cases } | Should -Throw '*Selection is required*'
            }
        }

        It 'can select top case on empty input when explicitly enabled' {
            InModuleScope FogBugzSkills {
                Mock Read-Host { '' }

                $cases = @(
                    [pscustomobject]@{ Id = 10; Title = 'Top'; Score = 9; Explanation = 'good' }
                    [pscustomobject]@{ Id = 11; Title = 'Second'; Score = 8; Explanation = 'fine' }
                )

                (Select-FogBugzCase -Case $cases -SelectTopOnEmpty).Id | Should -Be 10
            }
        }

        It 'does not show more... when cases fit within one page' {
            InModuleScope FogBugzSkills {
                $hostOutput = [System.Collections.Generic.List[string]]::new()
                Mock Write-Host { $hostOutput.Add($Object) }
                Mock Read-Host { '1' }

                $cases = @(
                    [pscustomobject]@{ Id = 1; Title = 'A'; Score = 9; Explanation = 'x' }
                    [pscustomobject]@{ Id = 2; Title = 'B'; Score = 8; Explanation = 'x' }
                    [pscustomobject]@{ Id = 3; Title = 'C'; Score = 7; Explanation = 'x' }
                )

                Select-FogBugzCase -Case $cases -PageSize 5
                $hostOutput | Where-Object { $_ -match 'more\.\.\.' } | Should -BeNullOrEmpty
            }
        }

        It 'shows more... when cases exceed one page' {
            InModuleScope FogBugzSkills {
                $hostOutput = [System.Collections.Generic.List[string]]::new()
                Mock Write-Host { $hostOutput.Add($Object) }
                Mock Read-Host { '1' }

                $cases = 1..6 | ForEach-Object {
                    [pscustomobject]@{ Id = $_; Title = "Case $_"; Score = (10 - $_); Explanation = 'x' }
                }

                Select-FogBugzCase -Case $cases -PageSize 5
                $hostOutput | Where-Object { $_ -match 'more\.\.\.' } | Should -Not -BeNullOrEmpty
            }
        }

        It 'advances to next page when more... is selected' {
            InModuleScope FogBugzSkills {
                $script:callCount = 0
                Mock Read-Host {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return '6' }
                    return '1'
                }

                $cases = 1..8 | ForEach-Object {
                    [pscustomobject]@{ Id = $_; Title = "Case $_"; Score = (10 - $_); Explanation = 'x' }
                }

                $result = Select-FogBugzCase -Case $cases -PageSize 5
                $result.Id | Should -Be 6
            }
        }

        It 'does not show more... on the last page' {
            InModuleScope FogBugzSkills {
                $script:pageOutputs = [System.Collections.Generic.List[string[]]]::new()
                $script:currentPageLines = [System.Collections.Generic.List[string]]::new()
                $script:callCount = 0

                Mock Write-Host { $script:currentPageLines.Add($Object) }
                Mock Read-Host {
                    $script:callCount++
                    $script:pageOutputs.Add($script:currentPageLines.ToArray())
                    $script:currentPageLines.Clear()
                    if ($script:callCount -eq 1) { return '6' }
                    return '1'
                }

                $cases = 1..8 | ForEach-Object {
                    [pscustomobject]@{ Id = $_; Title = "Case $_"; Score = (10 - $_); Explanation = 'x' }
                }

                Select-FogBugzCase -Case $cases -PageSize 5
                $lastPage = $script:pageOutputs[1]
                $lastPage | Where-Object { $_ -match 'more\.\.\.' } | Should -BeNullOrEmpty
            }
        }

        It 'can select a case from a non-first page' {
            InModuleScope FogBugzSkills {
                $script:callCount = 0
                Mock Read-Host {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return '6' }
                    return '2'
                }

                $cases = 1..8 | ForEach-Object {
                    [pscustomobject]@{ Id = $_; Title = "Case $_"; Score = (10 - $_); Explanation = 'x' }
                }

                $result = Select-FogBugzCase -Case $cases -PageSize 5
                $result.Id | Should -Be 7
            }
        }
    }

    Context 'New-FogBugzCaseBranch' {
        BeforeEach {
            $script:BranchTempRoot = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $script:BranchTempRoot -Force | Out-Null
        }

        AfterEach {
            if (Test-Path -LiteralPath $script:BranchTempRoot) {
                Remove-Item -LiteralPath $script:BranchTempRoot -Recurse -Force
            }
        }

        It 'creates and checks out the requested case branch' {
            InModuleScope FogBugzSkills -Parameters @{ RepoRoot = $script:BranchTempRoot } {
                param($RepoRoot)

                Push-Location $RepoRoot
                try {
                    git init --quiet
                    $result = New-FogBugzCaseBranch -CaseNumber '14630' -Description 'fix-login-flow'
                    $result.BranchName | Should -Be 'cases/14630-fix-login-flow'
                    $result.CaseNumber | Should -Be '14630'
                    (git branch --show-current) | Should -Be 'cases/14630-fix-login-flow'
                }
                finally {
                    Pop-Location
                }
            }
        }

        It 'throws when the exact target branch already exists' {
            InModuleScope FogBugzSkills -Parameters @{ RepoRoot = $script:BranchTempRoot } {
                param($RepoRoot)

                Push-Location $RepoRoot
                try {
                    git init --quiet
                    [void](New-FogBugzCaseBranch -CaseNumber '14630' -Description 'fix-login-flow')
                    { New-FogBugzCaseBranch -CaseNumber '14630' -Description 'fix-login-flow' } | Should -Throw '*Branch already exists*'
                }
                finally {
                    Pop-Location
                }
            }
        }

        It 'throws when another branch exists for the same case number' {
            InModuleScope FogBugzSkills -Parameters @{ RepoRoot = $script:BranchTempRoot } {
                param($RepoRoot)

                Push-Location $RepoRoot
                try {
                    git init --quiet
                    [void](New-FogBugzCaseBranch -CaseNumber '14630' -Description 'fix-login-flow')
                    { New-FogBugzCaseBranch -CaseNumber '14630' -Description 'update-docs' } | Should -Throw '*Another branch already exists for case 14630*'
                }
                finally {
                    Pop-Location
                }
            }
        }
    }

    Context 'Auth bootstrap workflow' {
        BeforeEach {
            $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            $script:WorkDir = Join-Path $script:TempRoot 'scriptcenter'
            New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
            $env:FOGBUGZ_SELECTED_CASE = $null
        }

        AfterEach {
            $env:FOGBUGZ_SELECTED_CASE = $null
            if (Test-Path -LiteralPath $script:TempRoot) {
                Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
            }
        }

        It 'exports fblogin alias to Initialize-FogBugzSession' {
            (Get-Alias -Name fblogin).Definition | Should -Be 'Initialize-FogBugzSession'
        }

        It 'uses fb prefix for all module aliases' {
            $aliases = Get-Command -Module FogBugzSkills -CommandType Alias
            $aliases.Count | Should -BeGreaterThan 0
            foreach ($alias in $aliases) {
                $alias.Name | Should -Match '^fb'
            }
        }

        It 'loads all expected public commands from the module' {
            $expected = @(
                'Add-FogBugzCaseComment'
                'Connect-FogBugzSession'
                'Find-FogBugzCase'
                'Get-FogBugzCaseDetails'
                'Get-FogBugzCaseProgress'
                'Get-FogBugzCaseScore'
                'Get-FogBugzRankedCase'
                'Initialize-FogBugzSession'
                'New-FogBugzCaseBranch'
                'Remove-FogBugzCaseProgress'
                'Resolve-FogBugzFilter'
                'Save-FogBugzCaseProgress'
                'Select-FogBugzCase'
            ) | Sort-Object

            $actual = Get-Command -Module FogBugzSkills -CommandType Function |
                Select-Object -ExpandProperty Name |
                Sort-Object

            $actual.Count | Should -Be $expected.Count
            (Compare-Object -ReferenceObject $expected -DifferenceObject $actual) | Should -BeNullOrEmpty
        }

        It 'exports expected alias-command mappings' {
            $expected = @{
                fblogin         = 'Initialize-FogBugzSession'
                fbconnect       = 'Connect-FogBugzSession'
                fbpick          = 'Find-FogBugzCase'
                fbcomment       = 'Add-FogBugzCaseComment'
                fbcase          = 'Get-FogBugzCaseDetails'
                fbresume        = 'Get-FogBugzCaseProgress'
                fbscore         = 'Get-FogBugzCaseScore'
                fbrank          = 'Get-FogBugzRankedCase'
                fbsaveprogress  = 'Save-FogBugzCaseProgress'
                fbclearprogress = 'Remove-FogBugzCaseProgress'
                fbfilter        = 'Resolve-FogBugzFilter'
                fbselect        = 'Select-FogBugzCase'
            }

            foreach ($name in $expected.Keys) {
                (Get-Alias -Name $name).Definition | Should -Be $expected[$name]
            }
        }

        It 'stores and reuses session context by working directory' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                Mock Invoke-FogBugzApi {
                    [pscustomobject]@{ Token = 'token-123' }
                }
                Mock Set-FogBugzCredential { }
                Mock Get-FogBugzCredential { [pscustomobject]@{ UserName = 'dummy.user@example.com'; Token = 'token-123' } }

                $cred = [pscredential]::new(
                    'dummy.user@example.com',
                    (ConvertTo-SecureString -String 'DummyPassword123!' -AsPlainText -Force)
                )

                $session = Initialize-FogBugzSession -BaseUri 'https://yourtenant.fogbugz.com' -WorkingDirectory $WorkDir -Credential $cred
                $session.BaseUri | Should -Be 'https://yourtenant.fogbugz.com'
                $session.Token | Should -Be 'token-123'

                $connected = Connect-FogBugzSession -WorkingDirectory $WorkDir
                $connected.Token | Should -Be 'token-123'

                Should -Invoke Invoke-FogBugzApi -Times 1
            }
        }

        It 'accepts lowercase token from FogBugz XML response' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                Mock Invoke-FogBugzApi {
                    [xml]'<response><token>token-xml-lower</token></response>'
                }
                Mock Set-FogBugzCredential { }

                $cred = [pscredential]::new(
                    'dummy.user@example.com',
                    (ConvertTo-SecureString -String 'DummyPassword123!' -AsPlainText -Force)
                )

                $session = Initialize-FogBugzSession -BaseUri 'https://yourtenant.fogbugz.com' -WorkingDirectory $WorkDir -Credential $cred
                $session.Token | Should -Be 'token-xml-lower'
            }
        }

        It 'throws when no stored session exists for non-interactive case picking' {
            { Connect-FogBugzSession -WorkingDirectory $script:WorkDir } | Should -Throw '*Initialize-FogBugzSession*'
        }

        It 'throws a clear error when no saved filters are returned' {
            InModuleScope FogBugzSkills {
                Mock Get-FogBugzSavedFilter { @() }
                Mock Invoke-FogBugzApi { [xml]'<response></response>' }

                $session = [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                { Get-FogBugzCaseFeed -Session $session -FilterName 'Any Filter' } | Should -Throw '*no saved filters*'
            }
        }

        It 'requests explicit case columns for search results' {
            InModuleScope FogBugzSkills {
                Mock Get-FogBugzSavedFilter {
                    @([pscustomobject]@{ Id = '1329'; Name = '4.5 Active assigned to me' })
                }
                Mock Invoke-FogBugzApi -ParameterFilter { $Command -eq 'search' } {
                    [xml]'<response><cases></cases></response>'
                }

                $session = [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                [void](Get-FogBugzCaseFeed -Session $session -FilterName '4.5 Active assigned to me')
                Should -Invoke Invoke-FogBugzApi -ParameterFilter { $Command -eq 'search' -and $Parameter.cols -eq 'ixBug,sTitle,ixPriority,sStatus,fBlocked,dtLastUpdated,sFilter' } -Times 1
            }
        }

        It 'falls back to listFilters when savedfilters is unsupported' {
            InModuleScope FogBugzSkills {
                Mock Invoke-FogBugzApi -ParameterFilter { $Command -eq 'savedfilters' } {
                    throw "FogBugz API error for cmd 'savedfilters': No such API command"
                }
                Mock Invoke-FogBugzApi -ParameterFilter { $Command -eq 'listFilters' } {
                    [xml]'<response><filters><filter><ixFilter>7</ixFilter><sFilter>My Queue</sFilter></filter></filters></response>'
                }

                $session = [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                $filters = Get-FogBugzSavedFilter -Session $session
                $filters.Count | Should -Be 1
                $filters[0].Name | Should -Be 'My Queue'
                Should -Invoke Invoke-FogBugzApi -ParameterFilter { $Command -eq 'savedfilters' } -Times 1
                Should -Invoke Invoke-FogBugzApi -ParameterFilter { $Command -eq 'listFilters' } -Times 1
            }
        }

        It 'loads comments and attachments for a case number' {
            InModuleScope FogBugzSkills {
                Mock Invoke-FogBugzApi {
                    [xml]@'
<response>
  <cases>
    <case>
      <ixBug>14630</ixBug>
      <sTitle>Case with context</sTitle>
      <events>
        <event>
          <ixBugEvent>11</ixBugEvent>
          <sPerson>Alice</sPerson>
          <dt>2026-05-11T12:00:00Z</dt>
          <s>Initial triage note</s>
          <attachment ixAttachment="501" sFileName="log.txt" sURL="https://example/log.txt" />
        </event>
      </events>
    </case>
  </cases>
</response>
'@
                }
                Mock Set-FogBugzSelectedCase { }

                $session = [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                $context = Get-FogBugzCaseDetails -Session $session -CaseNumber '14630'
                $context.Comments.Count | Should -Be 1
                $context.Comments[0].Text | Should -Be 'Initial triage note'
                $context.Attachments.Count | Should -Be 1
                $context.Attachments[0].FileName | Should -Be 'log.txt'
            }
        }

        It 'can load case details by case number using stored session context' {
            InModuleScope FogBugzSkills {
                Mock Connect-FogBugzSession {
                    [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                }
                Mock Invoke-FogBugzApi {
                    [xml]'<response><cases><case><ixBug>14630</ixBug><sTitle>Case from lookup</sTitle></case></cases></response>'
                }
                Mock Set-FogBugzSelectedCase { }

                $context = Get-FogBugzCaseDetails -CaseNumber '14630'
                $context.Id | Should -Be '14630'
                $context.Title | Should -Be 'Case from lookup'
                Should -Invoke Connect-FogBugzSession -Times 1
            }
        }

        It 'stores the selected case when case details are loaded' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                Mock Invoke-FogBugzApi -ParameterFilter { $Command -eq 'logon' } {
                    [xml]'<response><token>token-123</token></response>'
                }
                Mock Invoke-FogBugzApi -ParameterFilter { $Command -eq 'search' } {
                    [xml]'<response><cases><case><ixBug>14630</ixBug><sTitle>Case from lookup</sTitle></case></cases></response>'
                }
                Mock Set-FogBugzCredential { }

                $cred = [pscredential]::new(
                    'dummy.user@example.com',
                    (ConvertTo-SecureString -String 'DummyPassword123!' -AsPlainText -Force)
                )

                $session = Initialize-FogBugzSession -BaseUri 'https://yourtenant.fogbugz.com' -WorkingDirectory $WorkDir -Credential $cred
                [void](Get-FogBugzCaseDetails -Session $session -CaseNumber '14630' -WorkingDirectory $WorkDir)

                $selected = Get-FogBugzSelectedCase
                $selected.Id | Should -Be '14630'
                $selected.Title | Should -Be 'Case from lookup'
            }
        }

        It 'supports positional case number input for fbcase style usage' {
            InModuleScope FogBugzSkills {
                Mock Connect-FogBugzSession {
                    [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                }
                Mock Invoke-FogBugzApi {
                    [xml]'<response><cases><case><ixBug>14630</ixBug><sTitle>Positional call</sTitle></case></cases></response>'
                }
                Mock Set-FogBugzSelectedCase { }

                $context = Get-FogBugzCaseDetails '14630'
                $context.Id | Should -Be '14630'
                $context.Title | Should -Be 'Positional call'
            }
        }

        It 'loads case context during interactive pick flow' {
            InModuleScope FogBugzSkills {
                Mock Connect-FogBugzSession {
                    [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                }
                Mock Get-FogBugzCaseFeed {
                    @([pscustomobject]@{ Id = '14630'; Title = 'Case one'; Priority = 4; Status = 'Active'; IsBlocked = $false; Updated = '2026-05-10T00:00:00Z' })
                }
                Mock Get-FogBugzRankedCase {
                    @([pscustomobject]@{ Id = '14630'; Title = 'Case one'; Priority = 4; Status = 'Active'; Score = 33; Explanation = 'unblocked (+25)' })
                }
                Mock Select-FogBugzCase {
                    [pscustomobject]@{ Id = '14630'; Title = 'Case one'; Priority = 4; Status = 'Active'; Score = 33; Explanation = 'unblocked (+25)' }
                }
                Mock Get-FogBugzCaseDetails {
                    [pscustomobject]@{ Id = '14630'; Title = 'Case one'; Comments = @(); Attachments = @(); ContextSummary = 'Loaded 0 comments and 0 attachments.' }
                }

                $result = Find-FogBugzCase -FilterName 'Any Filter' -Interactive
                $result.ContextSummary | Should -Be 'Loaded 0 comments and 0 attachments.'
                Should -Invoke Get-FogBugzCaseDetails -Times 1
            }
        }

        It 'supports positional filter name input for fbpick style usage' {
            InModuleScope FogBugzSkills {
                Mock Connect-FogBugzSession {
                    [pscustomobject]@{ BaseUri = 'https://yourtenant.fogbugz.com'; Token = 'abc' }
                }
                Mock Get-FogBugzCaseFeed {
                    @([pscustomobject]@{ Id = '14630'; Title = 'Case one'; Priority = 4; Status = 'Active'; IsBlocked = $false; Updated = '2026-05-10T00:00:00Z' })
                }
                Mock Get-FogBugzRankedCase {
                    @([pscustomobject]@{ Id = '14630'; Title = 'Case one'; Priority = 4; Status = 'Active'; Score = 33; Explanation = 'unblocked (+25)' })
                }
                Mock Select-FogBugzCase {
                    [pscustomobject]@{ Id = '14630'; Title = 'Case one'; Priority = 4; Status = 'Active'; Score = 33; Explanation = 'unblocked (+25)' }
                }
                Mock Get-FogBugzCaseDetails {
                    [pscustomobject]@{ Id = '14630'; Title = 'Case one'; Comments = @(); Attachments = @(); ContextSummary = 'Loaded 0 comments and 0 attachments.' }
                }

                $result = Find-FogBugzCase 'Any Filter' -Interactive
                $result.Id | Should -Be '14630'
                Should -Invoke Get-FogBugzCaseFeed -ParameterFilter { $FilterName -eq 'Any Filter' } -Times 1
            }
        }

        It 'resolves directory attachments non-recursively and skips hidden files' {
            InModuleScope FogBugzSkills {
                $root = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
                $dir = Join-Path $root 'attachments'
                $nested = Join-Path $dir 'nested'
                New-Item -ItemType Directory -Path $nested -Force | Out-Null

                $visible = Join-Path $dir 'visible.txt'
                $hidden = Join-Path $dir 'hidden.txt'
                $nestedFile = Join-Path $nested 'nested.txt'

                Set-Content -LiteralPath $visible -Value 'visible'
                Set-Content -LiteralPath $hidden -Value 'hidden'
                Set-Content -LiteralPath $nestedFile -Value 'nested'
                [IO.File]::SetAttributes($hidden, [IO.FileAttributes]::Hidden)

                Mock Write-Warning { }

                $files = Resolve-FogBugzAttachmentPath -AttachmentPath $dir
                @($files).Count | Should -Be 1
                @($files)[0].Name | Should -Be 'visible.txt'
                Should -Invoke Write-Warning -Times 2

                Remove-Item -LiteralPath $root -Recurse -Force
            }
        }

        It 'uses the selected case when no case number is supplied' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                Mock Invoke-FogBugzApi -ParameterFilter { $Command -eq 'logon' } {
                    [xml]'<response><token>token-123</token></response>'
                }
                Mock Invoke-FogBugzMultipartApi {
                    [xml]'<response><ok>true</ok></response>'
                }
                Mock Set-FogBugzCredential { }
                Mock Get-FogBugzCredential { [pscustomobject]@{ UserName = 'dummy.user@example.com'; Token = 'token-123' } }

                $cred = [pscredential]::new(
                    'dummy.user@example.com',
                    (ConvertTo-SecureString -String 'DummyPassword123!' -AsPlainText -Force)
                )

                $session = Initialize-FogBugzSession -BaseUri 'https://yourtenant.fogbugz.com' -WorkingDirectory $WorkDir -Credential $cred
                Set-FogBugzSelectedCase -Case ([pscustomobject]@{ Id = '14630'; Title = 'Selected case' })

                $result = Add-FogBugzCaseComment 'Selected case note' -Session $session -WorkingDirectory $WorkDir -Confirm:$false
                $result.CaseNumber | Should -Be '14630'
                $result.AttachmentCount | Should -Be 0
                Should -Invoke Invoke-FogBugzMultipartApi -ParameterFilter { $Command -eq 'edit' -and $Parameter.ixBug -eq '14630' -and $Parameter.sEvent -eq 'Selected case note' -and $File.Count -eq 0 } -Times 1
            }
        }

        It 'aborts before posting when an attachment path is missing' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                Mock Invoke-FogBugzApi -ParameterFilter { $Command -eq 'logon' } {
                    [xml]'<response><token>token-123</token></response>'
                }
                Mock Invoke-FogBugzMultipartApi {
                    [xml]'<response><ok>true</ok></response>'
                }
                Mock Set-FogBugzCredential { }
                Mock Get-FogBugzCredential { [pscustomobject]@{ UserName = 'dummy.user@example.com'; Token = 'token-123' } }

                $cred = [pscredential]::new(
                    'dummy.user@example.com',
                    (ConvertTo-SecureString -String 'DummyPassword123!' -AsPlainText -Force)
                )

                $session = Initialize-FogBugzSession -BaseUri 'https://yourtenant.fogbugz.com' -WorkingDirectory $WorkDir -Credential $cred
                Set-FogBugzSelectedCase -Case ([pscustomobject]@{ Id = '14630'; Title = 'Selected case' })

                $missing = Join-Path $WorkDir 'missing.log'
                { Add-FogBugzCaseComment 'Selected case note' -Session $session -WorkingDirectory $WorkDir -AttachmentPath @($missing) -Confirm:$false } | Should -Throw
                Should -Invoke Invoke-FogBugzMultipartApi -Times 0
            }
        }
    }

    Context 'Config directory layout' {
        BeforeEach {
            $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            $script:WorkDir = Join-Path $script:TempRoot 'scriptcenter'
            New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
            $env:FOGBUGZ_SELECTED_CASE = $null
        }

        AfterEach {
            $env:FOGBUGZ_SELECTED_CASE = $null
            if (Test-Path -LiteralPath $script:TempRoot) {
                Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
            }
        }

        It 'stores tenant config in .fogbugz\config.json' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                Mock Invoke-FogBugzApi {
                    [pscustomobject]@{ Token = 'token-123' }
                }
                Mock Set-FogBugzCredential { }

                $cred = [pscredential]::new(
                    'dummy.user@example.com',
                    (ConvertTo-SecureString -String 'DummyPassword123!' -AsPlainText -Force)
                )

                [void](Initialize-FogBugzSession -BaseUri 'https://yourtenant.fogbugz.com' -WorkingDirectory $WorkDir -Credential $cred)

                $configPath = Join-Path $WorkDir '.fogbugz\config.json'
                Test-Path -LiteralPath $configPath -PathType Leaf | Should -BeTrue

                $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
                $config.BaseUri | Should -Be 'https://yourtenant.fogbugz.com'
            }
        }
    }

    Context 'Case progress workflow' {
        BeforeEach {
            $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            $script:WorkDir = Join-Path $script:TempRoot 'scriptcenter'
            New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
            $env:FOGBUGZ_SELECTED_CASE = $null
        }

        AfterEach {
            $env:FOGBUGZ_SELECTED_CASE = $null
            if (Test-Path -LiteralPath $script:TempRoot) {
                Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
            }
        }

        It 'saves and retrieves local case progress' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                Set-FogBugzSelectedCase -WorkingDirectory $WorkDir -Case ([pscustomobject]@{ Id = '14630'; Title = 'Selected case' })
                $changes = @([pscustomobject]@{ Path = 'module\FogBugzSkills.psm1'; Intent = 'Added local handoff persistence.' })
                $tests = @([pscustomobject]@{ Command = 'Invoke-Pester -Path .\tests\FogBugzSkills.Tests.ps1'; Result = 'Pass' })
                [void](Save-FogBugzCaseProgress -WorkingDirectory $WorkDir -WorkSummary 'Added local case progress support.' -Status 'In Progress' -Changes $changes -TestsRun $tests -NextSteps @('Create resume skill prompt'))

                $entry = Get-FogBugzCaseProgress -WorkingDirectory $WorkDir -CaseNumber '14630'
                $entry.CaseNumber | Should -Be '14630'
                $entry.Title | Should -Be 'Selected case'
                $entry.WorkSummary | Should -Be 'Added local case progress support.'
                @($entry.Changes).Count | Should -Be 1
                @($entry.TestsRun).Count | Should -Be 1
                @($entry.NextSteps).Count | Should -Be 1

                $progressPath = Join-Path $WorkDir '.fogbugz\case-progress.json'
                Test-Path -LiteralPath $progressPath -PathType Leaf | Should -BeTrue
            }
        }

        It 'removes one case progress entry while preserving others' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                [void](Save-FogBugzCaseProgress -WorkingDirectory $WorkDir -CaseNumber '14630' -Title 'Case A' -WorkSummary 'A')
                [void](Save-FogBugzCaseProgress -WorkingDirectory $WorkDir -CaseNumber '14631' -Title 'Case B' -WorkSummary 'B')

                $result = Remove-FogBugzCaseProgress -WorkingDirectory $WorkDir -CaseNumber '14630'
                $result.RemovedCount | Should -Be 1
                $result.RemainingCount | Should -Be 1

                $all = @(Get-FogBugzCaseProgress -WorkingDirectory $WorkDir)
                $all.Count | Should -Be 1
                $all[0].CaseNumber | Should -Be '14631'
            }
        }

        It 'supports explicit remove-all for case progress' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                [void](Save-FogBugzCaseProgress -WorkingDirectory $WorkDir -CaseNumber '14630' -Title 'Case A' -WorkSummary 'A')
                [void](Save-FogBugzCaseProgress -WorkingDirectory $WorkDir -CaseNumber '14631' -Title 'Case B' -WorkSummary 'B')

                $result = Remove-FogBugzCaseProgress -WorkingDirectory $WorkDir -All
                $result.RemovedCount | Should -Be 2
                $result.RemainingCount | Should -Be 0

                @(Get-FogBugzCaseProgress -WorkingDirectory $WorkDir).Count | Should -Be 0
            }
        }

        It 'requires case number when remove-all is not specified' {
            InModuleScope FogBugzSkills -Parameters @{ WorkDir = $script:WorkDir } {
                param($WorkDir)

                [void](Save-FogBugzCaseProgress -WorkingDirectory $WorkDir -CaseNumber '14630' -Title 'Case A' -WorkSummary 'A')
                { Remove-FogBugzCaseProgress -WorkingDirectory $WorkDir } | Should -Throw '*CaseNumber is required*'
            }
        }
    }
}
