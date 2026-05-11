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
}
