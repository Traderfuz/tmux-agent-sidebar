# Runbook: DevOS Discipline Hook Failure

| Field | Value |
|-------|-------|
| Service | DevOS Discipline Hooks |
| Runbook type | Operational / Diagnostic |
| Severity | P2 — hooks not firing means systematic-debugging and verification gates are silently bypassed |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-08 |
| Automation status | Partial — repair-hooks automates legacy git hook repair |
| Related runbooks | install-failure.md (P2 — covers full install regression) |

---

## 1. Overview

DevOS discipline hooks operate in two scopes. Understanding which scope a hook belongs to
is critical for correct diagnosis.

**Scope 2 — Global hooks** are registered in `~/.claude/settings.json` and fire in every
Claude Code session. They are installed by `scripts/install.sh`. Examples: `learnings-processor.sh`,
`bundle-injection.sh`, `session-recorder-hook.sh`.

**Scope 3 — Project discipline hooks** are registered in `$project/.claude/settings.json`
(project-relative) and fire only in that project. They are installed by `start`
(via `_install_project_hooks`). These are the two hooks this runbook primarily covers.

**Hook inventory (Scope 3 — project discipline):**

| Hook file | Event | Trigger condition | Behavior |
|-----------|-------|-------------------|----------|
| `.claude/hooks/systematic-debugging-gate.sh` | `PreToolUse` (Bash / Edit / Write) | Fix-intent keywords AND error-context keywords both present in tool input | Injects Phase 1 diagnostic checklist; exits 0 (non-blocking) |
| `.claude/hooks/verification-gate.sh` | `Stop` | Completion-signal keywords detected in last assistant turn | Injects verification gate block; exits 0 (non-blocking) |

Source files live in `profiles/general/hooks/` and are installed to `$project/.claude/hooks/` by
`_install_project_hooks()` in `scripts/lib/command-router.sh`, called during `start`.
Registration is written to `$project/.claude/settings.json` (project-relative) under
`hooks.PreToolUse` and `hooks.Stop`.

**What a healthy hook setup looks like:**

- `$project/.claude/settings.json` has a `hooks` object with `PreToolUse` and `Stop` entries
- `$project/.claude/hooks/systematic-debugging-gate.sh` and `verification-gate.sh` exist and are executable
- Both hooks exit 0 when invoked with sample JSON input
- No legacy `flowstate` or `adhd` commands appear in `.git/hooks/post-commit`

**Repair paths:**

- **Discipline hooks broken?** Re-run `start` (idempotent — reinstalls hooks from profile chain)
- **Or run:** `repair-hooks --claude-hooks` (targeted repair without full re-init)
- **Legacy git hooks?** Run `repair-hooks` (repairs `.git/hooks/post-commit`)

**Failure scenarios covered:**

| ID | Symptom | Root cause |
|----|---------|------------|
| A | systematic-debugging-gate never fires, even on "fix the bug" prompts | Project `settings.json` has no `hooks` entry |
| B | `git commit` triggers `flowstate: command not found` or `adhd: command not found` | Legacy git hook still references retired CLI names |
| C | Hook fires but exits with `Permission denied` | Hook script missing execute bit |
| D | Claude Code shows "hook failed" or blocks a tool call | Hook script exits non-zero |

---

## 2. Triage Checklist

Run all eight checks first to identify which scenario applies. Each check is one command;
expected output is noted inline. Match your results to a scenario in Section 3.

> **Important:** Discipline hooks are registered in the **project** `.claude/settings.json`,
> not the global `~/.claude/settings.json`. Run these checks from the project root.

```bash
# T1 — Is the hooks block present in the PROJECT settings.json?
cat .claude/settings.json | python3 -m json.tool | grep -c '"hooks"'
# Good: >= 1
# Bad:  0  → Scenario A (hooks not registered)

# T2 — Are the hook files present in the project?
ls .claude/hooks/*.sh 2>/dev/null | wc -l
# Good: >= 2
# Bad:  0 or 1  → re-run start to reinstall hook files

# T3 — Are the hook files executable?
ls -la .claude/hooks/*.sh 2>/dev/null | awk '{print $1, $NF}'
# Good: "-rwxr-xr-x ... .../systematic-debugging-gate.sh" (x bits set)
# Bad:  "-rw-r--r-- ..."  → Scenario C (missing execute bit)

# T4 — Does systematic-debugging-gate exit 0?
echo '{"tool_name":"Bash","tool_input":{"command":"fix the error"}}' \
  | bash .claude/hooks/systematic-debugging-gate.sh; echo "exit: $?"
# Good: "exit: 0"
# Bad:  non-zero exit code  → Scenario D (script exits non-zero)

# T5 — Does verification-gate exit 0?
echo '{"transcript_path":"/dev/null"}' \
  | bash .claude/hooks/verification-gate.sh; echo "exit: $?"
# Good: "exit: 0"
# Bad:  non-zero exit code  → Scenario D

# T6 — Does the PreToolUse registration exist in PROJECT settings.json?
cat .claude/settings.json | python3 -m json.tool | grep -A5 '"PreToolUse"'
# Good: shows matcher "Bash|Edit|Write" and command entry
# Bad:  empty or missing  → Scenario A

# T7 — Does the Stop registration exist in PROJECT settings.json?
cat .claude/settings.json | python3 -m json.tool | grep -A5 '"Stop"'
# Good: shows hooks entry with verification-gate.sh command
# Bad:  empty or missing  → Scenario A

# T8 — Does post-commit reference legacy CLI names?
cat .git/hooks/post-commit 2>/dev/null | grep -c "flowstate\|adhd"
# Good: 0
# Bad:  >= 1  → Scenario B (legacy git hook)
```

After running T1–T8, match your outputs to a scenario below and jump to that section.

---

## 3. Failure Scenarios and Remediation

### Scenario A — Hooks Not Registered in settings.json

**Symptom:** The systematic-debugging-gate never fires during coding sessions, even when
typing "fix the bug" or "resolve this error". T1, T6, and T7 above return empty or 0.

**Root cause:** `start` did not complete the hook registration step, or the
project `.claude/settings.json` was overwritten without preserving the `hooks` block.

**Remediation:**

1. Confirm the hooks block is absent in the **project** settings.

   ```bash
   cat .claude/settings.json | python3 -m json.tool | grep -c '"hooks"'
   ```

   Expected output: `0`

   If unexpected (output is `>= 1`): the hooks block exists — check Scenario C or D
   instead.

2. Re-run `start` to restore project discipline hooks (or use `repair-hooks --claude-hooks`).

   ```
   start
   ```

   Expected output: `Project hooks installed: 2 file(s) → .claude/hooks` and
   `Project settings.json: 2 hook registration(s) added`.

   If unexpected (start fails): see `install-failure.md` for install regression
   diagnosis.

3. Verify the PreToolUse entry was written to the **project** settings.

   ```bash
   cat .claude/settings.json | python3 -m json.tool | grep -A8 '"PreToolUse"'
   ```

   Expected output:
   ```json
   "PreToolUse": [
     {
       "matcher": "Bash|Edit|Write",
       "hooks": [{"type": "command", "command": "bash .claude/hooks/systematic-debugging-gate.sh"}]
     }
   ]
   ```

   If unexpected (still missing): add the hooks block manually — see step 4.

4. Manual fallback: add the hooks block to the **project** `.claude/settings.json` directly.

   Open `.claude/settings.json` (in the project root, NOT `~/.claude/settings.json`) and
   merge in the following structure (preserve any existing keys):

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash|Edit|Write",
           "hooks": [{"type": "command", "command": "bash .claude/hooks/systematic-debugging-gate.sh"}]
         }
       ],
       "Stop": [
         {
           "hooks": [{"type": "command", "command": "bash .claude/hooks/verification-gate.sh"}]
         }
       ]
     }
   }
   ```

   Expected output: `python3 -m json.tool .claude/settings.json` exits 0 (valid JSON).

   If unexpected (JSON parse error): use a JSON validator to locate the syntax error before
   saving.

5. Validate with Section 4.

---

### Scenario B — Legacy Git Hook References Retired CLI

**Symptom:** Running `git commit` in the project prints:
```
flowstate: command not found
```
or:
```
adhd: command not found
```

The commit may still succeed (exit 0) but the error is printed to stderr on every commit.
This indicates a stale post-commit hook left over from before the `flowstate` → `fst`
migration.

**Remediation:**

1. Inspect the post-commit hook.

   ```bash
   cat .git/hooks/post-commit
   ```

   Expected bad output: a line containing `flowstate git record-commit` or `adhd git`.

   If unexpected (file is absent or correct): this is not Scenario B — check if the error
   comes from a different hook (pre-commit, post-merge).

2. Run the automated repair command.

   ```bash
   # From inside the project directory
   repair-hooks
   ```

   Expected output: `[SUCCESS] Replaced legacy flowstate hook with canonical fst sync --repo
   template.`

   If unexpected (`repair-hooks` is not available): your command symlinks may be
   missing — run `bash scripts/install.sh` first, then retry.

3. Verify the legacy reference is gone.

   ```bash
   cat .git/hooks/post-commit 2>/dev/null | grep -c "flowstate\|adhd"
   ```

   Expected output: `0`

   If unexpected (still `>= 1`): the repair did not fully overwrite the file — manually
   replace it.

   ```bash
   cat > .git/hooks/post-commit << 'EOF'
   #!/usr/bin/env bash
   fst sync --repo 2>/dev/null || true
   EOF
   chmod +x .git/hooks/post-commit
   ```

4. Confirm the new hook is executable.

   ```bash
   ls -la .git/hooks/post-commit
   ```

   Expected output: `-rwxr-xr-x` (execute bit set).

5. Test a commit to confirm the error is gone.

   ```bash
   git commit --allow-empty -m "chore: test hook repair"
   ```

   Expected output: commit created with no `flowstate` or `adhd` error on stderr.

   If unexpected (fst itself not found): `fst` is the Flowstate CLI — ensure it is
   installed and on `PATH`.

   ```bash
   which fst
   ```

6. Validate with Section 4.

---

### Scenario C — Hook Script Not Executable

**Symptom:** The hook fires (Claude Code attempts to run it) but outputs:
```
bash: .claude/hooks/systematic-debugging-gate.sh: Permission denied
```

T3 above shows `-rw-r--r--` (no `x` bits).

**Root cause:** The hook files were copied or restored without the execute permission bit.
This can happen after a `cp` without `-p`, a git checkout that lost permissions, or a file
transfer that stripped execute bits.

**Remediation:**

1. Confirm the missing execute bit.

   ```bash
   ls -la .claude/hooks/
   ```

   Expected bad output: lines starting with `-rw-` rather than `-rwx-`.

   If unexpected (execute bit is already set): this is not Scenario C — check Scenario D.

2. Restore execute permissions on all hook scripts.

   ```bash
   chmod +x .claude/hooks/*.sh
   ```

   Expected output: silent success.

   If unexpected (No such file or directory): the hook files themselves are missing — run
   `bash scripts/install.sh` to reinstall, then repeat this step.

3. Verify the execute bit is set.

   ```bash
   ls -la .claude/hooks/*.sh | awk '{print $1, $NF}'
   ```

   Expected output: lines starting with `-rwxr-xr-x` for each `.sh` file.

4. Test both hooks manually.

   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"fix the error"}}' \
     | bash .claude/hooks/systematic-debugging-gate.sh; echo "exit: $?"

   echo '{"transcript_path":"/dev/null"}' \
     | bash .claude/hooks/verification-gate.sh; echo "exit: $?"
   ```

   Expected output: each prints its gate block and ends with `exit: 0`.

5. Validate with Section 4.

---

### Scenario D — Hook Script Exits Non-Zero

**Symptom:** Claude Code shows a "hook failed" notice or the tool call is blocked. T4 or T5
above returns a non-zero exit code.

**Root cause:** The hook script itself contains a syntax error, sources a missing file, or
has a logic path that exits non-zero without being caught. Both hooks are designed to trap
all errors and exit 0 — a non-zero exit means the trap is missing or broken.

**Remediation:**

1. Identify which hook is failing.

   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"fix the error"}}' \
     | bash .claude/hooks/systematic-debugging-gate.sh; echo "sysdbg exit: $?"

   echo '{"transcript_path":"/dev/null"}' \
     | bash .claude/hooks/verification-gate.sh; echo "verify exit: $?"
   ```

   Expected output: both lines end with `exit: 0`.

   If unexpected: note which hook is non-zero — that is the target for steps 2–4.

2. Check the hook for syntax errors.

   ```bash
   bash -n .claude/hooks/systematic-debugging-gate.sh && echo "syntax OK" || echo "SYNTAX ERROR"
   bash -n .claude/hooks/verification-gate.sh && echo "syntax OK" || echo "SYNTAX ERROR"
   ```

   Expected output: `syntax OK` for both.

   If unexpected (`SYNTAX ERROR`): the hook file is corrupt — reinstall from the profile
   source.

3. Compare the installed hook against the profile source.

   ```bash
   diff .claude/hooks/systematic-debugging-gate.sh \
        /home/tafadzwa/projects/os/dev-os/profiles/general/hooks/systematic-debugging-gate.sh

   diff .claude/hooks/verification-gate.sh \
        /home/tafadzwa/projects/os/dev-os/profiles/general/hooks/verification-gate.sh
   ```

   Expected output: no output (files are identical).

   If unexpected (diff shows differences): the installed copy has drifted from the source.
   Reinstall.

   ```bash
   /usr/bin/cp \
     /home/tafadzwa/projects/os/dev-os/profiles/general/hooks/systematic-debugging-gate.sh \
     .claude/hooks/systematic-debugging-gate.sh

   /usr/bin/cp \
     /home/tafadzwa/projects/os/dev-os/profiles/general/hooks/verification-gate.sh \
     .claude/hooks/verification-gate.sh

   chmod +x .claude/hooks/*.sh
   ```

4. Verify the hook traps errors and exits 0 even with unexpected input.

   ```bash
   echo '{}' | bash .claude/hooks/systematic-debugging-gate.sh; echo "exit: $?"
   echo '{}' | bash .claude/hooks/verification-gate.sh; echo "exit: $?"
   ```

   Expected output: `exit: 0` for both (hooks are non-blocking by contract).

   If unexpected (still non-zero): escalate — the hook source in
   `profiles/general/hooks/` itself may be broken and needs a code fix.

5. Validate with Section 4.

---

## 4. Validation — Measurable Pass/Fail Criteria

Run all five checks. Every check must pass before the hook setup is considered healthy.

**V1 — Hooks block registered in project settings.json:**

```bash
cat .claude/settings.json | python3 -m json.tool | grep -c '"hooks"'
```

Pass: `>= 1`

Fail: `0` → hooks block absent. See Scenario A.

---

**V2 — Hook files present in project:**

```bash
ls .claude/hooks/*.sh 2>/dev/null | wc -l
```

Pass: `>= 2`

Fail: `< 2` → hook files missing. Re-run `start` or `repair-hooks --claude-hooks`.

---

**V3 — systematic-debugging-gate exits 0:**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"fix the error"}}' \
  | bash .claude/hooks/systematic-debugging-gate.sh; echo $?
```

Pass: last line is `0`

Fail: non-zero → See Scenario C (permissions) or Scenario D (script error).

---

**V4 — verification-gate exits 0:**

```bash
echo '{"transcript_path":"/dev/null"}' \
  | bash .claude/hooks/verification-gate.sh; echo $?
```

Pass: last line is `0`

Fail: non-zero → See Scenario C or Scenario D.

---

**V5 — No legacy CLI references in post-commit:**

```bash
cat .git/hooks/post-commit 2>/dev/null | grep -c "flowstate\|adhd"
```

Pass: `0`

Fail: `>= 1` → legacy git hook present. See Scenario B.

---

All five checks pass → discipline hooks are healthy. Both gates will fire automatically in
future coding sessions without any manual invocation.

---

## 5. Rollback Procedure

Hooks are non-destructive — they inject context and exit 0. There is no data-loss risk from
hook failures. However, if a hook change introduced a regression, use these steps to restore
the last known-good state.

1. Identify the last known-good hook version in git.

   ```bash
   git log --oneline profiles/general/hooks/ | head -5
   ```

   Expected output: list of recent commits touching hook source files.

2. Restore the hook source files from a known-good commit.

   ```bash
   git show <COMMIT_SHA>:profiles/general/hooks/systematic-debugging-gate.sh \
     > .claude/hooks/systematic-debugging-gate.sh

   git show <COMMIT_SHA>:profiles/general/hooks/verification-gate.sh \
     > .claude/hooks/verification-gate.sh

   chmod +x .claude/hooks/*.sh
   ```

   Replace `<COMMIT_SHA>` with the commit hash from step 1.

   Expected output: silent success.

3. Run the V3 and V4 checks from Section 4 to confirm the rollback is working.

4. If `~/.claude/settings.json` was the source of the regression (e.g., hooks block was
   overwritten), restore the registration manually using the canonical format from Scenario A
   step 4.

5. Revalidate all five checks from Section 4.

---

## 6. Escalation

Escalate when:

- All five validation checks still fail after following all relevant scenarios
- Both hook scripts pass syntax check (`bash -n`) but still exit non-zero on any input
- `repair-hooks` fails to remove legacy references after three attempts
- `~/.claude/settings.json` cannot be written (permission denied at the user level)
- Hook fires but injects no output despite the trigger condition being met

**Escalation steps:**

1. Capture a diagnostic bundle.

   ```bash
   {
     echo "=== settings.json hooks block ==="
     cat ~/.claude/settings.json | python3 -m json.tool | grep -A20 '"hooks"'
     echo "=== hook file listing ==="
     ls -la .claude/hooks/
     echo "=== systematic-debugging-gate test ==="
     echo '{"tool_name":"Bash","tool_input":{"command":"fix the error"}}' \
       | bash .claude/hooks/systematic-debugging-gate.sh 2>&1; echo "exit: $?"
     echo "=== verification-gate test ==="
     echo '{"transcript_path":"/dev/null"}' \
       | bash .claude/hooks/verification-gate.sh 2>&1; echo "exit: $?"
     echo "=== post-commit hook ==="
     cat .git/hooks/post-commit 2>/dev/null || echo "(absent)"
   } 2>&1 | tee /tmp/devos-hook-diag-$(date +%Y%m%d-%H%M%S).log
   ```

2. Run the full triage checklist from Section 2 and record all outputs.

3. Open a GitHub issue in the dev-os repository with:
   - OS and shell version (`uname -a && bash --version`)
   - Full diagnostic bundle from step 1
   - Which scenario was attempted and what happened
   - Verbatim error message from Claude Code

4. Tag `@Traderfuz` for P2 response.

---

## 7. Prevention

- **Re-run `start` after resetting the project `.claude/settings.json`.** Any
  tool that rewrites the project settings.json will clobber the hooks block unless it merges
  carefully. `start` is idempotent and restores hook registrations.
- **Re-run `scripts/install.sh` after resetting the global `~/.claude/settings.json`.** This
  restores Scope 2 (DevOS global) hooks. Project discipline hooks are separate — see above.
- **Do not copy hook files without preserving permissions.** Use `cp -p` or restore execute
  bits with `chmod +x` immediately after copying.
- **Run `repair-hooks` after migrating from a legacy project.** Repairs both legacy
  git post-commit hooks and broken Claude Code discipline hooks.
- **Check T1 and T2 at the start of each new project setup.** The triage checklist takes
  under 30 seconds and catches missing registrations before they silently bypass the gates.
- **Keep hook source files in `profiles/general/hooks/` authoritative.** Never edit the
  installed copies in `.claude/hooks/` directly — edit the source and let `start`
  propagate the change.

---

## 8. Quick Reference Card

```
SCENARIO  SIGNAL                                      FIX
--------  ------------------------------------------  ---------------------------------
A         hooks block absent in project settings.json start (reinstalls hooks)
          (grep -c '"hooks"' → 0)                     OR repair-hooks --claude-hooks

B         git commit → "flowstate: command not found" repair-hooks
          (post-commit grep -c "flowstate|adhd" >= 1) OR manually replace post-commit

C         hook fires → Permission denied              chmod +x .claude/hooks/*.sh
          (ls -la shows -rw-r--r--)                   OR repair-hooks --claude-hooks

D         hook exits non-zero                         bash -n hook.sh (syntax check)
          (echo '{}' | bash hook.sh; echo $? → != 0)  diff vs profiles/general/hooks/
                                                       cp + chmod if drifted

VALIDATION (all 5 must pass — run from project root):
  cat .claude/settings.json | python3 -m json.tool | grep -c '"hooks"'           → >= 1
  ls .claude/hooks/*.sh 2>/dev/null | wc -l                                      → >= 2
  echo '{"tool_name":"Bash","tool_input":{"command":"fix the error"}}' \
    | bash .claude/hooks/systematic-debugging-gate.sh; echo $?                   → 0
  echo '{"transcript_path":"/dev/null"}' \
    | bash .claude/hooks/verification-gate.sh; echo $?                           → 0
  cat .git/hooks/post-commit 2>/dev/null | grep -c "flowstate\|adhd"             → 0
```

---

## 9. Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-04-08 | @Traderfuz | Initial version — 4 scenarios, 5 measurable validation checks |

---

## 10. References

| Resource | Path |
|----------|------|
| systematic-debugging-gate hook source | `profiles/general/hooks/systematic-debugging-gate.sh` |
| verification-gate hook source | `profiles/general/hooks/verification-gate.sh` |
| Installed hook files (project-level) | `.claude/hooks/` |
| Hook registration format | `~/.claude/settings.json` → `hooks.PreToolUse`, `hooks.Stop` |
| Repair hooks command | `repair-hooks` |
| Install script (re-registers hooks) | `scripts/install.sh` |
| Install failure runbook (P2) | `profiles/general/runbooks/install-failure.md` |
| Systematic debugging skill | `.claude/skills/systematic-debugging/SKILL.md` |
| Verification before completion skill | `.claude/skills/verify/SKILL.md` |
