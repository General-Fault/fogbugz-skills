---
name: fogbugz-handoff-case
description: Save local handoff progress for a FogBugz case into .fogbugz\case-progress.json without updating FogBugz server data. Use when wrapping up work, handing off to a new agent, or when user asks to capture current status, tests, and next steps for a case.
---

Use this skill to persist local case progress for cross-agent handoff.

## Inputs to collect

- `caseNumber` (optional): use current selected case when omitted.
- `status` (optional): current local status label.
- `workSummary` (required): concise summary of completed work.
- `changes` (required, at least one): file + intent per item.
- `testsRun` (required, at least one): command + result per item.
- `openQuestions` (optional): unknowns and blockers.
- `nextSteps` (required, at least one): ordered continuation steps.
- `artifacts` (optional): useful local paths/links.

## Execution flow

1. Ensure module and local auth context are available (`fbconnect`).
2. Ensure target case is selected:
   - if `caseNumber` provided: run `fbcase <caseNumber>`
   - else rely on current selected case from prior `fbpick`/`fbcase`
3. Collect handoff details in structured form:
   - `changes`: `@(@{ Path = '...'; Intent = '...' })`
   - `testsRun`: `@(@{ Command = '...'; Result = '...' })`
4. Save locally with `fbsaveprogress`:
   - include `-CaseNumber` only when explicitly provided
   - include `-WorkSummary`, `-Changes`, `-TestsRun`, `-NextSteps`
   - include optional `-Status`, `-OpenQuestions`, `-Artifacts`
5. Confirm saved record with key fields: case number, title, updated time, branch.

## Output behavior

- Keep output concise and handoff-focused.
- Do not create a new implementation plan during handoff.
- Make sure next steps are actionable for the next agent.
- If required fields are missing, ask for them before saving.

