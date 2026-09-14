# Autonomous Phases Workflow

Deterministic phase flow for `autonomous` after lifecycle routing is complete.

## When to Use

Use this workflow to execute the canonical phase sequence for `autonomous` after lifecycle routing completes successfully.

Do not use this workflow to handle lifecycle flags (--status, --resume) — those are handled by `autonomous-lifecycle` before this workflow is invoked.

## Canonical Sequence

1. product context check
2. brainstorm / design gate
3. shape-spec
4. architecture-creator
5. knowledge-pull
6. write spec
7. gap analysis          ← always runs, see planning-pipeline
8. gap closure           ← runs on any gap — all gaps closed before proceeding
9. verify                ← validates current artifacts before reviews/tasks/resume
10. architect review
11. process optimizer review
12. create tasks
13. verify               ← validates implementation readiness
14. implement tasks
15. completion handoff

The planning pipeline is governed by `{{workflows/specification/planning-pipeline}}`. Refer to that file for phase definitions, gate rules, skip conditions, and handoff contracts.

Automatic orchestrator modes may resume from any point, but they do not get to trust the resume point blindly. Before skipping earlier phases, run `verify` against the artifacts required for the target phase. If verification finds missing or stale evidence, route back to the earliest failed canonical operation.

## Wave Semantics

Every autonomous phase is also a wave. Each wave must update `.dev-os/runtime/session-state.yml` with:

- `current_wave` incremented from the previous wave
- `wave_phase` set to the current phase
- `wave_goal` describing the purpose of the wave
- `wave_scope_claims` listing the artifacts or subsystems the wave owns
- `discovery_summary` capturing what the wave learned or produced
- `next_wave_goal` describing the handoff target

This makes `autonomous`, `checkpoint`, `resume`, and `recover` converge on the same execution narrative.

## Phase Rules

### Product Context Check

- read project truth sources before planning or implementation
- route to product context repair if mission/roadmap/spec context is missing or a stub

### Brainstorm / Design Gate

- route into `brainstorm` when implementation would otherwise begin from an unapproved idea
- record an approved-design waiver when skipped by operator request

### Shape Spec

- skip when resuming at `spec`, `tasks`, or a later recorded phase
- include `{{workflows/_shared/knowledge/knowledge-pull-step}}` unless `--skip-docs` is set
- route into `shape-spec`

### Architecture Creator

- route into `architecture-creator` after shaped requirements and before spec authoring
- produce `product/specs/<slug>/planning/architecture.md`
- interactive sessions pause for human approve/revise; headless autonomous runs record canonical `auto-approved` only after persisting the artifact, with headless context in approval provenance
- automatic resume may reuse it only when `verify` confirms the architecture artifact is current for the active requirements

### Write Spec

- skip when starting from `spec`, `tasks`, or a later recorded phase
- route into `write-spec`
- pause for review unless `--no-pause` is set

### Gap Analysis

- always runs after write-spec — not skippable, not affected by `--skip-reviews`
- route into `gap-analysis --mode 6 --converge` (Multi-Angle with convergence) on `spec.md`
- override with `--mode N` to force a specific mode (e.g., `--mode 2` for process-only on simple specs)
- any gap (CRITICAL, HIGH, MEDIUM, or LOW) triggers gap-closure — all gaps are closed before reviews
- convergence loop re-analyzes after closure until 0 new gaps per pass

### Gap Closure

- **close ALL gaps** — every severity (CRITICAL, HIGH, MEDIUM, LOW) is closed before proceeding. If a gap is real enough to be flagged by the evidence standard, it gets closed. No exceptions.
- update spec.md, re-run verify-spec — the convergence loop re-runs gap analysis automatically to confirm closure and catch newly unmasked gaps
- update each closed gap's status to `"closed"` in `product/gap-analysis/gap-registry.jsonl`
- verify/review phases cannot begin while any gap is unresolved

### Verify

- run before reviews/tasks when resuming from a spec or later phase
- run before implementation when resuming from tasks or later phase
- inspect the actual artifacts required by the target phase; do not treat `tasks.md` existence as proof that planning completed
- if verification fails, resume at the earliest missing canonical operation instead of continuing forward

### Reviews

- architect review then process optimizer review
- full review definitions in `{{workflows/specification/planning-pipeline}}`
- skip both when `--skip-reviews` is set (gap analysis still runs)
- after review completion, pause unless `--no-pause` is set

### Create Tasks

- run `{{workflows/implementation/source-reality-check}}` before generating tasks — grep source files to confirm each gap still exists; exclude `exists` claims from task list, keep `missing` and `partial`
- generate executable tasks from the approved spec
- if tasks already exist and are current, resume at implementation instead of rewriting blindly

### Pre-Implementation Gate (mandatory)

Before routing to `implement-tasks`, verify the following artifacts exist:

1. `product/specs/<slug>/spec.md` — the approved spec contract
2. `product/specs/<slug>/tasks.md` — the executable task list
3. `product/specs/<slug>/planning/architecture.md`
4. Gap-analysis report with no unresolved gaps
5. Fresh `verify` evidence for the implementation-readiness claim
6. At least one unchecked task (`- [ ]`) in `tasks.md`

**If any check fails:** stop. Do not implement. Report exactly which artifact is missing and what command creates it:

```
Spec gate failed:
  ✗ spec.md missing — run write-spec
  ✗ tasks.md missing — run create-tasks
```

**This gate cannot be bypassed by `--no-pause`, `--skip-reviews`, `--skip-gap-analysis`, or any other skip flag.** The only bypass is `--force-skip-spec-gate`, which is reserved for retroactive spec creation (e.g., when a session created artifacts correctly but spec.md/tasks.md were written after implementation). Using this bypass logs a `[WARN]` and triggers post-session accounting.

**Enforcement:** `auto_run_from_tasks()` in `scripts/lib/auto.sh` calls `auto_verify_spec_gate()` and `auto_verify_tasks_gate()` here. `auto_run_implementation()` also performs inline gate checks as a second enforcement layer.

### Implement Tasks

- route into `implement-tasks`
- preserve checkpointing and failure capture in runtime libraries
- record the implementation wave scope before queue execution starts
- before starting implementation, run the project's type-check / lint / build command and capture baseline errors
- **pre-existing errors must be fixed** — if the baseline reveals errors in files unrelated to the current spec, fix them as part of the implementation pass; do not report them as "pre-existing and unrelated" and move on
- a clean type-check / build is required before the Completion Handoff phase regardless of where errors originated

### Completion Handoff

- confirm implementation state
- route into the normal completion or merge path
- recommend docs/backlog sync if the implementation changed the user-facing surface

## Error Handling

On any phase failure:

1. stop immediately
2. show phase name and failure summary
3. offer retry or abort
4. preserve session state and branch work
5. record the failure in the phase circuit breaker; when the breaker opens, pause the session and require a deliberate retry window

`--no-pause` does not suppress error stops.

## Debugging Escalation

Follow `standards/maintenance/debugging-escalation.md` during all error-fixing work.

**Hard rule:** Do not make a third fix attempt on the same error without first completing Phase 1 of `systematic-debugging`.

Quick trigger table:

| Situation | Action |
|---|---|
| Root cause unknown, about to guess | `diagnose-first` first |
| Same error persists after 2 attempts | `systematic-debugging` |
| Fix resolves error A, introduces error B | `systematic-debugging` |

## Pre-existing Error Policy

**Never dismiss errors as "pre-existing" or "unrelated to this spec."**

If a type-check, lint, or build surfaces errors in files outside the current spec scope:

1. fix them as part of the current implementation pass
2. do not flag them as someone else's problem or skip them with a note
3. the implementation is not complete until the full codebase compiles/passes cleanly
4. if the volume of pre-existing errors is large enough to warrant a separate commit, batch them into a single "fix pre-existing errors" commit before the spec work, then continue

The goal is: every autonomous session leaves the codebase in a cleaner state than it found it.

## Display Format

```
Autonomous phase execution:
  [1/15] product ctx  ✅
  [2/15] design gate  ✅
  [3/15] shape-spec   ✅
  [4/15] architecture ✅
  [5/15] knowledge    ✅
  [6/15] write-spec   ✅
  [7/15] gap-analysis 🔄 running...
  ...
  Spec: [spec-name]   Branch: [branch]
```
