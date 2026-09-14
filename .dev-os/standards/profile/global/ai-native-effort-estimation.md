<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/ai-native-effort-estimation.md and re-run profile-sync. -->
# AI-Native Effort Estimation Standards

## Overview

LLMs carry a structural bias: their training data is written by human developers, so when they estimate effort they reason from human throughput. "This will take 2 days" means two human days — typing code manually, reading docs linearly, debugging with breakpoints. With an AI coding agent, code generation is near-instant. The bottleneck shifts entirely to human review cycles, approval gates, external system latency, and ambiguous requirements. A standard that ignores this shift produces estimates that are wrong by an order of magnitude and causes incorrect prioritization, false deadlines, and poor capacity decisions.

This standard governs how effort is estimated, sized, and communicated in any project where an AI coding agent does the primary implementation work.

## Scope

This standard covers effort estimation and task sizing when an AI coding agent (Claude Code, Copilot, Cursor, or equivalent) is the primary implementation executor. It does NOT cover: infrastructure cost estimation, LLM compute time, model benchmarking, or human-only development workflows.

## Principles

1. **Clock time is not the bottleneck.** With AI agents, code generation is cheap. Human review, decision cycles, and external system waits dominate actual elapsed time.
2. **LLM time intuitions are human-calibrated.** Any time estimate an LLM produces is drawn from training data written by human developers. It must be reframed before use.
3. **Complexity translates; duration does not.** Cognitive load, decision points, and unknowns still size a task meaningfully. "Hours to complete" does not.
4. **Friction is the unit.** Estimate by counting the number of human touchpoints, external waits, and ambiguity rounds a task requires — not by imagining a developer at a keyboard.

## The Human-Time Translation Error

When an LLM estimates time, it is implicitly running this model:

```
estimated_time = code_volume / human_typing_speed + debugging_overhead + doc_reading_time
```

With an AI coding agent, the correct model is:

```
actual_elapsed_time = (human_review_cycles × review_latency)
                    + (external_waits: CI, deploys, APIs)
                    + (clarification_rounds × human_response_latency)
                    + (novel_problem_surface × LLM_iteration_cycles)
```

Code generation is not in the denominator of the second model. It is effectively zero. Presenting LLM-generated time estimates as calendar duration produces numbers that are wrong by 5–20×.

## Rules

### What to measure

Estimate tasks by counting **friction signals**, not duration:

| Signal | What to count | Example |
|---|---|---|
| **Human decision gates** | How many times does a human need to approve, redirect, or verify before the task can advance? | PR review, spec clarification, QA sign-off |
| **External system waits** | How many external round-trips are required? (CI runs, deployments, API calls that block progress) | CI pipeline, Vercel deploy, third-party API rate limit |
| **Ambiguity rounds** | How well-defined is the requirement? Under-specified tasks generate clarification cycles. | Each missing acceptance criterion = +1 round |
| **Novel problem surface** | What fraction of the task is genuinely new vs. pattern the LLM has already seen? | Integrating a new SDK = novel; CRUD endpoint = pattern |
| **Integration touchpoints** | How many distinct systems must be wired together and verified end-to-end? | 3 services = 3 integration touchpoints |

### Sizing tiers

Replace "hours/days" with friction-based tiers:

| Tier | Decision gates | External waits | Ambiguity | Novel surface |
|------|---------------|----------------|-----------|---------------|
| **XS** | 0–1 | 0 | None | 0% |
| **S** | 1–2 | 1 | Minimal | <20% |
| **M** | 2–4 | 2–3 | Moderate | 20–40% |
| **L** | 4–7 | 3–5 | High | 40–70% |
| **XL** | 7+ | 5+ | Very high / underspecified | >70% |

XL tasks MUST be decomposed before implementation begins. An AI coding agent working on an XL task without decomposition will generate a large implementation requiring many back-and-forth correction cycles, which is slower than upfront decomposition.

### How to estimate — the reframe rule

**OFF-STANDARD:** "This will take 3 days."

**ON-STANDARD:** "This is an M-tier task: 3 decision gates (spec confirm, PR review, QA pass), 2 external waits (CI + deploy), low ambiguity. Expect 1–2 human-calendar-day elapsed time based on review latency, not implementation time."

When communicating estimates to stakeholders, always distinguish:
- **AI implementation time** — time the agent spends generating code (minutes to hours; not the bottleneck)
- **Elapsed calendar time** — wall-clock time until the task is verified done (gated by humans and external systems)

### LLM self-estimation correction

When an LLM produces a time estimate (e.g., "this feature will take about 4 hours"), apply this correction before use:

1. Strip the time value.
2. Ask: what are the decision gates, external waits, and ambiguity signals?
3. Re-express as a tier + friction breakdown.
4. Elapsed time = (number of human review cycles) × (your team's average review turnaround).

Do not pass LLM-generated time estimates to stakeholders without this correction step.

### Task decomposition for AI execution

An AI coding agent works best on tasks with a single clear output verifiable in one review cycle. Decompose until each sub-task meets:

- One output artifact (one file, one endpoint, one component)
- One acceptance criterion
- Verifiable without running the full system (unit test, isolated render, single API call)

A task that requires more than one sequential review cycle is not yet small enough for efficient AI execution.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| "The LLM said this will take 2 hours" | Time estimate is human-calibrated from training data | Strip time, re-express as tier + friction count |
| Estimating by lines of code | AI generates LOC near-instantly; LOC does not correlate with elapsed time | Estimate by decision gates and external waits |
| "This is simple, just a few lines" | Simplicity of code ≠ simplicity of verification + integration | Count integration touchpoints regardless of code volume |
| Time-boxing AI work to human sprint velocity | Human velocity assumes human implementation speed | Calibrate sprint capacity to review bandwidth, not implementation bandwidth |
| Equating "AI can do this" with "this is fast" | Review, integration, and edge case discovery still take real time | Separate generation time from verification time in all estimates |

## Deviation guidance

MAY use time-based estimates when communicating with stakeholders who require calendar dates. When doing so: derive the calendar date from `(friction tier × team review latency)`, not from LLM-generated duration. Document the derivation. MUST NOT present an unmodified LLM time estimate as a commitment.

MAY use story points (complexity/uncertainty) as an equivalent alternative to friction tiers — they measure the same underlying signals without the time-translation problem.

## Compliance test

- [ ] Does each task estimate include a friction tier (XS/S/M/L/XL) rather than a time value as the primary sizing unit?
- [ ] Are LLM-generated time estimates converted to friction tier + calendar derivation before use?
- [ ] Are calendar estimates derived from `review cycles × review latency` rather than from implementation duration?
- [ ] Are XL-tier tasks decomposed before implementation begins?
- [ ] Does each sub-task have exactly one acceptance criterion verifiable in a single review cycle?

If any check fails: rework the estimate using the friction-based model above. If a stakeholder requires a time value, derive it explicitly from review latency — do not use the LLM's raw estimate.

## References

- [Mike Cohn — Agile Estimating and Planning](https://www.mountaingoatbooks.com/books/agile-estimating-and-planning/) — story points measure complexity and uncertainty, not time; foundational justification for decoupling size from duration
- [Woody Zuill & Vasco Duarte — #NoEstimates](http://noestimates.org/) — challenges time-based estimation; focus on decomposition and throughput measurement
- [Daniel Vacanti — Actionable Agile Metrics](https://actionableagile.com/) — cycle time vs. elapsed time; throughput forecasting; the empirical alternative to duration estimates
- [Simon Willison — AI-assisted development writing](https://simonwillison.net/) — practical observations on how AI coding tools shift the bottleneck from generation to review and verification
