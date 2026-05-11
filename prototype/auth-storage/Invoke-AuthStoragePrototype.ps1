# PROTOTYPE — THROWAWAY
# Question: Does the new three-store auth model feel right?
#   - BaseUri  → .fogbugz file in working directory
#   - Token    → Windows Credential Manager (persisted across sessions)
#   - Selected case → $env:FOGBUGZ_SELECTED_CASE (in-memory, cleared on new terminal)
#
# Run: .\prototype\auth-storage\Invoke-AuthStoragePrototype.ps1

#region --- Pure state module (the part worth keeping if the model is validated) ---

# All storage is simulated in-memory so the prototype runs without side effects.
# The interface mirrors what the real implementation would look like.

$script:SimConfigFile  = $null   # $null = .fogbugz file does not exist
$script:SimCredStore   = @{}     # key = BaseUri, value = @{ Token }
$script:SimEnvCase     = $null   # $null = env var not set
$script:SimLog         = [System.Collections.Generic.List[string]]::new()

function script:Get-SimConfig { $script:SimConfigFile }

function script:Set-SimConfig([string]$BaseUri) {
    $script:SimConfigFile = @{ BaseUri = $BaseUri.Trim() }
    script:Append-Log "Wrote .fogbugz  BaseUri = $BaseUri"
}

function script:Remove-SimConfig {
    $script:SimConfigFile = $null
    script:Append-Log "Deleted .fogbugz"
}

function script:Get-SimCredential([string]$BaseUri) {
    if ($script:SimCredStore.ContainsKey($BaseUri)) { $script:SimCredStore[$BaseUri] }
    else { $null }
}

function script:Set-SimCredential([string]$BaseUri, [string]$UserName, [string]$Token) {
    $script:SimCredStore[$BaseUri] = @{ UserName = $UserName; Token = $Token }
    script:Append-Log "Saved to Credential Manager  key = FogBugz:$BaseUri  user = $UserName"
}

function script:Remove-SimCredential([string]$BaseUri) {
    $script:SimCredStore.Remove($BaseUri)
    script:Append-Log "Removed from Credential Manager  key = FogBugz:$BaseUri"
}

function script:Get-SimSelectedCase { $script:SimEnvCase }

function script:Set-SimSelectedCase([string]$Id, [string]$Title) {
    $script:SimEnvCase = @{
        Id           = $Id
        Title        = $Title
        UpdatedAtUtc = [datetime]::UtcNow.ToString('o')
    }
    script:Append-Log "Set `$env:FOGBUGZ_SELECTED_CASE  case $Id - $Title"
}

function script:Clear-SimSelectedCase {
    $script:SimEnvCase = $null
    script:Append-Log "Cleared `$env:FOGBUGZ_SELECTED_CASE  (simulated new terminal)"
}

function script:Append-Log([string]$msg) {
    $script:SimLog.Add($msg)
    while ($script:SimLog.Count -gt 6) { $script:SimLog.RemoveAt(0) }
}

#endregion

#region --- TUI shell (throwaway) ---

function script:Render {
    Clear-Host
    $b = "`e[1m"; $d = "`e[2m"; $r = "`e[0m"
    $g = "`e[32m"; $red = "`e[31m"

    Write-Host ""
    Write-Host "  ${b}FogBugz Auth Storage Prototype${r}  ${d}throwaway — does this model feel right?${r}"
    Write-Host ""

    # .fogbugz file
    $cfg = script:Get-SimConfig
    Write-Host "  ${b}.fogbugz${r}  ${d}(working directory — committed or .gitignored per preference)${r}"
    if ($cfg) {
        Write-Host "    ${g}BaseUri${r}   $($cfg.BaseUri)"
    } else {
        Write-Host "    ${red}(file does not exist)${r}"
    }
    Write-Host ""

    # Windows Credential Manager
    Write-Host "  ${b}Windows Credential Manager${r}  ${d}(persists across terminal sessions)${r}"
    if ($cfg) {
        $cred = script:Get-SimCredential $cfg.BaseUri
        if ($cred) {
            $tok = $cred.Token
            $preview = if ($tok.Length -gt 8) { $tok.Substring(0,8) + '…' } else { $tok }
            Write-Host "    ${g}UserName${r}  $($cred.UserName)"
            Write-Host "    ${g}Token${r}     $preview  ${d}(key: FogBugz:$($cfg.BaseUri))${r}"
        } else {
            Write-Host "    ${red}(no credential stored for $($cfg.BaseUri))${r}"
        }
    } else {
        Write-Host "    ${d}(needs .fogbugz first)${r}"
    }
    Write-Host ""

    # Env var
    Write-Host "  ${b}`$env:FOGBUGZ_SELECTED_CASE${r}  ${d}(in-memory — lost when terminal closes)${r}"
    $sel = script:Get-SimSelectedCase
    if ($sel) {
        Write-Host "    ${g}Id${r}            $($sel.Id)"
        Write-Host "    ${g}Title${r}         $($sel.Title)"
        Write-Host "    ${d}UpdatedAtUtc   $($sel.UpdatedAtUtc)${r}"
    } else {
        Write-Host "    ${red}(not set)${r}"
    }
    Write-Host ""

    # Log
    Write-Host "  ${b}Recent actions${r}"
    if ($script:SimLog.Count -eq 0) {
        Write-Host "    ${d}(none yet)${r}"
    } else {
        foreach ($line in $script:SimLog) {
            Write-Host "    ${d}> $line${r}"
        }
    }
    Write-Host ""

    Write-Host "  ${d}─────────────────────────────────────────────────────────────────${r}"
    Write-Host "  ${b}[i]${r} init .fogbugz   ${b}[r]${r} remove .fogbugz   ${b}[l]${r} login   ${b}[x]${r} logout"
    Write-Host "  ${b}[p]${r} pick case        ${b}[c]${r} comment           ${b}[n]${r} new terminal session   ${b}[q]${r} quit"
    Write-Host ""
}

function script:Ask([string]$label) {
    Write-Host -NoNewline "  ${label}: "
    Read-Host
}

#endregion

#region --- Main loop ---

while ($true) {
    script:Render
    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character

    switch ($key) {
        'i' {
            $uri = script:Ask "BaseUri (e.g. https://myco.fogbugz.com)"
            if ($uri) { script:Set-SimConfig $uri }
        }
        'r' {
            script:Remove-SimConfig
            # Credential stays — removing .fogbugz shouldn't wipe credentials
        }
        'l' {
            $cfg = script:Get-SimConfig
            if (-not $cfg) { script:Append-Log "ERROR: run [i] to create .fogbugz first"; continue }
            $user = script:Ask "Email"
            $pass = script:Ask "Password"
            if ($user -and $pass) {
                # Simulates POST cmd=logon -> FogBugz returns a token
                $fakeToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${user}:${pass}"))
                script:Set-SimCredential $cfg.BaseUri $user $fakeToken
                script:Append-Log "Logged in as $user  (token simulated)"
            }
        }
        'x' {
            $cfg = script:Get-SimConfig
            if ($cfg) { script:Remove-SimCredential $cfg.BaseUri }
            else { script:Append-Log "ERROR: no .fogbugz — nothing to remove" }
        }
        'p' {
            $cfg = script:Get-SimConfig
            if (-not $cfg) { script:Append-Log "ERROR: run [i] to create .fogbugz first"; continue }
            $cred = script:Get-SimCredential $cfg.BaseUri
            if (-not $cred) { script:Append-Log "ERROR: not logged in — run [l] first"; continue }
            $id    = script:Ask "Case number"
            $title = script:Ask "Case title"
            if ($id -and $title) { script:Set-SimSelectedCase $id $title }
        }
        'c' {
            $cfg = script:Get-SimConfig
            if (-not $cfg) { script:Append-Log "ERROR: no .fogbugz"; continue }
            $cred = script:Get-SimCredential $cfg.BaseUri
            if (-not $cred) { script:Append-Log "ERROR: not logged in"; continue }
            $sel = script:Get-SimSelectedCase
            if (-not $sel) { script:Append-Log "ERROR: no selected case — run [p] or pass -CaseNumber"; continue }
            $text = script:Ask "Comment text"
            if ($text) {
                script:Append-Log "POST $($cfg.BaseUri)/api.asp?cmd=edit&ixBug=$($sel.Id)"
                script:Append-Log "     sEvent=$text  token=***"
                script:Append-Log "OK — comment posted (simulated)"
            }
        }
        'n' {
            # Simulates closing and reopening the terminal — clears env var only
            script:Clear-SimSelectedCase
        }
        'q' { return }
    }
}

#endregion
