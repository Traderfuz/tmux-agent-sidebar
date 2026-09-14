# Standards Refresh Pipeline

Deterministic pipeline for refreshing coding standards and propagating changes downstream. Use when codebase structure changed but documentation content is fine.

## When to Use

- After adding/removing major dependencies
- After restructuring directories or renaming patterns
- When `project-status` reports standards staleness (SNAPSHOT_HASH mismatch)
- When switching or updating the active DevOS profile
- When asked to "refresh standards" or "re-extract conventions"


- Anti-trigger: do NOT use when CLAUDE.md or docs are also stale — use `context-full-refresh` instead (standards-refresh does not update docs)

## Prerequisites

- DevOS initialized in project
- Codebase has source files to analyze

## Process

1. Extract standards from codebase (`extract-standards`).
2. Sync profile standards (`extract-standards --from-profile`).
3. Refresh context bundle (`project-status --refresh`).

## Steps

### Step 1: Extract Codebase Standards

**Skill:** `extract-standards`
**Input:** Codebase files (50-file sample at maxdepth 3)
**Output:** `.dev-os/standards/global/*`, `.dev-os/standards/.last-extracted`
**Gate to next step:** At least one standard file written
**Skip if:** SNAPSHOT_HASH matches (already current)

Why first: Codebase extraction is the ground truth. Everything else derives from it.

### Step 2: Sync Profile Standards

**Skill:** `extract-standards --from-profile`
**Input:** Profile inheritance chain from `~/.dev-os/profiles/`
**Output:** `.dev-os/standards/profile/*`, `.dev-os/standards/.profile-sync`
**Gate to next step:** Profile sync hash updated
**Skip if:** Profile hash matches (already current)

Why second: Profile standards overlay codebase standards. The profile may have opinions that supersede extracted conventions.

### Step 3: Context Bundle Refresh

**Skill:** `project-status --refresh`
**Input:** Updated standards, existing docs/skills/MCP
**Output:** Fresh context bundle, skill/chain registry surface, public surface inventory incorporating new standards
**Gate to completion:** `context-refresh-state.json` written
**Skip if:** N/A (always run to seal the new standards into context)

Why last: Context bundle must reflect the updated standards baseline.

## Dependency Graph

```
Step 1: extract-standards (codebase scan)
  |
  v
Step 2: extract-standards --from-profile (overlay)
  |
  v
Step 3: status --refresh (bundle rebuild)
```

## Resume Points

| Completed step | Resume at |
|----------------|-----------|
| Step 1 complete | Step 2 |
| Step 2 complete | Step 3 |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | No source files | Verify project has code; check exclusion patterns |
| Step 2 | Profile not found | Run `start` to set active profile |
| Step 3 | Write failure | Check `.dev-os/runtime/` permissions |

## Display Format

```
Standards Refresh Pipeline
  [1/3] extract-standards  ✓
  [2/3] profile-sync       ✓
  [3/3] context-refresh    ✓
  Standards updated: [N files]
  Status: complete
```
