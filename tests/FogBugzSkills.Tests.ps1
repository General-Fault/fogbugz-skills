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
        It 'returns the top case when the user presses enter' {
            InModuleScope FogBugzSkills {
                Mock Read-Host { '' }

                $cases = @(
                    [pscustomobject]@{ Id = 10; Title = 'Top'; Score = 9; Explanation = 'good' }
                    [pscustomobject]@{ Id = 11; Title = 'Second'; Score = 8; Explanation = 'fine' }
                )

                (Select-FogBugzCase -Case $cases).Id | Should -Be 10
            }
        }
    }

    Context 'Auth bootstrap workflow' {
        BeforeEach {
            $script:OriginalLocalAppData = $env:LOCALAPPDATA
            $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
            $script:WorkDir = Join-Path $script:TempRoot 'scriptcenter'
            New-Item -ItemType Directory -Path $script:WorkDir -Force | Out-Null
            $env:LOCALAPPDATA = $script:TempRoot
        }

        AfterEach {
            $env:LOCALAPPDATA = $script:OriginalLocalAppData
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
    }
}
