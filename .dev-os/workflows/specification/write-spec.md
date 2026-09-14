# Write Specification Workflow

Create or update `product/specs/[this-spec]/spec.md` from planned requirements.

> **Naming rule:** `[this-spec]` must always be in `YYYY-MM-DD-<slug>` format. If the spec directory was created by `shape-spec` and is already dated, use it as-is. If it is not dated, prepend today's date (`date +%Y-%m-%d`) before creating any files.

## When to Use

Run this workflow to create or update `spec.md` from gathered requirements. Use it after `shape-spec` completes or when updating an existing spec to add acceptance criteria.

Do not use this workflow as the first step in a spec — run `shape-spec` first to confirm scope and gather requirements, then invoke this workflow.

## Step 0: Knowledge Pull

<!-- per profiles/general/standards/global/knowledge-pull.md -->

{{workflows/_shared/knowledge/knowledge-pull-step}}

After completing the knowledge pull, the `knowledge_sources` entries are ready for the spec.md header. Proceed to write the spec.

## Step 0b: Frontend Scope Check

{{workflows/_shared/skills/frontend-scope-detection}}

**If `frontend_scope = true`** (skill is now loaded and active):

When writing the spec, include a `## Frontend Design Guidance` section before the Acceptance Criteria section. Use this canonical template:

```markdown
## Frontend Design Guidance

> **Frontend Design:** This spec uses the `frontend-design` skill for all UI implementation. Aesthetic direction must be established before coding begins.

Named aesthetic direction: [choose one, e.g. "refined utility", "editorial boldness", "warm brutalism"]

Key constraints from the skill:
- Typography: distinctive font pairing (avoid Inter, Roboto, Arial, system fonts)
- Color: one dominant (60%), one supporting (30%), one sharp accent (10%) — accent in ≤ 3 places
- Motion: purposeful only — staggered reveals, hover states; no animation on task-completion feedback
- Layout: at least one grid-breaking element in non-functional sections
```

If `planning/design-system.md` exists, reference its approved tokens in the spec's technical design section instead of specifying new ones.

**If `frontend_scope = false`:** Skip this step silently. Do not add a Frontend Design Guidance section.

## Step 0c: JTBD Product Context Probe

Before drafting the spec, run a lightweight jobs-to-be-done check to surface product gaps the requirements may not have captured.

Ask the user (or infer from project context if clear):

1. **What are the top 2-3 jobs a user needs to complete in this feature area?** (e.g. "generate a report", "invite a team member", "review a submission")
2. **For each job: does the current product complete it end-to-end without leaving the product or a manual workaround?**
3. **Is there anything a user would expect to be able to do here that the spec doesn't address?**

**Hard gate:** Run this step for every spec, including infrastructure, internal
tooling, refactors, and brainstorm-sourced specs. For non-product work, frame jobs
around the operator, developer, maintainer, or downstream automation consumer.
Prior JTBD is reused and verified, not skipped.

The only authorized skip requires an explicit user request containing both
`--skip-jtbd` and `--jtbd-skip-reason "<non-empty reason>"`. Persist the reason.
A bare `--skip-jtbd` is invalid. Model inference never authorizes a skip.

**On completion:** Always append or update `## Product Context (JTBD)` in
`planning/requirements.md` and mirror it into `spec.md`, even when no gaps are
found.

## Process

1. Read `product/specs/[this-spec]/planning/requirements.md`.
2. **Pre-spec evidence gate — run BEFORE creating any file.** The gate derives
   the change surface itself from declared metadata (`planning/requirements.md`
   frontmatter, `planning/metadata.yml`, and the owner/target this workflow
   already declares). Pass the declaration this run already knows — never a
   guessed surface; never `--change-surface` outside test fixtures. The
   resolver wins over any caller-supplied label, and `undeclared` fails
   closed with exit 2 (`SURFACE_UNDECLARED`) rather than silently passing.
   Run under bash (not zsh):

   ```bash
   source scripts/lib/spec-evidence-gate.sh
   spec_evidence_gate \
     --spec-dir product/specs/[this-spec] \
     --declared-owner <declared-owner-os> \
     --declared-target <declared-implementation-target> \
     --target <declared-target-system> \
     --output terminal
   ```

   - Exit 2 `SURFACE_UNDECLARED`: nothing declares the change surface. Add the
     declaration (requirements frontmatter `change_surface`/`affected_paths`,
     or the owner/target this workflow declares) and rerun. Undeclared is not
     product and never passes silently.
   - Exit 2 other: fix the invocation.
   - Exit 1 (blocked): a DevOS process/policy, execution-alignment, hook,
     host-adapter, or OMP integration surface lacks complete evidence. Do not
     create `spec.md`. Produce the missing ground-truth reconciliation and/or
     Dalio process gap-analysis artifact, link both from
     `planning/requirements.md`, and rerun.
   - Exit 0 (pass): proceed to step 3. The output states whether the gate was
     applicable and, for a no-change analysis, reports
     `disposition: no-change`.

   **Explicit no-change disposition:** when the Dalio analysis recommends no
   change, record `change_disposition: no-change` in the gap-analysis
   frontmatter. The gate then passes without a ranked proposed change and
   reports `disposition: no-change`. Omitting the field while also omitting a
   `## Binding Constraint` section blocks the spec (`BINDING_CONSTRAINT_MISSING`);
   a no-change outcome is only legitimate when declared explicitly.
3. Write `spec.md` with summary, scope, functional design, and success criteria.
4. Ensure paths use canonical `product/` layout.
5. Save verification notes to `product/specs/[this-spec]/verification/spec-verification.md`.
## Contract impact verification

Before reporting a successful spec verification, invoke the shared
`contract_impact_preflight --mode verify --phase planning` port for the canonical target and
record. Contract-relevant specs require a valid fresh target-matched planned
record (or permitted later state), complete required-class coverage, and a
`## Contract Impact` section. Missing/ambiguous/stale/invalid/blocked evidence
fails verification. A complete evidenced not-applicable receipt passes without
ledger creation.

Only stable record ID/path/revision/digest/fingerprint and blocker references
may be persisted in the spec. Do not copy record rows or policy. If a handoff
fails, preserve the prior record/audit and make no newer downstream revision
claim.


## Display Format

```
Spec written: product/specs/[spec-name]/spec.md
  Sections:     [N] (requirements, acceptance criteria, risks, knowledge sources)
  Frontend:     [yes — frontend-design skill active | no]
  Next: create-tasks --spec [spec-name]
```
