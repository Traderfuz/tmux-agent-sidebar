# Code Quality Loop Pipeline

Iterative review-refactor-test loop that progressively improves code quality until all issues above a severity threshold are resolved.

## When to Use

- After implementation is complete, before merging
- When asked to "clean up the code", "improve quality", or "review and fix"
- Orchestrate Mode C routes here for goal type: "Code review" with constraint "Quality"
- When a code review identifies issues that need systematic resolution


- Anti-trigger: do NOT use before implementation is complete — run this loop only when all tasks in `tasks.md` are checked

## Prerequisites

- Implementation complete (all tasks checked in `tasks.md`)
- Tests passing (baseline — the loop preserves this)
- On a feature branch (not main)

## Process

1. Review implementation for issues above severity threshold (`review`).
2. Refactor code to resolve found issues.
3. Run tests to confirm no regressions.
4. Repeat until no issues above threshold remain (convergence).

## Steps

### Step 1: Review

**Skill:** `devos-code-review`
**Input:** Current codebase (focused on changed files in this feature)
**Output:** Review findings with severity ratings (CRITICAL, HIGH, MEDIUM, LOW)
**Gate to next step:** At least one issue found above severity threshold
**Exit if:** No issues above threshold — pipeline complete (clean exit)

Review dimensions:
- Code quality (complexity, duplication, naming)
- Security vulnerabilities (injection, auth issues)
- Performance concerns (N+1 queries, unnecessary re-renders)
- Test coverage gaps (critical paths untested)
- Architecture adherence (patterns, conventions)

If the review surfaces obvious AI slop, note that `polish` owns the cleanup pass before refactor begins.
If the review surfaces repeated build/type/test failures or broad reliability issues, escalate to `harden` instead of staying in the loop indefinitely.
If the review surfaces auth, secrets, or injection issues, route to `devos-security-review` before continuing the refactor loop.

### Step 2: Refactor

**Skill:** `refactor`
**Input:** Review findings from Step 1, prioritized by severity
**Output:** Code changes addressing the highest-severity issues
**Gate to next step:** Changes made (at least one issue addressed)
**Skip if:** N/A (always address at least the top issue)

Address issues in severity order: CRITICAL first, then HIGH, then MEDIUM. Do not address LOW issues in a loop iteration — they are informational.

### Step 3: Test

**Skill:** `test`
**Input:** Refactored code from Step 2
**Output:** Test results confirming behavior is preserved
**Gate to next step:** All tests pass
**Exit if:** Tests fail — fix the regression before continuing the loop

### Step 4: Re-Review

**Skill:** `devos-code-review` (same as Step 1)
**Input:** Refactored codebase
**Output:** Updated review findings
**Decision:**
- Issues above threshold remain → loop back to Step 2
- No issues above threshold → exit the loop (clean exit)
- Maximum iterations reached → exit with remaining issues report

## Loop Control

### Maximum Iterations

Default: 3 iterations (configurable via `code_quality_max_iterations` in `.dev-os/config.yml`)

```yaml
# .dev-os/config.yml
code_quality_max_iterations: 3
```

After max iterations, exit the loop and report remaining issues:
```
Code Quality Loop: max iterations (3) reached.

Remaining issues:
- [MEDIUM] [description] in [file]
- [LOW] [description] in [file]

These can be addressed in a follow-up or accepted as-is.
```

### Severity Threshold

Default: stop when no HIGH or CRITICAL issues remain (configurable via `code_quality_threshold` in config)

```yaml
# .dev-os/config.yml
code_quality_threshold: HIGH   # Options: CRITICAL, HIGH, MEDIUM, LOW
```

### Single Pass (`--single-pass`)

Run Steps 1-3 once. Report findings. Do not loop. Use for a quick quality check without iterative fixes.

## Resume Points

The code quality loop is typically completed in a single session. No formal checkpoint system.

If interrupted mid-loop:
- Check `git log` for refactoring commits from this session
- Re-run from Step 1 (review) to assess current state
- The loop is idempotent — re-running produces the same result

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Review cannot run (missing dependencies) | Install dependencies, retry |
| Step 2 | Refactoring introduces new issues | Step 4 (re-review) will catch them; address in next iteration |
| Step 3 | Tests fail after refactoring | Revert the refactoring change; try a different approach in the next iteration |
| Step 4 | New CRITICAL issues found (introduced by refactoring) | Address immediately in the next loop iteration — CRITICAL issues take priority |

## Display Format

```
Code Quality Loop — pass [N]
  Issues found:  [N] (CRITICAL: [N], HIGH: [N], MEDIUM: [N])
  Fixed this pass: [N]
  Remaining: [N]
  Loop status: [continuing | converged — [N] passes]
```
