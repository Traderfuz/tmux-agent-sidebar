<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/agent-loop-design.md and re-run profile-sync. -->
# Agent Loop Design Standards

## Overview

This document defines standards for the internal structure of an agent loop — how an agent reasons,
acts, and recovers within a single execution cycle. Conforming to these standards prevents the two
most common production failures in agentic systems: unbounded execution and undetected error
accumulation.

## Scope

The internal structure of the agent loop — how the agent reasons, acts, and recovers within a
single execution cycle. Does NOT cover architecture pattern selection (see `agent-architecture.md`)
or multi-agent orchestration (see `multi-agent-patterns.md`).

## Principles

1. **Bounded iteration** — every agent loop MUST have a ceiling on iterations. Unbounded loops are
   a production safety hazard: they grow cost without limit, block downstream processes, and are
   impossible to reason about under failure.

2. **Observation-grounded reasoning** — reasoning that does not update from tool observations
   becomes hallucination. The TAO loop (Think-Act-Observe) enforces grounding: each Thought must
   explicitly reference the previous Observation before the next Action is taken.

3. **Checkpoint-based recovery** — on failure, resume from the last checkpoint; do not restart from
   scratch. If the context has become poisoned by compounding errors, spawn a fresh subagent with a
   clean context and a summary of verified work completed.

4. **Stop condition completeness** — all possible stop conditions must be handled. An unhandled stop
   condition silently drops the agent into undefined state with no user visibility.

## Rules

### R1 — Standard Agent Loop Phases

Every conforming agent loop executes exactly three phases per iteration:

- **Phase 1 — Gather context**: retrieve relevant memory, load needed documents just-in-time,
  understand the current state before acting.
- **Phase 2 — Take action**: execute tool calls and produce output.
- **Phase 3 — Verify work**: confirm the action produced the expected outcome; write the checkpoint.

A loop that skips Phase 3 accumulates undetected errors. Each subsequent iteration then builds on
a corrupted foundation that neither the agent nor the operator can see.

### R2 — Named Loop Patterns

Choose one of these four patterns explicitly. Document the choice and rationale. An implicit
`while True` with no named pattern is not acceptable.

**ReAct (Reasoning + Acting)** — Yao et al. 2023

Structure: Thought → Action (tool call) → Observation → repeat. Grounds reasoning in observations;
prevents hallucination drift over long horizons. Requires few-shot TAO trajectory examples in the
system prompt (3-6 examples). Best for: external-information-dependent tasks; long-horizon tasks
where reasoning must update from data.

**Plan-and-Execute**

Structure: generate the full plan before ingesting any external tool data; then execute
step-by-step. Defense against prompt injection: the plan is formed before untrusted content enters
context. Weakness: adapts poorly mid-execution when plan assumptions prove wrong. Best for: tasks
that ingest external data that could contain adversarial instructions; tasks where the plan
structure is fully knowable from the initial input.

**Reflexion** — Shinn et al. 2023

Structure: attempt task → evaluate result → generate verbal self-critique → store critique as
episodic memory → retry with critique in context. Test-time learning: each failure improves the
next attempt. Best for: tasks where initial failure is expected; tasks with a binary pass/fail
evaluation signal; tasks where improvement from critique is measurable. Requires an evaluator that
can determine pass/fail and a memory store for the critique.

**MRKL (Modular Reasoning, Knowledge, Language)** — Karpas et al. 2022

Structure: LLM routes sub-task types to deterministic specialist modules (calculator, SQL query,
date comparison, code executor). Correct for: exact computation that LLMs hallucinate (arithmetic,
precise SQL, date math). Best for: tasks that include subtasks requiring exact correctness that
LLMs cannot guarantee. Implementation: classify subtask type → route to deterministic module →
feed result back to LLM.

### R3 — Stop Condition Handling

All five stop conditions MUST be handled. No exceptions.

| Stop condition | Meaning | Required handling |
|---|---|---|
| `end_turn` | Model completed its turn naturally | Break the loop; return result |
| `tool_use` | Model requested a tool call | Execute tools; feed observation back; continue loop |
| `pause_turn` | Model yielded control (Claude extended thinking) | Yield to caller; resume when signalled |
| `refusal` | Model refused the request | Surface to user immediately; do NOT silently retry |
| `max_tokens` | Context or output limit reached | Checkpoint current state; surface to user; do NOT drop |

### R4 — Max Iterations Cap

A `max_turns` or `max_iterations` ceiling MUST be set on every agent loop. No exceptions.

Recommended ceilings by task type:

| Task type | Recommended cap |
|---|---|
| Task-specific research agents | 20-50 |
| Code execution agents | 10-20 |
| Simple retrieval loops | 5-10 |

On cap reached: checkpoint current state; surface to user with a summary of progress completed.
Silent exit is not acceptable.

### R5 — Error Recovery Patterns

- **Transient tool failure** (network, rate limit): exponential backoff with jitter; max 3 retries;
  log each attempt with failure reason and attempt number.
- **Compounding errors** (multiple failed steps that corrupt context): spawn a fresh subagent with
  clean context plus a summary of verified work completed. Do NOT continue in the poisoned context.
- **Checkpoint format**: external file (JSON or plain text) written after each successful Phase 3
  verification. Checkpoints are stored outside the agent context — in files readable via tools —
  not appended to the message history.

### R6 — Multi-Context-Window Patterns

For long-horizon tasks that exceed a single context window:

- Maintain structured state files (e.g., `progress.json`, `completed-steps.txt`) outside the
  context window; the agent reads and writes them via tool calls.
- Use git as a state tracker: commit after each verified milestone; allows rollback to a known-good
  state without restarting from scratch.
- For Claude extended thinking: enable an adaptive thinking budget after tool results. Thinking
  content blocks appear before the next tool call — preserve them in message history. Do NOT strip
  thinking blocks from context; they contain the reasoning chain that informs the next action.

## OFF / ON Standard Examples

### OFF — No iteration cap, incomplete stop condition handling

```typescript
// OFF-STANDARD: No iteration cap, no stop condition handling
while (true) {
  const response = await claude.messages.create({ /* ... */ });
  if (response.stop_reason === 'end_turn') break;
  // What about max_tokens? refusal? pause_turn? All unhandled.
  // What stops this loop if end_turn never arrives?
}
```

### ON — ReAct loop, bounded, all stop conditions handled, checkpoint per step

```typescript
// ON-STANDARD: Bounded ReAct loop with complete stop condition handling
const MAX_TURNS = 20;
let turns = 0;
let checkpoint = await loadCheckpoint(taskId);

while (turns < MAX_TURNS) {
  const response = await claude.messages.create({
    system: reactSystemPrompt, // includes 3-6 TAO few-shot examples
    messages: buildMessages(checkpoint),
    tools,
  });

  turns++;

  if (response.stop_reason === 'end_turn') break;

  if (response.stop_reason === 'refusal') {
    await surfaceToUser(response);
    break;
  }

  if (response.stop_reason === 'max_tokens') {
    await saveCheckpoint(taskId, checkpoint);
    break; // resume next session from checkpoint
  }

  if (response.stop_reason === 'pause_turn') {
    await yieldControl(taskId, checkpoint);
    break;
  }

  if (response.stop_reason === 'tool_use') {
    // Phase 2: Act
    const observation = await executeTools(response.content);
    // Phase 3: Verify — observation feeds into next Thought (TAO loop)
    checkpoint = await saveCheckpoint(taskId, { observation, turn: turns });
  }
}

if (turns >= MAX_TURNS) {
  await surfaceCapReached(taskId, checkpoint);
}
```

```python
# ON-STANDARD: Same pattern in Python
MAX_TURNS = 20
turns = 0
checkpoint = load_checkpoint(task_id)

while turns < MAX_TURNS:
    response = claude.messages.create(
        system=react_system_prompt,  # includes 3-6 TAO few-shot examples
        messages=build_messages(checkpoint),
        tools=tools,
    )

    turns += 1

    if response.stop_reason == "end_turn":
        break

    if response.stop_reason == "refusal":
        surface_to_user(response)
        break

    if response.stop_reason == "max_tokens":
        save_checkpoint(task_id, checkpoint)
        break  # resume next session from checkpoint

    if response.stop_reason == "pause_turn":
        yield_control(task_id, checkpoint)
        break

    if response.stop_reason == "tool_use":
        # Phase 2: Act
        observation = execute_tools(response.content)
        # Phase 3: Verify — observation feeds into next Thought (TAO loop)
        checkpoint = save_checkpoint(task_id, {"observation": observation, "turn": turns})

if turns >= MAX_TURNS:
    surface_cap_reached(task_id, checkpoint)
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Agent loop with no `max_turns` or `max_iterations` cap | Edge cases cause infinite loops; cost grows unboundedly; process hangs indefinitely | Set a task-appropriate ceiling; checkpoint and surface to user when cap is reached |
| Reasoning for multiple steps before any tool call (decoupled reasoning) | Reasoning that doesn't update from observations drifts into hallucination; later steps are based on invented facts | Use ReAct: each Thought must explicitly reference the most recent Observation |
| Restarting the entire loop on a single tool failure | Discards completed work; compounds API cost; often triggers the same failure again | Exponential backoff with max 3 retries for transient failures; checkpoint-based resume for persistent failures |
| Continuing in context after multiple compounding errors | Poisoned context causes cascading wrong decisions; the agent cannot self-correct once context is corrupted | Spawn a fresh subagent with clean context + a summary of verified work completed |
| Stripping extended thinking content blocks (Claude) | Thinking blocks contain the reasoning chain that informs the next tool call; removing them breaks reasoning continuity | Preserve thinking content blocks in message history; do not filter them from context |

## Deviation Guidance

MAY use a simpler loop structure (while/for without explicit ReAct scaffolding) for short,
well-bounded tasks (5 steps or fewer) where hallucination drift is not a risk. MUST still set a
max iterations cap and handle all stop conditions. MUST NOT use a simpler structure for any task
that involves external data retrieval over multiple steps.

MAY use Plan-and-Execute instead of ReAct for tasks that ingest untrusted external data (webpages,
user uploads) as a prompt injection defense. MUST document the security rationale in the system
prompt so that reviewers understand the choice.

## Compliance Test

Answer each question with Y or N before shipping an agent loop:

1. Is a `max_turns` or `max_iterations` cap explicitly set for this agent loop? (Y/N)
2. Are all 5 stop conditions handled: `end_turn`, `tool_use`, `pause_turn`, `refusal`, `max_tokens`? (Y/N)
3. Is the loop pattern (ReAct, Plan-and-Execute, Reflexion, MRKL) explicitly chosen and documented — not just an implicit while loop? (Y/N)
4. On cap reached: does the agent checkpoint current state and surface progress to the user (not silently exit)? (Y/N)
5. On transient tool failure: is there exponential backoff with a retry limit — not an infinite retry or immediate crash? (Y/N)

All five must be Y. Any N is a blocker before the agent loop reaches production.

## References

- Yao et al. (2023), "ReAct: Synergizing Reasoning and Acting in Language Models" — arXiv:2210.03629
- Shinn et al. (2023), "Reflexion: Language Agents with Verbal Reinforcement Learning" — arXiv:2303.11366
- Karpas et al. (2022), "MRKL Systems: A modular, neuro-symbolic architecture" — arXiv:2205.00445
- Anthropic Claude documentation — extended thinking, tool use stop conditions
