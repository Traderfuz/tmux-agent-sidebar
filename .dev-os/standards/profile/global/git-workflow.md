<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/git-workflow.md and re-run profile-sync. -->
# Git Workflow Standards

## Overview

This standard defines the canonical lifecycle for feature and bugfix work: how changes flow from idea through implementation to merge, and how GitHub Issues, branches, PRs, and merge operations connect into a single traceable loop. It replaces the implicit "commit to main" pattern with an explicit branch-per-spec workflow enforced at the git hook level.

## Scope

This standard covers branch naming conventions, commit type rules, the capture→issue→branch→PR→merge→close lifecycle, escape hatches for emergency bypasses, and integration points where GitHub issue numbers flow through the system. It does NOT cover CI/CD pipelines, branch protection rules, or release management (see `deployment.md`).

## Principles

1. **Main stays deployable.** Only `chore:`, `docs:`, `refactor:`, `test:`, `ci:`, `perf:`, `style:`, and `revert:` commits land directly on main. Feature and bugfix work lives on branches.
2. **One spec, one branch.** Each spec gets a single `feat/<slug>` or `fix/<slug>` branch. The branch dies when the spec merges.
3. **Issues and code travel together.** A GitHub issue number in the branch name flows into the PR body (`Closes #N`) and auto-closes the issue on merge — zero manual tracking.
4. **Short-lived branches only.** Branches older than one sprint are off-standard. Incomplete features use feature flags, not long-lived branches.

## Rules

### The Lifecycle

```
capture --issue → GitHub Issue #N
  → implement-tasks → feat/<N>-<slug> branch
    → work + commits (on branch)
      → git-pull-request.sh → PR body includes "Closes #N"
        → merge-feature → issue auto-closed by GitHub
          → branch deleted, worktree cleaned up
```

### Branch Naming Convention

| Pattern | When | Example |
|---------|------|---------|
| `feat/<issue>-<slug>` | Feature with linked GitHub issue | `feat/42-login-fix` |
| `feat/<slug>` | Feature without linked issue | `feat/capture-inbox-repair` |
| `fix/<issue>-<slug>` | Bugfix with linked GitHub issue | `fix/87-session-expiry` |
| `fix/<slug>` | Bugfix without linked issue | `fix/hook-timeout` |

**Retired prefixes:** `feature/` (too long), `wt/` (implementation detail of worktrees). All new work uses `feat/` or `fix/`.

### Commit Types and Branch Requirement

| Commit Type | Branch Required | Enforcement |
|-------------|----------------|-------------|
| `feat:` | **YES** | Blocked on main (exit 1) |
| `fix:` | **YES** | Blocked on main (exit 1) |
| `chore:` | No | Passes silently |
| `docs:` | No | Passes silently |
| `refactor:` | No | Passes silently |
| `test:` | No | Passes silently |
| `ci:` | No | Passes silently |
| `perf:` | No | Passes silently |
| `style:` | No | Passes silently |
| `revert:` | No | Passes silently |

### Escape Hatches

| Mechanism | Effect | When to use |
|-----------|--------|-------------|
| `BRANCH_DISCIPLINE_ENFORCE=0` | Allows single feat/fix commit on main | Emergency hotfix, circular bootstrap |
| `BRANCH_DISCIPLINE_DISABLE=1` | Disables all branch advisories | Testing, CI environments |
| `BRANCH_DISCIPLINE_FEAT_DISABLE=1` | Disables feat/fix advisory only | Legacy compatibility |
| `--no-git` on implement-tasks | Skips all git ops including branch creation | Dry-run, non-git contexts |

### Integration Points

The `github_issue` field flows through the system at these handoff points:

1. **capture → inbox.jsonl** — `capture_write --issue` creates a GitHub issue, stores number in `github_issue` field.
2. **shape-spec → planning/metadata.yml** — `shape-spec --from-capture <id>` copies `github_issue` to spec planning metadata.
3. **implement-tasks → branch name** — reads `planning/metadata.yml`, includes issue number in `feat/<N>-<slug>` branch name.
4. **git-pull-request.sh → PR body** — parses issue number from branch name or session state, injects `Closes #N`.
5. **GitHub → issue closure** — on PR merge, GitHub auto-closes the linked issue.

## Anti-Patterns

| Anti-Pattern | Why it fails | Correct approach |
|--------------|-------------|-----------------|
| Long-lived feature branches (> 1 sprint) | Accumulates merge conflicts; integration testing impossible | Merge early behind a feature flag; delete the branch |
| Multiple naming schemes (`feature/`, `feat/`, `wt/`) | Breaks automation that parses branch names for issue numbers | Use `feat/` or `fix/` only |
| Direct-to-main feat/fix commits | No reviewability, no issue linkage, collision risk in parallel sessions | Create a branch first |
| Manual issue closure after merge | Forgotten closures create false backlog | Use `Closes #N` in PR body for automatic closure |
| Worktree-specific branch names (`wt/feature-a`) | Worktrees are an implementation detail, not a naming convention | Use `feat/` prefix; worktree uses same branch |
