---
name: fogbugz-pick-case
description: Pick the next FogBugz case by named filter using stored local session context.
---

Use this skill to select the next FogBugz case for the active work queue.

## Inputs to collect

- `filterName` (required): exact or partial saved-filter name.

## Execution flow

1. Ensure the module is already available in the shell session.
2. Ensure auth context exists for the current working directory:
   - Primary: `fbconnect`
   - If missing: run `fblogin` (`Initialize-FogBugzSession`) and then continue.
3. Run case picker:
   `fbpick -FilterName '<filterName>' -Interactive`
   - The user must explicitly choose a case number.
   - Prefer this native interactive picker flow because it already prints detailed options.
   - Do not replace it with a generic “which number” prompt unless shell interactivity is unavailable.
4. After selection, ensure case details are loaded by case number:
   `fbcase <selected case id>`
5. Return selected case details clearly:
   - case id
   - title
   - status
   - rank explanation
   - context summary (comments/events + attachments loaded)

## Output behavior

- Keep output concise and task-focused.
- If filter resolution is ambiguous, show the suggestions and ask for a narrower name.
- If no cases match, say that explicitly and suggest validating filter membership in FogBugz.
- After case selection, use loaded comment and attachment context when summarizing the case.
- If you must ask for a choice in chat, each option must include details in this format:
  `<case id> — <title> (score <n>; <explanation>)`
- Never present numeric-only options like `1`, `2`, `3` without case details.

## Example

```powershell
fblogin
fbpick -FilterName '4.5 Active assigned to me' -Interactive
```

## Notes

- v1 supports named FogBugz filters.
- If filter name is incomplete, the module attempts partial resolution and provides disambiguation suggestions.
