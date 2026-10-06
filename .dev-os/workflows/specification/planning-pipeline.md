# Planning Pipeline

Single source of truth for the DevOS planning sequence. `shape-spec` owns requirements, contract pinning, architecture approval, requirements-gap convergence, and exactly-once `write-spec` and `create-tasks` continuations. Lifecycle workflows may consume its durable outputs, but must not repeat those planning operations.

## When to Use

Consumed by:
- `autonomous-phases.md` — planning and write-spec phases
- `shape-spec` — the planning owner and entry point
- `architecture-creator` — invoked by shape-spec for architecture approval
- `write-spec` and `create-tasks` — exactly-once continuations owned by shape-spec

The pipeline ends at implementation-ready tasks. Implementation follows `autonomous-phases.md`.
Avoid using this pipeline to repeat a completed phase; resume at the earliest incomplete gate.

## Canonical Phase Sequence

1. **Product Context Check** — once at pipeline entry.
2. **Brainstorm / Design Gate** — approved design or explicit waiver.
3. **Shape Spec** — requirements, contract plan, architecture approval, gap convergence, spec, and tasks. `shape-spec` invokes each downstream continuation at most once.
4. **Implementation-Readiness Verify** — fresh evidence for the spec, tasks, approved architecture, and converged gap report.

Do not model architecture creation, knowledge pull, write-spec, gap analysis/closure, planning reviews, or task creation as separate lifecycle phases. Their canonical execution belongs inside the shape-spec planning owner and its child skills.

## Phase Handoff Contracts

| Phase | Produces | Next phase requires |
|---|---|---|
| Product Context Check | Confirmed context or recorded override | Nothing written to disk |
| Brainstorm / Design Gate | Approved design or explicit waiver | Design decision is explicit before requirements work |
| Shape Spec | `planning/requirements.md`, contract record, approved `planning/architecture.md`, converged gap report, `spec.md`, and `tasks.md` | All required gates pass; both downstream continuations are recorded exactly once |
| Implementation-Readiness Verify | Fresh verification evidence | Ready for `implement-tasks` |

### Contract impact planning invariant

Shape-spec plans and enforces the contract-impact record before architecture approval and final handoff. Contract-relevant work must resolve one canonical implementation target and carry a valid, fresh planned record through requirements, architecture, and spec verification. Persist only stable ID/path/revision/fingerprint and blocker references. Evidenced not-applicable passes without ledger creation. Ambiguous targets, missing required classes, stale evidence, invalid records, or failed required adapters block. A failed handoff preserves the prior record/audit and downstream revision claims.

## Phase 1: Product Context Check

Run once at pipeline entry. Read `product/mission.md`, `product/roadmap.md`, and `product/tech-stack.md` when present; note missing files without blocking. Check for upstream OS handoff state at `.dev-os/state/{marketing,creative,design,research}-handoff.json`; if present, report the active handoffs. Do not repeat this check when resuming later phases.

## Phase 2: Brainstorm / Design Gate

Before shaping requirements, cite an existing approved design, route to `brainstorm`, or record an explicit approved-design waiver with its reason. A waiver is not a substitute for architecture approval or any shape-spec gate.

## Phase 3: Shape Spec

Route once to `shape-spec`. It owns the planning sequence and resumes from durable artifacts and invocation markers:

- Plan and enforce contract impact before implementation planning.
- Produce and obtain approval for `planning/architecture.md`; no silent skip.
- Run requirements gap analysis with convergence; a non-converged result blocks downstream work.
- **Downstream handoff gate:** `write-spec` and `create-tasks` may run only after both architecture approval and converged requirements gaps are freshly verified for the active spec. Missing, stale, or unapproved architecture, or any unresolved requirements gap, blocks both handoffs.
- Invoke `write-spec --spec <dated-spec>` exactly once after prerequisites pass.
- Invoke `create-tasks --spec <dated-spec>` exactly once after write-spec succeeds.

The handoff predicate is:

```text
approved architecture && converged requirements gaps && current contract record
  → write-spec (once) → create-tasks (once)
```

The downstream skills remain independent owners of their own implementation. A lifecycle workflow that starts from existing artifacts verifies freshness and continues; it does not recreate, rewrite, or re-run a completed planning phase.

**Gate:** requirements, contract plan, approved architecture, converged requirements gaps, verified spec, and tasks must all be present and current. A missing or stale artifact routes to the earliest incomplete shape-spec gate.

## Phase 4: Implementation-Readiness Verify

Run `verify` against the actual artifacts and the current task plan. It must inspect:

- `planning/requirements.md` and the contract-impact record when applicable
- `planning/architecture.md` and its approval evidence
- the final requirements gap report, with zero unresolved gaps
- `spec.md` and `verification/spec-verification.md`
- `tasks.md` and source-reality evidence when source code exists

Verification failure routes to the earliest missing or stale shape-spec gate. A valid task file alone is not proof of readiness.

## Flags

| Flag | Effect |
|---|---|
| `--skip-reviews` | Does not bypass architecture approval, contract impact, gap convergence, spec verification, or exactly-once continuations. |
| `--skip-knowledge-pull` / legacy `--skip-docs` | A knowledge waiver is recorded by the owning shape-spec workflow; it does not bypass other gates. |
| `--no-pause` | Removes optional pauses; required approval and verification gates still apply. |
| `--from spec` | Verify available artifacts, then resume shape-spec at its earliest incomplete gate. |
| `--from tasks` | Verify implementation-readiness evidence before proceeding to implementation. |
| `--skip-brainstorm` | Legacy alias for an explicit approved-design waiver. |

## Resume Rules

First verify the requested entry point, then resume from the earliest incomplete or stale owner artifact:

| Missing or stale artifact | Resume action |
|---|---|
| Approved design or waiver | Phase 2: Brainstorm / Design Gate |
| `planning/requirements.md` | Phase 3: shape-spec requirements |
| Contract record or valid target | Phase 3: shape-spec contract planning |
| Current approved `planning/architecture.md` | Phase 3: shape-spec architecture gate |
| Converged requirements gap report | Phase 3: shape-spec gap convergence |
| `spec.md` or current spec verification | Phase 3: exactly-once write-spec continuation |
| `tasks.md` | Phase 3: exactly-once create-tasks continuation |
| Fresh implementation-readiness evidence | Phase 4: Verify |

Never infer completion from a phase label, marker alone, or file existence alone. Reuse a completed artifact only when its owning verifier reports it current.

## Display Format

```text
Planning Pipeline: [spec-name]
  Phase 1  Product Context Check          ✓ passed
  Phase 2  Brainstorm / Design Gate       ✓ approved
  Phase 3  Shape Spec                    ✓ planning gates complete
  Phase 4  Implementation-Readiness Verify ✓ ready
Pipeline complete → run implement-tasks
```

Status symbols: `✓` complete · `⚠` warning/conditional · `↻` in progress · `—` skipped · `✗` blocked.

## Failure Handling

| Failure | Action |
|---|---|
| Design is missing or unapproved | Stop at Phase 2; obtain approval or record an explicit waiver. |
| Contract target, record, or required class is invalid | Stop; resolve the reported contract-impact blocker before continuing. |
| Architecture is missing, stale, or unapproved | Stop at Phase 3; resume shape-spec architecture approval. |
| Gap convergence fails or gaps remain | Stop at Phase 3; resolve gaps and resume shape-spec convergence. |
| write-spec or create-tasks fails | Preserve the invocation outcome; resume through shape-spec without retrying a completed continuation. |
| Implementation-readiness verification fails | Stop; route to the earliest missing or stale shape-spec gate. |
