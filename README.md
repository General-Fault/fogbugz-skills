# fogbugz-skills

Copilot skills and PowerShell helpers for working with FogBugz in a shared workflow.

## What this repo is for

- Find the next FogBugz case to work on.
- Summarize case-linked changes into concise QA test guidance.
- Update FogBugz with progress notes and commit context.

## Planned layout

- `module/` — PowerShell module with reusable FogBugz helpers.
- `skills/` — Copilot skill definitions and prompts.
- `tools/` — bootstrap and support scripts.

## Current status

This repo is still being bootstrapped. The initial governance files are in place, and the first vertical slice is the case picker.

## Development notes

- Use PowerShell for local automation.
- FogBugz access is expected to use interactive login with cached session tokens.
- The repo is intended to support shared use across coworkers.

## First slice

The first implemented slice is a PowerShell module that can:

- log in to FogBugz interactively,
- resolve exact named filters,
- rank cases with short explanations, and
- let the user pick a case from the returned list.

Import `module/FogBugzSkills.psd1` to use it locally.

## Real-world workflow (current)

1. Run pre-auth once in the working directory:
   `fblogin` (alias for `Initialize-FogBugzSession`).
2. Enter tenant URI and credentials at the secure local prompt.
3. Run case picker:
   `Find-FogBugzCase -FilterName "<your filter>" -Interactive`

The tenant context and session token are cached per working directory for later non-interactive module usage.
When a case is selected interactively, the module now loads case comments/events and attachment metadata into the returned case context.
You can also load details directly by case number with `Get-FogBugzCaseDetails` / `fbcase 14630`.
The current selected case is stored per working directory, so `fbcomment` can reuse the last picked or loaded case without retyping the case number.

The companion skill scaffold lives at `skills/fogbugz-pick-case/SKILL.md`.

Short aliases are available:
- `fblogin` -> `Initialize-FogBugzSession`
- `fbconnect` -> `Connect-FogBugzSession`
- `fbpick` -> `Find-FogBugzCase`
- `fbcomment` -> `Add-FogBugzCaseComment`
- `fbcase` -> `Get-FogBugzCaseDetails`
- `fbscore` -> `Get-FogBugzCaseScore`
- `fbrank` -> `Get-FogBugzRankedCase`
- `fbfilter` -> `Resolve-FogBugzFilter`
- `fbselect` -> `Select-FogBugzCase`

## Governance

Repository rules for Copilot agents live in `.github/copilot-instructions.md`.
