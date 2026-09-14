# Runbook: DevOS Version Upgrade and Rollback

| Field | Value |
|-------|-------|
| Service | DevOS framework — `~/.dev-os` (symlink to dev repo) |
| Runbook type | Operational |
| Severity | P2 |
| Owner team | DevOS operator |
| Last reviewed | 2026-04-03 |
| Automation status | Semi-automated (`scripts/install.sh --upgrade`) |

---

## 1. Trigger & Detection

**Trigger:** A new DevOS version is available (new tag in the repo) or a version upgrade has caused regressions that require rollback.

**Upgrade symptoms (time to upgrade):**
- `cat ~/.dev-os/VERSION` shows a version behind the latest tag
- New commands or fixes are needed from a newer release
- `help` reports fewer commands than expected

**Rollback symptoms (upgrade went wrong):**
- Commands that worked before the upgrade now fail or are missing
- `help` errors or shows incorrect command count
- Hook registration broke (systematic-debugging-gate or verification-gate not firing)
- `readlink ~/.dev-os` points to unexpected location after upgrade

---

## 2. Impact Assessment

**Low impact:**
- Version is behind but all commands and workflows function correctly
- Upgrade is elective (new features, not bug fixes)

**High impact (act immediately):**
- Commands are missing or broken after upgrade
- Hook registration failed — discipline hooks not firing
- Symlink chain broken — `*` commands invisible to Claude Code

---

## 3. Pre-Upgrade Checklist

Run all of these before starting the upgrade. Do not skip any step.

### Step 1: Record current version

```bash
cat ~/.dev-os/VERSION
# Expected: semantic version like 1.70.0
# Save this — you need it for rollback
```

### Step 2: Check git status (clean working tree required)

```bash
cd /home/tafadzwa/projects/os/dev-os
git status
```

- If there are uncommitted changes, commit or stash them first
- An upgrade on a dirty working tree risks losing local modifications

```bash
# If dirty — stash changes
git stash push -m "pre-upgrade stash $(date +%Y%m%d)"
```

### Step 3: Record current command count

```bash
ls ~/.claude/commands/dev-os/*.md | wc -l
# Expected: 118 (as of v1.70.0)
```

### Step 4: Record current tag

```bash
cd /home/tafadzwa/projects/os/dev-os
git describe --tags --abbrev=0
# Save this tag name for rollback (e.g. v1.70.0)
```

### Step 5: Verify symlink health

```bash
readlink ~/.dev-os
# Expected: /home/tafadzwa/projects/os/dev-os

ls ~/.dev-os/profiles/ >/dev/null && echo "Symlink OK" || echo "BROKEN"
```

If the symlink is broken, run the symlink-repair runbook first before upgrading.

---

## 4. Upgrade Procedure

### Step 1: Fetch and pull latest

```bash
cd /home/tafadzwa/projects/os/dev-os
git fetch --tags
git pull origin main
```

### Step 2: Run the install script

```bash
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh
```

The install script is idempotent. It will:
- Re-establish command symlinks in `~/.claude/commands/dev-os/`
- Register hooks in `~/.claude/settings.json`
- Run the command surface parity check
- Enforce the global command allowlist

**Alternative — upgrade flag (pulls + installs):**

```bash
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh --upgrade
```

### Step 3: Review install output

Watch for these in the output:
- `[SUCCESS]` — expected for each major step
- `[WARNING] Installed command surface parity check failed` — see Known Issues below
- `[ERROR]` — stop and investigate before using DevOS

---

## 5. Post-Upgrade Verification

Run every check. A passing upgrade must satisfy all five.

### Check 1: Version updated

```bash
cat ~/.dev-os/VERSION
# Must show the new version (e.g. 1.71.0)
```

### Check 2: Command count

```bash
ls ~/.claude/commands/dev-os/*.md | wc -l
# Expected: 118 or higher (never lower than pre-upgrade count)
```

If the count dropped, commands were lost during upgrade. See Known Issues.

### Check 3: help responds

Open a new Claude Code session (or restart the current one) and run:

```
help
```

It must display categorized command output without errors.

### Check 4: Symlink chain intact

```bash
# Global symlink
readlink ~/.dev-os
# Expected: /home/tafadzwa/projects/os/dev-os

# Command directory symlink
readlink ~/.claude/commands/dev-os
# Expected: points into ~/.dev-os/.claude/commands/dev-os/ or equivalent

# No nested structure
ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo "NESTED — FIX REQUIRED" || echo "OK"
```

### Check 5: Hooks registered

```bash
# Check settings.json for hook entries
python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
print(f'Hook events registered: {len(hooks)}')
for event, entries in hooks.items():
    for e in entries:
        m = e.get('matcher','')
        print(f'  {event}: {m}')
"
```

Expected: at least `PreToolUse` and `Stop` events with matchers for the discipline hooks.

---

## 6. Rollback Procedure

Use when the upgrade introduced regressions that cannot be quickly fixed forward.

### Step 1: Identify the previous good version

```bash
cd /home/tafadzwa/projects/os/dev-os
git tag --sort=-v:refname | head -5
# Pick the tag you recorded in the pre-upgrade checklist
# Example: v1.70.0
```

### Step 2: Check out the previous tag

```bash
cd /home/tafadzwa/projects/os/dev-os
git checkout v1.70.0
# Replace v1.70.0 with your target version
```

This puts the repo in detached HEAD state at the known-good version.

### Step 3: Re-run install

```bash
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh
```

### Step 4: Verify rollback

Run the same five checks from Section 5:

```bash
# Version matches rollback target
cat ~/.dev-os/VERSION

# Command count is correct for that version
ls ~/.claude/commands/dev-os/*.md | wc -l

# Symlink intact
readlink ~/.dev-os

# No nested structure
ls ~/.claude/commands/dev-os/dev-os/ 2>/dev/null && echo "NESTED" || echo "OK"
```

### Step 5: Return to main when ready

When the issue is fixed upstream, return to main:

```bash
cd /home/tafadzwa/projects/os/dev-os
git checkout main
git pull origin main
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh
```

### Step 6: Restore stashed changes (if applicable)

```bash
cd /home/tafadzwa/projects/os/dev-os
git stash list
# Find your pre-upgrade stash
git stash pop
```

---

## 7. Known Issues

### Stale symlinks after upgrade

**Symptom:** Command count drops after upgrade. Some `*` commands return "not found."

**Cause:** Commands were renamed or removed in the new version, but old symlinks in `~/.claude/commands/dev-os/` were not cleaned up — or new symlinks were not created.

**Fix:**

```bash
# Remove all command symlinks and re-create from scratch
/usr/bin/rm -f ~/.claude/commands/dev-os/*.md
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh

# Verify
ls ~/.claude/commands/dev-os/*.md | wc -l
```

### Command surface parity drift

**Symptom:** Install script warns `Installed command surface parity check failed`.

**Cause:** The profile commands directory has commands that are not symlinked into `~/.claude/commands/dev-os/`, or vice versa.

**Fix:**

```bash
# Run the parity check directly for detailed output
bash /home/tafadzwa/projects/os/dev-os/scripts/lib/command-surface-parity.sh

# Then re-run install to fix
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh
```

In symlink mode (dev repo), parity warnings are non-fatal but should still be investigated.

### Hook registration failure

**Symptom:** Discipline hooks (systematic-debugging-gate, verification-gate) stop firing after upgrade.

**Cause:** The install script's hook registration step failed silently, or `~/.claude/settings.json` was overwritten by another tool.

**Fix:**

```bash
# Check current hook state
cat ~/.claude/settings.json | python3 -m json.tool | grep -A 5 "hooks"

# Re-run install — hook registration is part of the install flow
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh

# If hooks are still missing, manually verify the hook scripts exist
ls ~/.dev-os/.claude/hooks/
# Expected: systematic-debugging-gate.sh, verification-gate.sh
```

### Detached HEAD after rollback

**Symptom:** `git status` shows `HEAD detached at v1.XX.X` after rollback.

**Cause:** Normal. The rollback procedure checks out a tag, which is always a detached HEAD.

**Impact:** DevOS functions correctly in detached HEAD. You cannot commit new changes until you return to a branch.

**Fix:** Return to main when the upstream issue is resolved (see Step 5 in Rollback).

---

## 8. Prevention

- Always run the pre-upgrade checklist before pulling new versions
- Keep the working tree clean before upgrades — stash or commit first
- After every upgrade, run the five verification checks before starting work
- Subscribe to release tags (`git fetch --tags` periodically) to stay aware of new versions
- Record the current version and command count in `product/runtime/learnings-log.jsonl` after each successful upgrade

---

## 9. Escalation

If both upgrade and rollback fail:

1. Check if `~/.dev-os` symlink is intact (`readlink ~/.dev-os`)
2. If symlink is broken, follow the symlink-repair runbook first
3. If the repo itself is corrupted, re-clone:

```bash
cd /home/tafadzwa/projects/os
git clone git@github.com:Traderfuz/dev-os.git dev-os-fresh
# Compare with existing repo, then replace if needed
```

4. Log the incident in `product/runtime/learnings-log.jsonl` with category `upgrade-failure`
