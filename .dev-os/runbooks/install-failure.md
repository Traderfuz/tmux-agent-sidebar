# Runbook: DevOS Install Failure

| Field | Value |
|-------|-------|
| Service | DevOS Framework |
| Runbook type | Operational |
| Severity | P2 — install failure blocks DevOS from being usable in any project |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-08 |
| Automation status | Manual |
| Related runbooks | symlink-repair.md (P1 — covers post-install symlink issues) |

---

## 1. Overview

This runbook covers the five most common failure modes when running `scripts/install.sh`. The installer is a 2900+ line Bash script with `set -euo pipefail` — any unhandled error triggers a built-in rollback trap (lines 1120–1148) that either restores a timestamped backup or removes the partial install.

**What a healthy install produces:**

- `~/.dev-os` symlink pointing at the dev repo
- `~/.claude/commands/dev-os/*.md` — 100+ command symlinks
- `~/.dev-os/profiles/` — 10+ profile directories
- `scripts/lib/logger.sh` sourceable without error

**Failure scenarios covered:**

| ID | Symptom | Root cause |
|----|---------|------------|
| A | `ERROR: DevOS requires Bash 4.0 or later` | macOS ships Bash 3.2 |
| B | `Failed to clone repository` + rollback fires | Network / auth / wrong URL |
| C | Install reports success but `readlink ~/.dev-os` is empty | `~/.dev-os` was a full directory, not a symlink |
| D | `ls ~/.claude/commands/dev-os/*.md` returns 0 or <10 files | `create_global_commands()` failed or `~/.claude/commands/` missing |
| E | `~/.dev-os/profiles/` missing after run | Interrupted mid-run, partial install left behind |

---

## 2. Triage Checklist

Run these checks first to identify which scenario applies. Each check is one command; expected good output is noted inline.

```bash
# T1 — Is ~/.dev-os a symlink?
ls -la ~/.dev-os 2>/dev/null | head -1
# Good: "lrwxrwxrwx ... ~/.dev-os -> /path/to/dev-repo"
# Bad:  "drwxr-xr-x ..."  (directory) or "No such file"

# T2 — Does the symlink resolve to the real repo?
readlink -f ~/.dev-os 2>/dev/null
# Good: non-empty absolute path
# Bad:  empty output

# T3 — How many command symlinks exist?
ls ~/.claude/commands/dev-os/*.md 2>/dev/null | wc -l
# Good: >= 100
# Bad:  0 or small number

# T4 — Does the profiles directory exist with enough entries?
ls ~/.dev-os/profiles/ 2>/dev/null | wc -l
# Good: >= 10
# Bad:  0 or directory missing

# T5 — Is there a partial backup left over?
ls -d ~/.dev-os.backup.* 2>/dev/null
# Present: rollback created a backup — use it if needed

# T6 — What Bash version is active?
bash --version | head -1
# Good (Linux): "GNU bash, version 4.x or 5.x"
# Bad (macOS default): "GNU bash, version 3.2.x"

# T7 — Is logger sourceable?
bash -c 'source ~/.dev-os/scripts/lib/logger.sh && log_success test'
# Good: exits 0, prints success line
# Bad:  exits non-zero, or "No such file"

# T8 — Is nested commands structure present? (indicates stale install)
ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo PROBLEM || echo OK
# Good: OK
# Bad:  PROBLEM
```

After running T1–T8, match your outputs to a scenario below and jump to that section.

---

## 3. Failure Scenarios and Remediation

### Scenario A — Bash Version Guard Fails

**Error message:**
```
ERROR: DevOS requires Bash 4.0 or later (found 3.2.57)
```

**When it occurs:** Running `bash scripts/install.sh` on macOS where `/bin/bash` is Bash 3.2. The installer checks Bash version at lines 9–28 and attempts to re-exec with Homebrew Bash automatically (guarded by `DEVOS_BASH_REEXEC=1` to prevent infinite loops). If Homebrew Bash is not installed the re-exec path fails and the guard aborts.

**Remediation:**

1. Confirm the Bash version causing the failure.

   ```bash
   bash --version | head -1
   ```

   Expected output: `GNU bash, version 3.2.x(x)-release (x86_64-apple-darwin...)`

   If unexpected (already 4.0+): the Bash guard is not the cause — check Scenario E instead.

2. Install Homebrew Bash.

   ```bash
   brew install bash
   ```

   Expected output: `==> Installing bash` followed by `Summary 🍺` line ending in `bash x.x.x`.

   If unexpected (brew not found): install Homebrew first — `https://brew.sh` — then re-run this step.

3. Verify the new Bash is available.

   ```bash
   /opt/homebrew/bin/bash --version | head -1
   ```

   Expected output: `GNU bash, version 5.x.x(x)-release ...`

   If unexpected (file not found): check Apple Silicon vs Intel path — Intel Macs use `/usr/local/bin/bash`.

   ```bash
   which -a bash
   ```

4. Re-run the installer using the Homebrew Bash explicitly.

   ```bash
   /opt/homebrew/bin/bash scripts/install.sh
   ```

   Expected output: installer proceeds past the version check, prints `[INFO] Bash version check passed`.

   If unexpected (still fails on version): the `DEVOS_BASH_REEXEC` env var may be set from a prior attempt.

   ```bash
   unset DEVOS_BASH_REEXEC && /opt/homebrew/bin/bash scripts/install.sh
   ```

5. Validate install with the full validation suite in Section 4.

---

### Scenario B — Git Clone Fails

**Error message:**
```
Failed to clone repository
```

The installer then fires the rollback trap (lines 1120–1148), which either restores from a timestamped backup or removes the partial `~/.dev-os` directory.

**Common causes:**

- No network connectivity
- Invalid repository URL
- Missing SSH key or GitHub token
- GitHub rate limiting (unauthenticated clone)

**Remediation:**

1. Confirm network connectivity.

   ```bash
   curl -s --max-time 5 https://github.com 2>&1 | head -1
   ```

   Expected output: HTTP response line or `<!DOCTYPE html>`.

   If unexpected (connection timeout / refused): resolve network issue before continuing.

2. Test git authentication against GitHub.

   ```bash
   ssh -T git@github.com 2>&1
   ```

   Expected output: `Hi <username>! You've successfully authenticated...`

   If unexpected (`Permission denied (publickey)`): add your SSH key to GitHub or switch to HTTPS.

   ```bash
   # Generate a new SSH key if needed
   ssh-keygen -t ed25519 -C "<your-email>"
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   # Then add the public key to GitHub: https://github.com/settings/keys
   ```

3. Verify any existing backup from the failed attempt.

   ```bash
   ls -d ~/.dev-os.backup.* 2>/dev/null
   ```

   Expected output: one or more backup directories (e.g., `~/.dev-os.backup.20260408-143022`).

   If unexpected (none): no backup — clean slate, proceed to step 4.

4. If the repo already exists locally (e.g., cloned to `<REPO_PATH>`), use `--link` mode to skip cloning.

   ```bash
   bash scripts/install.sh --link <REPO_PATH>
   ```

   Expected output: installer uses the local repo instead of cloning, proceeds to symlink creation.

   If unexpected (unknown flag): your install version may not support `--link`; proceed with a standard re-run instead.

5. Otherwise, retry a standard install after confirming git auth is working.

   ```bash
   bash scripts/install.sh
   ```

   Expected output: `[INFO] Cloning repository...` followed by `[SUCCESS] Repository cloned`.

   If unexpected (clone fails again): check the repository URL in `scripts/install.sh` line ~50 and verify your git credentials have access.

6. Validate with Section 4.

---

### Scenario C — `~/.dev-os` Exists as a Full Directory (Not Symlink)

**Symptom:** Install reports success but `readlink ~/.dev-os` returns empty and editing files in `~/.dev-os/` does not reflect in the git repo.

**Diagnosis:**

```bash
ls -la ~ | grep dev-os
```

Expected good output: `lrwxrwxrwx 1 ... .dev-os -> /home/<user>/projects/os/dev-os`

Bad output: `drwxr-xr-x 10 ... .dev-os` — this is a plain directory.

**Remediation:**

1. Back up the existing directory manually before overwriting.

   ```bash
   /usr/bin/mv ~/.dev-os ~/.dev-os.backup.manual
   ```

   Expected output: no output (silent success).

   If unexpected (permission denied): run with sudo or check ownership.

2. Re-run the installer. It will detect `~/.dev-os` is absent (or a prior backup) and create the correct symlink.

   ```bash
   bash scripts/install.sh
   ```

   Expected output: `[INFO] Creating symlink ~/.dev-os -> <repo-path>` followed by `[SUCCESS] Symlink created`.

   If unexpected (install says `~/.dev-os already exists`): the manual backup step above may not have run. Verify `~/.dev-os` is gone.

   ```bash
   ls -la ~/.dev-os 2>/dev/null && echo EXISTS || echo GONE
   ```

3. Confirm the symlink is correct.

   ```bash
   readlink -f ~/.dev-os
   ```

   Expected output: absolute path to the dev repo (non-empty).

4. Validate with Section 4.

---

### Scenario D — Command Symlinks Missing After Install

**Symptom:**

```bash
ls ~/.claude/commands/dev-os/*.md 2>/dev/null | wc -l
# Returns 0 or fewer than 10
```

`create_global_commands()` runs at line 2212 of `scripts/install.sh`. It creates symlinks in `~/.claude/commands/dev-os/`. Failure modes: the directory `~/.claude/commands/` does not exist before install, or the function failed silently because `set -e` was suppressed in that subshell.

**Remediation:**

1. Check whether the target directory exists.

   ```bash
   ls -la ~/.claude/commands/ 2>/dev/null | head -5
   ```

   Expected output: a directory listing showing `dev-os/` as an entry.

   If unexpected (No such file or directory): the commands directory was never created — create it and re-run.

   ```bash
   mkdir -p ~/.claude/commands
   ```

2. Check for a nested structure issue (stale install artefact).

   ```bash
   ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo PROBLEM || echo OK
   ```

   Expected output: `OK`.

   If unexpected (`PROBLEM`): remove the stale nested directory.

   ```bash
   /usr/bin/rm -rf ~/.claude/commands/dev-os/dev-os
   ```

3. Re-run the installer to repopulate command symlinks.

   ```bash
   bash scripts/install.sh
   ```

   Expected output: `[INFO] Creating global command symlinks` followed by success messages.

4. Count symlinks post-install.

   ```bash
   ls ~/.claude/commands/dev-os/*.md | wc -l
   ```

   Expected output: `>= 100`.

   If unexpected (still low): check the profiles directory the symlinks are sourced from.

   ```bash
   ls ~/.dev-os/profiles/general/commands/ | wc -l
   ```

   Expected output: `>= 100` `.md` files. If not, the profiles themselves may be missing — see Scenario E.

5. Validate with Section 4.

---

### Scenario E — Partial Install (Interrupted Mid-Run)

**Symptom:** `~/.dev-os/profiles/` is missing or has fewer than 10 entries, indicating the installer was killed or crashed mid-execution before completing the profile extraction step.

**Diagnosis:**

```bash
ls ~/.dev-os/profiles/ 2>/dev/null | wc -l
```

Expected bad output: `0` or "No such file or directory".

**Remediation:**

**Option 1 — Restore from backup (preferred if backup exists):**

1. List available backups.

   ```bash
   ls -lt ~/.dev-os.backup.* 2>/dev/null
   ```

   Expected output: one or more timestamped directories. Use the most recent.

   If unexpected (none): no backup available — proceed to Option 2.

2. Remove the partial install.

   ```bash
   /usr/bin/rm -rf ~/.dev-os
   ```

   Expected output: silent success.

3. Restore the backup.

   ```bash
   /usr/bin/mv ~/.dev-os.backup.<TIMESTAMP> ~/.dev-os
   ```

   Replace `<TIMESTAMP>` with the actual timestamp from step 1 (e.g., `20260408-143022`).

   Expected output: silent success.

4. Verify the restore.

   ```bash
   ls ~/.dev-os/profiles/ | wc -l
   ```

   Expected output: `>= 10`.

**Option 2 — Clean reinstall:**

1. Remove the partial install.

   ```bash
   /usr/bin/rm -rf ~/.dev-os
   ```

   Expected output: silent success.

2. Remove any stale command symlinks.

   ```bash
   /usr/bin/rm -rf ~/.claude/commands/dev-os
   ```

   Expected output: silent success.

3. Re-run the installer from the source repo.

   ```bash
   cd <REPO_PATH> && bash scripts/install.sh
   ```

   Replace `<REPO_PATH>` with the absolute path to the dev-os git repository.

   Expected output: full install output ending with `[SUCCESS] DevOS installation complete`.

   If unexpected (installer fails immediately): check for leftover lock files.

   ```bash
   ls /tmp/devos-install-* 2>/dev/null
   /usr/bin/rm -f /tmp/devos-install-*
   bash scripts/install.sh
   ```

4. Validate with Section 4.

---

## 4. Validation — Measurable Pass/Fail Criteria

Run all five checks. Every check must pass before the install is considered healthy.

**V1 — Symlink resolves to the real repo:**

```bash
readlink -f ~/.dev-os
```

Pass: non-empty absolute path (e.g., `/home/<user>/projects/os/dev-os`).

Fail: empty output → symlink broken or missing. Re-run install or see symlink-repair.md.

---

**V2 — Command symlinks are populated:**

```bash
ls ~/.claude/commands/dev-os/*.md | wc -l
```

Pass: `>= 100`.

Fail: `< 100` → `create_global_commands()` incomplete. See Scenario D.

---

**V3 — Profiles directory is populated:**

```bash
ls ~/.dev-os/profiles/ | wc -l
```

Pass: `>= 10`.

Fail: `< 10` → partial install. See Scenario E.

---

**V4 — No nested commands structure:**

```bash
ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo PROBLEM || echo OK
```

Pass: `OK`.

Fail: `PROBLEM` → stale nested directory. Remove it: `/usr/bin/rm -rf ~/.claude/commands/dev-os/dev-os`.

---

**V5 — Logger is sourceable:**

```bash
bash -c 'source ~/.dev-os/scripts/lib/logger.sh && log_success "validation-v5"'
```

Pass: exits 0 and prints a green success line.

Fail: exits non-zero or "No such file" → core library missing or symlink broken.

---

All five checks pass → install is healthy. Proceed to any `start` workflow.

---

## 5. Rollback Procedure

The installer has a built-in rollback trap (lines 1120–1148 of `scripts/install.sh`). When `set -e` triggers on a failing command, the trap:

1. Checks for a timestamped backup at `$INSTALL_DIR.backup.YYYYMMDD-HHMMSS`.
2. If a backup exists: restores it by moving it back to `~/.dev-os`.
3. If no backup exists: removes the partial `~/.dev-os` directory.

**Manual rollback steps (if automatic rollback did not fire):**

1. List backups.

   ```bash
   ls -lt ~/.dev-os.backup.* 2>/dev/null
   ```

2. Remove the broken install.

   ```bash
   /usr/bin/rm -rf ~/.dev-os
   /usr/bin/rm -rf ~/.claude/commands/dev-os
   ```

3. If a good backup exists, restore it.

   ```bash
   /usr/bin/mv ~/.dev-os.backup.<TIMESTAMP> ~/.dev-os
   ```

4. If no backup exists, a fresh install is required. Confirm the source repo is intact before proceeding.

   ```bash
   ls <REPO_PATH>/scripts/install.sh
   ```

   Expected output: file path printed without error. Then run `bash <REPO_PATH>/scripts/install.sh`.

5. Revalidate with Section 4.

---

## 6. Escalation

Escalate when:

- All five validation checks fail after three reinstall attempts
- Rollback fired but left an unrestorable state (backup was also corrupted)
- The installer itself exits non-zero on a clean machine with Bash 4.0+
- Symlink creation fails due to OS-level restrictions (SELinux, AppArmor, restricted home directory)

**Escalation path:**

1. Capture the full install log.

   ```bash
   bash scripts/install.sh 2>&1 | tee /tmp/devos-install-$(date +%Y%m%d-%H%M%S).log
   ```

2. Run the triage checklist from Section 2 and record all outputs.

3. Open a GitHub issue in the dev-os repository with:
   - OS and Bash version (`uname -a && bash --version`)
   - Full install log
   - Triage checklist outputs
   - Any error message verbatim

4. Tag `@Traderfuz` for P2 response.

---

## 7. Prevention

- **Always use Bash 4.0+.** On macOS, add `/opt/homebrew/bin/bash` before `/bin/bash` in your `PATH`.
- **Keep a known-good backup.** Run `cp -r ~/.dev-os ~/.dev-os.backup.known-good` after a verified healthy install.
- **Do not interrupt installs.** If you must stop mid-run, `Ctrl-C` should trigger the trap; confirm with `ls ~/.dev-os` afterwards.
- **Ensure `~/.claude/commands/` exists before install.** Claude Code creates this directory on first launch — run Claude Code once before running the DevOS installer on a fresh machine.
- **Test with `--dry-run` first.** `bash scripts/install.sh --dry-run` previews all changes without writing anything.

---

## 8. Quick Reference Card

```
SCENARIO  SIGNAL                                    FIX
--------  ----------------------------------------  -----------------------------------
A         "requires Bash 4.0 or later"             brew install bash; use homebrew bash
B         "Failed to clone repository"             check git auth; retry; use --link
C         readlink ~/.dev-os → empty               mv ~/.dev-os ~/.dev-os.backup.manual
                                                   && bash scripts/install.sh
D         command count < 100                      mkdir -p ~/.claude/commands
                                                   && bash scripts/install.sh
E         profiles dir missing or < 10 entries     rm -rf ~/.dev-os
                                                   && bash scripts/install.sh

VALIDATION (all 5 must pass):
  readlink -f ~/.dev-os                                         → non-empty path
  ls ~/.claude/commands/dev-os/*.md | wc -l                    → >= 100
  ls ~/.dev-os/profiles/ | wc -l                               → >= 10
  ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && ... || echo OK  → OK
  bash -c 'source ~/.dev-os/scripts/lib/logger.sh && log_success test' → exit 0
```

---

## 9. Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-04-08 | @Traderfuz | Initial version — 5 scenarios, measurable validation thresholds |

---

## 10. References

| Resource | Path / URL |
|----------|------------|
| Install script | `scripts/install.sh` |
| Rollback logic | `scripts/install.sh` lines 1120–1148 |
| Bash version guard | `scripts/install.sh` lines 9–28 |
| Command symlink creation | `scripts/install.sh` line 2212 (`create_global_commands`) |
| Symlink repair runbook (P1) | `profiles/general/runbooks/symlink-repair.md` |
| DevOS architecture docs | `docs/ARCHITECTURE.md` |
| Migrate-to-symlink script | `scripts/migrate-to-symlink.sh` |
