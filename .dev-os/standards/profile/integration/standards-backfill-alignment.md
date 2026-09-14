<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/integration/standards-backfill-alignment.md and re-run profile-sync. -->
# Standards Backfill Alignment Standard

## Overview

A new standard creates a new contract for future work, but existing features do not become compliant just because the standard exists. Without a backfill pass, the system produces a false sense of governance: new specs obey the rule while older integrations, docs, skills, workflows, and runbooks continue to violate it silently.

This standard defines the required backfill loop whenever DevOS authors or materially changes a standard. It applies the Toyota/Lean idea of standard work plus gap closure: define the new standard, find current-state drift, create remediation tasks, and verify alignment.

## Scope

This standard covers backfill alignment after a new or changed standard is introduced. It does NOT cover the content requirements of any individual standard; those belong in that standard itself.

## Principles

1. **A standard is not adopted until existing surfaces are assessed:** Future-only rules leave silent historical drift.
2. **Backfill is evidence-based, not vibes-based:** Search/read concrete surfaces and record exactly what is aligned, drifted, or waived.
3. **Alignment work belongs in specs/tasks:** Nontrivial backfill changes must be tracked like product work, not hand-edited opportunistically.
4. **Waivers are explicit:** Some legacy surfaces may remain noncompliant, but only with a dated reason and owner.
5. **Verification closes the loop:** A standard change is complete only when the backfill report or task list can be re-run or audited.

## Rules

### R1 — Every new or material standard change triggers a backfill scan (`MUST`)

When a standard is created or materially updated, the author MUST identify affected surface classes and run a scan for existing artifacts that should comply.

Examples:

| Standard topic | Required backfill surfaces |
|---|---|
| Integration documentation | `docs/integrations/`, `docs/runbooks/`, integration specs, MCP/CLI/OAuth/scheduler specs |
| Skill authoring | `.claude/skills/*/SKILL.md`, skill templates, skill validation tests |
| Hook safety | `.claude/settings*.json`, `.claude/hooks/`, `scripts/hooks/`, hook specs/tests |
| Artifact ownership | `docs/context/`, generated reports, runtime state files, ownership manifest |

### R2 — Backfill scan output uses three states (`MUST`)

Each affected surface MUST be classified as one of:

- `aligned` — already satisfies the new standard.
- `drifted` — should satisfy the new standard but does not.
- `waived` — intentionally not aligned, with reason, owner, and review date.

Use a simple table in a gap report, spec planning file, or backfill manifest:

```markdown
| Surface | State | Evidence | Action |
|---|---|---|---|
| docs/integrations/hermes-scheduling.md | aligned | has setup/verify/rollback sections | none |
| product/specs/2026-06-23-rtk-integration/tasks.md | drifted | no integration-doc task | add task |
| legacy one-off helper | waived | no external runtime / no operator action | revisit 2026-09-01 |
```

### R3 — Drift becomes work, not a note (`MUST`)

Every `drifted` surface MUST be converted into one of:

1. A task in the active spec's `tasks.md`.
2. A new backfill spec under `product/specs/YYYY-MM-DD-<standard>-backfill/`.
3. A gap-registry entry with `blocked_by_spec` or `remediation_task` when deferred.

A drift row with no task, spec, gap entry, or waiver is noncompliant.

### R4 — Backfill scope is bounded before edits (`MUST`)

Before changing existing surfaces, define scope using the ISO Scope Pattern:

> This backfill covers [artifact class] affected by [standard]. It does NOT cover [adjacent artifact class].

If the backfill needs multiple artifact classes with different owners, split into separate task groups or specs.

### R5 — Backfill does not rewrite unrelated history (`MUST NOT`)

Do not bulk-edit historical reports/specs solely to make them look compliant. Backfill live operational surfaces first: current docs, runbooks, active specs, templates, generators, validators, and checkers. Historical specs may receive a note or waiver only when they are still used as current operator documentation.

### R6 — Enforcement hooks are separate from standards (`SHOULD`)

A standard SHOULD name where enforcement belongs, but the standard itself does not implement enforcement. Use the right owner:

| Enforcement need | Owner |
|---|---|
| Spec/task requirement | `write-spec`, `create-tasks`, active spec templates |
| Documentation drift | `docs-sync`, `docs-verify`, `audit-docs` |
| Project health surfacing | `triage`, `project-status`, `health` |
| Gap closure | `gap-analysis`, `implement-tasks` |
| Specialized artifact quality | `bx-*-creator` skills |

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Create a standard and stop | Existing work remains noncompliant and invisible | Run a backfill scan and create tasks for drift |
| Search only filenames | Misses docs embedded in specs, generated context, or runbooks | Search by concepts and read candidate files |
| Bulk edit old reports | Creates churn without improving live behavior | Backfill current operational surfaces first |
| Drift row with no owner | Nobody fixes it | Convert drift to task/spec/gap or waiver |
| Standard implements enforcement directly | Blurs policy and tooling | Standard names enforcement owner; tool implements it |

## Deviation guidance

You MAY skip a backfill scan when the standard is purely prospective and all of the following are true:
1. No existing surface can reasonably be expected to comply.
2. The standard includes a `Prospective only` note with rationale.
3. A follow-up date or trigger is recorded for first adoption review.

You MAY waive individual legacy surfaces when the cost of alignment exceeds current value. The waiver MUST include owner, reason, and review date.

## Backfill procedure

1. **Name the standard and affected surfaces.** Example: integration docs standard affects `docs/integrations`, `docs/runbooks`, integration specs, and templates.
2. **Run concept search.** Search for the domain terms, not just filenames: `integration`, `OAuth`, `MCP`, `hook`, `scheduler`, `webhook`, `token`, `external API`, etc.
3. **Read candidate files.** Confirm whether each candidate actually falls in scope.
4. **Classify each surface.** Mark `aligned`, `drifted`, or `waived` with evidence.
5. **Create remediation tasks.** Put drift into active tasks, a backfill spec, or gap registry.
6. **Verify.** Run the relevant validator (`docs-verify`, `standards-validator`, focused tests, or gap-analysis) and record evidence.

## Compliance test

- [ ] Does the standard change identify which existing surface classes are affected?
- [ ] Was a concept search run for affected surfaces, not only a filename check?
- [ ] Does every in-scope surface have `aligned`, `drifted`, or `waived` state with evidence?
- [ ] Does every `drifted` surface link to a task, spec, gap-registry entry, or waiver?
- [ ] Are historical artifacts left alone unless they are still live operator documentation?
- [ ] Was the relevant verification command or review recorded after backfill tasks were created or completed?

If any check fails: do not claim the standard is adopted. Create the missing backfill report/tasks first, then re-run verification.

## References

- [Lean standard work](https://www.lean.org/lexicon-terms/standardized-work/) — standards create a baseline for improvement; drift must be made visible and corrected.
- [ISO Scope Pattern](https://www.iso.org/directives-and-policies.html) — standards require explicit scope and exclusions.
- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) — normative vocabulary for compliance rules.
- `profiles/general/standards/maintenance/artifact-ownership.md` — related ownership/freshness contract for derived artifacts.
- `profiles/general/standards/product/spec-to-qa-traceability.md` — example of shift-left traceability and spec-close enforcement.
