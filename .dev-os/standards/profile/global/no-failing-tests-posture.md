<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/no-failing-tests-posture.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/no-failing-tests-posture.md and re-run profile-sync. -->
<!-- source: global -->
# No-Failing-Tests Posture

## Overview

A failing test is a broken contract. It means either the code is wrong, the test is wrong, or the system is in a state that was never supposed to ship. Regardless of who introduced the failure, the developer committing code inherits full responsibility for the test suite at the moment of commit. "I didn't break that test" is never a valid reason to leave it failing.

This standard establishes a zero-tolerance posture for committing over failing tests, and defines the explicit escape hatches — each with a cost — for cases where immediate fixing is not feasible.

## Scope

All test types: unit, integration, end-to-end, snapshot, and contract tests. Any file that can be executed by the project's test runner (Vitest, Jest, Playwright, Pytest, etc.) is in scope.

## Rules

### 1. Pre-commit gate

Before any commit, run the full test suite (or the affected subset when a full run exceeds five minutes). If tests fail:

- **Option A — Fix:** Resolve the failure in the same commit that introduces it.
- **Option B — Defer with documentation:** Create a tracked task for each failing test and add a comment directly above the failing test or `describe` block:

  ```typescript
  // TODO(test-failure): [TASK-123] Fails due to missing Supabase fixture setup.
  // Deferred 2026-04-17. Do not remove this comment without closing the task.
  ```

  Then get explicit acknowledgment from a second developer (or explicitly from the human you are working with) before committing. This is not a unilateral decision.

Neither option permits committing silently over a known failure.

### 2. Ownership is irrelevant

The phrase "that was already failing before I started" describes a historical fact, not a permission grant. You commit to the state of the codebase — including its broken tests — the moment you push.

If you pick up work and the suite is already red, apply Rule 1 before adding your own commits. The inherited failure is now your failure to address.

### 3. No test-skipping shortcuts without a paper trail

Do not use `.skip`, `xit`, `xtest`, `xdescribe`, `test.todo`, `@pytest.mark.skip`, or any other silencing mechanism without:

1. A comment explaining the reason in the test file.
2. A tracked task ID in the comment.
3. A time-bound expectation (sprint, release, or explicit owner).

OFF-STANDARD — silent skip:
```typescript
it.skip("calculates invoice total correctly", () => { ... });
```

ON-STANDARD — documented deferral:
```typescript
// TODO(test-failure): [TASK-456] Skipped — invoice rounding logic under revision.
// Owner: @dev. Target: sprint-22. Remove skip when TASK-456 is closed.
it.skip("calculates invoice total correctly", () => { ... });
```

Silencing is not fixing. A skipped test with no explanation is indistinguishable from a deleted test.

### 4. New code requires new tests before the session closes

Any new public function, React component, API route handler, or database query introduced in a session must have at least one corresponding test before that session ends. The test does not need to be exhaustive — it must be meaningful.

"I'll write tests later" is not acceptable for new public interfaces. Untested public interfaces are unverified contracts.

Minimum test bar by type:

| New artifact | Minimum test |
|---|---|
| Utility function | Unit test covering the happy path and one error/edge case |
| React component | Render test; at least one interaction if the component has user-facing behaviour |
| API route handler | Integration test covering the success response and one error response |
| Database query | Test against a seeded fixture verifying returned shape and at least one filter |

### 5. Regression must be fixed before the commit that introduced it

If work in a session causes a previously passing test to fail, that regression must be resolved in the same commit (or an earlier commit in the same branch) — not deferred to a follow-up commit.

A branch that introduces a regression and then fixes it in a later commit is acceptable only if both commits land in the same pull request and the regression never reaches the default branch. A pull request with a known mid-branch regression must not be merged until all tests are green.

### 6. Inherited failures must be registered in the gap registry

If the test suite was already failing when you began work (failures you did not introduce), you must:

1. Document each failure as an entry in `product/gap-analysis/gap-registry.jsonl` with `severity: "High"`.
2. Create a task for each.
3. Do not commit any of your own work until you have either fixed the inherited failures or completed the defer procedure from Rule 1.

Silently committing over pre-existing failures makes it impossible for the next developer to distinguish new failures from old ones. This is the primary mechanism by which test suites lose credibility.

## Enforcement

- CI must run the full test suite on every pull request. A red CI pipeline is a merge blocker — no exceptions, no bypass without a team lead sign-off.
- Pull request descriptions must include: "Test suite: all passing" or a documented list of known deferred failures with task IDs.
- Code review must check for newly introduced `.skip` / `xit` / `xtest` markers without accompanying task comments.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Commit over pre-existing failures without acknowledging them | The next developer cannot tell old failures from new; CI becomes noise | Apply Rule 1 or Rule 6 — fix or register and defer explicitly |
| `it.skip(...)` with no comment or task | Skipped tests are invisible debt; no one knows why or for how long | Add a `TODO(test-failure)` comment with a task ID |
| "I'll add tests in a follow-up PR" for new public interfaces | Follow-up PRs rarely happen; unverified interfaces ship | Write the minimum test before closing the session |
| Fixing a regression in a commit after the one that caused it (on main) | Regression window on main; blame makes causation unclear | Fix in the same commit, or squash before merge |
| Deleting a failing test instead of fixing it | Removes the contract; the bug may still exist undetected | Fix the underlying code or document why the test is no longer valid |
| Running a subset of tests before commit "because the others are unrelated" | "Unrelated" is often wrong; side effects exist | Run the full suite, or use coverage-based selection tools that are deterministic |

## The Test

Before any commit, you should be able to answer yes to each of the following:

- [ ] Did I run the test suite and confirm zero failing tests, or apply the documented defer procedure for each failure?
- [ ] Does every new public function, component, or route handler have at least one test?
- [ ] Are all new `.skip` / `xit` markers accompanied by a `TODO(test-failure)` comment with a task ID?
- [ ] If tests were already failing when I started, did I register them in `gap-registry.jsonl` and create tasks?
- [ ] If my work introduced a regression, did I fix it before or in the same commit — not after?
