# Runbook: DevOS Symlink Repair

| Field | Value |
|-------|-------|
| Service | DevOS global install — `~/.dev-os` symlink + command symlinks |
| Runbook type | Operational |
| Severity | P1 |
| Owner team | DevOS operator |
| Last reviewed | 2026-03-29 |
| Automation status | Semi-automated (`scripts/migrate-to-symlink.sh`) |

---

## 1. Trigger & Detection

**Trigger:** DevOS commands are invisible to Claude Code, `*` commands are not found, or `~/.dev-os` no longer points to the correct dev repo.

**Symptoms:**
- `start`, `project-status`, or any `*` command returns "Command not found"
- `ls ~/.claude/commands/dev-os/` shows 0 or very few files
- `ls ~/.dev-os/` fails or shows the wrong directory
- `readlink ~/.dev-os` returns a path that no longer exists

**Root causes:**
- The dev repo was moved (e.g. `~/projects/b-labs/dev-os` → `~/projects/os/dev-os`) without re-running `migrate-to-symlink.sh`
- `~/.dev-os` was accidentally deleted with `rm -rf` instead of `rm` (removed the symlink AND the repo)
- `~/.claude/commands/dev-os/` symlink directory was corrupted, creating a nested `dev-os/dev-os/` structure

---

## 2. Impact Assessment

**P1 — immediate action required:**
- All `*` commands invisible: no spec writing, no task creation, no pipeline execution
- Affects all projects on this machine

---

## 3. Diagnosis

```bash
# Check symlink state
ls -la ~/.dev-os
readlink ~/.dev-os

# Expected output:
# ~/.dev-os -> /home/tafadzwa/projects/os/dev-os

# Check command symlinks
ls ~/.claude/commands/dev-os/ | wc -l
# Expected: ~100+ .md files

# Check for nested dev-os/dev-os/ structure (known bug)
ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo "NESTED STRUCTURE DETECTED"
```

---

## 4. Recovery Steps

### Scenario A: Symlink points to wrong/missing path

```bash
# 1. Remove stale symlink (NOT rm -rf — just rm)
rm ~/.dev-os

# 2. Re-create symlink to the correct repo location
ln -s /home/tafadzwa/projects/os/dev-os ~/.dev-os

# 3. Verify
ls ~/.dev-os/profiles/ && echo "Symlink OK"
readlink ~/.dev-os
```

### Scenario B: Command symlinks are missing or broken

```bash
# Re-run the install script — it is idempotent
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh

# Verify command count
ls ~/.claude/commands/dev-os/*.md | wc -l
# Expected: 100+
```

### Scenario C: Nested dev-os/dev-os/ structure

This happens when `start` is run inside the dev-os repo itself, creating a nested symlink loop.

```bash
# Remove the nested directory
rm -rf ~/.claude/commands/dev-os/dev-os/

# Re-run install to restore correct symlinks
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh

# Verify — should NOT exist after fix
ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo "STILL NESTED — investigate" || echo "Fixed"
```

### Scenario D: Repo was deleted (not just symlink)

```bash
# If the repo was deleted, restore from git
cd /home/tafadzwa/projects/os
git clone https://github.com/Traderfuz/dev-os dev-os

# Re-establish symlink
rm -f ~/.dev-os
ln -s /home/tafadzwa/projects/os/dev-os ~/.dev-os

# Re-run install
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh
```

### Scenario E: Repo was relocated (safest migration path)

```bash
# Use the migration script — handles symlink + all path updates
bash /home/tafadzwa/projects/os/dev-os/scripts/relocate-dev-os.sh \
  --old-path /home/tafadzwa/projects/b-labs/dev-os \
  --new-path /home/tafadzwa/projects/os/dev-os
```

---

## 5. Verification

After any repair:

```bash
# 1. Symlink resolves
readlink -f ~/.dev-os
# Expected: /home/tafadzwa/projects/os/dev-os

# 2. Commands visible
ls ~/.claude/commands/dev-os/*.md | wc -l
# Expected: 100+

# 3. No nested structure
ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo "PROBLEM" || echo "OK"

# 4. Runtime dir accessible
ls ~/.dev-os/product/runtime/ && echo "Runtime accessible"
```

---

## 6. Prevention

- **Never** `rm -rf ~/.dev-os` — always `rm ~/.dev-os` (removes symlink only)
- **Never** run `start` inside the dev-os source repo itself
- After moving the dev repo, always run `scripts/relocate-dev-os.sh` before using any DevOS commands
- Periodically run `readlink ~/.dev-os` to confirm the symlink target still exists
