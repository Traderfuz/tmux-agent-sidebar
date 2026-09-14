# Post-Merge Cleanup Pipeline

Cleanup and documentation pipeline that runs after a feature branch is merged to main, ensuring docs are current, worktrees are cleaned, and the backlog is updated.

## When to Use

- Immediately after `merge-feature` completes successfully
- When returning to a project after a merge to catch up on documentation
- When asked to "sync docs after merge" or "clean up after shipping"

**Trigger:** Suggested by `merge-feature` in its "Next Steps After Merge" section.

**Relationship to `post-merge-docs`:** This pipeline handles operational cleanup (worktrees, backlog). For context artifact sealing (`docs-sync --scope product` + `status --refresh`), run `post-merge-docs` after this pipeline. The two pipelines share `docs-sync` (Step 1 here, Step 2 there) — running both is safe and idempotent.

> **Recommended order when running both:** `post-merge-cleanup` first (operational), then `post-merge-docs` (context sealing).


Do not run before the merge is confirmed on main. Do not use to clean up worktrees that are still in active use by another session.
## Prerequisites

- Feature branch successfully merged to main
- On the `main` branch (post-merge)
- Merge commit exists in git history

## Steps

### Step 1: Sync Documentation

**Skill:** `docs-sync`
**Input:** Current codebase on main (post-merge)
**Output:** Updated README.md, CLAUDE.md, and other docs to reflect implementation
**Gate to next step:** Docs sync complete (no CRITICAL discrepancies unresolved)
**Skip if:** `--docs-only` was passed (run only this step, then stop)

Checks performed:
- README.md reflects current commands, profiles, skills
- CLAUDE.md reflects current architecture and configuration
- Code examples in docs match actual API/usage
- Version numbers are current

### Step 2: Generate User Flows

**Skill:** `generate-user-flows`
**Input:** Current codebase, commands, workflows
**Output:** Updated `docs/user-flows.md` with ASCII flowcharts
**Gate to next step:** User flows generated or intentionally skipped
**Skip if:** `docs/user-flows.md` does not exist (project has not adopted user-flows docs)

### Step 3: Clean Worktrees

**Command:** `git worktree list` + `git worktree remove`
**Input:** Git worktree state
**Output:** Stale worktrees removed
**Gate to next step:** All stale worktrees removed, or none existed
**Skip if:** No active worktrees (`git worktree list` shows only the main worktree)

Process:
1. List all worktrees
2. Identify worktrees for the completed feature branch
3. Confirm removal with user
4. Remove stale worktrees and prune

### Step 4: Update Backlog

**Command:** Inline edit to `product/specs/feature-backlog.md`
**Input:** Completed spec name and merge date
**Output:** Feature moved from "In Progress" to "Completed" in backlog
**Gate to completion:** Backlog updated with completion date
**Skip if:** N/A (always update the backlog)

## Pipeline Variants

### Docs Only (`--docs-only`)

Run only Step 1 (docs-sync). Skip Steps 2-4. Use when documentation is the only concern.

## Resume Points

Post-merge cleanup is typically single-session and fast. No formal checkpoint system. If interrupted:

| Completed step | Resume at |
|----------------|-----------|
| Step 1 complete | Step 2 |
| Step 2 complete | Step 3 |
| Step 3 complete | Step 4 |

Re-running any step is safe — all steps are idempotent.

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Docs sync finds CRITICAL discrepancy | Fix the discrepancy before proceeding — stale docs are a maintenance risk |
| Step 2 | User flows generation fails | Skip and continue — user flows are non-blocking |
| Step 3 | Worktree removal fails (locked) | Run `git worktree unlock` first, then retry removal |
| Step 4 | Backlog file missing | Create the backlog file with initial structure, then add entry |

## Display

Cleanup confirmation:

```
Post-merge cleanup complete
  Branch deleted:  feature/[spec-name]
  Worktree removed: .dev-os/worktrees/[name] (if existed)
  Backlog updated:  [spec-name] → Completed
```
