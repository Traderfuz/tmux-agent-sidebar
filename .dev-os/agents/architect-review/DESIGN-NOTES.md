# Architect-Review Agent — Design Notes

## Architecture Pattern
**Pattern selected:** ReAct
**Rationale:** Architecture issues are discovered iteratively — finding a circular dependency in module A reveals where to look next in module B. The search path is unknowable at invocation time. Prompt Chaining would require a fixed step list, but architecture review is inherently exploratory.
**Escalation justified by:** Each observation redirects the next investigation step, which is the structural constraint that eliminates fixed-sequence patterns.

## Action Posture
**Posture:** Default-to-action
**Rationale:** This is a read-only analysis agent. There are no destructive operations to gate. The agent should complete the full review and present findings without interrupting the user for confirmation on file reads.

## Tool Access
| Tool | R/W | Reversibility | HITL Required |
|------|-----|---------------|---------------|
| Read (files) | R | N/A | No |
| Grep (search) | R | N/A | No |
| Glob (find files) | R | N/A | No |
| Bash (read-only commands) | R | N/A | No |

No write tools. This agent is purely analytical — it surfaces findings but does not modify code. If fixes are needed, delegate to the `refactor` skill or `implementer` agent.

## max_turns
**Cap:** 25 turns
**On cap reached:** Output all findings collected so far. Mark the review as `partial` and list the architectural dimensions not yet examined. Do not silently exit.

## Multi-agent context
**Role:** Standalone (can also serve as a worker for orchestrator)
**Inputs received:** Target scope — a directory, module, or "full project"
**Output format:** Structured findings report with severity, file references, and remediation
**Trust boundary validation:** N/A — reads only local source files, no external data ingestion

## Deviations from standards
- No reversibility guardrails block in system prompt — justified because this agent has zero write access. Adding the block would be misleading.
- No injection defense — agent reads only local files, not external/untrusted data.

## Relationship to other agents
- Upstream of `implementer` — architect-review findings may generate refactoring tasks
- Complements `code-reviewer` — code-reviewer focuses on correctness and style; architect-review focuses on structural design
- Uses `bx-architecture-extractor` skill for blueprint generation when invoked via `extract-architecture`
