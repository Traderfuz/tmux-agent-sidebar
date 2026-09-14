# Merge Feature Branch Workflow

Merge a completed feature branch back to main.

## When to Use

This workflow is invoked when a feature is complete, verified, and ready to deploy.

Do not use for hotfixes that must bypass review. Do not merge when CI is failing — resolve failures first.

## Prerequisites

Before merging, ensure:
1. All tasks for the spec are completed
2. All tests pass
3. Red-team review has been run (warnings reviewed)
4. The feature has been manually tested if applicable

## Process

### 1. Verify Feature Branch Status

Check current branch and uncommitted changes:

{{include workflows/_shared/git/git-status-check}}

If not on a feature branch or there are uncommitted changes, ask for confirmation before proceeding.

### 1.5. Check for MVP Merge Mode

Determine if this is an MVP merge (partial completion) or full merge:

```bash
# Check if MVP merge flag is set
mvp_merge="${MVP_MERGE:-false}"

# Or auto-detect: check only unchecked P2/P3 task lines.
spec_name=$(git branch --show-current | sed -E 's#^(feature|wt)/##')
if [ -f "product/specs/${spec_name}/tasks.md" ]; then
    remaining_tasks=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[[:space:]]*\].*\(P[23]\)' "product/specs/${spec_name}/tasks.md" 2>/dev/null || true)
    if [ "${remaining_tasks:-0}" -gt 0 ]; then
        mvp_merge=true
    fi
fi
```

**If MVP merge is detected:**
```
🚀 MVP Merge Mode Detected

This appears to be an MVP merge (P1 tasks complete, P2/P3 remaining).

MVP merge behavior:
- ✅ Changes will be merged to main
- ✅ Feature branch will remain active (NOT deleted)
- ✅ After merge: run implement-tasks --continue for P2/P3

Ready to proceed?
```

**Note:** In MVP merge mode, the branch is NOT deleted at the end (step 9 is skipped).

<!-- Added: 2026-02-21, source: session-insights-fixes, pattern: git-boundary -->
### 1.7 Pre-Staging Repository Boundary Check

Before staging any files for the merge commit, verify every file is inside the git repository root:

```bash
repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
files_to_stage=("${changed_files[@]}")  # list of files to be staged

out_of_repo=()
in_repo=()
for file in "${files_to_stage[@]}"; do
  abs_file=$(realpath "$file" 2>/dev/null || readlink -f "$file" 2>/dev/null || echo "$file")
  if [[ "$abs_file" == "$repo_root"/* ]]; then
    in_repo+=("$file")
  else
    out_of_repo+=("$file")
  fi
done

if [[ ${#out_of_repo[@]} -gt 0 ]]; then
  echo "WARNING: The following files are OUTSIDE the git repository and cannot be committed:"
  for f in "${out_of_repo[@]}"; do echo "  $f"; done
  echo "Ask the user how to handle them before proceeding."
fi
```

**Rule:** Only stage files that resolve to paths inside `$repo_root`. Files outside the repo (e.g. wrapper scripts in a parent directory, symlink targets, globally installed configs) must be reported to the user — never silently skipped or staged.

### 2. Update Main Branch

Capture the source identity before switching to `main`; after the merge, `git branch --show-current` is `main` and cannot recover the feature slug.

```bash
_source_branch="$(git branch --show-current)"
_spec_slug="${_source_branch#feature/}"
_spec_slug="${_spec_slug#wt/}"
```

{{include workflows/_shared/git/branch-operations}}

### 3. Merge Feature Branch

```bash
git merge feature/[spec-name] --no-ff -m "feat([spec-name]): merge feature branch

- [Summary of major changes]
- [Summary of major changes]"
```

### 3.5 Refresh Session State

The merge commit advances main, but `.dev-os/runtime/session-state.yml` still points at the (now-merged) feature branch. Refresh it with the source identity captured before the branch switch.

```bash
_recovery_lib="${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/recovery.sh"
if [[ -f "$_recovery_lib" ]] && source "$_recovery_lib"; then
  if declare -f recovery_refresh_runtime_session_state >/dev/null 2>&1; then
    recovery_refresh_runtime_session_state "$_spec_slug" "merged" "feature-merged" "$_source_branch" 2>/dev/null || true
  fi
fi
```

The runtime refresh validates the source branch/spec identity and fails closed when the merge handoff names a missing or mismatched spec. This prevents a bad branch-derived slug from creating a false active session.

**Why explicit:** the `posttooluse-session-state-refresh.sh` hook fires on the `git merge` Bash command and covers the common path, but fast-forward merges, merges performed outside the agent (CLI, web UI), and merges via `git pull` skip the PostToolUse gate. This explicit call is the deterministic fallback that guarantees session-state advances on every merge-feature landing.

**Closes:** cap-20260627-session-state-stale-on-closeout (Layer 3)

{{include workflows/_shared/git/commit-message-format}}

### 4. Handle Conflicts (if any)

If conflicts occur:
1. List the conflicting files
2. Ask user for guidance on resolution
3. Do not automatically resolve conflicts

### 5. Pre-Merge Verification and Documentation

Before finalizing changelog, run comprehensive verification and generate artifacts:

#### 5.1 Documentation Scan (Verification)

{{workflows/verification/doc-scan}}

**Brief process:**
1. Read tasks.md and verify all parent tasks are complete
2. Scan for documentation files (spec.md, QUICKSTART.md, etc.)
3. Compare implementation against documentation
4. Generate verification report
5. Wait for user confirmation if issues found

**Note:** Skip this step for quick-fix branches.

#### 5.2 Generate Changelog from Implementation

{{workflows/git/generate-changelog-from-implementation}}

**Brief process:**
1. Analyze git diff to see what was actually implemented
2. Compare against original spec/requirements
3. Invoke changelog-generator skill to generate comprehensive entries
4. Create [Unreleased] entries in CHANGELOG.md
5. Generate implementation vs spec comparison report

#### 5.3 Automated Documentation Sync

{{workflows/implementation/sync-documentation}}

**Brief process:**
1. Scan codebase for new/modified code elements since last sync
2. Compare against existing documentation
3. Update outdated documentation files:
   - QUICKSTART.md with new usage patterns
   - ARCHITECTURE.md with new components
   - CHECKLIST.md with completed verification items
4. Generate documentation update report
5. Wait for user confirmation before applying changes (unless auto mode)

**Configuration:**
- `merge_auto_sync_docs: true` (default: true)
- `merge_doc_update_mode: auto|suggest|manual` (default: auto for auto-mode, suggest for manual)
- `merge_doc_backup: true` (create backups before modifications)

#### 5.4 Update Architecture Diagrams

{{workflows/architecture/update-architecture-diagrams}}

**Brief process:**
1. Identify affected components from git diff
2. Update only affected diagram sections (incremental)
3. Invoke visual-architect skill for Mermaid diagrams
4. Update root-level ARCHITECTURE.md
5. Add change history entry

**Note:** Only runs if `merge_update_arch_diagrams: true` in config.

#### 5.5 Verification Summary

After all verification steps, display summary:

```
📋 Pre-Merge Verification Complete

Spec: [spec-name]

Tasks: ✅ All complete / ⚠️ [X] incomplete
Documentation: ✅ Updated / ⚠️ [X] issues found
Changelog: ✅ Generated from implementation
Architecture: ✅ Diagrams updated

Reports:
- Verification: product/specs/[spec]/verification/merge-verification.md
- Implementation: product/specs/[spec]/verification/implementation-report.md
- Doc Updates: product/specs/[spec]/verification/doc-update-suggestions.md

Type "continue" to proceed with changelog finalization and merge.
```

### 6. Finalize Changelog

After the merge, finalize the changelog entry by moving items from `[Unreleased]` to a new version:

{{workflows/git/update-changelog}}

### 7. Update Feature Backlog

Mark the feature as completed in the backlog:

{{workflows/backlog/update-backlog}}

This moves the entry from "In Progress" to "Completed" with the completion date.

### 8. Run Tests on Main

Verify the merge didn't break anything:

```bash
# Run project-specific tests
npm test  # or pytest, cargo test, etc.
```

### 9. Delete Feature Branch (or Keep Active for MVP)

After successful merge and verified tests:

**If NOT MVP merge (all tasks complete):**

```bash
git branch -d feature/[spec-name]
```

If the branch was pushed to remote (optional for solo dev):

```bash
git push origin --delete feature/[spec-name]
```

**If MVP merge (P2/P3 tasks remaining):**

Keep the feature branch active for continued development:

```
🔄 MVP Merged - Branch Remains Active

MVP shipped to main! Branch kept active for P2/P3 iteration.

Branch: feature/[spec-name]
Status: Active with [X] remaining tasks

NEXT STEP 👉 implement-tasks --continue
```

Switch back to the feature branch:

```bash
git checkout feature/[spec-name]
```

### 10. Summary Output

```
✅ Merged feature/[spec-name] into main

Merge commit: [commit hash]
Release version: [version number]

Changes merged:
- [number] commits
- [number] files changed
- [number] additions(+)
- [number] deletions(-)

Changelog updated: CHANGELOG.md
Version updated: VERSION
Release command: scripts/git/git-release.sh
Feature backlog updated: product/specs/feature-backlog.md
Feature branch deleted.
```

## Example

```
✅ Merged feature/user-authentication into main

Merge commit: b2c3d4e
Release version: 1.1.0

Changes merged:
- 12 commits
- 45 files changed
- 1,234 additions(+)
- 89 deletions(-)

Changelog updated: CHANGELOG.md
Feature backlog updated: feature-backlog.md
Feature branch deleted.
```

## Notes

- Always verify tests pass before and after merge
- Consider tagging the merge commit for easy reference: `git tag -a v1.0.0 -m "User authentication feature"`
- If deployment is automated, merging to main may trigger deployment

## Display

Merge completion output:

```
Branch merged: feature/[spec-name] → main
Commit: [sha] [subject]
Branch deleted: feature/[spec-name]
Tag (if created): v[version]
```
## Lifecycle closeout postcondition

After the landing merge and before release or push finalization, invoke the
shared lifecycle contract:

```bash
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/spec-lifecycle.sh"
spec_lifecycle_postcondition "$PWD" merge-branch true "${USER:-unknown}" shell "<spec-slug>"
```

Only a verified `normalized` or `not_applicable` result permits successful
closeout. Exit 1 is unresolved drift; exit 3 is a mutation, lock, receipt, or
verification failure.
