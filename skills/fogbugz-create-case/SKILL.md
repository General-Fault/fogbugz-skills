---
name: fogbugz-create-case
description: Creates a new FogBugz case with a title, description, and optional project/area/category/priority/assignment/tags. Use when the user wants to open, file, log, or create a new FogBugz case or bug.
---

Use this skill to create a new FogBugz case through `New-FogBugzCase` (`fbnewcase`).

## Inputs to collect

- `title` (required): short, specific summary of the problem or task.
- `description` (optional but strongly preferred): the initial case details/repro steps. Ask for
  this if the user only gave a title and the request is non-trivial.
- `project` (optional): FogBugz project name.
- `area` (optional): FogBugz area within the project.
- `category` (optional): e.g. `Bug`, `Feature`, `Inquiry`.
- `priority` (optional): numeric FogBugz priority id.
- `assignTo` (optional): person to assign the case to (name or email).
- `tags` (optional): one or more tags.
- `dueDate` (optional): a due date.
- `attachmentPath` (optional): one or more files/directories to attach.

Only ask the user for fields that are ambiguous or missing and clearly relevant to the request.
Do not block on optional fields the user hasn't mentioned and has no obvious need for.

## Execution flow

1. Ensure auth context exists for the current working directory:
   - Primary: `fbconnect`
   - If missing: run `fblogin` (`Initialize-FogBugzSession`) and then continue.
2. Confirm the title and description with the user before creating the case if either was
   inferred/summarized rather than stated verbatim, especially for non-trivial cases.
3. Create the case:
   `fbnewcase -Title '<title>' -Description '<description>' [-Project '<project>'] [-Area '<area>'] [-Category '<category>'] [-Priority <n>] [-AssignTo '<assignTo>'] [-Tags @('<tag1>','<tag2>')] [-DueDate <date>] [-AttachmentPath @('<path>')]`
   - Only pass the optional parameters that were actually collected.
4. `New-FogBugzCase` also loads full case details and stores the new case as the selected case
   for the working directory, so it is immediately usable by `fbcomment`, handoff, and branch
   creation skills.
5. Report back:
   - case id
   - title
   - project/area/category (if set)
   - assigned-to (if set)
   - a short confirmation that the case was created and selected

## Output behavior

- Keep output concise and creation-focused.
- If FogBugz rejects the project/area/category/assignee (e.g. unknown name), surface the exact
  error and ask the user to confirm the correct value rather than guessing a substitute.
- Do not create a branch or post a comment as part of this skill; those are separate skills
  (`fogbugz-create-branch`, `fbcomment`).

## Example

```powershell
fblogin
fbnewcase -Title 'Login button unresponsive on mobile Safari' -Description 'Tapping Login does nothing on iOS 17 Safari. Repro: ...' -Project 'Portal' -Area 'Authentication' -Category 'Bug' -Priority 2
```

## Notes

- `New-FogBugzCase` supports `-WhatIf`/`-Confirm` (`SupportsShouldProcess`); use `-Confirm:$false`
  only when the user has already confirmed the fields in conversation.
- Attachments are uploaded in the same request that creates the case.
