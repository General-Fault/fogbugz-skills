# fogbugz-skills

Copilot skills plus a PowerShell module for running a FogBugz case workflow end-to-end with AI assistance.

## Why this project exists

This repository exists to integrate FogBugz into your AI-assisted development workflow:

1. Pick a FogBugz case from your queue.
2. Create a correctly named case branch and start work.
3. Capture local handoff context before switching away.
4. Resume quickly in a later agent/session without losing state.
5. Update the case with testing guidance or progress notes when needed.

The project combines Copilot skills with a PowerShell module so humans and agents can collaborate with less context loss and less repeated setup.

## Current skills

All skills live under `skills/`:

- `fogbugz-pick-case` - pick the next case from a named filter using an interactive picker.
- `fogbugz-create-case` - create a new FogBugz case with title, description, and optional project/area/category/priority/assignment.
- `fogbugz-create-branch` - create/switch to `cases/<case-number>-<description>`.
- `fogbugz-handoff-case` - save local handoff progress for the selected case.
- `fogbugz-resume-case` - restore saved case progress and reload live case context.
- `fogbugz-clear-case-progress` - remove local saved progress for one case or all cases.

## AI-assisted workflow

### 1. Pick a case

Run `/fogbugz-pick-case` and provide a filter such as **My Saved FogBugz Filter**.

Skill behavior:

- select a case from the top 5 of a given filter
- selected case details are loaded (including comments/events and attachment metadata)
- selected case context is persisted for follow-up skills and commands
- if auth/session context is missing, it guides you through login before retrying

### 2. Create a new case

Run `/fogbugz-create-case`.

Skill behavior:

- creates a new FogBugz case from a title and description, with optional project/area/category/priority/assignment/tags
- loads full case details after creation and persists the new case as the selected case
- confirms inferred/summarized title or description with you before creating a non-trivial case

### 3. Create a case branch

Run `/fogbugz-create-branch`.

Skill behavior:

- proposes a branch name in `cases/<case-number>-<description>` format
- prefers case-title-derived descriptions
- prevents duplicate branch creation for the same case number
- creates and switches to the selected branch

### 4. Save handoff before stopping

Run `/fogbugz-handoff-case`.

Skill behavior:

- saves local handoff progress to `.fogbugz\case-progress.json`
- infers summary, changes, tests, open questions, and next steps from the conversation context and git diff
- all handoff information is saved locally (no FogBugz server changes)

### 5. Resume later

Run `/fogbugz-resume-case`.

Skill behavior:

- restores saved local handoff progress from the /fogbugz-handoff-case skill
- reloads live FogBugz case context for the selected case
- if multiple saved entries exist, it presents choices so you can pick which case to resume

### 6. Clear stale handoff data (when needed)

Run `/fogbugz-clear-case-progress`.

Skill behavior:

- removes one saved handoff entry or all saved handoff entries
- reports what was removed and what remains
- only updates local progress files (no FogBugz server changes)

## Running the commands yourself

If you prefer direct module usage, import the module and run cmdlets explicitly:

```powershell
Import-Module .\module\FogBugzSkills.psd1 -Force
```

### Initialize-FogBugzSession

Initializes FogBugz auth/session context for a working directory.

| Parameter | Required | Description |
| --- | --- | --- |
| `-BaseUri <string>` | No | FogBugz tenant base URI to connect to. |
| `-Credential <pscredential>` | No | Credentials for authentication. If omitted, interactive prompting is used. |
| `-WorkingDirectory <string>` | No | Directory key used for storing/retrieving local session context. |

### Connect-FogBugzSession

Loads an existing session context and returns a usable session object, or prompts when requested.

| Parameter | Required | Description |
| --- | --- | --- |
| `-BaseUri <string>` | No | FogBugz tenant base URI override. |
| `-PromptForCredentials` | No | Forces an interactive credential prompt when cached credentials are missing or invalid. |
| `-WorkingDirectory <string>` | No | Directory key used to locate stored local session context. |

### Find-FogBugzCase

Finds and ranks candidate cases from a saved filter, with optional interactive selection.

| Parameter | Required | Description |
| --- | --- | --- |
| `-BaseUri <string>` | No | FogBugz tenant base URI override for the query. |
| `-FilterName <string>` | No | Saved-filter name (exact or partial) to resolve before searching cases. |
| `-Interactive` | No | Opens the interactive picker so you can choose from ranked cases. |
| `-Top <int>` | No | Maximum number of ranked cases to return before selection. |
| `-WorkingDirectory <string>` | No | Directory key for local auth/selected-case context. |

### Get-FogBugzCaseDetails

Loads full case details, including case feed/context artifacts.

| Parameter | Required | Description |
| --- | --- | --- |
| `-CaseNumber <string>` | Yes | FogBugz case ID to retrieve. |
| `-Session <psobject>` | No | Existing session object to reuse. If omitted, stored session context is used. |
| `-WorkingDirectory <string>` | No | Directory key for loading stored session context. |

### Add-FogBugzCaseComment

Posts a comment to a FogBugz case, with optional attachments.

| Parameter | Required | Description |
| --- | --- | --- |
| `-Comment <string>` | Yes | Comment text to post. |
| `-CaseNumber <string>` | No | Target case ID. If omitted, the currently selected local case is used. |
| `-AttachmentPath <string[]>` | No | One or more file or directory paths to attach to the comment. |
| `-Session <psobject>` | No | Pre-resolved session object. If omitted, stored session context is used. |
| `-WorkingDirectory <string>` | No | Directory key for local auth/selected-case context. |

### New-FogBugzCase

Creates a new FogBugz case, loads its full details, and selects it for the working directory.

| Parameter | Required | Description |
| --- | --- | --- |
| `-Title <string>` | Yes | Title of the new case. |
| `-Description <string>` | No | Initial case description/repro steps (posted as the opening event). |
| `-Project <string>` | No | FogBugz project name. |
| `-Area <string>` | No | FogBugz area name within the project. |
| `-Category <string>` | No | Case category (e.g. `Bug`, `Feature`). |
| `-Priority <int>` | No | Numeric FogBugz priority ID. |
| `-AssignTo <string>` | No | Person to assign the case to (name or email). |
| `-Tags <string[]>` | No | One or more tags to apply. |
| `-DueDate <datetime>` | No | Due date for the case. |
| `-AttachmentPath <string[]>` | No | One or more file or directory paths to attach when creating the case. |
| `-Session <psobject>` | No | Pre-resolved session object. If omitted, stored session context is used. |
| `-WorkingDirectory <string>` | No | Directory key for local auth/selected-case context. |

### New-FogBugzCaseBranch

Creates and checks out a new git branch for a FogBugz case.

| Parameter | Required | Description |
| --- | --- | --- |
| `-CaseNumber <string>` | Yes | FogBugz case ID used in the branch name. |
| `-Description <string>` | Yes | Short description slug appended after the case number. |
| `-WorkingDirectory <string>` | No | Directory where the git command is run. |

### Save-FogBugzCaseProgress

Saves local handoff progress for the currently selected case to `.fogbugz\case-progress.json`.

| Parameter | Required | Description |
| --- | --- | --- |
| `-WorkSummary <string>` | Yes | Concise paragraph describing completed work. |
| `-CaseNumber <string>` | No | Case ID to save progress for. Resolved from selected case when omitted. |
| `-Title <string>` | No | Case title. Resolved from selected case when omitted. |
| `-Status <string>` | No | Current local status label. |
| `-Branch <string>` | No | Current branch. Resolved from git when omitted. |
| `-Changes <object[]>` | No | Array of `@{ Path; Intent }` objects describing changed files. |
| `-TestsRun <object[]>` | No | Array of `@{ Command; Result }` objects for tests executed. |
| `-OpenQuestions <string[]>` | No | Unresolved unknowns or blockers. |
| `-NextSteps <string[]>` | No | Ordered continuation steps for the next agent. |
| `-Artifacts <string[]>` | No | Useful local paths or links. |
| `-WorkingDirectory <string>` | No | Directory key for reading selected case and writing progress. |

### Get-FogBugzCaseProgress

Reads saved local case progress from `.fogbugz\case-progress.json`.

| Parameter | Required | Description |
| --- | --- | --- |
| `-CaseNumber <string>` | No | Returns the entry for this specific case. If omitted, returns all entries sorted newest-first. |
| `-WorkingDirectory <string>` | No | Directory to search for `.fogbugz\case-progress.json`. |

### Remove-FogBugzCaseProgress

Removes one or all local case progress entries from `.fogbugz\case-progress.json`.

| Parameter | Required | Description |
| --- | --- | --- |
| `-CaseNumber <string>` | No | Case ID to remove. |
| `-All` | No | Remove all entries. Mutually exclusive with `-CaseNumber`. |
| `-WorkingDirectory <string>` | No | Directory containing `.fogbugz\case-progress.json`. |



| Parameter | Required | Description |
| --- | --- | --- |
| `-Case <psobject>` | Yes | Case object to score (for rank priority and explanation). |

### Get-FogBugzRankedCase

Ranks multiple cases by score and returns sorted results.

| Parameter | Required | Description |
| --- | --- | --- |
| `-Case <object[]>` | Yes | Array of case objects to score and sort from highest to lowest priority. |

### Resolve-FogBugzFilter

Resolves a user-supplied filter name against available FogBugz saved filters.

| Parameter | Required | Description |
| --- | --- | --- |
| `-FilterName <string>` | Yes | Filter name (exact or partial) to resolve. |
| `-Filter <object[]>` | Yes | Candidate filter objects to match against `-FilterName`. |

### Select-FogBugzCase

Performs explicit case selection from ranked candidates.

| Parameter | Required | Description |
| --- | --- | --- |
| `-Case <object[]>` | Yes | Candidate cases to display and select from. |
| `-SelectTopOnEmpty` | No | If enabled, pressing Enter on empty input selects the top-ranked case. |

## Useful module aliases

- `fblogin` -> `Initialize-FogBugzSession`
- `fbconnect` -> `Connect-FogBugzSession`
- `fbpick` -> `Find-FogBugzCase`
- `fbcomment` -> `Add-FogBugzCaseComment`
- `fbcase` -> `Get-FogBugzCaseDetails`
- `fbnewcase` -> `New-FogBugzCase`
- `fbscore` -> `Get-FogBugzCaseScore`
- `fbrank` -> `Get-FogBugzRankedCase`
- `fbfilter` -> `Resolve-FogBugzFilter`
- `fbselect` -> `Select-FogBugzCase`
- `fbsaveprogress` -> `Save-FogBugzCaseProgress`
- `fbresume` -> `Get-FogBugzCaseProgress`
- `fbclearprogress` -> `Remove-FogBugzCaseProgress`

## Notes for contributors

Repository automation and agent rules are in `.github/copilot-instructions.md`.
