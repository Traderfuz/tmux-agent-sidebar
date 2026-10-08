# Quick Fix Pipeline

Streamlined pipeline for small, targeted fixes (<50 lines) that bypasses full specification and task planning.

## When to Use

- Bug fix with a clear root cause (or one that can be quickly diagnosed)
- Typo correction, config tweak, or small refactoring
- Change touches <50 lines and does not modify dependencies, migrations, or API contracts
- Orchestrate Mode C routes here for goal type: "Small fix"


Do not use for changes that require a spec or affect more than ~50 lines — use `implement-tasks` instead. Do not use for breaking changes or changes that require migration.
## Prerequisites

- Git repository with a clean working directory
- Clear understanding of what needs to be fixed (or willingness to diagnose)

## Scope Guard

Before starting, verify the change qualifies. Redirect to the feature-delivery pipeline if any of these are true:
- Estimated change exceeds 50 lines
- Change touches package dependencies or lock files
- Change requires database migrations
- Change modifies API contracts or public interfaces
- Change requires new test infrastructure

If the change is small but actually belongs in a richer path, escalate instead of forcing quick-fix:
- UI or visible layout change -> `ui-review` or full feature delivery
- Security-sensitive input / auth / secrets change -> `devos-security-review`
- AI slop cleanup / noisy diffs -> `polish`
- Repeated test/typecheck/build failures or cross-file fallout -> `harden` or feature delivery

## Steps

### Step 1: Diagnose Root Cause

**Command:** Inline diagnostic (3-check process from `diagnose-first` workflow)
**Input:** Bug report, error message, or observed behavior
**Output:** Confirmed root cause with 1 falsifiable hypothesis
**Gate to next step:** Root cause confirmed — mechanism identified, interaction layers checked, live state audited
**Skip if:** Trivial fix (typo, config value, comment) where root cause is self-evident

The 3 diagnostic checks:
1. **Check mechanism** — read the code, confirm what actually happens vs what should happen
2. **Check layers** — is this config, runtime, build, or logic? Which layer owns the bug?
3. **Audit live state** — run 1-2 diagnostic commands to confirm the hypothesis

### Step 1b: Issue Implementation Scope (after diagnosis, before the fix)

Quick-fix stays read-only through diagnosis. Once the root cause and targeted file set are confirmed, issue and enroll the scope derived from that diagnosis — one of exactly two scope issuers (with `implement-tasks`); a third identity is refused by the issuer allowlist with `SCOPE_UNAUTHORIZED_ISSUER`.

```bash
scripts/lib/implementation-scope.sh issue    scope-payload.json LEDGER.jsonl PROJECT_ID quick-fix
scripts/lib/implementation-scope.sh activate LEDGER.jsonl SCOPE_ID PROJECT_ID
scripts/lib/implementation-scope.sh enroll   LEDGER.jsonl SCOPE_ID PROJECT_ID STATE_DIR
```

Omit `baselines` from the payload: `issue` captures them from `repo_identity.root` on a genesis scope and inherits the prior revision's baselines on renewal or widening; supplied baselines are stored untouched.

Gate to next step: enrollment succeeds. If a needed widening fails with `SCOPE_WIDENING_REQUIRES_APPROVAL`, stop the scope (`scripts/lib/implementation-scope.sh stop LEDGER.jsonl SCOPE_ID PROJECT_ID`), disclose non-success, and route the operator-approved revision (`approval_source: operator`) decision before any mutation.

### Step 2: Implement Fix

**Command:** Direct code edit (Read → Edit → verify with `git diff --stat`)
**Input:** Confirmed root cause from Step 1
**Output:** Code changes (<50 lines)
**Gate to next step:** Change is <50 lines (`git diff --stat`)
**Skip if:** N/A (core step)

If the change exceeds 50 lines during implementation:
```
This change is estimated at [X] lines, exceeding the quick-fix limit (50 lines).
Consider using the feature-delivery pipeline instead:
  shape-spec → write-spec → create-tasks → implement-tasks

Proceed anyway? (May skip important reviews)
```

### Step 3: Run Affected Tests

**Command:** Run test command scoped to affected files only
**Input:** Changed files from Step 2
**Output:** Test results for affected area
**Gate to next step:** Tests pass
**Skip if:** No tests exist for the affected area (warn user)

Run only tests related to the changed files — do NOT run the full test suite.

### Step 4: Commit

**Command:** `git commit` with conventional format
**Input:** Staged changes + changelog entry
**Output:** Commit on `quick-fix/*` branch (or direct to main)
**Gate to next step:** Commit succeeds, changelog updated
**Skip if:** N/A (core step)

Commit message format:
```
fix([scope]): [brief description]

- [what was fixed]
- [root cause if known]
```

### Step 5: Merge Decision

**Command:** Merge to main (direct or via PR)
**Input:** Committed quick-fix branch
**Output:** Changes on main, branch deleted
**Gate to completion:** Tests pass on main after merge
**Skip if:** Already on main with no branch policy

If on a `quick-fix/*` branch:
1. Switch to main, pull latest
2. Merge with `--no-ff`
3. Delete the quick-fix branch
4. Push main

## Pipeline Variants

None — the quick-fix pipeline is intentionally simple. If the fix needs variants (MVP, skip-reviews), it belongs in the feature-delivery pipeline.

## Resume Points

Quick fixes are typically single-session. No formal resume points. If interrupted:
- Check `git status` and `git log` for partial work
- If branch `quick-fix/*` exists, the fix is in progress
- Complete remaining steps manually

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Cannot identify root cause | Escalate to `systematic-debugging` for deeper investigation |
| Step 2 | Change exceeds 50 lines | Redirect to feature-delivery pipeline |
| Step 3 | Tests fail | Fix the test failure (may reveal incorrect diagnosis); re-run Step 1 |
| Step 4 | Commit fails (pre-commit hook) | Fix hook issues, re-commit |
| Step 5 | Merge conflict | Resolve manually, complete merge |

## Display

Quick-fix completion summary:

```
Quick fix complete
  Change: [description]
  Files:  [N] modified
  Commit: [sha] [subject]
  Merged: main ✓
```
