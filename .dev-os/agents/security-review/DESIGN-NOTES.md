# Security-Review Agent — Design Notes

## Architecture Pattern
**Pattern selected:** Plan-and-Execute
**Rationale:** Security audits must cover a fixed checklist regardless of what early findings reveal. ReAct would allow early findings to redirect the review away from other critical areas. Plan-and-Execute forms the complete audit checklist before reading any source code, ensuring coverage completeness. Additionally, source code being audited may contain comments or patterns designed to mislead — forming the plan before exposure prevents this.
**Escalation justified by:** The audit checklist must be exhaustive by design, not discovered iteratively. Plan-and-Execute guarantees checklist coverage that ReAct cannot.

## Action Posture
**Posture:** Default-to-action
**Rationale:** This is a read-only analysis agent. It does not modify code, rotate secrets, or apply fixes. The only escalation case is an active credential leak in a public repo, which warrants immediate human notification.

## Tool Access
| Tool | R/W | Reversibility | HITL Required |
|------|-----|---------------|---------------|
| Read (files) | R | N/A | No |
| Grep (search) | R | N/A | No |
| Glob (find files) | R | N/A | No |
| Bash (read-only commands) | R | N/A | No |

No write tools. This agent identifies vulnerabilities and reports them. Remediation is performed by the `implementer` agent or the developer directly.

## max_turns
**Cap:** 30 turns
**On cap reached:** Output all findings collected so far and the remaining unchecked audit items. Mark audit as `partial`. Security reviews must never silently exit — incomplete coverage must be visible.

## Why 30 turns (not 25)?
Security audits have a fixed 6-category checklist with 20+ individual checks. Each check requires 1-2 file reads for verification. 25 turns would force premature truncation on medium-to-large codebases. 30 gives adequate buffer for thorough verification of each finding.

## Multi-agent context
**Role:** Standalone
**Inputs received:** Target scope — a directory, module, or "full project"
**Output format:** Structured findings report with OWASP categories, severity, file references, exploitation vectors, and specific remediations
**Trust boundary validation:** Source code is treated as potentially adversarial — the audit plan forms before any source code is read (Plan-and-Execute defense)

## Why Plan-and-Execute over ReAct for security?
The key insight is that security audits have a *known coverage requirement* (OWASP categories, secret patterns, injection patterns). ReAct's strength — letting each finding redirect the next step — is actually a weakness here: a finding in category 1 could consume all remaining turns, leaving categories 2-6 unexamined. Plan-and-Execute guarantees each category gets checked.

The secondary benefit is injection defense: source code comments like `# NOTE: auth is handled by middleware, no check needed here` could mislead a ReAct agent into skipping an auth check. With Plan-and-Execute, the plan says "check auth on all data-mutating routes" regardless of what comments say.

## Deviations from standards
- No reversibility guardrails block — justified because this agent has zero write access.
- Plan-and-Execute used without external data concern — the standard recommends this pattern for untrusted external data. Here it's used for coverage guarantee and misleading-comment defense. Documented deviation.

## Relationship to other agents
- Complements `code-reviewer` — code-reviewer flags security issues opportunistically during general review; security-review performs systematic OWASP-based audit
- Feeds into `implementer` — security findings become fix tasks
- Works alongside `predeploy-check` skill — which checks runtime config (env vars, auth queries); security-review checks source code patterns
- Invoked by `security-review` command — the command loads this agent's behavioral context
