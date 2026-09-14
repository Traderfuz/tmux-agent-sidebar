<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/companion-tool-supersession.md and re-run profile-sync. -->
# Companion-Tool Supersession Standard

## Overview

DevOS repeatedly evaluates external "companion" tools — GUI shells, schedulers, task boards, observability dashboards — that sit alongside the core CLI layer. Without a governing rule, each evaluation starts from scratch, prior decisions are forgotten, and redundant tools accumulate as parallel stacks. This standard governs how a new companion tool is evaluated against what already exists, so the operational surface shrinks toward the best single tool instead of growing.

## Scope

This standard covers how a candidate external GUI/scheduling/observability companion tool is evaluated against existing coverage before adoption. It does NOT cover coding-agent CLI integrations (`scripts/lib/integrations/*` agent clients), internal DevOS skill/command authoring, or library/dependency selection inside application code.

## Principles

1. **Capability redundancy is a cost, not a hedge:** two tools that do the same job are a maintenance and cognitive liability, not resilience.
2. **Decisions compound only if recorded:** every companion-tool choice must leave a durable ADR so the next evaluation builds on it instead of re-litigating.
3. **Supersede before you stack:** when a new tool covers an incumbent's capability natively, the default is to retire the incumbent, not run both.
4. **Spend innovation tokens deliberately:** adding a new operational tool is a finite-budget choice (per "Choose Boring Technology"); the burden of proof is on the addition.

## Rules

### Before adopting a companion tool

- **Inventory existing coverage:** evaluators `MUST` enumerate which currently-installed tools/integrations already provide the candidate's capability before proposing adoption.
- **Review prior ADRs:** evaluators `MUST` read prior companion-tool ADRs (`docs/adr/`) and reference them in the new evaluation. A decision that contradicts a prior ADR `MUST` explicitly supersede it.
- **Prefer supersession:** when the candidate natively covers an incumbent's capability, evaluators `SHOULD` retire the incumbent rather than run parallel stacks. Running both `MUST` be justified by a capability the candidate genuinely lacks.
- **Record the decision:** the outcome `MUST` be written as a new ADR (per the ADR standard), including alternatives considered and the supersession (if any).

```text
// OFF-STANDARD
"Add Multica for a task board." → installed alongside Orca/Hermes,
which already provide a board + scheduling. Two stacks, no ADR.

// ON-STANDARD
Evaluate task-board need → inventory: Orca automations panel + Hermes
cron already cover it → supersede/retire Multica → record ADR-0022.
```

### When superseding an incumbent

- The superseding ADR `MUST` mark the incumbent `Superseded by ADR-NNNN` and list the live artifacts to decommission.
- Decommission of live integration code/docs/wiring `MUST` be operator-confirmed; dated historical records (prior specs, ADRs, gap reports) are archived in place, not deleted.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Adopt a tool without inventorying existing coverage | Creates silent redundancy | Inventory current coverage first (Rule 1) |
| Run new + incumbent "to be safe" | Two stacks to maintain; cognitive load | Supersede the incumbent unless a real capability gap exists |
| Decide without writing an ADR | Next evaluation repeats the debate | Record an ADR every time |
| Delete the incumbent's historical specs/ADRs | Loses the decision trail | Archive dated records in place; mark `Superseded` |

## Deviation guidance

You MAY run a new companion tool alongside an incumbent when the new tool lacks a specific capability the incumbent uniquely provides. When you do: name the missing capability explicitly in the ADR, and record the trigger that would later collapse the two stacks into one.

## Compliance test

- [ ] Did the evaluation inventory existing tools/integrations that already provide the capability?
- [ ] Did it reference all prior companion-tool ADRs in `docs/adr/`?
- [ ] If the new tool covers an incumbent's capability, was the incumbent superseded (or a capability-gap justification recorded)?
- [ ] Was the decision recorded as a new ADR with alternatives considered?
- [ ] If an incumbent was retired, did the ADR mark it `Superseded by ADR-NNNN` and were dated historical records archived (not deleted)?

If any check fails: complete the missing step before the adoption/decommission lands.

## References

- [Choose Boring Technology — Dan McKinley](https://mcfunley.com/choose-boring-technology) — "innovation tokens": adding operational tools is a finite-budget decision.
- TOGAF Application Portfolio Rationalization — consolidating redundant applications toward a minimal, non-overlapping portfolio.
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) — the durable decision-record format this standard requires (see `global/adr.md`).
- Worked example: `docs/adr/2026-06-04-orca-hermes-supersede-multica.md` (ADR-0022) — Orca + Hermes supersede Multica.
