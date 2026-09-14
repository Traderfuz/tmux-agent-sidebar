# Performance-Review Agent — Design Notes

## Architecture Pattern
**Pattern selected:** Plan-and-Execute
**Rationale:** Performance audits have a fixed 6-category coverage requirement (complexity, N+1, blocking I/O, unbounded growth, payload size, startup cost). ReAct would let a juicy early finding (one hot loop) consume the turn budget and leave the other categories unexamined. Plan-and-Execute forms the checklist before reading source, guaranteeing category coverage.
**Escalation justified by:** Coverage completeness is the product; iterative discovery cannot guarantee it.

## Action Posture
**Posture:** Default-to-action
**Rationale:** Read-only analysis agent. It never modifies code, never applies fixes. The only pause cases are ambiguous scope and any measurement that would require a write-capable command.

## Tool Access
| Tool | R/W | Reversibility | HITL Required |
|------|-----|---------------|---------------|
| Read (files) | R | N/A | No |
| Grep (search) | R | N/A | No |
| Glob (find files) | R | N/A | No |
| Bash (read-only measurement) | R | N/A | No |

No write tools. Remediation is performed by the `implementer` agent or the developer directly.

## max_turns
**Cap:** 30 turns
**On cap reached:** Output all findings collected so far plus the remaining unchecked categories. Mark audit as `partial`. Incomplete coverage must be visible, never silent.

## Why 30 turns (not 25)?
Six categories × verification reads (each candidate finding needs the file plus at least one call site) plus optional cheap measurements. 25 forces truncation on medium codebases; 30 gives verification headroom without inviting unbounded exploration.

## Multi-agent context
**Role:** Standalone specialist, chain-routable
**Inputs received:** Scope — a diff range, module, directory, or "full project"
**Output format:** Structured findings report with checklist categories, severity, file:line references, measured-vs-estimated impact labels, and specific remediations
**Trust boundary validation:** Source comments claiming "this is fine, cached upstream" are treated as unverified — the plan checks the category regardless (Plan-and-Execute defense, same rationale as security-review)

## Origin
Created via the `bx-agent-creator` pattern for spec `2026-06-28-omp-agent-dispatch-chain-coverage` (specialist coverage expansion). The spec's coverage audit found no generic performance lane in any of the 35 chains — `web-perf` exists but only measures live web pages; nothing reviews performance of arbitrary change sets. This is the "durable missing perspective" case the spec reserves `bx-agent-creator` for.

## Relationship to other agents
- Complements `code-reviewer` — code-reviewer flags perf issues opportunistically; performance-review runs the systematic checklist
- Complements `web-perf` skill — web-perf measures a running page (CWV); this agent reviews source for structural defects
- Feeds into `implementer` — findings become fix tasks
- Routable in chains via `agent_routes.performance-review: complex` and dispatchable via `devos-agent performance-review`
