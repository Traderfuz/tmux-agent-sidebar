# Session Start Freshness Pipeline

Lightweight pipeline that checks freshness of all context artifacts at session start and offers to fix stale ones in correct order.

## When to Use

- At the beginning of every Claude Code session (automatic via hooks or manual)
- When asked "is everything up to date?" or "check freshness"
- When returning to a project after time away


Do not use mid-session — this is a session-start check only. Do not skip this when starting after a multi-day break; staleness accumulates.
## Prerequisites

- DevOS initialized in project

## Steps

### Step 1: Freshness Scan (read-only)

**Skill:** `project-status` (default mode, no --refresh)
**Input:** All state files and mtime comparisons
**Output:** List of stale artifacts with age/reason
**Gate to next step:** At least one stale artifact detected
**Skip if:** N/A (always run — this IS the check)

Checks performed (in this order):
1. Standards staleness (SNAPSHOT_HASH comparison)
2. Profile standards drift (PROFILE_HASH comparison)
3. Product context check (stub detection)
4. CLAUDE.md staleness (mtime comparison)
5. Context bundle staleness (age > max_age_days)
6. OS handoff staleness (new output in `output_root/` since `last_consume` — only when `os-registry.yml` exists)
7. Codebase map staleness (`docs/context/codebase-map.md` — stale if missing, >7 days old, or ≥5 commits since generated)
8. Design handoff artifact staleness (age > 30 days) [G-016]:
   ```bash
   python3 -c "
   import json, os, datetime
   p = '.dev-os/state/design-handoff.json'
   if os.path.exists(p):
       with open(p) as f:
           state = json.load(f)
       imported = state.get('imported_at') or state.get('generated_at')
       if imported:
           age = (datetime.datetime.now(datetime.timezone.utc) -
                  datetime.datetime.fromisoformat(imported.replace('Z','+00:00'))).days
           if age > 30:
               print(f'STALE: design-handoff.json is {age} days old — re-run design-handoff if design has changed')
   " 2>/dev/null
   ```
   If STALE: surface a warning (informational — does not block). The warning is: "Design handoff artifact is N days old. If the design has changed, re-run the design-handoff workflow before implementing."

### Step 2: Route to Correct Pipeline

Based on Step 1 findings, recommend the minimum pipeline:

| Findings | Recommended pipeline |
|----------|---------------------|
| Everything fresh | No action needed |
| Only context bundle stale | Run `project-status --refresh` (single command, no pipeline) |
| OS handoff stale only | Run `cross-os-handoff` pipeline first, then re-check |
| OS handoff stale + other stale | Run `cross-os-handoff` first → then appropriate pipeline below |
| Codebase map stale only | Run `map` (single command) |
| Standards stale only (CLAUDE.md and docs current) | Run `standards-refresh` pipeline |
| CLAUDE.md or docs stale only (standards current) | Run `docs-full-sync` pipeline |
| Standards stale (any combo) | Run `context-full-refresh` pipeline |
| Multiple stale + CRITICAL triage issues | Run `maintenance-session` pipeline |
| Post-merge (on main, recent merge commit) | Run `post-merge-docs` pipeline |

> **Evaluation order:** check for OS handoff first (upstream data), then standards staleness, then CLAUDE.md/docs. `docs-full-sync` requires standards current — if standards are stale, escalate to `context-full-refresh`.

**Gate to next step:** User confirms which pipeline to run
**Skip if:** Everything is fresh (report "All context artifacts are current" and stop)

### Step 3: Execute Selected Pipeline

**Command:** The pipeline selected in Step 2
**Input:** Varies by pipeline
**Output:** All stale artifacts refreshed
**Gate to completion:** Re-run Step 1 to confirm all artifacts are now fresh
**Skip if:** User declines to refresh now

**Invocation mechanism:** Pipelines are markdown files in `profiles/general/workflows/pipelines/`. Follow the steps in the selected pipeline's `.md` file directly — this pipeline does not call a separate slash command to invoke them. Execute each step inline:
- `context-full-refresh` → follow `pipelines/context-full-refresh.md` steps 1-6
- `docs-full-sync` → follow `pipelines/docs-full-sync.md` steps 0-4
- `standards-refresh` → follow `pipelines/standards-refresh.md` steps 1-3
- `maintenance-session` → follow `pipelines/maintenance-session.md` steps 1-10
- `post-merge-docs` → follow `pipelines/post-merge-docs.md` steps 1-3
- `project-status --refresh` → run inline (single command, no pipeline file)

## Dependency Graph

```
Step 1: status (read-only scan)
  |
  v
Step 2: route decision
  |
  v
Step 3: execute pipeline ──> [selected pipeline's own dependency graph]
  |
  v
[re-check: status confirms freshness]
```

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | State files missing | Recommend `context-full-refresh` (first-time setup) |
| Step 2 | Ambiguous findings | Default to `maintenance-session` (most thorough) |
| Step 3 | Pipeline step fails | Follow that pipeline's error handling table |

## Display

Freshness scan result:

```
Session freshness check
  Standards:    [current | stale]
  Profile:      [current | drifted]
  Context:      [current | N days old]
  CLAUDE.md:    [current | stale]
  → Recommended: [pipeline-name | none needed]
```
