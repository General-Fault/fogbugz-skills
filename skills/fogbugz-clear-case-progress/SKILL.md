---
name: fogbugz-clear-case-progress
description: Remove local FogBugz case progress entries from .fogbugz\case-progress.json without editing FogBugz server data. Use when handoff notes are obsolete, incorrect, or intentionally reset for one case or all saved cases.
---

Use this skill to delete local case-progress entries safely.

## Inputs to collect

- `caseNumber` (optional): case to remove.
- `removeAll` (optional): clear all local progress entries.

## Execution flow

1. Confirm intent:
   - one case: remove by `caseNumber`
   - all cases: require explicit confirmation before continuing
2. Run command:
   - single case: `fbclearprogress -CaseNumber <caseNumber>`
   - all: `fbclearprogress -All`
3. Return result details:
   - removed count
   - remaining count
   - removed case number (when applicable)

## Output behavior

- Be explicit that this updates local progress only.
- Never imply FogBugz case content/status was modified.
- If the target case is missing from local progress, report that directly.

