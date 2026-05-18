# Auth Storage Prototype — Notes

## Question
Does the new three-store auth model feel right?

| What | Where | Lifetime |
|---|---|---|
| BaseUri | `.fogbugz` file in working directory | Until deleted |
| Token | Windows Credential Manager | Until logged out |
| Selected case (Id, Title, timestamp) | `$env:FOGBUGZ_SELECTED_CASE` | Current terminal session only |

## Run

```powershell
.\prototype\auth-storage\Invoke-AuthStoragePrototype.ps1
```

## Answer

_(fill in after driving the prototype)_

- Did the three-store split feel natural?
- Was it annoying that case selection resets on new terminal?
- Should `.fogbugz` be committed to the repo, or `.gitignore`d?
- Any edge cases that felt wrong?

## Verdict

- [x] Model validated — lift state module into real code, delete TUI shell
