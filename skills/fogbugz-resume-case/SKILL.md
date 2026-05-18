---
name: fogbugz-resume-case
description: Resume work from locally saved FogBugz case progress in .fogbugz\case-progress.json and reload case context. Use when starting a new agent, continuing interrupted work, or when user asks to pick up the last/previous handoff case.
---

Use this skill to resume from saved local case progress and continue execution.

## Inputs to collect

- `caseNumber` (optional): exact FogBugz case ID.
- `branchHint` (optional): branch name fragment if selection is ambiguous.

## Execution flow

1. Ensure module and local auth context are available (`fbconnect`).
2. Load local progress entries:
   - `@($entries = fbresume)`
3. Select target case in this priority order:
   - explicit `caseNumber` input
   - branch match when current branch contains a case number
   - single available progress entry
   - otherwise prompt the user with detailed options and let them choose
4. Resolve and load live case context:
   - `fbcase <selected case number>`
5. Return resume context:
   - case id/title/status
   - saved work summary
   - saved changes/tests/open questions/next steps/artifacts
   - current branch and updated timestamp

## Selection details

- Read current branch:
  `git rev-parse --abbrev-ref HEAD`
- If branch contains a case number, prefer the matching saved entry.
- If user must choose, list each option as:
  `<case id> — <title> (updated <utc>; branch <branch>; summary <workSummary>)`

## Output behavior

- Do not generate a new plan; continue from the saved next steps.
- If no local progress exists, state that clearly and suggest `fbpick` then `fogbugz-handoff-case`.
- If a requested case number has no saved progress, say so explicitly.

