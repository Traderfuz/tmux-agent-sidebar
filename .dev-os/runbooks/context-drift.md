# Runbook: DevOS Context Drift Recovery

| Field | Value |
|-------|-------|
| Service | DevOS Context System (ledger + memory + bundle) |
| Runbook type | Diagnostic / Operational |
| Severity | P3 — degraded accuracy; context drift causes confusion and wasted tokens but does not break DevOS functionality |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-08 |
| Automation status | Partial — SessionStart hook auto-refreshes ledger; `map` + `status --refresh-context` rebuild bundle |

> **Scope:** This runbook covers the three context layers that can silently drift out of sync with the current project state: the context ledger, Memory MCP, and the DEVOS_CONTEXT_BUNDLE snapshot. Cross-CLI context mismatch (Claude Code vs. Gemini/Codex) is covered as Path D.

---

## 1. Trigger & Detection

**Trigger conditions (any one initiates this runbook):**

1. `project-status` shows the wrong project name, branch, or "Last active: N days ago" when the session was recent
2. `mcp__memory__get_relevant_context` or `project-status` returns context from a different project or old session
3. `docs/context/DEVOS_CONTEXT_BUNDLE.md` references commands or files that no longer exist, or is missing capabilities added in the last sprint
4. Gemini/Codex/Kimi sessions operate with a different system prompt or different MCP tool set than Claude Code

**Detection commands:**

```bash
# Check context ledger — project and branch must match current working session
cat .dev-os/runtime/context-refresh-state.json 2>/dev/null \
  || cat product/runtime/context-refresh-state.json 2>/dev/null \
  | python3 -m json.tool

# Check context bundle age (threshold: 7 days)
stat docs/context/DEVOS_CONTEXT_BUNDLE.md 2>/dev/null | grep Modify

# Check capabilities index age
stat docs/context/DEVOS_CAPABILITIES_INDEX.md 2>/dev/null | grep Modify

# Check cross-CLI sync (GEMINI.md should carry recent DevOS header)
head -5 ~/.gemini/GEMINI.md 2>/dev/null
```

**P3 note:** SessionStart hook auto-refreshes the context ledger on every new session. Most ledger drift resolves without intervention. Manual recovery is only needed when symptoms persist across multiple sessions or when the bundle/memory layers are affected.

**Maintenance idempotency invariant:** A context maintenance run on unchanged inputs must leave the tracked tree clean. `devos-init`, `context-full-refresh`, and bundle index rebuilds may refresh and report, but they must not stage or commit their own regenerated artifacts. If a second identical run changes only `Generated at`, `Generated:`, `built_at`, or similar wall-clock fields, treat that as a generator defect rather than workflow drift. Real generated drift is committed by the lifecycle owner (`merge-feature` pre-push refresh, release, or an explicit docs maintenance slice).

---

## 2. Impact Assessment

**Triage checklist** — identify which layer is drifted before picking a recovery path:

- [ ] Is the `project` or `branch` field in the context ledger wrong or stale? → **Path A**
- [ ] Does `mcp__memory__get_working_memory` return blank or does `get_relevant_context` return another project's memories? → **Path B**
- [ ] Is `DEVOS_CONTEXT_BUNDLE.md` older than 7 days, or references missing commands/files? → **Path C**
- [ ] Is `~/.gemini/GEMINI.md` missing the current DevOS header, or Codex/Kimi missing tools present in Claude Code? → **Path D**
- [ ] Multiple layers drifted simultaneously? → Work through Path A → B → C → D in order

**Blast radius:** DevOS functionality is unaffected. The drift causes the AI assistant to waste tokens correcting stale context, issue wrong project references in status output, or miss recently added commands. No data is corrupted.

---

## 3. Prerequisites

| Tool | Purpose | Notes |
|------|---------|-------|
| `bash` | Run context-refresh and sync scripts | System default |
| `python3` | JSON inspection of ledger files | System default |
| `stat` | Check file modification timestamps | System default |
| `~/.dev-os/scripts/lib/context-refresh.sh` | Rewrites the context ledger | Must be readable |
| `dev-os-cli` | Combined mcp-sync + context-sync for all CLIs | At `~/.dev-os/scripts/sync/dev-os-cli.sh` |
| Memory MCP tools | `mcp__memory__*` (local SQLite) + `mcp__memory-http__*` (Cloudflare) | Active in session |

---

## 4. Investigation Steps

### Step 4.1 — Read the context ledger

```bash
python3 -c "
import json, os
# Try project path first, fall back to product mirror
for path in ['.dev-os/runtime/context-refresh-state.json',
             'product/runtime/context-refresh-state.json']:
    try:
        with open(path) as f:
            d = json.load(f)
        print(f'Source: {path}')
        print(f'  project    : {d.get(\"project\", \"MISSING\")}')
        print(f'  branch     : {d.get(\"branch\", \"MISSING\")}')
        print(f'  provider   : {d.get(\"provider\", \"MISSING\")}')
        print(f'  last_active: {d.get(\"last_active\", \"MISSING\")}')
        break
    except FileNotFoundError:
        print(f'Not found: {path}')
"
```

**Expected:** `project` matches your current project name, `branch` matches current git branch, `last_active` is within the last 24 hours.

### Step 4.2 — Check memory MCP working state

```bash
# In an active Claude Code session, call:
# mcp__memory__get_working_memory
# Expected: non-null working memory entry for the current session

# Check recent sessions for cross-project contamination:
# mcp__memory__get_recent_sessions
# Expected: session list dominated by the current project
```

### Step 4.3 — Check bundle and index ages

```bash
python3 -c "
import os, datetime
for path in ['docs/context/DEVOS_CONTEXT_BUNDLE.md',
             'docs/context/DEVOS_CAPABILITIES_INDEX.md']:
    try:
        mtime = os.path.getmtime(path)
        age_days = (datetime.datetime.now().timestamp() - mtime) / 86400
        status = 'OK' if age_days < 7 else 'STALE'
        print(f'{path}: {age_days:.1f} days old [{status}]')
    except FileNotFoundError:
        print(f'{path}: NOT FOUND')
"
```

**Threshold:** Both files should be under 7 days old. STALE → Path C.

### Step 4.4 — Check cross-CLI sync state

```bash
# Check GEMINI.md first line for DevOS header
head -3 ~/.gemini/GEMINI.md 2>/dev/null || echo "GEMINI.md missing"

# Check when context-sync.sh last ran
stat ~/.gemini/GEMINI.md 2>/dev/null | grep Modify
stat ~/.dev-os/.claude/skills/devos/SKILL.md 2>/dev/null | grep Modify
```

If `GEMINI.md` is older than the most recent `CLAUDE.md` change → **Path D**.

---

## 5. Resolution Steps

### Path A: Context Ledger Stale or Wrong

**Symptom:** `project` shows wrong name, `branch` is outdated, or `last_active` is more than 24 hours ago despite recent active sessions.

**Root cause:** The SessionStart hook rewrites the ledger automatically on each new Claude Code session. If the hook didn't fire (e.g., session was resumed mid-way, or Claude Code was launched without a fresh init), the ledger may lag behind.

**Fix — Rewrite the ledger manually:**

```bash
bash -c "
  source ~/.dev-os/scripts/lib/context-refresh.sh
  context_refresh_write
  echo 'Ledger rewritten.'
"
```

**Alternative — Start a fresh session:**

Closing and reopening a Claude Code session triggers the SessionStart hook, which rewrites the ledger automatically. No manual intervention needed.

**Verify:**

```bash
python3 -c "
import json, datetime
d = json.load(open('.dev-os/runtime/context-refresh-state.json'))
age = (datetime.datetime.now().timestamp() - \
       datetime.datetime.fromisoformat(d['last_active'].replace('Z','')).timestamp()) / 3600
print(f'project: {d[\"project\"]}')
print(f'branch: {d[\"branch\"]}')
print(f'last_active: {d[\"last_active\"]} ({age:.1f}h ago)')
"
```

Success: `project` and `branch` match current state; `last_active` within the last hour.

---

### Path B: Memory MCP Returning Stale or Cross-Project Context

**Symptom:** `mcp__memory__get_relevant_context` returns memories from a different project, or working memory is blank despite an active session.

**Step 1 — Triage: check working memory first**

Call `mcp__memory__get_working_memory` in the session.

- If it returns blank or null → proceed to soft reset.
- If it returns content from another project → check `mcp__memory__get_recent_sessions` for cross-session contamination before resetting.

**Step 2 — Soft reset (preferred — does not delete memories)**

```bash
# In session, call:
# mcp__memory__memory_sync
# This re-syncs state without clearing stored memories.
```

Wait ~10 seconds, then re-test `get_relevant_context`. If it now returns correct context, the issue is resolved.

**Step 3 — Hard reset (only if soft reset fails)**

```bash
# In session, call:
# mcp__memory__memory_sync_reset
# This clears working memory and re-initializes sync state.
# Episodic and semantic memories are preserved; only the working layer is cleared.
```

**Step 4 — Verify**

```bash
# In session, call:
# mcp__memory__get_working_memory
# Expected: non-null working memory entry for the current project session
```

If `get_relevant_context` continues returning another project's memories after a hard reset, the contamination is in episodic memory. Use `mcp__memory__query_memories` with a project-name filter to identify the stale entries, then `mcp__memory__delete_memory` on the offending records.

---

### Path C: DEVOS_CONTEXT_BUNDLE.md Stale

**Symptom:** Bundle is older than 7 days, references commands that no longer exist, or is missing capabilities added since the last sprint.

**Fix — Rebuild capabilities index only (fast, ~30 seconds):**

```bash
# Regenerates DEVOS_CAPABILITIES_INDEX.md from current codebase state
map
project-status --refresh-context
```

**Fix — Full bundle rebuild (slower, use when bundle is badly stale):**

```bash
# Regenerates all context artifacts including DEVOS_CONTEXT_BUNDLE.md
docs-sync
```

**Verify:**

```bash
python3 -c "
import os, datetime
for path in ['docs/context/DEVOS_CONTEXT_BUNDLE.md',
             'docs/context/DEVOS_CAPABILITIES_INDEX.md']:
    mtime = os.path.getmtime(path)
    age_mins = (datetime.datetime.now().timestamp() - mtime) / 60
    print(f'{os.path.basename(path)}: updated {age_mins:.0f} minutes ago')
"
```

Success: both files updated within the last 5 minutes.

---

### Path D: Cross-CLI Context Mismatch

**Symptom:** Gemini, Codex, or Kimi sessions are missing DevOS system context, or have a different tool set than Claude Code. Root cause: `context-sync.sh` was not run after `~/.claude/CLAUDE.md` was updated.

**Fix — Sync all CLIs in one command:**

```bash
dev-os-cli
```

This runs `mcp-sync.sh` (MCP server configs) then `context-sync.sh` (system instructions) for all CLIs in sequence.

**Selective sync (if only one CLI needs updating):**

```bash
# Sync only Gemini (MCP + context)
dev-os-cli --cli gemini

# Sync only context (no MCP changes needed)
~/.dev-os/scripts/sync/context-sync/context-sync.sh
```

**Verify:**

```bash
# GEMINI.md should start with a DevOS header referencing current config
head -5 ~/.gemini/GEMINI.md

# SKILL.md for Kimi / Codex should exist and be recently modified
stat ~/.dev-os/.claude/skills/devos/SKILL.md | grep Modify
```

Success: `GEMINI.md` begins with a DevOS section header; `SKILL.md` modified within the last hour.

---

## 6. Validation

After completing any recovery path, run this consolidated check:

```bash
python3 -c "
import json, os, datetime

print('=== Context Ledger ===')
for path in ['.dev-os/runtime/context-refresh-state.json',
             'product/runtime/context-refresh-state.json']:
    try:
        d = json.load(open(path))
        age_h = (datetime.datetime.now().timestamp() -
                 datetime.datetime.fromisoformat(
                     d.get('last_active','1970-01-01').replace('Z','')).timestamp()) / 3600
        ok = 'OK' if age_h < 24 else 'STALE'
        print(f'  project={d.get(\"project\",\"?\")} branch={d.get(\"branch\",\"?\")} age={age_h:.1f}h [{ok}]')
        break
    except Exception as e:
        print(f'  {path}: {e}')

print()
print('=== Context Bundle Age ===')
for path in ['docs/context/DEVOS_CONTEXT_BUNDLE.md',
             'docs/context/DEVOS_CAPABILITIES_INDEX.md']:
    try:
        age_d = (datetime.datetime.now().timestamp() - os.path.getmtime(path)) / 86400
        ok = 'OK' if age_d < 7 else 'STALE'
        print(f'  {os.path.basename(path)}: {age_d:.1f} days old [{ok}]')
    except FileNotFoundError:
        print(f'  {os.path.basename(path)}: NOT FOUND')

print()
print('=== Cross-CLI Sync ===')
try:
    with open(os.path.expanduser('~/.gemini/GEMINI.md')) as f:
        first = f.readline().strip()
    print(f'  GEMINI.md first line: {first[:60]}')
except FileNotFoundError:
    print('  GEMINI.md: NOT FOUND')
"
```

**Success thresholds:**

| Check | Threshold |
|-------|-----------|
| Context ledger `last_active` | Within last 24 hours |
| Context ledger `project` | Matches current project name |
| `DEVOS_CONTEXT_BUNDLE.md` age | < 7 days |
| `DEVOS_CAPABILITIES_INDEX.md` age | < 7 days |
| `GEMINI.md` first line | Contains DevOS header text |
| Memory MCP `get_working_memory` | Returns non-null for current session |

---

## 7. Rollback

Context recovery operations are non-destructive by design:

- **Context ledger rewrite** (Path A): The previous ledger is overwritten in place. No rollback needed — the new ledger reflects current truth. If the script fails mid-write, the file may be corrupt; restore from the mirror at `product/runtime/context-refresh-state.json`.
- **Memory MCP reset** (Path B): `memory_sync_reset` clears only the working memory layer. Episodic and semantic memories are unaffected. No rollback is possible or needed for the working layer — it is session-scoped.
- **Bundle rebuild** (Path C): `docs/context/` files are regenerated, not deleted. If the rebuild produces a worse result (e.g., truncated output), restore from git:

```bash
# Restore the previous bundle from the last commit
git checkout HEAD -- docs/context/DEVOS_CONTEXT_BUNDLE.md
git checkout HEAD -- docs/context/DEVOS_CAPABILITIES_INDEX.md
```

- **Cross-CLI sync** (Path D): `context-sync.sh` overwrites `~/.gemini/GEMINI.md` and the SKILL.md. Back up first if needed:

```bash
/usr/bin/cp ~/.gemini/GEMINI.md ~/.gemini/GEMINI.md.bak
/usr/bin/cp ~/.dev-os/.claude/skills/devos/SKILL.md \
            ~/.dev-os/.claude/skills/devos/SKILL.md.bak
dev-os-cli
```

---

## 8. Communication

**P3 severity — no external communication required.**

This is a single-operator workstation. Context drift is a self-contained quality-of-experience issue. Log the incident type in session notes if it recurs more than once per week — that pattern indicates the SessionStart hook is not firing reliably and should be investigated.

**If drift recurs frequently (> 3 times in a week):**

> File an issue: `fix(context-refresh): SessionStart hook not reliably rewriting ledger — investigate hook registration`

---

## 9. Post-Incident

**Cleanup:** No artifacts to clean up. All recovery operations write in-place.

**If bundle rebuild was required (Path C):**

Consider adding a reminder in `docs-sync` output: "Bundle last regenerated N days ago — schedule regeneration if > 7 days."

**If cross-CLI mismatch was found (Path D):**

Make it a habit to run `dev-os-cli` after any edit to `~/.claude/CLAUDE.md`. The rule of thumb: any CLAUDE.md change that adds, removes, or renames a command should be followed immediately by `dev-os-cli`.

**If memory contamination required hard reset (Path B escalation):**

Use `mcp__memory__query_by_metadata` with `project` filter to audit what memories exist for which projects. If a project has memories bleeding into another session, consider tagging memories with explicit project identifiers when storing them via `mcp__memory__store_memory`.

**Runbook update:** If any step did not work as described, edit this file before closing the incident.

---

## 10. Related Runbooks

| Runbook | When to use |
|---------|-------------|
| [`mcp-failure-recovery.md`](./mcp-failure-recovery.md) | Memory MCP tool itself is returning errors or timing out (not stale data — the tool is broken) |
| [`mcp-sync-failure.md`](./mcp-sync-failure.md) | `dev-os-cli` or `mcp-sync.sh` fails to write configs to Gemini/Codex/Kimi/OpenCode |
| [`hook-failure.md`](./hook-failure.md) | SessionStart hook is not firing — context ledger is never written automatically |
| [`symlink-repair.md`](./symlink-repair.md) | `~/.dev-os/` symlink is broken — `context-refresh.sh` and `dev-os-cli` cannot be found |
