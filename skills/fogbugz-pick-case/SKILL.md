---
name: fogbugz-pick-case
description: Pick the next FogBugz case by named filter using stored local session context.
---

Use this skill to select the next case to work on in the current repository working directory.

## Preconditions

- The PowerShell module is available at `module/FogBugzSkills.psd1`.
- If no local auth context exists, run `fblogin` (`Initialize-FogBugzSession`) first.

## Steps

1. Import module:
   `Import-Module .\module\FogBugzSkills.psd1 -Force`
2. If needed, initialize auth:
   `Initialize-FogBugzSession`
3. Pick case:
   `Find-FogBugzCase -FilterName "<named filter>" -Interactive`

## Notes

- v1 supports named FogBugz filters.
- If filter name is incomplete, the module attempts partial resolution and provides disambiguation suggestions.
