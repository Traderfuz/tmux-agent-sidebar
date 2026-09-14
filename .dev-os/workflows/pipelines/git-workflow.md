# Git Workflow Pipeline

Manage the full lifecycle of a feature branch: create a branch, gate it for readiness, enforce branch protections, and create a release — without manual Git ceremony.

## When to Use

- Starting a new branch for a feature, fix, or experiment
- "Create a branch and start working", "get this branch PR-ready", "protect the branch", "create a release"
- Before merging — to validate branch health and PR readiness
- Preparing a release from main
- Orchestrate routes here for goal types: "Branch management", "PR prep", "Release", "Git workflow"
- Anti-trigger: do NOT use for the merge itself — use the feature-delivery pipeline's Step 10 (`merge-feature`)
- Anti-trigger: do NOT use for hotfixes — use quick-fix pipeline (it manages its own branch lifecycle)

## Prerequisites

- Git repository initialized and connected to a remote
- DevOS initialized in the project (`start` has been run)
- Remote `origin` configured with push access

## Steps

### Step 1: Create Branch

**Command:** Inline git
**Input:** Branch type and name (feature, fix, refactor, chore, experiment)
**Output:** New branch created and checked out locally; tracked to remote
**Gate to next step:** `git branch --show-current` shows the new branch name
**Skip if:** Already on the intended feature branch (confirm with user)

```bash
BRANCH_TYPE="feature"   # or fix / refactor / chore / experiment
BRANCH_NAME="${BRANCH_TYPE}/<slug>"
git checkout -b "$BRANCH_NAME"
git push -u origin "$BRANCH_NAME"
echo "✓ Branch created: $(git branch --show-current)"
```

Branch naming convention:
```
feature/<spec-name>   — for feature delivery work
fix/<issue-slug>      — for bug fixes
refactor/<scope>      — for refactoring campaigns
chore/<task>          — for maintenance tasks
experiment/<name>     — for exploratory work (not merged to main)
```

### Step 2: Development Work

**Command:** Standard DevOS workflow commands (e.g., `implement-tasks`, `quick-fix`)
**Input:** Tasks.md or user direction
**Output:** Code changes on the feature branch
**Gate to next step:** All intended changes committed; `git status` clean
**Skip if:** This pipeline was invoked at Step 3 or later (branch already has commits)

This step is a placeholder — actual development happens via the appropriate pipeline (feature-delivery, quick-fix, refactoring-campaign). The git-workflow pipeline wraps the branch lifecycle.

### Step 3: Branch Readiness Check

**Command:** Inline checks
**Input:** Current branch
**Output:** Readiness report — tests passing, no uncommitted changes, branch up to date with main, no conflicts
**Gate to next step:** All checks pass
**Skip if:** Never skipped — readiness check always runs before PR prep

```bash
echo "=== Branch Readiness Check ==="
# 1. Clean working tree
git diff --quiet && git diff --cached --quiet \
  && echo "✓ Working tree clean" || echo "✗ Uncommitted changes — commit or stash first"
# 2. Up to date with origin/main
git fetch origin
BEHIND=$(git rev-list HEAD..origin/main --count)
[[ "$BEHIND" == "0" ]] \
  && echo "✓ Branch up to date with origin/main" \
  || echo "✗ Branch is $BEHIND commit(s) behind origin/main — rebase (Step 3b)"
# 3. No conflicts with main
git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main | grep -q "^<<<" \
  && echo "✗ Merge conflicts detected with main" || echo "✓ No conflicts with main"
# 4. Tests pass
test && echo "✓ Tests pass" || echo "✗ Tests failing"
```

Readiness checks:
1. `git status` is clean (no uncommitted changes)
2. Branch is up to date with `origin/main` (or rebased)
3. No merge conflicts with main
4. Tests pass (`test`)

### Step 3b: Rebase if Behind (conditional)

**Trigger:** Only when Step 3 finds the branch is behind `origin/main`
**Process:** `git fetch origin && git rebase origin/main` → resolve any conflicts → re-run Step 3
**Gate:** Branch is up to date with main and conflict-free
**Skip if:** Branch is already up to date with main

### Step 4: PR Readiness Check

**Command:** Inline checks + `gh pr create` (if ready)
**Input:** Current branch, `product/specs/[spec]/spec.md` (if exists)
**Output:** PR checklist — description quality, scope, test coverage, docs
**Gate to next step:** PR checklist passes or user confirms acceptable
**Skip if:** Not creating a PR (direct-to-main workflow without PR policy)

PR readiness criteria:
- Branch has a meaningful name (not `main` or `test`)
- At least one commit beyond the branch point
- Commit messages follow conventional format
- All spec tasks marked complete (if spec exists)

### Step 5: Apply Branch Protection

**Command:** `gh api` (GitHub branch protection via REST) or Inline note
**Input:** Branch name; protection rules from `.dev-os/config.yml`
**Output:** Branch protection rules applied (status checks required, direct push disabled if configured)
**Gate to next step:** Protection rules applied or confirmed already in place
**Skip if:** Branch protection is not configured in this project (document explicitly)

### Step 6: Create Release (optional — when releasing)

**Command:** Inline git tag + changelog update
**Input:** `main` branch with all features merged; version bump type (patch/minor/major)
**Output:** Git tag `v<version>`, changelog entry, release notes
**Gate to completion:** Tag pushed to remote, changelog committed
**Skip if:** This is a feature branch merge, not a release — skip entirely for non-release branches

Version bump rules:
- `--patch`: bug fixes, maintenance, documentation
- `--minor`: new features, backward-compatible additions
- `--major`: breaking changes, API contract changes

## Pipeline Variants

### Feature Branch Only (`--feature`)

Run Steps 1-4. Create branch, develop, check readiness, prep PR. Skip protection and release.
Use for standard feature development flow.

### Release Only (`--release`)

Run Step 6 only. Tag and release main.
Use when all features are merged and main is ready for a release tag.

### PR Prep Only (`--pr-prep`)

Run Steps 3-4 only. Check readiness and PR criteria on an existing branch.
Use when development is already done and you need to verify before opening the PR.

### Branch History Cleanup (`--clean-history`)

Before Step 4, squash or reword commits using inline git: `git rebase -i $(git merge-base HEAD origin/main)`
Use when the branch has many "WIP" or "fix" commits that should be consolidated before PR.

## Resume Points

| Artifact | Indicates | Resume at |
|----------|-----------|-----------|
| Branch `feature/*` or `fix/*` exists | Branch created | Step 2 (development) |
| `git log` shows commits beyond branch point | Development work done | Step 3 (readiness check) |
| `product/runtime/reports/branch-ready-{branch}.md` | Readiness checked | Step 4 (PR readiness) |
| PR open on GitHub/GitLab | PR created | Monitor for review/merge |
| Git tag `v<version>` exists | Release created | Pipeline complete |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Branch name already exists | Choose a unique name or check out the existing branch |
| Step 1 | Remote push fails (no access) | Verify remote credentials; check `git remote -v` |
| Step 3 | Tests fail on branch | Fix failing tests before proceeding; do not open a PR with failing tests |
| Step 3 | Lint errors found | Run linting-and-standards pipeline to fix before readiness check |
| Step 3b | Rebase conflicts | Resolve conflicts manually; `git rebase --continue`; re-run Step 3 |
| Step 3b | Rebase conflict too complex | Use `git merge origin/main` instead of rebase; note in PR description |
| Step 5 | Branch protection config missing | Add protection rules to `.dev-os/config.yml`; skip for now with note |
| Step 6 | Release tag already exists | Bump version number; do not force-push existing tags |
| Step 6 | Changelog conflicts | Resolve manually; re-run `create-release --changelog-only` |

## Display Format

```
Git Workflow Pipeline
  Branch:  [branch-name]
  Status:  [created | PR-ready | protected | released]
  PR URL:  [url | n/a]
  Next:    [next action or 'complete']
```
