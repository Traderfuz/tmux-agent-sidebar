<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/multi-agent-patterns.md and re-run profile-sync. -->
# Multi-Agent Patterns Standards

## Overview

This standard defines when and how to decompose work across multiple agents. Multi-agent systems can unlock parallelism, specialization, and context isolation — but they also introduce latency, cost, debugging complexity, and new failure modes. This document provides the rules needed to make that trade-off correctly.

## Scope

**Covers:** Decomposing work across multiple independent agent instances — when to do it, how to structure handoffs, which orchestration patterns to use, and how to prevent compounding errors.

**Does NOT cover:** Single-agent loop mechanics such as tool call sequencing or observation formatting — see `agent-loop-design.md`. The internal architecture of an individual agent — see `agent-architecture.md`.

## Principles

**Start with the simplest approach.** Multi-agent adds latency, cost, and debugging complexity at every layer. An error in a two-agent pipeline doubles the failure surface; a three-agent pipeline triples it. Only introduce multi-agent when a single agent has a measurable limitation, not a speculative one.

**Context-centric decomposition.** Decompose on context isolation, not on problem structure. A "planner/implementer/tester" split maps to job roles, not to context requirements — each agent must re-infer intent from a summary, and misalignment compounds at every handoff. A "research agent / code agent / verify agent" split works because each agent needs a distinct, bounded context that does not pollute the others.

**Every agent-to-agent message boundary is a trust boundary.** A sub-agent's output is not inherently trustworthy. Adversarial content in one agent's tool results can propagate through the system as instructions to subsequent agents. Validate inter-agent messages as rigorously as user input: schema check, range check, anomaly check.

**Distilled summaries, not full traces.** Passing full conversation history between agents consumes context budget and amplifies earlier errors. Pass 1-2k token summaries of completed work. The downstream agent needs the conclusion and relevant evidence — not the intermediate reasoning that produced them.

## Rules

### R1 — The Default Rule: Start Single-Agent

Multi-agent decomposition is justified only when at least one of the following conditions is present:

1. **Context protection** — Subtasks pollute each other's working memory. A long research subtask would crowd out the synthesis subtask's working context if run in the same agent turn.
2. **Parallelization** — Subtasks are genuinely independent and can save significant wall-clock time by running concurrently.
3. **Specialization** — 20 or more tools exist for different unrelated domains, and tool selection quality is measurably degrading because the model cannot distinguish relevant tools in the available set.

If none of these conditions exists, a single agent with a well-structured tool set is the correct choice. For large tool libraries, apply the Tool Search Tool pattern (surface tools dynamically) before escalating to multi-agent.

---

### R2 — Context-Centric vs. Problem-Centric Decomposition

This is the most important rule. Problem-centric decomposition maps to job titles. Context-centric decomposition maps to what each agent actually needs in its context window to perform its task without confusion.

**Problem-centric (WRONG):** planner agent → implementer agent → tester agent.

Context is lost at every handoff. Each agent must re-infer intent from a summary of the previous agent's output. The implementer does not have the planner's reasoning; the tester does not have the implementer's reasoning. This is the telephone game anti-pattern: the final agent has no connection to the original intent.

**Context-centric (CORRECT):** Each agent is defined by what context it needs, not what role it plays.

- Research agent: needs only the search query and source material — isolated context.
- Implementation agent: needs spec and codebase — isolated context.
- Verification agent: needs spec, produced output, and success criteria — does NOT need the implementation history or reasoning.

**OFF-STANDARD (TypeScript) — problem-centric decomposition:**

```typescript
// OFF-STANDARD: Planner → Implementer → Tester (telephone game)
const plan = await plannerAgent.run(userRequest);
const code = await implementerAgent.run(plan.output); // Lost: why these decisions were made
const result = await testerAgent.run(code.output);   // Lost: what was originally intended
```

**ON-STANDARD (TypeScript) — context-centric decomposition:**

```typescript
// ON-STANDARD: Each agent gets only the context its task requires
const [research, outline] = await Promise.all([
  researchAgent.run({ query: topic, tools: [webSearch, arxivSearch] }),
  outlineAgent.run({ topic, constraints }),
]);
// Distilled summaries passed forward — not full traces
const final = await writerAgent.run({
  research: research.summary,    // 1-2k token summary, not full conversation trace
  outline: outline.structure,
  topic,
});
```

**OFF-STANDARD (Python) — problem-centric decomposition:**

```python
# OFF-STANDARD: Planner → Implementer → Tester (telephone game)
plan = planner_agent.run(user_request)
code = implementer_agent.run(plan.output)   # Lost: planner's reasoning
result = tester_agent.run(code.output)      # Lost: original intent
```

**ON-STANDARD (Python) — context-centric decomposition:**

```python
# ON-STANDARD: Each agent gets only the context its task requires
import asyncio

research, outline = await asyncio.gather(
    research_agent.run(query=topic, tools=[web_search, arxiv_search]),
    outline_agent.run(topic=topic, constraints=constraints),
)
# Pass distilled summaries — not full traces
final = await writer_agent.run(
    research=research.summary,    # 1-2k token summary
    outline=outline.structure,
    topic=topic,
)
```

---

### R3 — Four Orchestration Patterns

Choose the pattern based on the structural requirements of the workflow, not on familiarity.

**Handoffs (Triage + Specialists)**

Full conversation history transfers to the specialist. The specialist owns the remainder of the conversation. The triage agent classifies and routes; the specialist receives accumulated context and continues directly.

- Use when: Routing is part of the user-facing workflow and the user should experience a smooth handoff.
- SDK note (OpenAI): Use `RECOMMENDED_PROMPT_PREFIX` on handoff-target agents to orient them on their role in the context they are receiving.
- Example: Customer support triage routes to billing specialist or technical specialist. The specialist sees the full conversation to that point.

**Agents-as-Tools (Manager + Specialists)**

The orchestrator retains control. The specialist is invoked like a function and returns a result. The orchestrator synthesizes multiple specialist outputs before responding to the user.

- Use when: The user should not see the decomposition. The orchestrator must combine outputs from multiple specialists before a coherent response is possible.
- SDK note (OpenAI): Use `needs_approval=True` for specialists that perform write operations.
- Example: Research manager calls literature agent, data agent, and synthesis agent in sequence or parallel, then returns one combined report.

**Code-driven orchestration**

Agents are called from application code (Python or TypeScript), not from within another agent. Supports sequential chaining (output of A feeds input of B), `asyncio.gather()` or `Promise.all()` parallelism, and classification-based routing in code.

- Use when: The pipeline structure is deterministic and fully known at design time.
- Example: ETL pipeline with an LLM transformation step; the code controls flow, not an agent.

**Supervisor / Hierarchical (LangGraph Supervisor pattern)**

Multi-level hierarchy: supervisor dispatches to sub-supervisors, which dispatch to workers. Supports enterprise-scale workflows with many specialized agents.

- Use when: More than 10 specialized agents exist and the workflow requires dynamic dispatch across them.
- Risk: Deep hierarchies amplify latency and error propagation. Keep to 2 levels maximum in production. A 3-level hierarchy in a user-facing workflow is an engineering debt item, not a feature.

---

### R4 — Verification Subagent Pattern

The verification subagent is effective precisely because it needs only three things: the original requirements, the produced output, and the success criteria. It does NOT need the implementation history.

Provide:
- The original requirements or specification
- The produced output to be verified
- The success criteria and tools needed to test them

Do NOT provide:
- The implementation agent's intermediate reasoning
- The implementation agent's tool call trace
- The implementation context

This isolation is the source of value. A verification agent that knows how the output was built will have confirmation bias toward accepting it. A verification agent that sees only spec + output + criteria delivers unbiased evaluation.

---

### R5 — Anthropic Production Reference Architecture

For context-heavy production workflows, Anthropic's reference model:

- **Lead agent (Opus 4.6):** Orchestrates the workflow; holds the global plan in context; decomposes into subtasks.
- **3-5 parallel worker agents (Sonnet 4.6):** Execute subtasks with isolated context windows; return distilled summaries.
- **Distilled summaries:** Each worker returns 1-2k tokens summarizing its completed work — not the full tool call trace.
- **External memory:** Persistent file or vector database stores the global plan before context limits are reached in the lead agent.
- **`max_turns` discipline:** Always set on every agent invocation. No agent invocation should be unbounded.

**ON-STANDARD (TypeScript) — production multi-agent with distilled summaries:**

```typescript
// ON-STANDARD: Lead orchestrator + parallel workers with distilled summaries
const subtasks = await leadAgent.decompose(spec, { maxTurns: 10 });

const workerResults = await Promise.all(
  subtasks.map((task) =>
    workerAgent.run(task.context, { maxTurns: 20 })
  )
);

// Pass only summaries to synthesis — not full worker traces
const report = await synthesisAgent.run({
  summaries: workerResults.map((r) => r.summary), // 1-2k tokens each
  spec,
  maxTurns: 15,
});
```

**ON-STANDARD (Python) — production multi-agent with distilled summaries:**

```python
# ON-STANDARD: Lead orchestrator + parallel workers with distilled summaries
subtasks = await lead_agent.decompose(spec, max_turns=10)

worker_results = await asyncio.gather(*[
    worker_agent.run(task.context, max_turns=20)
    for task in subtasks
])

# Pass only summaries to synthesis — not full worker traces
report = await synthesis_agent.run(
    summaries=[r.summary for r in worker_results],  # 1-2k tokens each
    spec=spec,
    max_turns=15,
)
```

---

### R6 — Trust Boundary at Every Agent-to-Agent Message Boundary

Every message received from another agent must be treated as untrusted input. Adversarial content in an early agent's tool results can propagate as instructions to downstream agents without validation at boundaries.

Minimum validation at every agent-to-agent boundary:

1. **Schema check** — Does the message conform to the expected structure? Reject malformed output before passing it forward.
2. **Range check** — Are values within expected bounds? Flag outputs that are anomalously large, small, empty, or structured unexpectedly.
3. **Anomaly check** — Does the message contain unexpected tool calls, instruction-like content, or references to capabilities the sending agent should not have used?

An orchestrator MUST NOT blindly pass a sub-agent's output as instructions to another agent. Validate first. The trust boundary applies even when all agents are running in the same codebase and under the same operator.

---

### R7 — Multi-Agent Failure Modes to Prevent

The following failure modes are specific to multi-agent systems and are not present in single-agent architectures:

- **Inter-agent misalignment:** Each agent optimizes for its own local objective. Without an orchestrator actively maintaining the global objective, agents can produce locally correct but globally incoherent results. The orchestrator must hold the global plan and evaluate each agent's output against it — not just against the sub-task spec.
- **Incorrect output verification:** Downstream agents accept wrong outputs without challenge. Validation at every boundary (R6) is the mitigation.
- **Error amplification:** A small error in an early agent is compounded at each subsequent handoff. An orchestrator that detects and corrects errors at each boundary prevents amplification.
- **Infinite delegation loops:** Agent A delegates to Agent B, which delegates back to Agent A, resulting in an unbounded loop. `max_turns` set on every invocation (R5) and explicit loop-detection logic in the orchestrator are the mitigations.

## Anti-Patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Planner/Implementer/Tester decomposition (problem-centric) | Context is lost at every handoff; each agent re-infers intent from summaries; compounding misalignment produces a final result that diverges from the original intent | Decompose on context isolation: each agent gets only the context its specific task requires — not a role assignment |
| Passing full agent conversation history between agents | Full traces consume context budget; irrelevant tool calls crowd out working memory; earlier agent's reasoning biases later agents toward accepting its framing | Pass distilled 1-2k token summaries of completed work, not full traces |
| Multi-agent for tasks a single agent can handle with 20 tools | Adds latency, cost, and debugging complexity without any benefit; the problem is tool selection, not agent separation | Apply the Tool Search Tool pattern to surface tools dynamically before escalating to multi-agent |
| No trust validation at agent-to-agent message boundaries | Adversarial content in one agent's tool results propagates as instructions to other agents; incorrect outputs are accepted and amplified | Validate all inter-agent messages: schema check, range check, anomaly check before passing any output forward |
| Deep hierarchies (>2 levels of supervision) in production | Latency multiplies at each level; errors amplify across levels; debugging a 3-level hierarchy is exponentially harder than a 2-level one | Keep multi-agent architectures to 2 levels: orchestrator + workers; use code-driven orchestration for deterministic pipelines |

## Deviation Guidance

**3-level hierarchies:** MAY use a 3-level hierarchy for research or analysis workflows where the depth is justified by data volume and the work is asynchronous (latency is not user-facing). MUST document the full hierarchy map in a `DESIGN-NOTES.md` file in the project root and set `max_turns` at every level of the hierarchy.

**Skipping inter-agent validation:** MAY skip inter-agent validation for agents within a fully trusted internal pipeline where all agents run in the same security context, all inputs are controlled by the operator, and no agent receives tool results from external systems or user-provided data. MUST implement inter-agent validation for any agent that receives tool results from external systems, third-party APIs, or any user-provided content.

## Compliance Test

Answer each question with Y (yes) or N (no). All five must be Y for a compliant multi-agent implementation.

1. Is multi-agent decomposition justified by at least one of the three conditions — context protection, parallelization, or specialization — and not by role-based problem structure alone? (Y/N)
2. Is the decomposition context-centric (each agent receives only the context its specific task requires) rather than problem-centric (role-based handoffs where each agent re-infers intent from a summary)? (Y/N)
3. Are distilled summaries of 1-2k tokens passed between agents — not full conversation traces or tool call histories? (Y/N)
4. Is there explicit validation at every agent-to-agent message boundary — at minimum a schema check and a range check before the output is passed forward? (Y/N)
5. Is `max_turns` set on every agent invocation in the multi-agent system — with no unbounded agent calls? (Y/N)

## References

- Anthropic, "Building Effective Agents" (2024) — multi-agent taxonomy, context-centric decomposition, parallelization conditions
- OpenAI Agents SDK, multi-agent orchestration guide — Handoffs pattern, Agents-as-Tools pattern, `RECOMMENDED_PROMPT_PREFIX` for handoff-target agents
- LangGraph documentation, Supervisor pattern — hierarchical orchestration, sub-supervisor dispatch
