# Proactive Orchestrator Agent -- Design Notes

## Architecture Pattern
**Pattern selected:** Orchestrator-Workers
**Rationale:** The orchestrator cannot determine the full subtask structure until it reads the spec, config, and signal state. Different goals require different pipeline sequences. Different specs have different task groups. Signal-driven recommendations change the execution plan dynamically. The structure is genuinely unknowable at invocation time.
**Escalation justified by:** Subtask structure (which workers to invoke, in what order, which recommendations to act on) depends on runtime inputs that cannot be known at design time. The proactive signal scan adds another dimension of runtime-dependent planning.

## Why 5 Agents (Constraint Value, Not Convenience)

The agent portfolio is capped at 5 active agents. Each agent exists because it requires a distinct constraint boundary that skills alone cannot enforce:

| Agent | Why an agent, not a skill |
|-------|--------------------------|
| proactive-orchestrator | Hub role. Invokes all skills + delegates to other agents. Owns session state, recommendation lifecycle, and check cadence. No other agent or skill fills this coordination role. |
| implementer | Write access with safety gates. Skills are invoked through the protocol and remain stateless. The implementer holds mutable state (working tree) and has gated Bash + Write access that would be unsafe to grant broadly. |
| security-review | Read-only constraint. Security audits must never accidentally modify what they analyze. This is a safety-critical property enforced by tool access restriction. |
| architect-review | Read-only constraint. Architecture analysis must never modify code. Same safety-critical separation as security-review, applied to structural analysis. |
| code-reviewer | Dual posture. Reads for analysis, writes only with confirmation for fixes. The gated write access is a distinct constraint from full write (implementer) or no write (security/architect). |

**Why not more agents?** Seven former agents (docs-maintainer, git-automation, skill-architect, skill-validator, standards-enforcer, testing-standards, spec-writer) were converted to skill-only. They had no tool access constraints that skills could not satisfy. The orchestrator invokes them directly through the protocol.

**Agent ceiling rule:** No new agents without converting an existing one to skill-only. This forces discipline and keeps the portfolio lean across platforms.

## Action Posture Per Mode

| Mode | Posture | Confirmation gates |
|------|---------|-------------------|
| advise | Display-only | Never acts. All recommendations shown as cards for user review. |
| triage | Organize-then-confirm | Creates tasks and reorders backlog automatically. User approves execution. |
| autonomous | Execute-then-report | Executes auto-actionable items. Pauses at hard guardrails (merge, push, delete). Reports actions taken. |

**Default:** advise. Conservative by design. User opts into higher modes explicitly.

## Tool Access Table (5 Retained Agents)

| Agent | Read | Write | Bash | Skill Invocation | Agent Delegation |
|-------|------|-------|------|-----------------|-----------------|
| proactive-orchestrator | Yes | No | No | Yes (protocol) | Yes |
| implementer | Yes | Yes (gated) | Yes (gated) | No | No |
| security-review | Yes | No | No | No | No |
| architect-review | Yes | No | No | No | No |
| code-reviewer | Yes | Yes (confirmation) | No | No | No |

The orchestrator is the only agent that can invoke skills and delegate to other agents. Specialist agents are workers with constrained tool access.

## Why Skill-First (Composability, Platform Neutrality)

1. **Composability:** Skills are stateless, composable units. The orchestrator provides statefulness via scratch directory and session state. Skills can be combined into pipelines without coordination overhead.

2. **Platform neutrality:** Skills invoked through the protocol work identically across Claude Code, Codex, Gemini, and OpenCode. Agent-to-agent delegation is provider-specific. Skills are the portable unit.

3. **Reduced portfolio complexity:** 12 agents required 12 system prompts, 12 constraint definitions, and O(n^2) potential interaction surfaces. 5 agents + skills reduces this dramatically while maintaining full capability coverage.

4. **Testability:** Skills have clear input/output contracts. Agent behavior is harder to test deterministically. The protocol contract makes skill invocation testable at the contract level.

## Orchestrator Self-Telemetry

The orchestrator monitors itself. Every recommendation it generates, every action it takes or delegates, emits an OTEL span (`devos.orchestrator.recommendation`). This means:
- The orchestrator's own decisions appear in `devos-agent-report`
- Recommendation acceptance/dismissal rates are measurable
- Mode ceiling violations are tracked
- Cross-session recommendation persistence is auditable

## State Persistence

- `orchestrator-session.json`: atomic writes via tmp-then-rename
- Mode persisted on every transition, restored on crash recovery
- Session presumed dead rule: idle > 2x threshold (4h) triggers clean reset
- Schema validation on every read-back before acting on data

## Autonomous Loop Circuit Breaker

The orchestrator's autonomous mode operates in a wave loop. Without a halt condition, a runaway loop can exhaust the token budget or spin indefinitely on unresolvable blockers.

**Max-iterations rule (documented halt condition):**
- Default: 50 wave iterations per autonomous session before mandatory pause
- Hard cap: 100 iterations — session terminates and surfaces `[CIRCUIT-BREAKER]` regardless of progress
- Per-blocker cap: If the same blocker fingerprint fires ≥3 consecutive waves, pause immediately and surface it rather than retrying

**Implementation surface:** `autonomous-session-orchestration` skill reads `session-state.yml:wave` count before starting each wave. If `wave >= MAX_ITERATIONS`, it emits:
```
[CIRCUIT-BREAKER] Autonomous session reached <N> iterations without completion.
Pausing. Run: autonomous --status to inspect, autonomous --continue to resume.
```

**Session-dead rule (existing — separate from circuit breaker):** Idle > 4h (2× 2h threshold) triggers clean reset. Iteration limit is a distinct guard for active-but-runaway loops.

**Token budget cap**: Autonomous mode has no per-session token budget limit yet. Open question for future spec.

## Deferred Work

- **Continuous loop mode**: Background monitoring via `/loop` pattern for real-time monitoring during long autonomous sessions. Separate spec.
- **Recommendation persistence between sessions**: Currently resets each session. Open question whether pending recommendations should carry over.
