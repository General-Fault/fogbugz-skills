---
name: fogbugz-create-branch
description: Creates and checks out a local git branch for the currently selected FogBugz case. Use when starting case work, creating a branch from an active FogBugz case, or when branch names must follow cases/[case number]-[description].
---

# FogBugz Create Branch

## Quick start

1. Load the currently selected case with `fbcase` if it is not already available.
2. Build the target branch name from the case number and a short description:
   - default format: `cases/[case number]-[two to four word description]`
   - accept a user-supplied description or partial `case-number-description`
3. Prefer the case title for the description.
4. If the title is vague or conceptually different from the proposed branch name, ask the user to verify the name before continuing.
5. Check local branches before creating anything:
   - if the exact target branch exists, stop
   - if another branch exists for the same case number, show it and ask the user which name to use
6. Run `New-FogBugzCaseBranch -CaseNumber <case number> -Description <description>`.

## Naming rules

- Convert the title into lowercase kebab-case.
- Keep the description to 2-4 words when possible.
- Remove punctuation and extra whitespace.
- Preserve the selected case number in the branch prefix.

## Workflow

### Creating a new case branch

1. Confirm the selected FogBugz case.
2. Propose the branch name.
3. Ask for confirmation if the proposed name feels too broad, too narrow, or conceptually off.
4. Create and switch to the branch.

### Handling conflicts

1. If a branch with the same case number already exists, surface the matching branch names.
2. If the exact target branch exists, abort.
3. If the user supplied a partial branch name, use the description fragment as-is after confirming it still matches the selected case.

## Reference

See `New-FogBugzCaseBranch` in the FogBugzSkills module for the deterministic git branch creation step.
