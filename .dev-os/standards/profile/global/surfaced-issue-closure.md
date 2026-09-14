<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/surfaced-issue-closure.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/surfaced-issue-closure.md and re-run profile-sync. -->
---
id: surfaced-issue-closure
category: global
version: 1.0.0
created: 2026-05-24
status: active
---

# Surfaced Issue Closure Standard

## Scope

This standard covers issues discovered during implementation, review, test execution, gap analysis, or verification in DevOS-managed work sessions. It does NOT cover feature requests that have not been observed as defects, risks, failed checks, or missing verification.

## Rationale

A discovered issue is already part of the work system. Leaving it in a final note as "residual risk" without either fixing it or registering it creates invisible debt: the next session cannot reliably tell whether the issue is known, owned, deferred, or forgotten.

The standard follows three named frameworks:

- **RFC 2119 normative vocabulary**: `MUST`, `SHOULD`, and `MAY` define compliance levels so agents and reviewers can distinguish hard requirements from judgment calls.
- **Jidoka / stop-the-line quality**: when a defect is detected, the work system stops long enough to expose the problem and prevent it from being passed downstream.
- **Issue tracking discipline**: defects are managed from discovery to closure; an untracked defect is not managed.

## Principles

1. **Surfaced means owned.** The agent or workflow that discovers an issue owns the next action until the issue is fixed, tracked, or explicitly waived.
2. **Residual risk is not a disposal mechanism.** A final note may summarize risk, but it must point to a concrete tracking artifact or completed fix.
3. **No silent downgrade.** Calling an issue "unrelated", "pre-existing", or "out of scope" does not remove the obligation to track it.
4. **Verification output is evidence.** Failed tests, skipped checks, lint failures, manual QA gaps, and incomplete verification items are issue records until resolved or tracked.

## Rules

### R1 - Every discovered issue MUST end in one of four states

Before a session can be called done, every discovered issue must be in exactly one of these states:

| State | Required evidence |
|---|---|
| `fixed_now` | Code/docs changed and verification command or manual check result recorded |
| `tracked_gap` | Entry in `product/gap-analysis/gap-registry.jsonl` or a dated gap report with severity and remediation path |
| `tracked_task` | Task in a spec `tasks.md`, backlog, or task registry with owner/priority |
| `explicit_waiver` | Written waiver with reason, scope, date, and why no fix/task is required |

Anything else is non-compliant.

### R2 - Final answers MUST NOT leave unsurfaced bugs

A final answer that mentions a bug, failing test, incomplete verification, untested path, skipped check, or residual issue MUST also include its disposition:

```text
Issue: full legacy statusline suite has two failures.
Disposition: fixed_now.
Verification: bats tests/bats/statusline.bats -> 44/44 passed.
```

OFF-STANDARD:

```text
Residual note: there are two unrelated failures.
```

ON-STANDARD:

```text
Residual issue: two unrelated failures remain.
Disposition: tracked_gap G-SL-LEGACY-001, remediation_task 5.10.
```

### R3 - "Unrelated" issues MUST still be surfaced

When an issue is outside the current implementation scope, classify it explicitly:

- `pre_existing`: existed before this change
- `adjacent`: discovered while inspecting nearby code
- `blocked`: cannot be fixed without missing dependency or user decision
- `manual_only`: requires a human or external service

Then create a tracking artifact unless the issue is fixed immediately.

### R4 - Verification failures MUST be fixed or tracked before positive claims

An agent MUST NOT say "converged", "complete", "all good", "verified", or "no issues" while any verification command from the session has unresolved failures.

Allowed positive claim:

```text
Target verification passed. One unrelated failure is tracked as G-123.
```

Not allowed:

```text
Target verification passed. Residual unrelated failure remains.
```

### R5 - Manual verification gaps MUST become tasks

If an acceptance item cannot be run because it requires a human, external account, hardware, paid service, or live environment, it MUST be converted into a task or checklist item with:

- exact command or action to run
- expected result
- dependency or owner
- date captured

### R6 - Gap-analysis and review reports MUST include a disposition table

Any implementation review, code review, gap-analysis report, or convergence summary that lists findings MUST include a table with:

| Field | Meaning |
|---|---|
| `id` | Stable issue or finding ID |
| `severity` | Critical, High, Medium, Low |
| `disposition` | `fixed_now`, `tracked_gap`, `tracked_task`, or `explicit_waiver` |
| `trace` | File path, gap ID, task ID, or verification command |

Reports without dispositions are analysis drafts, not completed work.

## Required Workflow

When a new issue appears during a session:

1. Name it in one sentence.
2. Classify severity and scope.
3. Decide: fix now, track as gap, track as task, or waive.
4. Apply the decision immediately.
5. Re-run the relevant verification if fixed.
6. Mention the disposition in the final answer.

## Compliance Test

A session passes this standard only if every answer is "yes":

- [ ] Did every failed command, test, skipped check, manual-verification gap, or review finding get a disposition?
- [ ] Did every non-fixed issue receive a gap ID, task ID, backlog entry, or explicit waiver?
- [ ] Did the final answer avoid bare "residual risk" notes without tracking?
- [ ] If an issue was called unrelated or pre-existing, was it still tracked or fixed?
- [ ] If the final answer claims completion or convergence, are all verification failures either fixed or tracked?
- [ ] Do reports include a disposition table for listed findings?

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Bare residual note | Leaves no machine-readable or human-actionable trail | Fix it or create a gap/task before final |
| "Unrelated" dismissal | Scope language hides a real defect | Track as `pre_existing` or `adjacent` |
| Manual check left unchecked | Acceptance criteria becomes unverifiable | Add a task with owner, action, and expected result |
| Positive completion with known failures | Misleads the user and future agents | State target passed, then include tracked issue disposition |
| Report-only finding | Analysis becomes a dead end | Add disposition and trace artifact |

## Deviation Guidance

A deviation is allowed only when the issue is not reproducible and no evidence remains. The final answer must say what was attempted, why no artifact can be created, and what signal should trigger reopening.

## References

- RFC 2119: requirement levels for `MUST`, `SHOULD`, and related keywords.
- Toyota Jidoka: stop and expose abnormalities so defects are not passed downstream.
- `profiles/default/standards/global/gap-closure-posture.md`
- `profiles/default/standards/global/no-failing-tests-posture.md`
- `profiles/general/standards/global/verify-before-surface.md`
