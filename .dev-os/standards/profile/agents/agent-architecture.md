<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/agent-architecture.md and re-run profile-sync. -->
# Agent Architecture Standards

## Overview

This standard defines how to select and justify architecture patterns when building AI-powered systems. Pattern selection is the highest-leverage architectural decision — the wrong pattern adds cost, latency, and failure surface without improving outcomes. The right pattern is determined by the structural constraints of the problem, not by familiarity or perceived sophistication.

## Scope

**Covers:** Architecture pattern selection for a given problem — which of the six Anthropic patterns to use and when to escalate from simpler to more complex patterns.

**Does NOT cover:** Internal loop mechanics such as tool call sequencing or observation formatting — see `agent-loop-design.md`. Multi-agent decomposition across independent agent instances — see `multi-agent-patterns.md`.

## Principles

**Minimum viable architecture.** Start with the simplest pattern that satisfies the structural constraints of the problem. Add complexity only when evidence from the actual problem — not speculation — demands it. Complexity increases cost, latency, and debugging surface at every escalation step.

**Pattern-to-problem fit.** Each of the six architecture patterns has specific trigger conditions. Applying a pattern outside its conditions wastes resources and introduces avoidable failure modes. The question is not "which pattern is powerful?" but "which pattern fits this specific constraint?"

**Escape hatch discipline.** Every architecture must have defined stop conditions and failure modes before implementation begins. A loop without an exit condition, an agent without a max-iterations cap, or an optimizer without a quality threshold are incomplete architectures — not conservative ones.

**Build with, not around.** Use native LLM capabilities — tool use, structured output, context windows — before adding framework layers. Each framework layer is an abstraction that adds failure surface. Reach for abstractions only when the native capability is genuinely insufficient.

## Rules

### R1 — Workflows vs. Agents: The Fundamental Distinction

Workflows use predefined code paths with LLMs positioned at fixed, known points. The control flow is deterministic; the LLM fills a slot within it. Agents allow the LLM to dynamically determine its own control flow — the sequence of actions is not known at design time.

**Default to workflows.** Escalate to an agent only when the control flow is genuinely unpredictable at design time — meaning you cannot enumerate the decision branches before seeing real input.

**OFF-STANDARD (TypeScript) — agent for a task with known steps:**

```typescript
// OFF-STANDARD: Autonomous agent for a task with known structure
const agent = new Agent({
  instructions: "Process the user's refund request",
  tools: [lookupOrder, processRefund, sendEmail],
});
// This task has exactly 3 steps in a fixed order — an agent adds unpredictability
```

**ON-STANDARD (TypeScript) — prompt chain for known steps; agent only when genuinely dynamic:**

```typescript
// ON-STANDARD: Sequential chain for known steps
const order = await lookupOrder(orderId);
const refund = await llm.complete({ prompt: refundPrompt(order) });
const confirmed = validateRefund(refund); // programmatic gate
if (confirmed) await processRefund(refund);
await sendEmail(refund.email, refund.summary);

// ON-STANDARD: Agent ONLY when steps are genuinely unknowable at design time
// e.g., debugging an arbitrary codebase where the error path is unknown
```

**OFF-STANDARD (Python) — agent for a task with known steps:**

```python
# OFF-STANDARD: Autonomous agent for a task with known structure
agent = Agent(
    instructions="Process the user's refund request",
    tools=[lookup_order, process_refund, send_email],
)
# This task has exactly 3 steps in a fixed order — an agent adds unpredictability
```

**ON-STANDARD (Python) — prompt chain for known steps; agent only when genuinely dynamic:**

```python
# ON-STANDARD: Sequential chain for known steps
order = await lookup_order(order_id)
refund_draft = await llm.complete(refund_prompt(order))
confirmed = validate_refund(refund_draft)  # programmatic gate
if confirmed:
    await process_refund(refund_draft)
await send_email(refund_draft["email"], refund_draft["summary"])

# ON-STANDARD: Agent ONLY when steps are genuinely unknowable at design time
# e.g., debugging an arbitrary codebase where the error path is unknown
```

### R2 — The Augmented LLM Building Block

All agent architectures compose from a single primitive: the Augmented LLM. It has three components:

- **Retrieval** — knowledge beyond the training cutoff, fetched at inference time (RAG, search)
- **Tools** — access to external systems and APIs (databases, browsers, code execution)
- **Memory** — state across turns or sessions (session memory, episodic memory, semantic memory, procedural memory stored in system prompts)

A valid agent implementation may use only one of these three components. Using all three is not required and not a quality signal. Add only the components the task actually requires.

### R3 — The Six Architecture Patterns

**1. Prompt Chaining**
Each step passes output to the next; programmatic gates validate quality between steps.

Use when: the task has linear stages, quality can be checked between stages, or stages are too long for a single context window.

Stop condition: gate fails → halt and alert. Do not retry indefinitely.

**2. Routing**
Classify input first; dispatch to a specialized handler; handlers are independent.

Use when: task types are clearly distinguishable at classification time and handlers need different models or prompts.

Warning: routing quality degrades when input categories overlap more than roughly 25%.

**3. Parallelization — two distinct modes**

- *Sectioning*: divide the task into independent chunks, run simultaneously, aggregate. Use when the task decomposes cleanly into subtasks with no shared state.
- *Voting*: run the same task multiple times, compare outputs for confidence. Use when single-attempt confidence is too low for the risk level. Requires a clear resolution strategy (majority vote or judge model) before enabling.

**4. Orchestrator-Workers**
The orchestrator dynamically decomposes a task; subtask structure is NOT predefined at design time. Workers execute subtasks; orchestrator synthesizes.

Critical distinction: if subtasks CAN be predefined, use Prompt Chaining instead. Dynamic decomposition overhead is only justified when task structure is only known after seeing the input.

**5. Evaluator-Optimizer**
Generator produces output; evaluator returns structured feedback; generator revises; loop exits when quality criteria are met.

Requires measurable quality criteria — not subjective improvement. Must have an explicit exit condition: maximum iterations OR a quality threshold. Both are valid; at least one is mandatory.

**6. Autonomous Agents**
Continuous tool-use loop: perceive → plan → act → observe. Continues until the task is complete or a stop condition is reached.

Use only when the problem is genuinely open-ended and the solution path cannot be anticipated. Must have: explicit stop conditions, a max-iterations cap, and checkpoint/resume capability.

### R4 — Escalation Decision Framework

A pattern is justified when you can point to a specific structural constraint that simpler patterns cannot handle. "It seems like it fits" is not sufficient justification.

Escalation order (each step increases latency, cost, debugging complexity, and failure surface area):

```
Single LLM call
  → Prompt Chain
    → Routing
      → Parallelization
        → Orchestrator-Workers
          → Autonomous Agent
```

Before escalating, state the constraint explicitly: "A prompt chain cannot handle this because the subtask structure is only known after seeing the input" is a valid escalation rationale. "An orchestrator feels cleaner" is not.

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Building an autonomous agent for tasks with known step sequences | Adds latency, cost, and unpredictability to a deterministic problem; control flow that could be compiled into code is instead re-decided at runtime | Use Prompt Chaining; reserve agents for genuinely open-ended control flow where the decision path cannot be anticipated |
| Using Parallelization (Voting) without a resolution strategy | Conflicting outputs with no tie-breaker produce worse results than a single careful run; the additional LLM calls consume cost with negative net return | Define a majority-vote rule or judge-model strategy before enabling voting mode |
| Orchestrator-Workers when subtasks can be predefined | Dynamic decomposition overhead for a static problem; harder to debug and reproduce than a simple chain | Use Prompt Chaining if the subtask structure is fully known at design time |
| Evaluator-Optimizer loop without an exit condition | On edge cases the loop runs indefinitely; cost and latency grow unboundedly with no guaranteed termination | Set explicit `max_iterations` AND a quality threshold; either condition alone is sufficient to exit the loop |
| Adding retrieval, tools, and memory to every agent regardless of need | Each Augmented LLM component adds latency and cost; unused components expand the failure surface without contributing to the task | Only add components the task actually requires; start with the minimum building block and add components when evidence demands them |

## Deviation Guidance

MAY skip the escalation order when a well-understood prior implementation already exists for the problem domain and the pattern choice has been validated in production. MUST document the rationale in a `DESIGN-NOTES.md` file co-located with the agent implementation when deviating from the minimum-viable escalation path — so the next developer understands why the chosen pattern was selected and can evaluate whether the constraint still holds.

## Compliance Test

1. Is the architecture pattern selected based on a specific constraint that simpler patterns cannot handle — not because the pattern "seems like it fits"? (Y/N)
2. If using Orchestrator-Workers: can the subtask structure NOT be determined until the input is seen? (Y/N) — answer N/A for other patterns
3. If using Evaluator-Optimizer: is there an explicit exit condition — either a max-iterations cap OR a measurable quality threshold? (Y/N)
4. If using Autonomous Agent: is there a max-iterations cap AND a defined checkpoint/resume mechanism? (Y/N)
5. Is the escalation rationale documented — in a comment, a `DESIGN-NOTES.md`, or the system prompt — so the next developer understands why this pattern was chosen? (Y/N)

## References

- Anthropic, "Building Effective Agents" (2024) — architecture taxonomy and Augmented LLM model
- Anthropic Claude documentation — tool use and agentic workflows
