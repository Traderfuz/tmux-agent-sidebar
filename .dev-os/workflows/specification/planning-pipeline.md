# Planning Pipeline

Single source of truth for the DevOS planning phase sequence. Defines canonical order, phase gates, handoff contracts, and skip conditions for every step from raw requirements to implementation-ready tasks.

Commands and workflows that run planning phases MUST follow this sequence. Do not invent a different order or add phases without updating this file.

## When to Use

Consumed by:
- `autonomous-phases.md` — Planning and Write Spec phases
- `shape-spec` command — entry to phase 2
- `architecture-creator` skill — entry to phase 4
- `write-spec` command — entry to phase 6
- `create-tasks` command — entry to phase 12

Anti-triggers: Do not use this for implementation. The pipeline ends at task creation. Everything after `create-tasks` is governed by `autonomous-phases.md`.

---

## Canonical Phase Sequence

```
Phase 1: Product Context Check      (once at pipeline entry)
Phase 2: Brainstorm / Design Gate   (approved design or explicit waiver)
Phase 3: Shape Spec                 (requirements + emotion-first)
Phase 4: Architecture Creator       (architecture package + handoff)
Phase 5: Knowledge Pull             (current ecosystem context)
Phase 6: Write Spec                 (spec.md authoring)
Phase 7: Gap Analysis               (always runs — not skippable)
Phase 8: Gap Closure                (conditional — all gaps closed before proceeding)
Phase 9: Verify                     (artifact and requirement gate)
Phase 10: Architect Review          (skippable with --skip-reviews)
Phase 11: Process Optimizer Review  (skippable with --skip-reviews)
Phase 12: Create Tasks              (generates tasks.md)
Phase 13: Verify                    (implementation-readiness gate)
```

---

## Phase Handoff Contracts

| Phase | Produces | Next phase requires |
|---|---|---|
| 1 — Product Context Check | Confirmed context (pass/override) | Nothing written to disk |
| 2 — Brainstorm / Design Gate | Approved design artifact or waiver | Design decision is explicit before requirements/spec work |
| 3 — Shape Spec | `planning/requirements.md` | `planning/requirements.md` exists |
| 4 — Architecture Creator | `planning/architecture.md` | Architecture decisions are available for spec and task design |
| 5 — Knowledge Pull | `knowledge_sources` context or waiver | Current ecosystem context is available for spec authoring |
| 6 — Write Spec | `spec.md`, `verification/spec-verification.md` | `spec.md` exists, verify-spec passed |
| 7 — Gap Analysis | `planning/gap-analysis-report.md` | Report exists with severity ratings |
| 8 — Gap Closure | Updated `spec.md`, re-run verify-spec | No gaps remain |
| 9 — Verify | Fresh evidence that spec/gap artifacts are current | Reviews may begin |
| 10 — Architect Review | `planning/architect-review.md` | Review recorded (pass or exceptions noted) |
| 11 — Process Optimizer Review | `planning/process-optimizer-review.md` | Review recorded (pass or exceptions noted) |
| 12 — Create Tasks | `tasks.md` | Tasks exist |
| 13 — Verify | Fresh evidence that `spec.md` and `tasks.md` are ready | Ready for `implement-tasks` |
### Contract impact planning invariant

Phases 2–6 use the shared `contract_impact_preflight` port at final handoff.
Contract-relevant work must resolve one canonical implementation target and
carry a valid, fresh planned record through requirements, architecture, and
spec verification. Persist only stable ID/path/revision/fingerprint and
blocker references. Evidenced not-applicable passes without ledger creation.
Ambiguous targets, missing required classes, stale evidence, invalid records,
or failed required adapters block. A failed handoff preserves the prior
record/audit and downstream revision claims.


---

## Phase 1: Product Context Check

Run once at pipeline entry. Do not repeat in subsequent phases.

{{include workflows/_shared/specification/product-context-check}}

### Handoff Context Check (Phase 1 addition)

After the product context file check, before routing to Phase 2, check for upstream OS handoff state files:

```
.dev-os/state/marketing-handoff.json  ← Marketing OS
.dev-os/state/creative-handoff.json   ← Creative OS
.dev-os/state/design-handoff.json     ← Design OS
.dev-os/state/research-handoff.json   ← Research OS
```

**If any are present**, display a one-line advisory:

```
Handoff context active — [N] OS package(s) consumed. Run brainstorm to use this context.
→ shape-spec Step 2b will inject marketing and creative context into requirements writing.
```

**If none are present:** skip silently — no output, no error.

**Scope boundary:** This check fires only when Phase 1 is entered naturally (pipeline start). When `--from spec` or `--from tasks` are passed, Phase 1 is skipped entirely — the handoff notice is not surfaced for resume scenarios. `brainstorm` and `shape-spec` still read handoff state directly regardless of pipeline entry point.

**Skip condition:** Skip if resuming at Phase 3 or later and the check was already recorded in this session.

---

## Phase 2: Brainstorm / Design Gate

Before shaping requirements or writing a spec, confirm whether an approved design artifact already exists for this feature.

- If no approved design exists, route into `brainstorm`.
- If an approved design exists, cite the artifact and proceed.
- If the user explicitly waives brainstorm, record an approved-design waiver with the reason before proceeding.

`brainstorm` is the default front door for new feature, architecture, workflow, standards, or implementation work that would otherwise begin from an unexamined idea. This gate is skipped only for resumes at `--from spec` or later where a spec already exists.

## Phase 3: Shape Spec

Collect requirements, constraints, and success criteria. For eligible specs, capture emotional direction and generate a design preview.

- Route into `{{workflows/specification/shape-spec}}`
- Output: `product/specs/[this-spec]/planning/requirements.md`
- **Skip condition:** Skip if `planning/requirements.md` already exists and `--from spec` or later was passed

---

## Phase 4: Architecture Creator

Run `architecture-creator` after requirements are shaped and before spec authoring. The architecture package gives the spec and task list concrete module boundaries, integration contracts, ADR candidates, and fitness checks instead of leaving those decisions implicit.

- Route into `architecture-creator` in Spec-Backed Mode when `planning/requirements.md` exists.
- Output: `product/specs/[this-spec]/planning/architecture.md`
- For greenfield project creation, also allow the primary architecture package at `product/architecture/YYYY-MM-DD-<project>-architecture.md`.
- **Approval gate:** Interactive runs pause for human approve/revise on the generated architecture before Phase 5. Headless autonomous runs record canonical `auto-approved` only after persisting the artifact, with headless context in approval provenance.
- **Reuse condition:** Reuse only when `planning/architecture.md` already exists and `verify` confirms it is current for the active requirements. No waiver or opt-out path exists for this phase.

---

## Phase 5: Knowledge Pull

Run the shared knowledge-pull step before spec authoring unless the workflow is pure local structure/git/file movement or a prior phase in the same session already pulled the same current targets.

{{workflows/_shared/knowledge/knowledge-pull-step}}

Legacy `--skip-docs` is treated as an explicit knowledge waiver. Prefer `--skip-knowledge-pull` in new workflow text because this step covers current ecosystem knowledge, not just documentation.

---

## Phase 6: Write Spec

Draft `spec.md` from requirements. Run `verify-spec` immediately after writing.

- Route into `{{workflows/specification/write-spec}}`
- Output: `product/specs/[this-spec]/spec.md` + `verification/spec-verification.md`
- **Skip condition:** Skip if `spec.md` already exists and `--from tasks` was passed
- **Gate:** `verify-spec` must pass (or pass-with-warnings) before proceeding. A FAIL status blocks Phase 7.

---

## Phase 7: Gap Analysis

**Always runs. Not skippable. `--skip-reviews` does not affect this phase.**

Run `gap-analysis --mode 6 --converge` (Multi-Angle with convergence) against the completed `spec.md`. Multi-angle cross-references process gaps, codebase wiring, and friction in a single pass — catching compound issues that Mode 2 alone misses. The convergence loop re-analyzes after gap closure until 0 new gaps remain, eliminating the hidden-layer problem where fixing one gap unmasks another.

Override with `--mode N` to force a specific mode (e.g., `--mode 2` for process-only on simple specs).

### What to analyse

- **Coverage gaps** — requirements in `planning/requirements.md` that are not addressed in `spec.md`
- **Undefined edge cases** — acceptance criteria that lack failure/error paths
- **Missing non-goals** — scope boundaries that are implied but not stated
- **Dependency gaps** — integrations or services referenced but not specified
- **Testability gaps** — success criteria that cannot be objectively validated

### Severity thresholds

| Severity | Definition | Action |
|---|---|---|
| CRITICAL | Gap would cause implementation to fail or ship the wrong thing | Phase 8 closure required |
| HIGH | Gap would cause significant rework after implementation starts | Phase 8 closure required |
| MEDIUM | Gap is a risk but implementation can proceed with caution | Phase 8 closure required |
| LOW | Minor omission with negligible implementation impact | Phase 8 closure required |

### Output

Write findings to `product/specs/[this-spec]/planning/gap-analysis-report.md`:

```markdown
# Gap Analysis Report: [spec-name]

**Date:** [date]
**Status:** [Clean | Warnings | Gaps Found]
**CRITICAL gaps:** N
**HIGH gaps:** N
**MEDIUM gaps:** N
**LOW gaps:** N

## Gaps

### [CRITICAL/HIGH/MEDIUM/LOW] [Gap title]
- **Area:** [requirements / edge cases / dependencies / testability]
- **Description:** [what is missing]
- **Impact:** [what breaks or goes wrong without it]
- **Suggested fix:** [what to add to spec.md]

## Warnings (MEDIUM/LOW)
[List with brief description]

## Recommended Next Phase
[Gap Closure required / Proceed to Architect Review]
```

---

## Phase 8: Gap Closure (Conditional)

**Triggered when:** Phase 7 report contains any gap at any severity.
**Skipped when:** Phase 7 report is clean (no gaps).
**All gaps are closed.** If a gap passes the evidence standard, it gets fixed. No severity-based exemptions.

### Process

1. For each gap found:
   - Update `spec.md` to address the gap
   - Update the gap's status to `"closed"` in `product/gap-analysis/gap-registry.jsonl` with `closed_at` date
2. Re-run `{{workflows/specification/verify-spec}}` against the updated spec
3. The convergence loop (`--converge`) re-runs gap analysis automatically to confirm closure and catch newly unmasked gaps
4. If new gaps appear, repeat gap closure for those gaps
5. When all gaps are resolved: proceed to Phase 9

**Gate:** Phase 9 cannot begin while any gap is unresolved.

---

## Phase 9: Verify

Run `verify` before review and task generation. This is the resume safety gate: when an automatic mode starts from `spec`, `tasks`, or a saved session phase, it must verify the artifacts for that point before skipping earlier phases.

Verification must inspect the actual artifacts, not just tracking state:

- `planning/requirements.md` exists or has an explicit waiver
- `planning/architecture.md` exists and is current for the active requirements
- knowledge-pull output or waiver is recorded for external/current dependencies
- `spec.md` exists and `verification/spec-verification.md` is current
- `planning/gap-analysis-report.md` exists and records no unresolved gaps

If verification fails, route to the earliest missing or stale phase instead of continuing from the requested resume point.

---

## Phase 10: Architect Review

**Skippable with `--skip-reviews`.**

A structured technical review of `spec.md` by Claude acting as architect. Purpose: catch technical problems before tasks are created, not after implementation starts.

### Review dimensions

1. **Technical feasibility** — Can the spec be implemented with the project's current stack? Flag anything requiring new runtimes, major version upgrades, or unsupported APIs.

2. **Architecture fit** — Does the spec align with the existing codebase architecture? Check against `product/tech-stack.md` and the project's CLAUDE.md for architectural conventions.

3. **Dependency risks** — Are there third-party services, APIs, or libraries introduced by this spec that add risk? Flag version conflicts, deprecated APIs, and single-points-of-failure.

4. **Security surface** — Does the spec introduce new auth paths, data exposure, or privilege boundaries? Check for missing auth requirements, unvalidated inputs, or exposed secrets.

5. **Scalability concerns** — Are there patterns in the spec that work at current scale but will fail under growth? (N+1 queries, unbounded loops, synchronous chains that should be async.)

6. **Spec completeness vs. codebase** — Does the spec reference files, modules, or APIs that don't exist yet? Is any assumed infrastructure missing?

### Output

Write to `product/specs/[this-spec]/planning/architect-review.md`:

```markdown
# Architect Review: [spec-name]

**Date:** [date]
**Reviewer:** Architect (Claude)
**Status:** [Approved | Approved with Exceptions | Blocked]

## Findings

### [PASS/WARN/BLOCK] [Dimension]
[Finding and recommendation]

## Exceptions (if Approved with Exceptions)
[List of accepted risks with rationale]

## Blockers (if Blocked)
[What must be resolved before create-tasks]
```

**Gate:** BLOCK status prevents Phase 12. WARN and Approved-with-Exceptions may proceed.

---

## Phase 11: Process Optimizer Review

**Skippable with `--skip-reviews`.**

A structured workflow review of `spec.md` and the gap-analysis report. Purpose: ensure the implementation plan is efficient — not just correct — before tasks are written.

### Review dimensions

1. **Task granularity** — Are the spec's functional requirements granular enough to produce 1–2 day tasks? Flag anything that would become a single massive task.

2. **Parallel opportunities** — Which parts of the spec can be implemented independently (in parallel worktrees)? Identify clear dependency boundaries.

3. **Over-engineering detection** — Is anything in the spec more complex than the problem requires? Flag premature abstractions, over-specified interfaces, or YAGNI violations.

4. **Missing edge cases** — Are failure paths, empty states, and error conditions specified? These are often missing from specs and always expensive to add during implementation.

5. **Workflow efficiency** — Does the spec's proposed user journey have unnecessary steps, redundant confirmations, or friction points that could be removed?

6. **Sequencing risks** — Is there a task ordering implied by the spec that would require risky late-stage rewrites? (e.g., data model decisions that affect all other tasks should be first.)

### Output

Write to `product/specs/[this-spec]/planning/process-optimizer-review.md`:

```markdown
# Process Optimizer Review: [spec-name]

**Date:** [date]
**Reviewer:** Process Optimizer (Claude)
**Status:** [Approved | Approved with Recommendations | Blocked]

## Findings

### [PASS/RECOMMEND/BLOCK] [Dimension]
[Finding and recommendation]

## Parallel Opportunities
[List of spec sections that can be implemented in parallel]

## Recommended Task Sequencing
[Suggested order for create-tasks to follow]
```

**Gate:** BLOCK status prevents Phase 12. RECOMMEND status proceeds with notes carried into `create-tasks`.

---

## Phase 12: Create Tasks

Generate `tasks.md` from the approved spec. If Phase 11 produced parallel opportunities or recommended sequencing, apply them here.

### Phase 12 Gate: Source Reality Check

Before writing tasks, run `{{workflows/implementation/source-reality-check}}` to confirm that each
gap and requirement in the spec does not already exist in source files. Claims marked `exists`
are excluded from the task list. Claims marked `partial` are kept with a note.

> Key learning: Before creating tasks from a spec, grep the actual source files to confirm each
> gap still exists. Writing tasks for already-fixed issues wastes implementation cycles and
> creates false "done" accounting.

Skip with `--skip-source-check` only for refactor specs or if check already ran this session.

- Route into `create-tasks`
- Input: `spec.md` + `planning/process-optimizer-review.md` (if it exists)
- Output: `product/specs/[this-spec]/tasks.md`
- **Skip condition:** Skip if `tasks.md` already exists, is current, and resume was requested at `--from tasks`

---

## Phase 13: Verify

Run `verify` after task creation and before handing off to implementation. This proves the implementation-readiness claim with fresh evidence instead of treating `tasks.md` as sufficient.

Verification must inspect:

- `spec.md`
- `planning/architecture.md`
- `planning/gap-analysis-report.md`
- `tasks.md`
- the source-reality check output when source code already exists

If verification fails, route back to the earliest stale or missing phase.

---

## Flag Behaviour

| Flag | Effect on pipeline |
|---|---|
| `--skip-reviews` | Skips Phase 10 and Phase 11. Phase 7 (gap-analysis) and verify gates still run. |
| `--skip-knowledge-pull` | Explicitly waives Phase 5 knowledge-pull. Requires a reason unless the work is pure local structure/git/file movement. |
| `--skip-docs` | Legacy alias for `--skip-knowledge-pull`. Avoid in new workflow text. |
| `--no-pause` | Removes interactive pause points between phases. Gates still apply. |
| `--from spec` | Requested entry at Phase 6. First run Phase 9 verify against available planning artifacts; route backward if evidence is stale or missing. |
| `--from tasks` | Requested entry at Phase 13. First run Phase 13 verify against implementation-readiness artifacts; route backward if evidence is stale or missing. |
| `--skip-brainstorm` | Legacy alias for an approved-design waiver at Phase 2. Avoid in new workflow text. |
| `--skip-writing-plans` | Skips writing-plans skill invocation at Phase 12. `create-tasks` runs directly. |

---

## Resume Rules

When resuming mid-pipeline, run `verify` for the requested entry point, then determine the earliest incomplete phase by checking artifact existence and freshness:

| Missing artifact | Resume at phase |
|---|---|
| Approved design artifact or waiver | Phase 2 |
| `planning/requirements.md` | Phase 3 |
| `planning/architecture.md` | Phase 4 |
| `knowledge_sources` context or waiver | Phase 5 |
| `spec.md` | Phase 6 |
| `planning/gap-analysis-report.md` | Phase 7 |
| Gap-analysis shows unresolved gaps at any severity | Phase 8 |
| planning artifacts need fresh evidence | Phase 9 |
| `planning/architect-review.md` | Phase 10 (unless `--skip-reviews`) |
| `planning/process-optimizer-review.md` | Phase 11 (unless `--skip-reviews`) |
| `tasks.md` | Phase 12 |
| implementation-readiness evidence missing | Phase 13 |

---

## Display Format

```
Planning Pipeline: [spec-name]
──────────────────────────────────────────
  Phase 1  Product Context Check    ✓ passed
  Phase 2  Brainstorm / Design Gate ✓ approved
  Phase 3  Shape Spec               ✓ requirements.md written
  Phase 4  Architecture Creator     ✓ architecture.md written
  Phase 5  Knowledge Pull           ✓ current context loaded
  Phase 6  Write Spec               ✓ spec.md written, verify-spec passed
  Phase 7  Gap Analysis             ⚠ 2 HIGH gaps found → Phase 8 required
  Phase 8  Gap Closure              ✓ gaps resolved, spec updated
  Phase 9  Verify                   ✓ planning artifacts current
  Phase 10 Architect Review         ✓ approved with 1 exception (noted)
  Phase 11 Process Optimizer        ✓ 3 parallel opportunities identified
  Phase 12 Create Tasks             ✓ tasks.md written (12 tasks)
  Phase 13 Verify                   ✓ implementation readiness confirmed
──────────────────────────────────────────
Pipeline complete → run implement-tasks
```

Status symbols: `✓` complete · `⚠` warning/conditional · `↻` in progress · `—` skipped · `✗` blocked

---

## Failure Handling

| Failure | Action |
|---|---|
| verify-spec FAIL (Phase 6) | Stop. Fix spec issues. Re-run write-spec before proceeding. |
| Gap analysis any severity (Phase 7) | Stop. Phase 8 gap closure required — all gaps closed before reviews. |
| Verify FAIL (Phase 9 or Phase 13) | Stop. Route to the earliest stale or missing canonical operation. |
| Architect review BLOCK (Phase 10) | Stop. Resolve blockers in spec.md. Re-run architect review. |
| Process optimizer BLOCK (Phase 11) | Stop. Resolve blockers in spec.md. Re-run process optimizer review. |
| Gap closure introduces new gaps (Phase 8) | Loop Phase 8 for new gaps only. Maximum 3 loops before escalating to user. |
