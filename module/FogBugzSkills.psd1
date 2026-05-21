@{
    RootModule        = 'FogBugzSkills.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'd9c4b0f8-4d73-4a79-9c62-2f3f0f3e7b12'
    Author            = 'Cody Barnes'
    CompanyName       = 'ConceptGenesis'
    Copyright         = '(c) ConceptGenesis. All rights reserved.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Add-FogBugzCaseComment'
        'Connect-FogBugzSession'
        'Find-FogBugzCase'
        'Get-FogBugzCaseDetails'
        'Get-FogBugzCaseScore'
        'Get-FogBugzRankedCase'
        'Initialize-FogBugzSession'
        'New-FogBugzCaseBranch'
        'Resolve-FogBugzFilter'
        'Select-FogBugzCase'
    )
    AliasesToExport   = @(
        'fblogin'
        'fbconnect'
        'fbpick'
        'fbcomment'
        'fbcase'
        'fbscore'
        'fbrank'
        'fbfilter'
        'fbselect'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
}
