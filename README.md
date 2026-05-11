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

## Governance

Repository rules for Copilot agents live in `.github/copilot-instructions.md`.
