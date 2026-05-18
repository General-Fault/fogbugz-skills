---
name: fogbugz-handoff-case
description: Save local handoff progress for a FogBugz case into .fogbugz\case-progress.json without updating FogBugz server data. Use when wrapping up work, handing off to a new agent, or when user asks to capture current status, tests, and next steps for a case.
---

Use this skill to persist local case progress for cross-agent handoff.

## Inputs

- `focusHint` (optional): a free-text phrase the user provides to narrow what the skill emphasises (e.g. "focus on the auth layer", "summarise database changes").

Do not ask the user for any other inputs. All handoff fields are inferred from the conversation context and git.

## Execution flow

### 1. Resolve the current case

Run `fbcase` (without arguments) to load the currently selected case.

If that fails due to missing auth/config, ask the user to run `fblogin` (`Initialize-FogBugzSession`), then retry.

### 2. Gather git diff context

Determine whether the working directory is a git repository:

```powershell
git rev-parse --is-inside-work-tree 2>$null
```

If git is unavailable or the directory is not a repo, skip all diff steps silently and proceed with context-only inference.

Otherwise:

**Detect the current branch:**
```powershell
git rev-parse --abbrev-ref HEAD
```

**Root branches** are: `main`, `develop`, `master`. Any other branch is a case/feature/hotfix branch.

**On a non-root branch** — find the merge-base against the nearest root branch:
```powershell
# Try parent branches in this order: develop, master, main
foreach ($parent in @('develop', 'master', 'main')) {
    if (git rev-parse --verify $parent 2>$null) {
        $mergeBase = git merge-base HEAD $parent
        break
    }
}
# Committed changes since branch diverged
git diff --name-only $mergeBase HEAD
# Plus uncommitted tracked changes
git diff --name-only HEAD
```

**On a root branch** — use only uncommitted tracked changes:
```powershell
git diff --name-only HEAD
```

Deduplicate the combined file list. For each changed file, read a brief excerpt of the diff to understand intent:
```powershell
git diff $mergeBase HEAD -- <file>   # committed (non-root branch)
git diff HEAD -- <file>              # uncommitted
```

### 3. Infer handoff fields

Using the conversation context and the diff output gathered above:

- **`workSummary`**: synthesise a concise paragraph from the conversation turns and the list of changed files. If `focusHint` was provided, weight the summary toward that area.
- **`changes`**: build one entry per changed file: `@{ Path = '<relative path>'; Intent = '<what changed and why, inferred from diff>' }`. If `focusHint` was provided, surface those files first.
- **`testsRun`**: include only tests explicitly mentioned or executed during this session: `@{ Command = '...'; Result = '...' }`. Leave empty (`@()`) if no tests were discussed.
- **`nextSteps`**: extract any remaining tasks or continuation steps from the conversation. Leave empty (`@()`) if nothing clear is present.
- **`openQuestions`**: extract any unresolved unknowns or blockers from the conversation. Leave empty (`@()`) if nothing clear is present.

### 4. Save progress

```powershell
fbsaveprogress `
  -WorkSummary $workSummary `
  -Changes $changes `
  -TestsRun $testsRun `
  -NextSteps $nextSteps `
  -OpenQuestions $openQuestions
```

Do not pass `-CaseNumber`; the module resolves it from the selected case automatically.

### 5. Confirm

Report the saved record with: case number, title, branch, updated timestamp, and a one-line summary of what was captured.

## Output behavior

- Keep output concise and handoff-focused.
- Do not create a new implementation plan.
- Make sure next steps (when present) are actionable for the next agent.
- Do not ask the user for required fields — infer everything.
- Avoid redundant preflight calls to `fbconnect`; only ask for `fblogin` when auth/config errors occur during case loading.
