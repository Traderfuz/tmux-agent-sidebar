# Context Full Refresh Pipeline

Deterministic pipeline that rebuilds all DevOS context artifacts in correct dependency order. This is the canonical "make everything current" operation.

## When to Use

- `project-status` reports multiple stale artifacts
- After significant codebase changes (new features, refactors, dependency updates)
- When asked to "refresh everything", "rebuild context", or "full sync"
- Before starting a new major feature (ensures clean baseline)
- When context bundle is >7 days old


- Anti-trigger: do NOT use for documentation-only updates when standards are current — use `docs-full-sync` pipeline instead

## Prerequisites

- DevOS initialized in project (`.dev-os/config.yml` exists)
- Clean or committed git state (uncommitted changes are fine but noted)

## Process

1. Extract standards (`extract-standards`).
2. Sync profile standards (`extract-standards --from-profile`).
3. Sync product docs (`docs-sync --scope product`).
4. Sync all documentation (`docs-sync`).
5. Regenerate AGENTS.md (`generate-agents-md`).
6. Refresh context bundle (`project-status --refresh`).

## Steps

### Step 1: Extract Standards

**Skill:** `extract-standards`
**Input:** Codebase files (50-file sample), `.dev-os/config.yml`
**Output:** `.dev-os/standards/global/*`, `.dev-os/standards/.last-extracted`
**Gate to next step:** Standards directory populated with at least one `.md` file
**Skip if:** `.dev-os/standards/.last-extracted` SNAPSHOT_HASH matches current codebase hash (already current)

Why first: Standards establish the baseline truth about what the codebase IS. Every downstream operation benefits from current standards.

### Step 2: Sync Profile Standards

**Skill:** `extract-standards --from-profile`
**Input:** `~/.dev-os/profiles/<profile>/standards/` inheritance chain
**Output:** `.dev-os/standards/profile/*`, `.dev-os/standards/.profile-sync`
**Gate to next step:** Profile sync hash updated
**Skip if:** `.dev-os/standards/.profile-sync` hash matches current profile content (already current)

Why second: Profile standards overlay extracted standards. Must run after codebase extraction so the two don't conflict.

### Step 3: Product Docs Sync

**Skill:** `docs-sync --scope product`
**Input:** `product/specs/*/` (completed specs), task completion status, repo structure
**Output:** drift flags in operator-owned product narrative (`plan-product` owns those docs; this step only reports)
**Gate to next step:** Product docs updated or confirmed current
**Skip if:** No completed specs exist in `product/specs/`

Why third: Product narrative must be current BEFORE docs-sync audits it. Otherwise docs-sync would validate stale product claims.

### Step 4: Docs Sync

**Skill:** `docs-sync`
**Input:** All `.md` files, implementation evidence (commands, skills, version, config)
**Output:** Corrected documentation, discrepancy report
**Gate to next step:** No WRONG-severity discrepancies remaining
**Skip if:** N/A (always run — this is the core audit)

Why fourth: Docs-sync audits ALL documentation including product docs (Step 3), README, CLAUDE.md, and AGENTS.md. Running it after docs-sync product scope means it validates already-current product narrative.

### Step 5: Generate AGENTS.md

**Skill:** `generate-agents-md`
**Input:** `package.json`, codebase structure, README.md
**Output:** `./AGENTS.md`
**Gate to next step:** AGENTS.md exists and is non-empty
**Skip if:** `package.json` exists AND AGENTS.md mtime is newer than `package.json` mtime (no dependency changes). If `package.json` does not exist (Bash/CLI projects), treat the skip condition as False — always run using Mode 3 LLM synthesis.

Why fifth: AGENTS.md generation uses codebase metadata that may have been corrected by docs-sync. Must run after docs are current.

### Step 6: Context Bundle Refresh

**Skill:** `project-status --refresh`
**Input:** Skills (3 locations), MCP configs (9 sources), CLAUDE.md, AGENTS.md, product docs, learnings.md
**Output:** `docs/context/DEVOS_CONTEXT_BUNDLE.md`, `docs/context/DEVOS_CAPABILITIES_INDEX.json`, `docs/context/DEVOS_CAPABILITIES_INDEX.md`, `docs/context/DEVOS_SKILLS_INDEX.json`, `docs/context/DEVOS_CHAINS_INDEX.json`, `docs/context/DEVOS_PUBLIC_SURFACE.md`, `.dev-os/runtime/context-refresh-state.json`, `.dev-os/reports/context-refresh-latest.md`
**Gate to completion:** `context-refresh-state.json` written with current timestamp
**Skip if:** N/A (always run — this is the final aggregation)

Why last: The context bundle reads from EVERYTHING upstream. It must be the final step so it captures the fully-current state of standards, docs, product narrative, and AGENTS.md.

## Dependency Graph

```
Step 1: extract-standards
  |
  v
Step 2: extract-standards --from-profile
  |
  v
Step 3: docs-sync --scope product
  |
  v
Step 4: docs-sync
  |
  v
Step 5: generate-agents-md
  |
  v
Step 6: status --refresh (context bundle)
```

All steps are strictly sequential. No parallelism — each step's output feeds the next.

## Pipeline Variants

### Quick Refresh (docs + context only)

Skip Steps 1-2 when standards are known to be current:
- Step 3 (docs-sync --scope product) -> Step 4 (docs-sync) -> Step 5 (generate-agents-md) -> Step 6 (context refresh)

### Standards Only

Run Steps 1-2 only. Use when codebase structure changed but docs are fine.

### CLI Projects

Step 5 (generate-agents-md) may produce minimal output since CLI projects often lack `package.json` framework detection. Still runs but output is lightweight.

## Resume Points

| Completed step | Resume at |
|----------------|-----------|
| Step 1 complete (standards extracted) | Step 2 |
| Step 2 complete (profile synced) | Step 3 |
| Step 3 complete (product docs current) | Step 4 |
| Step 4 complete (docs synced) | Step 5 |
| Step 5 complete (AGENTS.md current) | Step 6 |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | No source files found | Check project has code; verify `.dev-os/config.yml` path |
| Step 2 | Profile not found | Run `start` to set profile; check `~/.dev-os/profiles/` |
| Step 3 | No completed specs | Skip step — product docs sync requires at least one merged spec |
| Step 4 | WRONG discrepancies found | Review and approve corrections; re-run if needed |
| Step 5 | package.json missing | Skip or use Mode 3 (LLM synthesis) for AGENTS.md |
| Step 6 | State file write fails | Check `.dev-os/runtime/` directory exists and is writable |

## Display Format

```
Context Full Refresh Pipeline
  [1/6] extract-standards      ✓
  [2/6] profile-sync           ✓
  [3/6] docs-sync --scope product ✓
  [4/6] docs-sync              ✓
  [5/6] generate-agents-md     ✓
  [6/6] context-refresh        ✓
  Status: complete
```
