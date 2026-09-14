# Runbook: DevOS Profile Corruption

| Field | Value |
|-------|-------|
| Service | DevOS Profile System |
| Runbook type | Diagnostic / Operational |
| Severity | P2 — profile corruption causes wrong or missing command surface, broken standards, silently wrong workflow resolution |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-08 |
| Automation status | Partial — sync automates re-sync; repair-hooks automates hook repair |

---

## 1. Trigger & Detection

**Trigger:** DevOS profile artifacts are inconsistent — commands are missing from `help`, standards are stale, or the inheritance chain resolves to the wrong set of profiles.

**Symptoms:**
- `help` shows fewer categories or commands than expected (threshold: < 100 commands)
- Commands from a parent profile (e.g. `general`) are invisible from a child profile (e.g. `cli`)
- `project-status` or `triage` reports an unexpected profile name
- Profile-specific standards are absent from `.dev-os/standards/profile/`
- Workflows from an inherited profile fail to resolve
- `get_inheritance_chain()` returns a truncated or wrong chain
- `activate_local_profile()` silently copies an outdated artifact set

**Root causes:**
- **Path A:** `profile-config.yml` YAML is malformed (tabs, broken list syntax, bad `inherits_from:` key)
- **Path B:** A parent profile directory is missing from `~/.dev-os/profiles/` (symlink chain broken)
- **Path C:** `.dev-os/standards/.profile-sync` is stale and `activate_local_profile()` skipped the re-sync

**Related runbooks:**
- `symlink-repair.md` — P1, for `~/.dev-os` symlink issues
- `version-upgrade-rollback.md` — P2, for post-upgrade regressions

---

## 2. Impact Assessment

**Medium impact (act within the session):**
- Missing commands from parent profile reduce command surface — spec writing, task creation, or pipeline commands may not appear
- Wrong standards applied silently — code quality and gitignore rules from a different profile may be in effect
- Broken inheritance chain causes `auto.sh` workflow routing to fall back to `default` profile, stripping project-specific agents and hooks

**Not immediately critical:**
- Profile corruption does not affect running code or deployed services
- Git history and spec files are unaffected
- Memory, MCP servers, and global Claude Code settings are unaffected

---

## 3. Scope Confirmation

Before diagnosing, confirm whether this is a global issue (affects all projects) or project-local.

```bash
# Check active profile in current project
cat .dev-os/config.yml | grep profile
# Expected output: profile: cli   (or general, webapp, etc.)

# Check global profiles directory
ls ~/.dev-os/profiles/
# Expected: at minimum — default  general  cli  webapp  pwa
```

**Expected output for second command:** at least 5 profile directories listed.

**If unexpected:** Global profile directory is missing entries — proceed to Path B diagnosis.

---

## 4. Diagnosis

Work through each path in order. Stop at the first path that explains the symptom.

---

### Path A: Profile YAML malformed

**Symptom:** `help` shows fewer commands than expected; inheritance chain resolves incorrectly or errors.

#### Step A1 — Validate the YAML file

```bash
python3 -c "
import yaml, sys
try:
    yaml.safe_load(open('/home/tafadzwa/projects/os/dev-os/profiles/general/profile-config.yml'))
    print('OK')
except yaml.YAMLError as e:
    print('PARSE ERROR:', e)
    sys.exit(1)
"
```

**Expected output:** `OK`

**If unexpected (parse error printed):** Note the line number and character position. Common causes:
- Tabs used instead of spaces for indentation
- `inherits_from:` value not quoted when it contains special characters
- Multiline string missing the `|` or `>` block scalar

#### Step A2 — Inspect the raw YAML

```bash
cat /home/tafadzwa/projects/os/dev-os/profiles/general/profile-config.yml
```

Look for:
- `inherits_from:` key — must be a YAML string or list of strings
- Indentation using 2 spaces, never tabs
- No trailing colons without values

#### Step A3 — Check the specific profile in use

```bash
# Replace <profile> with the active profile from config.yml
python3 -c "
import yaml, sys
profile = '<profile>'
path = f'/home/tafadzwa/projects/os/dev-os/profiles/{profile}/profile-config.yml'
try:
    data = yaml.safe_load(open(path))
    print('inherits_from:', data.get('inherits_from', '(not set)'))
    print('OK')
except yaml.YAMLError as e:
    print('PARSE ERROR:', e)
    sys.exit(1)
"
```

**Expected output:** `inherits_from: general` (or the correct parent), then `OK`.

---

### Path B: Symlink chain broken — parent profile directory missing

**Symptom:** Commands from a parent profile are invisible; `ls ~/.dev-os/profiles/` shows fewer directories than expected.

#### Step B1 — List installed profiles

```bash
ls ~/.dev-os/profiles/ | sort
```

**Expected output (minimum set):**
```
boxi-ops
cli
default
general
pwa
webapp
```

**If a profile is absent:** That profile's commands, standards, and agents are invisible to all child profiles.

#### Step B2 — Count installed commands

```bash
ls ~/.claude/commands/dev-os/*.md | wc -l
```

**Expected output:** `100` or higher.

**If below 100:** The command symlink set is incomplete. Reinstall to restore.

#### Step B3 — Walk the inheritance chain manually

```bash
bash -c "
source /home/tafadzwa/projects/os/dev-os/scripts/lib/profile-resolver.sh
get_inheritance_chain general
"
```

**Expected output:** `general default`

For a child profile like `cli`:
```bash
bash -c "
source /home/tafadzwa/projects/os/dev-os/scripts/lib/profile-resolver.sh
get_inheritance_chain cli
"
```

**Expected output:** `cli general default`

**If unexpected (truncated chain or error):** A parent directory is missing or `profile-config.yml` for the parent has a broken `inherits_from:` key. Proceed to Recovery — Path B.

#### Step B4 — Check for circular inheritance

If `get_inheritance_chain` hangs or returns an error mentioning a loop, a circular `inherits_from:` chain exists. The detector lives at lines 74-81 of `scripts/lib/profile-resolver.sh`.

```bash
# Check for self-referencing inherits_from
grep -r "inherits_from" /home/tafadzwa/projects/os/dev-os/profiles/*/profile-config.yml
```

Visually confirm no profile lists itself or a descendant as a parent.

---

### Path C: Cache stale — profile-sync out of date

**Symptom:** Profile was recently changed (e.g. from `general` to `cli`) but old profile artifacts are still in `.dev-os/`; commands from the new profile do not appear.

#### Step C1 — Check .profile-sync version tracking

```bash
cat .dev-os/standards/.profile-sync
```

**Expected output:** Contains `devos_version:` and a profile name matching `.dev-os/config.yml`.

**If unexpected (empty, missing, or wrong profile name):** The sync was not completed after the profile change. Proceed to Recovery — Path C.

#### Step C2 — Compare active profile with synced profile

```bash
echo "Config profile:"; cat .dev-os/config.yml | grep profile
echo "Sync record:";   cat .dev-os/standards/.profile-sync | grep profile
```

**Expected output:** Both lines show the same profile name.

#### Step C3 — Check for stale artifact directories

```bash
ls .dev-os/
```

**Expected directories:** `agents/`, `commands/`, `hooks/`, `runbooks/`, `standards/`, `workflows/`

If directories from an old profile are present (e.g. `frontend/` in a `cli` profile project), the sync did not clean up the previous profile's artifacts.

---

## 5. Recovery Steps

### Recovery — Path A: Fix malformed YAML

#### Step 1 — Edit the malformed file

Open `profiles/<profile>/profile-config.yml` in your editor. Fix the YAML syntax:

- Replace all tab characters with 2-space indentation
- Ensure `inherits_from:` is a plain string or YAML list:
  ```yaml
  inherits_from: general        # string form
  # OR
  inherits_from:
    - general                   # list form (if multiple parents)
  ```
- Remove any trailing whitespace after colons

#### Step 2 — Validate the fix

```bash
python3 -c "import yaml; yaml.safe_load(open('profiles/<profile>/profile-config.yml')); print('OK')"
```

**Expected output:** `OK`

#### Step 3 — Verify the chain resolves correctly

```bash
bash -c "
source /home/tafadzwa/projects/os/dev-os/scripts/lib/profile-resolver.sh
get_inheritance_chain <profile>
"
```

**Expected output:** Full chain from the repaired profile to `default`.

---

### Recovery — Path B: Reinstall missing profile directories

#### Step 1 — Run the install script (idempotent)

```bash
bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh
```

**Expected output:** Install completes without errors. Profile directories are restored under `~/.dev-os/profiles/`.

#### Step 2 — Re-activate the project-local profile

```bash
bash /home/tafadzwa/projects/os/dev-os/scripts/lib/profile-distribution.sh \
  activate <profile> $(pwd) ~/.dev-os
```

Replace `<profile>` with the value from `.dev-os/config.yml`.

**Expected output:** Profile artifacts copied to `.dev-os/` with no errors.

#### Step 3 — Verify profile directory count

```bash
ls ~/.dev-os/profiles/ | wc -l
```

**Expected output:** `5` or higher (default, general, cli, webapp, pwa minimum).

---

### Recovery — Path C: Clear stale cache and re-sync

#### Option 1 — Use the sync command (preferred)

```bash
# In the affected project directory
sync
```

This command runs `activate_local_profile()` for the current project, updates `.profile-sync`, and refreshes all artifact directories.

**Expected output:** Sync completes; `.dev-os/standards/.profile-sync` is updated with the current profile and DevOS version.

#### Option 2 — Manual reset (if Option 1 is unavailable)

```bash
# Step 1: Remove the stale sync record
/usr/bin/rm .dev-os/standards/.profile-sync

# Step 2: Re-run profile distribution
bash /home/tafadzwa/projects/os/dev-os/scripts/lib/profile-distribution.sh \
  activate <profile> $(pwd) ~/.dev-os

# Step 3: Confirm .profile-sync was recreated
cat .dev-os/standards/.profile-sync | grep devos_version
```

**Expected output for Step 3:** A non-empty `devos_version:` line.

---

### Recovery — Circular inheritance

If `get_inheritance_chain` detected a loop:

```bash
# 1. Find which profile-config.yml introduced the loop
grep -r "inherits_from" /home/tafadzwa/projects/os/dev-os/profiles/*/profile-config.yml

# 2. Edit the offending profile-config.yml and correct the inherits_from value
# 3. Re-run chain check
bash -c "
source /home/tafadzwa/projects/os/dev-os/scripts/lib/profile-resolver.sh
get_inheritance_chain <profile>
"
```

---

## 6. Verification

Run all checks after any recovery step before declaring the incident resolved.

```bash
# 1. Profile directories present
ls ~/.dev-os/profiles/ | wc -l
# Expected: 5 or higher

# 2. Command surface complete
ls ~/.claude/commands/dev-os/*.md | wc -l
# Expected: 100 or higher

# 3. YAML parses cleanly
python3 -c "import yaml; yaml.safe_load(open('/home/tafadzwa/projects/os/dev-os/profiles/general/profile-config.yml')); print('OK')"
# Expected: OK

# 4. Inheritance chain resolves
bash -c "
source /home/tafadzwa/projects/os/dev-os/scripts/lib/profile-resolver.sh
get_inheritance_chain general
"
# Expected: general default

# 5. Profile-sync record is current
cat .dev-os/standards/.profile-sync | grep devos_version
# Expected: non-empty line with version string

# 6. Active profile matches config
echo "Config:"; cat .dev-os/config.yml | grep profile
echo "Sync:";   cat .dev-os/standards/.profile-sync | grep profile
# Expected: both show the same profile name
```

All six checks must pass. If any check fails, re-read the relevant diagnosis path above and re-run the matching recovery step.

---

## 7. Escalation

If recovery steps do not resolve the issue after two attempts:

1. Run `triage` and capture the full output
2. Run `git log --oneline -20` in `/home/tafadzwa/projects/os/dev-os` — note any recent commits to `scripts/lib/profile-resolver.sh` or `profile-distribution.sh`
3. Check `product/runtime/learnings-log.jsonl` for recent session errors related to profile resolution
4. If the corruption is reproducible, open an issue with: the `profile-config.yml` content, the `get_inheritance_chain` output, and the `.profile-sync` content

For `~/.dev-os` symlink issues that underlie the profile failure, switch to `symlink-repair.md` (P1).

---

## 8. Prevention

- **After editing any `profile-config.yml`:** immediately run `python3 -c "import yaml; yaml.safe_load(open('profiles/<profile>/profile-config.yml')); print('OK')"` to confirm YAML is valid
- **After changing a project's profile:** run `sync` in the project to flush `.profile-sync` and re-copy artifacts
- **After running `scripts/install.sh`:** verify `ls ~/.dev-os/profiles/ | wc -l` ≥ 5 before starting work
- **Never edit `profile-config.yml` with a YAML-unaware editor** that auto-converts spaces to tabs (VS Code and most editors are safe; some terminal editors are not)
- **Never manually delete directories under `.dev-os/`** without running `sync` immediately after

---

## 9. Quick Reference

| Failure | First command |
|---------|--------------|
| YAML parse error | `python3 -c "import yaml; yaml.safe_load(open('profiles/<profile>/profile-config.yml')); print('OK')"` |
| Missing parent profile | `bash /home/tafadzwa/projects/os/dev-os/scripts/install.sh` |
| Stale cache / wrong artifacts | `sync` |
| Command count too low | `ls ~/.claude/commands/dev-os/*.md \| wc -l` → then reinstall |
| Circular inheritance detected | `grep -r "inherits_from" profiles/*/profile-config.yml` |
| Hooks not firing after profile change | `repair-hooks` |

---

## 10. Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-08 | Initial version — three failure paths, measurable verification thresholds | @Traderfuz |
