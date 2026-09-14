# Post-Merge Docs Pipeline

Deterministic pipeline that runs after `merge-feature` to ensure all documentation and context artifacts reflect the newly merged work.

## When to Use

- Immediately after `merge-feature` completes (see its "Next Steps After Merge" section)
- After manual `git merge` of a feature branch to main
- When asked to "update docs after merge" or "sync after merge"

**Relationship to `post-merge-cleanup`:** This pipeline seals context artifacts (`docs-sync --scope product` + `status --refresh`). For operational cleanup (worktrees, backlog, user-flows), run `post-merge-cleanup` before this pipeline. The two pipelines share `docs-sync` — running both is safe and idempotent.

**Step 1 output note:** `product/roadmap.md` drift is *flagged* by docs-sync product scope but NOT auto-updated. Review and apply drift flags manually after this pipeline completes.


- Anti-trigger: do NOT use when standards are also stale after the merge — use `context-full-refresh` or `docs-full-sync` instead

## Prerequisites

- Feature branch successfully merged to main
- On main branch with clean working directory
- Version bump and changelog already applied (handled by merge-feature)

## Process

1. Create missing reader-facing docs if the merge introduced a new reader job (`user-facing-docs`).
2. Sync product docs (`docs-sync --scope product`).
3. Sync all documentation (`docs-sync`).
4. Refresh context bundle (`project-status --refresh`).

## Steps

### Step 0: User-Facing Docs Creation

**Skill:** `user-facing-docs`
**Input:** Newly merged spec, tasks, changed public surfaces
**Output:** Missing guides, runbooks, references, quickstarts, or no-docs waiver
**Gate to next step:** Required reader-facing docs exist or are explicitly waived
**Skip if:** Merged feature had no changed reader job

Why first: Docs-sync validates and repairs existing docs. It should not be the producer of net-new reader-facing docs.

### Step 1: Product Docs Sync

**Skill:** `docs-sync --scope product`
**Input:** Newly completed specs, updated task status
**Output:** `product/product-overview.md` reflects merged feature
**Gate to next step:** Product overview includes merged feature
**Skip if:** Merged feature had no spec (e.g., quick-fix)

Why first: The merged feature may have completed a spec. Product narrative must reflect this before general doc audit.

### Step 2: Docs Sync

**Skill:** `docs-sync`
**Input:** All `.md` files (including updated product docs from Step 1)
**Output:** Corrected counts, version strings, paths
**Gate to next step:** No WRONG discrepancies
**Skip if:** N/A (always run — merge likely changed counts)

Why second: Merge changes command counts, skill counts, version numbers. Docs-sync catches all of these.

### Step 3: Context Bundle Refresh

**Skill:** `project-status --refresh`
**Input:** Updated docs, skills, MCP configs
**Output:** Fresh context bundle, capabilities index, skill/chain registry surface, public surface inventory, state file
**Gate to completion:** State file written with post-merge timestamp
**Skip if:** N/A (always run)

Why last: Seals the post-merge state into context artifacts.

## Dependency Graph

```
[merge-feature completes]
  |
  v
Step 0: user-facing-docs
  |
  v
Step 1: docs-sync --scope product
  |
  v
Step 2: docs-sync
  |
  v
Step 3: status --refresh
```

## Resume Points

| Completed step | Resume at |
|----------------|-----------|
| Step 0 complete | Step 1 |
| Step 1 complete | Step 2 |
| Step 2 complete | Step 3 |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | No specs directory | Skip — not all merges involve specs |
| Step 2 | Discrepancies found | Auto-correct safe changes; flag ambiguous ones for user |
| Step 3 | Write failure | Check `.dev-os/runtime/` permissions |

## Display Format

```
Post-Merge Docs Pipeline
  [0/3] user-facing-docs       ✓/—
  [1/3] docs-sync --scope product ✓
  [2/3] docs-sync              ✓
  [3/3] context-refresh        ✓
  Status: complete
```
