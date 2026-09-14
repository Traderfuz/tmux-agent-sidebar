<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/debugging-escalation.md and re-run profile-sync. -->
# Debugging Escalation Standard

## Purpose

Prevent "fix-attempt spirals" — repeated code edits that surface new symptoms without resolving the root cause. When error-fixing stalls or repeats, escalate to a structured diagnostic tool before making another change.

## Escalation Triggers

Route to `systematic-debugging` or `diagnose-first` when **any** of the following is true:

| Condition | Route to |
|---|---|
| Same error (or a variant of it) persists after 2 fix attempts | `systematic-debugging` |
| A fix resolves the original error but introduces a new one | `systematic-debugging` |
| The root cause is unknown and the fix is a guess | `diagnose-first` |
| A workaround is being considered without a confirmed diagnosis | `diagnose-first` |
| Error message is ambiguous or points to multiple possible causes | `diagnose-first` |
| A runtime error contradicts the static type analysis (or vice versa) | `systematic-debugging` |

## Tool Selection

| Tool | Use when |
|---|---|
| `diagnose-first` | Root cause is not yet confirmed — run this first to establish a hypothesis before touching code |
| `systematic-debugging` | Root cause is suspected but fix attempts keep failing — run the four-phase investigation to confirm and isolate |

When in doubt, start with `diagnose-first`. It is lighter and feeds directly into `systematic-debugging` if needed.

## Hard Rule: No Third Attempt Without Escalation

**Do not make a third fix attempt on the same error without first completing at least Phase 1 of `systematic-debugging`.**

This applies regardless of:
- How obvious the fix seems
- Whether the error is "pre-existing"
- Whether the error is in a file outside the current spec scope

## Integration Points

This standard is referenced by:

- `autonomous-phases.md` — enforced during the Implement Tasks phase
- `bx-tool-routing.md` — debugging escalation is a named routing domain

## What Counts as a "Fix Attempt"

A fix attempt is any edit made with the intention of resolving an error. This includes:
- Changing types, interfaces, or function signatures
- Adding/removing imports
- Adjusting config files (tsconfig, eslint, etc.)
- Adding type assertions or casts

Reading, running tests, or gathering diagnostic output does **not** count as a fix attempt.

## Compliance test

- [ ] Does the systematic-debugging gate hook exist at `.claude/hooks/systematic-debugging-gate.sh` and fire on PreToolUse (attempt 3+)?
- [ ] Does `command grep -r "systematic-debugging" scripts/hooks/ | command grep -v "\.bats"` return at least one result (gate is wired into the hook chain)?
- [ ] Does `bats tests/bats/hooks/` pass with no failures on the systematic-debugging gate tests?

If any check fails: the escalation gate is unwired. Re-wire via the wiring-contract checklist before merging.
