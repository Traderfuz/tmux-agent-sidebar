# Docs Full Sync Pipeline

Deterministic pipeline that synchronizes all documentation layers in correct dependency order. Use when documentation is known to be stale but standards are current.

## When to Use

- After editing CLAUDE.md, README.md, or AGENTS.md manually
- After `merge-feature` **when standards are also stale** (if standards are current, use `post-merge-docs` pipeline instead — it is the named post-merge standard and has no standards prerequisite)
- When `project-status` reports CLAUDE.md staleness or doc drift
- When asked to "sync all docs" or "update documentation"


- Anti-trigger: if standards are also stale, use the `context-full-refresh` pipeline instead — `docs-full-sync` requires current standards as a prerequisite.

## Prerequisites

- Standards extraction is current (`.dev-os/standards/.last-extracted` matches codebase)
- If standards are also stale, use `context-full-refresh` pipeline instead

## Process

1. Verify standards currency (abort and redirect to context-full-refresh if stale).
2. Create missing reader-facing docs when a changed reader job lacks coverage (`user-facing-docs`).
3. Sync product docs (`docs-sync --scope product`).
4. Sync all documentation (`docs-sync --full`).
5. Regenerate AGENTS.md (`generate-agents-md`).
6. Refresh context bundle (`project-status --refresh`).

## Steps

### Step 0: Standards Currency Check

**Command:** Inline check
**Input:** `.dev-os/standards/.last-extracted`
**Output:** Abort with redirect if standards are stale
**Gate to next step:** SNAPSHOT_HASH in `.last-extracted` matches current codebase hash
**Skip if:** N/A — always verify before proceeding

```bash
stored=$(grep '^SNAPSHOT_HASH=' .dev-os/standards/.last-extracted 2>/dev/null | cut -d= -f2)
if [[ -z "$stored" ]]; then
  echo "✗ .dev-os/standards/.last-extracted not found — standards have never been extracted."
  echo "  Stop. Use the context-full-refresh pipeline instead:"
  echo "  profiles/general/workflows/pipelines/context-full-refresh.md"
  exit 1
fi
recomputed=$(/usr/bin/find . -maxdepth 3 -type f \
  ! -path './.dev-os/*' ! -path './node_modules/*' ! -path './.git/*' \
  ! -path './dist/*' ! -path './build/*' \
  | sort | head -50 | xargs stat -c %Y 2>/dev/null | sort | md5sum | awk '{print $1}')
if [[ "$stored" != "$recomputed" ]]; then
  echo "✗ Standards are stale (SNAPSHOT_HASH mismatch)."
  echo "  Stop. This pipeline requires current standards as a prerequisite."
  echo "  Run context-full-refresh instead:"
  echo "  profiles/general/workflows/pipelines/context-full-refresh.md"
  echo "  (context-full-refresh runs extract-standards first, then all docs-full-sync steps)"
  exit 1
fi
echo "✓ Standards current — proceeding with docs-full-sync"
```

Why first: Every downstream step audits docs against standards truth. Running docs-sync on stale standards produces incorrect corrections and false positives.

### Step 1: User-Facing Docs Creation

**Skill:** `user-facing-docs`
**Input:** Changed features, specs, tasks, public commands, APIs, workflows, and operator procedures
**Output:** Reader-facing docs package or explicit no-docs waiver
**Gate to next step:** Missing reader-facing docs are created before validation
**Skip if:** No reader job changed

Why before sync: Docs-sync can validate docs that exist; it does not decide the required docs package for a new capability.

### Step 2: Product Docs Sync

**Skill:** `docs-sync --scope product`
**Input:** Completed specs, task status, repo structure
**Output:** `product/product-overview.md`, `product/roadmap.md` drift flags
**Gate to next step:** Product narrative updated or confirmed current
**Skip if:** No completed specs in `product/specs/`

Why first: Product narrative is upstream of general docs. Docs-sync will audit product doc claims, so they must be current first.

### Step 3: Complete Docs Sync

**Skill:** `docs-sync --full`
**Input:** All `.md` files, implementation evidence
**Output:** Corrected docs, discrepancy report
**Gate to next step:** No WRONG-severity discrepancies remaining
**Skip if:** N/A (always run)

Why second: Uses explicit full mode to audit everything including product docs from Step 1. Catches count mismatches, stale paths, version drift. Routine `docs-sync` without args is bounded and should not be used when the goal is complete repository-wide docs coverage.

### Step 4: Generate AGENTS.md

**Skill:** `generate-agents-md`
**Input:** `package.json`, codebase structure
**Output:** `./AGENTS.md`
**Gate to next step:** AGENTS.md exists and is non-empty
**Skip if:** `package.json` exists AND AGENTS.md mtime is newer than `package.json` mtime. If `package.json` does not exist (Bash/CLI projects), treat the skip condition as False — always run using Mode 3 LLM synthesis.

Why third: AGENTS.md is a derivative of codebase metadata. Runs after docs-sync ensures it uses corrected metadata.

### Step 5: Context Bundle Refresh

**Skill:** `project-status --refresh`
**Input:** All context sources (skills, MCP, docs, AGENTS.md)
**Output:** Context bundle, capabilities index, skill/chain registry surface, public surface inventory, state file
**Gate to completion:** `context-refresh-state.json` written with current timestamp
**Skip if:** N/A (always run as final seal)

Why last: Bundles everything into the context artifacts that AI agents consume.

## Dependency Graph

```
Step 0: standards currency check
  |
  v
Step 1: user-facing-docs
  |
  v
Step 2: docs-sync --scope product
  |
  v
Step 3: docs-sync --full
  |
  v
Step 4: generate-agents-md
  |
  v
Step 5: status --refresh
```

## Resume Points

| Completed step | Resume at |
|----------------|-----------|
| Step 1 complete | Step 2 |
| Step 2 complete | Step 3 |
| Step 3 complete | Step 4 |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | No specs directory | Skip — not all projects use specs |
| Step 2 | Discrepancies found | Review corrections; approve or adjust |
| Step 3 | No package.json | Skip or use LLM synthesis mode |
| Step 4 | Write failure | Check `.dev-os/runtime/` permissions |

## Display Format

```
Docs Full Sync Pipeline
  Standards:   current ✓
  Product docs: synced ✓
  Docs:         synced ✓
  AGENTS.md:    regenerated ✓
  Context:      refreshed ✓
  Status: complete
```
