# Maintenance Session Pipeline

Deterministic pipeline for periodic project maintenance. Combines diagnostics, standards refresh, doc sync, and context rebuild into a single ordered session.

## When to Use

- Weekly or bi-weekly project housekeeping
- When asked to "run maintenance", "housekeep", or "clean up project state"
- When returning to a project after >7 days away
- When `project-status` shows multiple stale indicators simultaneously


- Anti-trigger: do NOT use for targeted single-artifact fixes — run the relevant command directly instead of a full 10-step maintenance session

## Prerequisites

- DevOS initialized in project
- Git repository with at least one commit

## Process

1. Triage project state.
2. Fix critical blocking issues.
3. Extract standards.
4. Check codebase map.
5. Sync profile standards.
6. Sync product docs.
7. Run complete docs validation (`docs-sync --full`).
8. Regenerate AGENTS.md.
9. Refresh context bundle.
10. Run contract-drift-audit.

## Steps

### Step 1: MCP Health Check

**Skill:** `mcp-ops` (runs `mcp-smoke-check.sh --probe-init`)
**Input:** `~/.claude.json` MCP server config
**Output:** Pass/fail per HTTP server; `.dev-os/runtime/mcp-health-state.json`
**Gate to next step:** Informational — does not block. Note any `AUTH-FAIL` or `DOWN` servers.
**Skip if:** N/A (always run — takes <5s and surfaces tool failures before they waste later steps)

Why first: A maintenance session often calls MCP tools (memory, context7, supabase). Discovering a broken server at Step 1 prevents silent failures later. `UPSTREAM-FAIL` servers (403 from upstream API) are noted but do not block — they may be non-critical to this session.

> **Ordering note (G-29):** `mcp-ops reference`'s integration docs describe this as "Step 1.5 (after triage)". This pipeline places it at Step 1 (before triage) because triage itself may call MCP tools and a Step-1 probe avoids silent tool failures during triage. `mcp-ops reference`'s integration docs should be updated to match this ordering.

### Step 2: Triage

**Skill:** `triage`
**Input:** Backlog, specs, git state, config
**Output:** Severity-classified diagnosis (Critical/High/Medium/Healthy)
**Gate to next step:** No CRITICAL issues (fix those first before proceeding)
**Skip if:** N/A (always run — sets the maintenance agenda)

Why second: Triage identifies what's broken in the project. No point refreshing docs if there are critical git issues or orphaned specs that would invalidate the refresh.

### Step 3: Fix Critical Issues (conditional)

**Command:** Varies based on triage output
**Input:** Triage findings
**Output:** Resolved critical issues
**Gate to next step:** Re-run triage confirms no CRITICAL items
**Skip if:** Triage returned no CRITICAL findings

Common fixes:
- Uncommitted changes: commit or stash
- Orphaned specs: archive or delete
- Config parse errors: fix `.dev-os/config.yml`

### Step 3b: Codebase Map Refresh

**Skill:** `map --update`
**Input:** repository tree (tracked source files)
**Output:** Fresh `docs/context/codebase-map.md`
**Gate to next step:** Map regenerated this run
**Skip if:** Never — the staleness conditional was removed because it meant the map
was effectively never refreshed; the regeneration costs seconds and a stale map
silently degrades every downstream gate that reads it.

Why here: The maintenance session ends with contract-drift-audit and is often followed by gap-analysis. Both hard-gate on map freshness. Checking the map now (before standards extraction changes codebase state) ensures a fresh, accurate baseline. Running `map --update` here costs seconds; a stale map at gap-analysis discovery costs the full pipeline restart.

```bash
python3 -c "
import os, subprocess, datetime
p = 'docs/context/codebase-map.md'
if not os.path.exists(p):
    print('MISSING: run map --update now (required before gap-analysis)')
    exit(1)
mtime = datetime.datetime.fromtimestamp(os.path.getmtime(p))
age_days = (datetime.datetime.now() - mtime).days
since = mtime.strftime('%Y-%m-%dT%H:%M:%S')
result = subprocess.run(['git','log','--oneline',f'--since={since}'], capture_output=True, text=True)
commit_count = len([l for l in result.stdout.strip().splitlines() if l])
if age_days > 7 or commit_count >= 5:
    print(f'STALE: map is {age_days}d old, {commit_count} commits since generation — run map --update')
    exit(1)
print(f'OK: map is {age_days}d old, {commit_count} commits since generation')
" 2>/dev/null
```

### Step 4: Extract Standards

**Skill:** `extract-standards`
**Input:** Codebase files
**Output:** `.dev-os/standards/global/*`, `.dev-os/standards/.last-extracted`
**Gate to next step:** Standards extracted successfully
**Skip if:** SNAPSHOT_HASH matches (standards already current)

### Step 5: Profile Standards Sync

**Skill:** `extract-standards --from-profile`
**Input:** Profile inheritance chain
**Output:** `.dev-os/standards/profile/*`
**Gate to next step:** Profile sync complete
**Skip if:** Profile hash matches (already current)

### Step 6: Product Docs Sync

**Skill:** `docs-sync --scope product`
**Input:** Completed specs, task status
**Output:** Updated product narrative
**Gate to next step:** Product docs current
**Skip if:** No completed specs

### Step 7: Complete Docs Sync

**Skill:** `docs-sync --full`
**Input:** All `.md` files, implementation evidence
**Output:** Corrected documentation
**Gate to next step:** No WRONG discrepancies
**Skip if:** N/A (always run)

Why full mode here: routine `docs-sync` is bounded for fast post-merge and session checks. Maintenance is the deliberate slower path, so it uses `--full` to discover, classify, verify, run drift checks, and report complete documentation drift before regenerating context artifacts.

### Step 8: Generate AGENTS.md

**Skill:** `generate-agents-md`
**Input:** `package.json`, codebase
**Output:** `./AGENTS.md`
**Gate to next step:** AGENTS.md current
**Skip if:** Already current (mtime check)

### Step 9: Context Bundle Refresh

**Skill:** `project-status --refresh`
**Input:** All context sources
**Output:** Context bundle, capabilities index, skill/chain registry surface, public surface inventory, state file, project-index outputs
**Gate to next step:** State file written
**Skip if:** N/A (always run)

**Design system audit staleness check (informational) [G-010]:** After Step 9 completes, check whether the design system audit is due:

```bash
python3 -c "
import json, os, datetime
p = '.dev-os/runtime/design-audit-state.json'
if os.path.exists(p):
    with open(p) as f:
        state = json.load(f)
    last = state.get('last_audit')
    if last:
        age = (datetime.datetime.now() - datetime.datetime.fromisoformat(last.replace('Z',''))).days
        if age > 90:
            print(f'STALE: design-system-audit last run {age} days ago — run ui-design-system-audit')
        else:
            print(f'OK: design-system-audit last run {age} days ago')
    else:
        print('STALE: design-audit-state.json exists but last_audit not set — run ui-design-system-audit')
else:
    print('MISSING: design-audit-state.json not found — run ui-design-system-audit if this project has a design system')
" 2>/dev/null
```

If the output shows STALE or MISSING and the project has a `tokens.css` or `design-system.json`, suggest running `ui-design-system-audit`. This is informational only — does not block Step 10.

**Codebase map:** Verified as part of Step 3b (blocking gate). No re-check needed here.

### Step 10: Contract Drift Audit

**Skill:** `contract-drift-audit`
**Input:** Git diff since last audit, `product/artifact-ownership.yml`
**Output:** Drift audit report with canonical coverage and freshness gaps called out explicitly
**Gate to completion:** Report generated (informational — does not block)
**Skip if:** `product/artifact-ownership.yml` does not exist

Why last: Drift audit reads the freshly-updated state. Running it after everything is synced gives the most accurate picture of what derivatives are actually stale vs what was just refreshed.
It also catches missing canonical outputs such as the skill/chain registry surface, public surface inventory, and project index, which are governed alongside the usual context bundle and capabilities index.

## Dependency Graph

```
Step 1: mcp-ops (informational — always run)
  |
  v
Step 2: triage
  |
  v
Step 3: fix critical (conditional)
  |
  v
Step 4: extract-standards ----+
  |                            |  (sequential — profile overlay
  v                            |   depends on base extraction)
Step 5: extract-standards      |
        --from-profile --------+
  |
  v
Step 6: docs-sync --scope product
  |
  v
Step 7: docs-sync --full
  |
  v
Step 8: generate-agents-md
  |
  v
Step 9: status --refresh
  |
  v
Step 10: contract-drift-audit
```

## Resume Points

| Completed step | Resume at |
|----------------|-----------|
| Step 1 (mcp-ops done) | Step 2 |
| Step 2 (triage clean) | Step 3b (map check) |
| Steps 2-3 (critical fixed) | Step 3b (map check) |
| Step 3b (map current) | Step 4 |
| Steps 2-5 (standards done) | Step 6 |
| Steps 2-7 (docs done) | Step 8 |
| Steps 2-9 (context done) | Step 10 |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | AUTH-FAIL or DOWN servers | Informational — note servers, does not block. Run `mcp-ops --fix` to diagnose. |
| Step 2 | CRITICAL findings | Must fix before continuing (Step 3) |
| Step 3 | Fix fails | Escalate to user — manual intervention needed |
| Step 4-5 | Standards extraction fails | Check codebase has source files; check profile exists |
| Step 6 | No specs | Skip — informational only |
| Step 7 | Discrepancies | Review and approve corrections |
| Step 8 | No package.json | Skip or use LLM mode |
| Step 9 | Write failure | Check permissions on `.dev-os/runtime/` |
| Step 10 | No ownership manifest | Skip — audit requires `product/artifact-ownership.yml` |

## Display Format

```
Maintenance Session
  [1/10] triage                ✓
  [2/10] fix-critical          ✓
  ...
  [10/10] contract-drift-audit ✓
  Issues resolved: [N]
  Status: complete
```
