<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/pipeline-spec-task-gate.md and re-run profile-sync. -->
# Standard: Pipeline Spec/Task Gate

**Category:** maintenance
**Version:** 1.1.0
**Created:** 2026-04-19
**Status:** active

## Rule

Any pipeline that creates, edits, or deletes implementation files in a project MUST have a corresponding traceable spec+tasks entry before implementation begins:

- `product/specs/YYYY-MM-DD-<slug>/spec.md` — written via `write-spec`
- `tasks.md` at `product/specs/<slug>/tasks.md` OR `product/specs/<slug>/planning/tasks.md` — written via `create-tasks`
- Entry in `product/specs/feature-backlog.md`

For `gap-analysis --fix`, the same rule applies per gap. A gap may skip spec/tasks only when it is explicitly classified as a direct local fix and records a waiver reason.

## Canonical spec entry points

Non-trivial product, implementation, architecture, workflow, or user-facing
changes MUST enter the planning pipeline through a canonical entry point:

- `/brainstorm` — use when the problem, scope, approach, or trade-offs are not
  already approved. It produces the design decision and approval trail before
  requirements are shaped.
- `/shape-spec` — use when the request is ready for structured requirements
  gathering. It produces the shaped requirements artifact and invokes the
  brainstorm path when its design gate determines that exploration is needed.

Do not hand-roll a first draft of `spec.md`, `planning/requirements.md`,
`tasks.md`, architecture artifacts, gap reports, or review records. These are
owned by the canonical planning skills (`brainstorm`, `shape-spec`, `write-spec`,
`architecture-creator`, `gap-analysis`, `create-tasks`, and `implement-tasks`).
Human feedback MAY revise an existing canonical artifact only inside the owning
skill's documented review or gap-closure loop.

### Entry-point selection

| Starting state | Required entry |
|---|---|
| Raw idea, unclear approach, or competing designs | `/brainstorm` → `/shape-spec` |
| Clear requirements but no shaped artifact | `/shape-spec` |
| Approved `planning/requirements.md` exists | Resume at `write-spec` |
| Approved `spec.md` exists but no clean gap report | Resume at `gap-analysis --dalio --converge --fix` |
| Existing `tasks.md` has unchecked items | Resume at `implement-tasks` |
| Tiny, single-root-cause change meeting every quick-fix exemption | `quick-fix`, with the waiver recorded |

Existing approved artifacts are resume points, not permission to bypass their
missing predecessor. `orchestrate` MAY select the resume point, but it MUST NOT
invent a parallel planning path.

## Canonical build process

The standard feature path is:

`/brainstorm` (when required) → `/shape-spec` → `write-spec` →
`architecture-creator` → `gap-analysis --dalio --converge --fix` →
architect/process reviews → source-reality check → `create-tasks` →
`implement-tasks` → `test`/`harden` → verification → review/docs/merge as
applicable.

Every transition MUST be gated by the artifact produced by the preceding
stage. The canonical pipeline definition is
[`feature-delivery.md`](../../workflows/pipelines/feature-delivery.md); this
standard does not create a second ordering that can drift from it.

## Paper-trail requirements

For every non-exempt run, the spec directory MUST preserve the dated, linked
record of:

1. approved design or explicit design waiver;
2. shaped requirements;
3. formal specification and spec verification;
4. architecture artifact and approval outcome;
5. gap-analysis report and registry trace;
6. architect/process review outcomes;
7. source-reality findings;
8. generated tasks and implementation checkoffs; and
9. verification, review, documentation, and merge evidence where applicable.

If a stage is skipped because the work resumes from an existing artifact, the
resume reason and the artifact that satisfied the gate MUST be recorded. If a
quick-fix or direct-fix exemption applies, record the exact exemption criteria
and verification evidence; "small" or "obvious" is not a waiver.

## Named framework anchors

- **RFC 2119 normative vocabulary:** `MUST`, `MUST NOT`, `SHOULD`, and `MAY`
  make entry rules and exemptions mechanically reviewable.
- **DRY / Single Source of Truth:** canonical skills own each planning artifact;
  parallel hand-authored copies create drift between the design, requirements,
  tasks, and implementation record.
- **Walking Skeleton (Cockburn):** the ordered pipeline proves the smallest
  end-to-end delivery path before the implementation surface expands.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Writing `spec.md` directly from a chat request | Skips scope, design, requirements, and approval evidence | Start with `/brainstorm` or `/shape-spec` |
| Running `write-spec` against an unshaped idea | Produces a formal document with hidden assumptions | Shape requirements first |
| Creating `tasks.md` by hand | Loses source-reality checks, priorities, and task ownership | Run `create-tasks --spec <slug>` |
| Implementing before gap convergence | Ships known design, wiring, or process gaps | Run the required gap-analysis gate |
| Marking a skipped stage as "not needed" without evidence | Breaks resume safety and auditability | Record the explicit waiver or resume artifact |

## Deviation guidance

The only default deviation is the existing `quick-fix` exemption above. A
different deviation MAY be used only when the owning canonical skill is
unavailable or the work is a documented resume from an equivalent approved
artifact. In either case, record the missing skill or equivalence evidence,
the reason, the exact files affected, and the verification command in the
spec or gap-analysis record. Silent manual authoring is prohibited.

## Compliance test

- [ ] Did the work begin through `/brainstorm` or `/shape-spec`, or use a recorded quick-fix/resume exemption?
- [ ] Were all planning artifacts created or revised by their owning canonical skill rather than hand-rolled?
- [ ] Does the spec directory contain the design, requirements, spec verification, architecture, gap, review, task, and verification trail required for its stage?
- [ ] Did each stage consume the preceding artifact and stop when its gate failed?
- [ ] Can a reviewer identify the exact next step, skipped-stage reason, and verification evidence from the artifacts alone?

If any check fails: stop implementation, route the work back through the
missing canonical entry point, and record the remediation in the existing spec
or gap-analysis trail.


## Rationale

Without this gate, pipelines do real work with no auditable trail. `triage`, `project-status`, and `gap-analysis` cannot surface or track the work. Completed work is invisible to retrospectives and the series gap analysis.

## Covered pipelines

| Pipeline | Compliant | Notes |
|----------|-----------|-------|
| `deliver-product-slice` | ✅ | Follows the canonical feature-build process: write-spec, create-tasks, verify, implement-tasks |
| `gap-analysis --fix` / `--converge` | ✅ | Fix phase mandates write-spec + create-tasks + verify before implement-tasks |
| `close-all-gaps` | ✅ | Step 3b mandates write-spec + create-tasks before Step 4 |
| `autonomous` | ✅ | `auto_phase_tasks()` explicitly calls create-tasks |
| `quick-fix` | ✅ (exempt) | <50 lines, single root cause — see exemption below |

## Exemptions

### quick-fix exemption
Fixes that meet ALL of the following are exempt:
- Total diff < 50 lines
- Single clear root cause
- No new dependencies, no migrations, no schema/API changes
- Verifiable in one command

If a fix grows past any boundary, the exemption is revoked — halt and redirect to `write-spec`.

### gap-analysis direct-fix waiver

`gap-analysis --fix` may close a gap without a new spec/tasks package only when ALL of the following are true:

- The change is single-file OR docs-only
- No behavior, runtime wiring, API, schema, deployment, security, or user-facing flow changes
- The registry entry records `spec_not_required: true`
- The registry entry or report records `waiver_reason`
- `closed_by` still contains concrete verification evidence

If any condition is false, create or update `product/specs/YYYY-MM-DD-<slug>/spec.md` and `tasks.md` before implementation.

## tasks.md path resolution

All pipelines and diagnostic tools MUST resolve `tasks.md` using this dual-path check:

```bash
if [[ -f "$spec_dir/tasks.md" ]]; then
    tasks_file="$spec_dir/tasks.md"
elif [[ -f "$spec_dir/planning/tasks.md" ]]; then
    tasks_file="$spec_dir/planning/tasks.md"
else
    # tasks.md missing — emit finding
    tasks_file="$spec_dir/tasks.md"
fi
```

Never check only the root path. Specs using the `planning/` layout are valid.

## Enforcement

- `triage` Scan 2 surfaces specs missing tasks.md (using dual-path check)
- `gap-registry.jsonl` tracks open gaps; unlinked gap closures (no spec entry) surface in series gap analysis (Mode 5)
- Pipelines that skip this gate will produce untracked implementation work that `triage` cannot surface

## References

- `maintenance/command-skill-split.md` — related: skills do the work, commands are thin wrappers
- `global/verification-before-implementation.md` — verify spec exists before coding
- `product/gap-analysis/2026-04-19-pipeline-spec-task-alignment.md` — origin gap analysis
- [Feature Delivery Pipeline](../../workflows/pipelines/feature-delivery.md) — canonical ordered build process and resume gates
- [`brainstorm` skill](../../../../.claude/skills/brainstorm/SKILL.md) — design approval gate
- [`shape-spec` skill](../../../../.claude/skills/shape-spec/SKILL.md) — requirements shaping and architecture gate
- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) — normative vocabulary
- [The Pragmatic Programmer — DRY](https://pragprog.com/tips/) — one authoritative representation of knowledge
- [Walking Skeleton](https://alistair.cockburn.us/writing-effective-use-cases/) — prove the end-to-end path early

