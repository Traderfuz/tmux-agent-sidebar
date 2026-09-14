# Quick Fix Workflow

Streamlined workflow for small changes (<50 lines) that bypasses full Agent OS planning phases.

## When to Use

Use this workflow for:
- Simple bug fixes (1-50 lines changed)
- Small refactoring (renaming, extracting functions)
- Typo corrections
- Configuration tweaks

**NOT for:** New features, complex logic, database changes, API additions

## Quick Fix Line Limit

Default: 50 lines (configurable via `quick_fix_line_limit` in config.yml)

## Process

### Step 1: Verify Change Scope

Before starting, verify the change qualifies:

1. Describe the change you're making
2. Estimate lines changed (use `git diff --stat` if already made changes)
3. If >50 lines, suggest using full workflow instead

**If change exceeds limit:**
```
This change is estimated at [X] lines, which exceeds the quick-fix limit ([limit] lines).

Consider using the full Agent OS workflow instead:
- write-spec for new features
- start-feature for larger changes

Proceed anyway? (May skip important reviews)
```

### Step 2: Create Quick-Fix Branch

{{include workflows/_shared/git/guided-git-operations}}

Use branch name format: `quick-fix/[brief-description]`

### Step 2a: Issue Implementation Scope (after diagnosis, before the fix)

Quick-fix stays read-only through diagnosis. Once the root cause and targeted file set are confirmed, issue and enroll the scope derived from that diagnosis (exactly two issuers: `quick-fix` and `implement-tasks`):

```bash
scripts/lib/implementation-scope.sh issue    scope-payload.json LEDGER.jsonl PROJECT_ID quick-fix
scripts/lib/implementation-scope.sh activate LEDGER.jsonl SCOPE_ID PROJECT_ID
scripts/lib/implementation-scope.sh enroll   LEDGER.jsonl SCOPE_ID PROJECT_ID STATE_DIR
```

If a needed widening fails with `SCOPE_WIDENING_REQUIRES_APPROVAL`: stop the scope, disclose non-success, and obtain an operator-approved revision (`approval_source: operator`) before any mutation.

### Step 3: Implement the Fix

Make the necessary changes:

1. Read the file(s) to modify
2. Implement the fix
3. Run tests for affected files only (not full suite)

### Step 3a: Polish the Diff (conditional)

If the quick fix introduced obvious AI slop, run `polish` on the changed files before testing. Keep the cleanup narrowly scoped to the quick-fix files.

### Step 4: Run Affected Tests

Run only tests related to the changed files:

```bash
# Run specific test file(s)
npm test -- path/totest.test.js
# Or
pytest path/totest_test.py

# Do NOT run full test suite at this stage
```

### Step 5: Commit the Fix

Stage and commit with conventional format:

1. Stage the changed files:
   ```bash
   git add [list of changed files]
   ```

2. Commit with a conventional commit message:
   ```bash
   git commit -m "fix([scope]): [brief description]

   - [what was fixed]
   - [root cause if known]

   ```

3. Confirm to the user:
   ```
   Committed: fix([scope]): [brief description]
   ```

### Step 6: Update Changelog

Add entry to CHANGELOG.md `[Unreleased]` section:

```markdown
### Fixed
- [Brief description] (quick-fix)
```

Commit the changelog:
```bash
git add CHANGELOG.md
git commit --amend --no-edit
```

### Step 7: Push, PR, and Merge

{{include workflows/_shared/git/push-and-pr}}

After push/PR (or if skipped), merge to main:

1. Switch to main and update:
   ```bash
   git checkout main
   git pull origin main
   ```

2. Merge the quick-fix branch:
   ```bash
   git merge quick-fix/[description] --no-ff
   ```

3. Delete the quick-fix branch:
   ```bash
   git branch -d quick-fix/[description]
   ```

4. Push main to remote:
   ```bash
   git push origin main
   ```

### Step 8: Summary Output

```
Quick Fix Complete

Change: [description]
Branch: quick-fix/[description]
Lines changed: [X]
Tests: [X/X passed]

Git Summary:
  Committed: fix([scope]): [description]
  Merged to main: Yes
  Pushed: Yes / No
  PR: [URL] / Not created
```

---

## Differences from Full Workflow

| Aspect | Quick Fix | Full Workflow |
|--------|-----------|---------------|
| Spec creation | Skipped | Required |
| Task breakdown | Skipped | Required |
| Pre-implementation reviews | Skipped | Required |
| Feature branch | `quick-fix/*` | `feature/*` |
| Test scope | Affected files only | Full suite |
| Changelog entry | `(quick-fix)` | `(spec-name)` |
| Documentation updates | Skipped | Required |

---

## Notes

- Quick fixes skip important reviews (architect, process, security)
- Use discretion - if unsure, use full workflow
- Quick fixes still create git history and changelog entries
- If the fix touches security-sensitive paths, prefer the full feature-delivery workflow so `security-review` and `harden` can run.
- For security-sensitive changes, always use full workflow

## Display Format

```
Quick Fix Applied
  Files changed: [N] ([file list])
  Lines changed: [N] (within 50-line limit)
  Tests: [pass | skipped]
  Next: commit
```
