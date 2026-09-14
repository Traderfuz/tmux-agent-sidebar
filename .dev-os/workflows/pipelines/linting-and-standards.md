# Linting and Standards Pipeline

Run linting and coding-standards enforcement across the project, auto-fix everything that can be auto-fixed, and produce a clean commit with zero lint violations.

## When to Use

- "Fix all lint errors", "run linting", "enforce coding standards", "clean up the code style"
- Before creating a PR — linting must pass before review
- After large changes (feature implementation, refactoring) that may have introduced style drift
- As a scheduled maintenance step alongside the maintenance-session pipeline
- Orchestrate routes here for goal types: "Lint", "Code style", "Standards", "Pre-PR cleanup"
- Anti-trigger: do NOT use for logic bugs or architectural issues — use quick-fix or audit-and-remediate instead
- Anti-trigger: do NOT use for refactoring beyond style — use refactoring-campaign instead

## Prerequisites

- DevOS initialized in the project (`start` has been run)
- Git repository with a clean working tree (or willingness to stash unrelated changes)
- Project has a linting configuration (`.eslintrc`, `biome.json`, `.prettierrc`, or similar)

## Steps

### Step 1: Enforce Standards

**Command:** Inline — run project's configured standards enforcer
**Input:** Current codebase
**Output:** Standards violations listed with file locations and rule names
**Gate to next step:** Report written; proceed even if violations found
**Skip if:** Never skipped — standards enforcement always runs first

```bash
# Detect and run the configured standards enforcer (pick the first that exists)
if [[ -f biome.json ]]; then
  bunx biome check . 2>&1 | tee /tmp/standards-report.txt
elif [[ -f .eslintrc* ]] || [[ -f eslint.config* ]]; then
  bunx eslint . 2>&1 | tee /tmp/standards-report.txt
elif command -v shellcheck >/dev/null && ls ./**/*.sh >/dev/null 2>&1; then
  find . -name '*.sh' ! -path './.git/*' | xargs shellcheck 2>&1 | tee /tmp/standards-report.txt
else
  echo "No linter configured — checking .dev-os/standards/ for manual standards"
  ls .dev-os/standards/global/*.md 2>/dev/null | wc -l | xargs echo "Standards files:"
fi
```

### Step 2: Backend Lint Check

**Command:** Inline — run project's backend linter
**Input:** Server-side code (`src/`, `app/api/`, `server/`, `lib/`, or project-specific backend root)
**Output:** Backend lint results — errors and warnings with counts
**Gate to next step:** Report recorded; proceed to Step 3 regardless of results
**Skip if:** Project has no backend code (frontend-only project — document in run log)

```bash
# Backend lint — adapt to project's toolchain
if [[ -f biome.json ]]; then
  bunx biome check src/ app/api/ server/ lib/ 2>/dev/null || true
elif [[ -f .eslintrc* ]] || [[ -f eslint.config* ]]; then
  bunx eslint src/ --ext .ts,.tsx,.js 2>/dev/null || true
elif command -v shellcheck >/dev/null; then
  find scripts/ -name '*.sh' | xargs shellcheck
fi
```

### Step 3: Frontend Lint Check

**Command:** Inline — run project's frontend linter
**Input:** Client-side code (`components/`, `app/`, `pages/`, `src/`, or project-specific frontend root)
**Output:** Frontend lint results — errors and warnings with counts
**Gate to next step:** Report recorded; proceed to Step 4 regardless of results
**Skip if:** Project has no frontend code (CLI/backend-only project — document in run log)

```bash
# Frontend lint — adapt to project's toolchain
if [[ -f biome.json ]]; then
  bunx biome check components/ app/ pages/ 2>/dev/null || true
elif [[ -f .eslintrc* ]] || [[ -f eslint.config* ]]; then
  bunx eslint components/ app/ pages/ --ext .ts,.tsx 2>/dev/null || true
fi
```

### Step 4: Auto-Fix

**Command:** Inline auto-fix
**Input:** Lint results from Steps 1-3
**Output:** Code changes auto-fixing all auto-fixable violations
**Gate to next step:** Auto-fixer ran; check remaining violations with `git diff --stat`
**Skip if:** Steps 1-3 produced zero violations

```bash
# Run auto-fix with the project's configured tool
if [[ -f biome.json ]]; then
  bunx biome check --write .
elif [[ -f .eslintrc* ]] || [[ -f eslint.config* ]]; then
  bunx eslint . --fix
elif [[ -f .prettierrc* ]] || [[ -f prettier.config* ]]; then
  bunx prettier --write .
fi
git diff --stat   # review what changed
```

Auto-fix covers: import ordering, trailing whitespace, semicolons, quote normalization, indentation, unused import removal (when safe).

### Step 5: Re-Check

**Command:** Re-run the lint commands from Steps 2-3 (scoped to changed files only)
**Input:** Auto-fixed code from Step 4
**Output:** Updated lint results — should show zero errors; warnings acceptable
**Gate to next step:** Zero lint errors (warnings are acceptable)
**Skip if:** Step 4 was skipped (no violations to recheck)

If errors remain after auto-fix:
1. These require manual fixes — list them explicitly
2. Address each manually
3. Re-run Step 5 until zero errors

### Step 6: Run Tests

**Skill:** `test` (scoped to changed files if possible)
**Input:** Linted/fixed code
**Output:** Test results confirming auto-fix did not change behavior
**Gate to next step:** Tests pass
**Skip if:** Never skipped — tests always run after lint fixes

Auto-fixers should never change behavior, but unused import removal and code restructuring can occasionally affect module resolution. Always verify.

### Step 7: Commit

**Command:** `git commit` with conventional format
**Input:** All staged lint/style changes
**Output:** Commit on current branch
**Gate to completion:** Commit succeeds
**Skip if:** N/A — always commit lint fixes

Commit message format:
```
style(<scope>): enforce linting and coding standards

- <X> errors fixed (auto-fix)
- <Y> warnings resolved
- Remaining warnings: <count> (informational)
```

## Pipeline Variants

### Frontend Only (`--frontend-only`)

Skip Step 2 (backend lint). Run Steps 1, 3, 4, 5, 6, 7.
Use for frontend-focused PRs or frontend-only projects.

### Backend Only (`--backend-only`)

Skip Step 3 (frontend lint). Run Steps 1, 2, 4, 5, 6, 7.
Use for API-focused PRs or backend-only projects.

### Check Only (`--check`)

Run Steps 1-3 only. Produce the lint report without applying any fixes.
Use when auditing lint health before deciding whether to fix now.

### Standards Only (`--standards-only`)

Run Step 1 only (code-standards-enforcer). Skip linters.
Use when checking for convention drift without running the full lint suite.

## Resume Points

| Artifact | Indicates | Resume at |
|----------|-----------|-----------|
| `product/runtime/reports/lint-check-{date}.md` | Lint report written | Step 4 (auto-fix) |
| `git diff` shows lint-only changes | Auto-fix applied | Step 5 (re-check) |
| Re-check shows zero errors | Re-check clean | Step 6 (test) |
| Tests pass | Verified | Step 7 (commit) |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Standards enforcer not configured | Check `.dev-os/standards/` directory; run `extract-standards` first |
| Step 2 | Backend lint fails (config missing) | Check for `.eslintrc` or equivalent in project root; run lint config setup if needed |
| Step 3 | Frontend lint fails (config missing) | Same as Step 2 — check frontend lint config |
| Step 4 | Auto-fixer breaks a file (parse error) | `git checkout -- <file>`; mark file for manual fix; continue with remaining files |
| Step 5 | Errors remain after auto-fix | List all remaining errors; fix manually one by one; re-run Step 5 |
| Step 6 | Tests fail after lint fixes | Identify which fix caused the regression (`git bisect`); revert that specific change |
| Step 7 | Commit fails (pre-commit lint hook) | Fix issues the hook reports; recommit — never skip hooks |

## Display Format

```
Linting & Standards Pipeline
  Lint:       [N issues | clean]
  Type check: [N errors | clean]
  Standards:  [N violations | compliant]
  Status:     [PASS | FAIL]
```
