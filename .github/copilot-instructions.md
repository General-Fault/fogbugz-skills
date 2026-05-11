# Repository Instructions for Copilot Agents

These rules apply to all code changes in this repository.

## Issue-First Requirement
- Before making any code change, create or reference a GitHub issue that explains the problem and intended fix.
- Use one issue per independently resolvable problem.

## Commit and Issue Linking
- Use separate commits for separate issues.
- Add a comment to each relevant issue with the commit SHA and summary of what changed.
- If a commit should resolve an issue, mention that intent in the issue comment.
- Do not rely on auto-close keywords alone.

## Safe Multi-line String Construction (CRITICAL)
When constructing multi-line `git commit` messages or `gh issue comment` bodies, **never** use ANSI-C quoting (`$'...\n...'`) or any shell mechanism that interprets backslash escape sequences. Words beginning with `a`, `v`, `n`, `t`, `r`, `b`, `f`, etc. will have their first character silently replaced by a control character.

**Always use one of these safe patterns instead:**

Multi-line commit message — use multiple `-m` flags:
```powershell
git commit -m "subject line" -m "Body paragraph one." -m "Body paragraph two."
```

Issue comment body — assign to a variable with a PowerShell here-string, then pass the variable:
```powershell
$body = @"
Summary:
- Updated the FogBugz skill prompt flow
- Added tests for score/ranking behavior
"@
gh issue comment 17 --body $body
```

Never construct the body inline with `\n` sequences, e.g. do **not** do:
```powershell
gh issue comment 17 --body "Summary:\n- Updated actions/checkout"  # \a corrupts "actions"
```

## Testing and TDD Expectations
- For functional changes, add or update unit tests first when feasible, then implement/fix code.
- If true test-first is not feasible, add tests in the same change before merging.
- Run local tests and relevant lint checks before pushing.

## Issue Closure Rule
- Do not close an issue until the relevant GitHub Actions checks have passed for the fix commit/PR.

## Pull Request Expectations
- Link issue(s) in the PR description.
- Explain test evidence and workflow status.
- Keep each PR scoped to the linked issue(s).

## Pull Request-First Execution Policy
- Default delivery path is Pull Request.
- Do not push commits directly to `main`, `develop`, or any protected branch unless the user explicitly instructs direct push or no PR.
- If user intent on PR versus direct push is ambiguous, stop and ask before pushing.
- In final handoff, include PR link, linked issue(s), and workflow/check status.
- If direct push is explicitly user-requested, state that this was an exception to the default PR-first policy.
