<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/architecture/substrate-reuse.md and re-run profile-sync. -->
# Substrate Reuse Standards

## Overview

When an agent needs a capability the system does not obviously have, the cheapest visible path is to build it. Building is legible, fast to start, and produces a diff the operator can see. Searching for an existing mechanism is none of those things: it produces no artifact, it can end in "nothing found," and it requires reading code the author did not write. The asymmetry is structural, not a matter of diligence, which is why competent agents reliably build second implementations of mechanisms that already exist.

The cost lands later. A second mechanism does not merely duplicate code; it duplicates the contract, and the two copies then drift independently. Every consumer must now learn which one is authoritative, and every future change must be applied twice or silently applied once. This standard makes the reuse evaluation a recorded artifact rather than a private judgment, so that "I did not find one" and "I did not look" stop being indistinguishable.

## Scope

This standard covers evaluating existing mechanisms for reuse before a new mechanism is designed. It does NOT cover how to implement the mechanism that is finally chosen, skill archetype selection (see `skill-composition.md`), or durable artifact ownership declaration (see `../maintenance/artifact-ownership.md`).

## Principles

1. **Read before rebuild:** A mechanism is a candidate for reuse only once someone has read it. An agent may not reject a candidate it has not opened.
2. **Absence of evidence is not evidence of absence:** "No existing mechanism" is a claim about the search, not about the system. The claim is only as strong as the recorded search that produced it.
3. **Layer before replace:** Two mechanisms that appear to compete often occupy different layers. Establish which layer each owns before concluding that one must replace the other.
4. **Rejection is a claim requiring evidence:** Declining to reuse a candidate requires naming the specific capability it lacks. A general preference for a cleaner fit is not a reason.

## Rules

### The Substrate Evaluation Record

- Any change that introduces a new mechanism MUST carry a `## Substrate Evaluation` section in its spec, ADR, or PR description before implementation begins (`MUST`, RFC 2119).
- Each candidate MUST carry exactly one verdict: `reuse`, `extend`, `compose`, or `rejected` (`MUST`).
- Each candidate MUST cite evidence that it was read: a `file:line`, a skill path, or a spec path (`MUST`).
- Every `rejected` verdict MUST name the specific missing capability (`MUST`).

A "new mechanism" means a controller, state machine, adapter layer, registry, scheduler, supervision loop, dispatch path, or evaluation ordering. It does not mean a new caller of an existing mechanism.

```markdown
<!-- OFF-STANDARD: verdict with no evidence and no missing capability -->
## Substrate Evaluation
Considered reusing the existing controller. It did not fit our use case,
so we built a new supervision loop.

<!-- ON-STANDARD -->
## Substrate Evaluation

| Candidate | Evidence read | Verdict | Reason |
|---|---|---|---|
| `devos-crew --supervised` controller | `product/specs/2026-09-06-supervised-devos-crew/spec.md`; `.claude/skills/devos-crew/SKILL.md:117-126` | `compose` | Owns custody (approval-bound actions, pause/resume/recover). Owns no transport to a terminal pane, so it composes with the pane operations rather than replacing them. |
| `session_provider_operation` vocabulary | `scripts/lib/integrations/session-provider.sh:125` | `extend` | Already dispatches `send_command`, `capture_output`, `wait`. Adding `agent_get`/`agent_read`/`agent_prompt`/`agent_wait` extends one dispatch table instead of creating a second one. |
| `agent-dispatch` runtime | `.claude/skills/agent-dispatch/SKILL.md:1-12` | `rejected` | Dispatches installed specialist agents by system prompt. Has no handle to a long-lived provider pane, which is the identity this feature must supervise. |
```

### Search obligation

- The search MUST cover the capability vocabulary, not only the feature name (`MUST`). A mechanism named `custody` will not be found by grepping `supervise`.
- The search MUST include implemented specs (`product/specs/*/spec.md` with `status: implemented`), because a shipped mechanism is frequently invisible from the skill layer that would consume it (`MUST`).

```bash
# OFF-STANDARD: single-term grep over one surface, absence reported as fact
grep -rl "supervise" .claude/skills/

# ON-STANDARD: capability vocabulary across skills, libraries, and shipped specs
for term in supervis custody admission approval "pause\|resume" controller; do
  printf '== %s ==\n' "$term"
  grep -rliE "$term" .claude/skills/ scripts/lib/ product/specs/*/spec.md 2>/dev/null | head
done
```

### Layer disambiguation

- When a candidate overlaps a proposed mechanism only partially, the record MUST state which layer each owns before a verdict is assigned (`MUST`).
- A candidate that occupies a different layer MUST NOT be recorded as `rejected` (`MUST NOT`). The correct verdict is `compose`.

Transport (how a thing is reached), custody (who may act and how work resumes), policy (what should happen), and ordering (in what sequence) are distinct layers. Two mechanisms in different layers are complementary, and treating them as rivals produces a rebuild where an integration was available.

### Consumption over restatement

- A skill or document that describes behavior an existing library implements MUST name that library as the canonical owner rather than restating its algorithm (`MUST`).

```markdown
<!-- OFF-STANDARD: prose re-derives what a library already executes -->
## Scan roster
Run all 9 scans in sequence: read the backlog file, parse the header date,
compare against 14 days, then emit a Medium finding when stale...

<!-- ON-STANDARD: canonical owner named, prose documents rather than duplicates -->
## Scan roster
Layer 1 is owned by `scripts/lib/triage.sh`. Source it and call
`triage_run_audit`; do not re-implement its scans in the session.
Layer 2 lists only the scans that library does not implement.
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Silent greenfield: building without recording any search | "Did not find one" and "did not look" become indistinguishable, so the decision cannot be reviewed or revisited | Record the Substrate Evaluation with candidates, evidence, and verdicts before implementing |
| Name-only search | Mechanisms are named for their domain, not their capability, so a single feature-name grep misses the match that matters | Search the capability vocabulary across skills, libraries, and implemented specs |
| False rivalry | Treating a different-layer mechanism as a competitor forces a rebuild where composition was available | Assign layers first; a different layer is `compose`, never `rejected` |
| Preference-shaped rejection | "It did not fit cleanly" is unfalsifiable, so the rejection cannot be challenged by a reviewer | Name the specific capability the candidate lacks |
| Prose duplication of a library | The document and the library drift, and consumers cannot tell which is authoritative | Name the canonical owner and document only the delta |
| Evaluating after the build | The record becomes a justification for work already done rather than an input to the decision | Gate the evaluation before implementation begins |

## Deviation guidance

You MAY skip the Substrate Evaluation Record when the change adds a caller to an existing mechanism, fixes a defect inside one, or is a documentation-only edit. These are not new mechanisms.

You MAY record a `rejected` verdict on a candidate you have read only partially when the missing capability is provable from its public contract alone (its declared capabilities, frontmatter, or function signatures). When you do: cite the contract line you relied on, and say explicitly that the implementation was not read.

You MAY proceed with a new mechanism when every candidate is `rejected`. When you do: the record MUST still list the candidates searched, so a later reviewer can challenge the rejections rather than repeat the search.

## Profile inheritance notes

Standalone. This standard has no parent-profile predecessor and overrides nothing. It is referenced by `skill-composition.md` (archetype selection assumes the reuse question is already settled) and by `../maintenance/artifact-ownership.md` (a reused mechanism does not create a second owner).

## Substrate Evaluation (this standard)

A standard that mandates a record should carry one. This is the evaluation that preceded authoring it, in the format the rules above require.

| Candidate | Evidence read | Verdict | Reason |
|---|---|---|---|
| `skill-composition.md` | `profiles/general/standards/architecture/skill-composition.md:11` | `rejected` | Governs how a skill is scoped, typed, and composed once it exists. Assumes the decision to build has already been made, so it cannot gate that decision. |
| `../maintenance/artifact-ownership.md` | `profiles/general/standards/maintenance/artifact-ownership.md` | `compose` | Declares who owns a durable artifact after it exists. This standard governs whether a second owner should be created at all, so the two are sequential rather than overlapping. |
| `../global/llm-agnostic-primitives.md` | `profiles/general/standards/global/llm-agnostic-primitives.md:15-19` | `rejected` | Constrains primitives to be portable across LLM platforms. Its "composability over monolith" principle is about primitive granularity, not about searching for a prior implementation. |

Search performed: `grep -rliE "before (building\|designing\|creating) a new\|evaluate reuse\|existing mechanism\|substrate" profiles/general/standards/` across all standards areas. One candidate surfaced and was read; no existing standard mandates a reuse evaluation.

## Compliance test

- [ ] Does the design artifact contain a `## Substrate Evaluation` section naming at least one existing mechanism that was considered?
- [ ] Does every candidate carry exactly one verdict from `reuse`, `extend`, `compose`, `rejected`?
- [ ] Does every candidate cite a `file:line`, skill path, or spec path as evidence it was read?
- [ ] Does every `rejected` verdict name a specific missing capability rather than a general preference?
- [ ] If a candidate overlaps only partially, does the record state which layer each mechanism owns?
- [ ] Was the record written before implementation began, rather than added to justify completed work?

If any check fails: complete the record before implementing. If implementation has already started, record the evaluation against the current state and mark it retrospective, so the reviewer knows it did not gate the decision.

## References

- [Katz, R. and Allen, T. J. (1982), "Investigating the Not Invented Here (NIH) Syndrome"](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1467-9310.1982.tb00478.x) - R&D Management 12(1), 7-20. Empirical basis for the default toward internal invention: groups of stable composition come to believe they hold a monopoly of knowledge and reject outside work, with measurable performance cost. Applied here as the reason the reuse search must be an obligation rather than a habit.
- [Levin, R., Cohen, E., Corwin, W., Pollack, F., and Wulf, W. (1975), "Policy/Mechanism Separation in Hydra"](https://dl.acm.org/doi/10.1145/800213.806531) - SOSP 5, 132-140. Establishes mechanism and policy as separable layers rather than competing designs. Applied here as the Layer disambiguation rule: a candidate in a different layer composes, it does not lose.
- [Krueger, C. W. (1992), "Software Reuse"](https://dl.acm.org/doi/10.1145/130844.130856) - ACM Computing Surveys 24(2), 131-183. Its four-dimension taxonomy (abstraction, selection, specialization, integration) supplies the verdict vocabulary: `reuse` is selection, `extend` is specialization, `compose` is integration. Its notion of cognitive distance explains why the search is skipped: reading an unfamiliar mechanism costs more up front than writing a familiar one.
- G. K. Chesterton, *The Thing* (1929), "The Drift from Domesticity" - the fence parable. Applied here as the read-before-rebuild principle: do not replace a mechanism until you can state why it was built that way.
