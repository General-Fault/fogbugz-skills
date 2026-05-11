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

        It 'exports expected alias-command mappings' {
            $expected = @{
                fblogin   = 'Initialize-FogBugzSession'
                fbconnect = 'Connect-FogBugzSession'
                fbpick    = 'Find-FogBugzCase'
                fbcomment = 'Add-FogBugzCaseComment'
                fbcase    = 'Get-FogBugzCaseDetails'
                fbscore   = 'Get-FogBugzCaseScore'
                fbrank    = 'Get-FogBugzRankedCase'
                fbfilter  = 'Resolve-FogBugzFilter'
                fbselect  = 'Select-FogBugzCase'
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
}
