# Code-Reviewer Agent — Design Notes

## Architecture Pattern
**Pattern selected:** ReAct
**Rationale:** Code review is inherently exploratory — a missing auth check in one file directs attention to related routes. A failing test points to recent commits. Each finding redirects where to look next. A fixed Prompt Chain would miss cross-file connections.
**Escalation justified by:** The next file to inspect depends on what the current file reveals. Step order is unknowable at review start.

## Action Posture
**Posture:** Default-to-action (read phase) / Default-to-ask (apply fix phase)
**Rationale:** Reading and analysing is always safe — proceed without confirmation. Applying a fix modifies code, which requires a confirmation gate. The dual posture maps to the two distinct phases of a code review.

## Tool Access
| Tool | R/W | Reversibility | HITL Required |
|------|-----|---------------|---------------|
| Read (files) | R | N/A | No |
| Grep (search) | R | N/A | No |
| Glob (find files) | R | N/A | No |
| Bash (test runner) | R (execute) | N/A | No |
| Edit (apply fix) | W | Reversible via git | Yes — show change first |

The agent is primarily read-only. Write access is scoped to fix application, which requires the diagnostic gate and user confirmation.

## max_turns
**Cap:** 30 turns
**On cap reached:** Output all findings collected. Mark review as `partial`. List files not yet reviewed. Never silently exit mid-review.

## Named Loop: finding-directed-review
One iteration = one file reviewed, finding recorded (or PASS noted), next file determined from findings.

## Multi-agent context
**Role:** Worker (invoked by orchestrator or directly by commands)
**Inputs received:** Changed files list, test output, optionally a spec for context
**Output format:** Structured findings report (severity, file:line, description, fix)
**Trust boundary validation:** Reads local source files only — no external data ingestion

## Relationship to other agents
- Downstream of `implementer` — reviews work that implementer delivers
- Upstream of merge — findings must be resolved before merge-feature runs
- Complements `security-review` — code-reviewer catches issues opportunistically; security-review does systematic OWASP audit
- Complements `testing-standards` — code-reviewer checks correctness; testing-standards checks test quality

## Why max_turns: 30?
Large implementation task groups may touch 10-15 files. Each file requires 2-3 turns (read, search, verify). 30 turns covers a thorough review of a full task group with buffer for fix-verification cycles.
