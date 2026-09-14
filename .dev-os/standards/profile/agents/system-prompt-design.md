<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/system-prompt-design.md and re-run profile-sync. -->
# System Prompt Design Standards

## Overview

This standard defines how to write agent system prompts — the persistent behavioral instructions that shape how an LLM agent reasons, acts, and communicates across every turn of a conversation. A well-structured system prompt is the single highest-leverage artifact in an agent system: it determines whether the agent persists to task completion, uses tools responsibly, and behaves predictably across providers. A poorly structured one produces an agent that stops early, guesses values it should verify, and acts inconsistently under variation.

## Scope

**Covers:** How to write agent system prompts — required structural elements, the 3 non-negotiable behavioral blocks, action posture selection, provider-specific calibration, and data placement rules.

**Does NOT cover:** Tool descriptions and schema design — see `tool-design.md`. Guardrail prompts, content filtering, and policy enforcement layers — see `agent-safety-and-guardrails.md`.

## Principles

**The brilliant new employee mental model.** Write the system prompt as an onboarding document for someone with exceptional skills but zero institutional context. They know how to code, reason, and use tools — but they do not know your project's conventions, your users' expectations, or which edge cases matter. The system prompt supplies exactly that missing context. Every sentence should answer: "What would a skilled person get wrong without being told this?"

**3 non-negotiable elements.** Validated across providers by OpenAI's GPT-4.1 guidance and confirmed against Claude and reasoning model behavior: persistence reminder, tool-use discipline, and planning/reflection instruction. Omitting any one produces measurably worse agent behavior — the agent stops early, guesses values, or acts without reflection. These three blocks are mandatory regardless of prompt length or agent simplicity.

**Structure before content.** Section ordering matters. Role and identity appear first because they establish the frame through which everything else is interpreted. Tools appear after role but before constraints — the agent needs to know what capabilities exist before it can understand what limits apply to those capabilities. LLMs and human readers both build mental models top-down; violating the canonical order forces the reader to hold unresolved references.

**Provider-specific calibration.** Prompting strategies that work for Claude diverge meaningfully from GPT-4.1 and reasoning models. Claude's extended thinking, GPT-4.1's instruction placement sensitivity, and reasoning models' rejection of step-by-step procedures each require different prompt construction. A single uncalibrated system prompt deployed across providers produces unpredictable quality variation. Calibrate deliberately for the target model.

## Rules

### R1 — Required Section Structure

System prompts must include the following sections in this order. Each section serves a distinct cognitive function; reordering breaks the top-down mental model that both LLMs and human reviewers rely on.

1. **Role & Identity** — What the agent is, what it does, who it serves. Sets the frame for all subsequent instructions.
2. **Personality & Tone** — Communication style, formality level, how to handle uncertainty or disagreement. Prevents the agent from defaulting to generic assistant behavior.
3. **Context / Background** — What the agent knows about the project, user, and environment. Supplies institutional knowledge the agent cannot infer.
4. **Tools** — When and why to use each tool. Not what the tool does (that belongs in the tool schema) — but under what conditions the agent should reach for it.
5. **Instructions / Rules** — Specific behavioral constraints, required workflows, step-by-step procedures where appropriate.
6. **Conversation Flow** — How to handle handoffs, requests for clarification, escalation to humans, and multi-turn task continuity.
7. **Safety & Escalation** — What to refuse, when to ask for confirmation before acting, and how to surface errors clearly.

**OFF-STANDARD:** Sections listed in arbitrary order; tools described before role is established; safety rules buried inside a general instructions block with no visual separation.

**ON-STANDARD:** Sections in the canonical order above; each section has a clear heading; a reader can locate any section in under 5 seconds.

---

### R2 — The 3 Non-Negotiable Elements

Every system prompt must include all three of the following behavioral blocks, verbatim or functionally equivalent. These originate from OpenAI's GPT-4.1 prompting guidance and have been validated to improve agent behavior across providers.

**1. Persistence reminder:**
```
Keep working until the user's query is completely resolved before ending your turn.
Do not stop early or ask if you should continue — just do it.
```

**2. Tool-use discipline:**
```
If you are unsure about any information, use your available tools to look it up.
Do NOT guess or assume values you haven't verified.
```

**3. Planning instruction:**
```
Before each tool call, think through what you expect to get back and how it fits your plan.
After each tool call, reflect on what the result means before proceeding.
```

**OFF-STANDARD — Prompt that omits all 3:**
```text
You are a helpful coding assistant. You can use search, read_file, and write_file tools.
Help the user with their coding tasks.
```
Result: agent stops mid-task and asks "should I continue?", guesses import paths instead of reading files, calls tools sequentially without updating its plan between results.

**ON-STANDARD — Prompt that includes all 3:**
```xml
<instructions>
You are a senior software engineer specializing in TypeScript and React.

PERSISTENCE: Keep working until the user's coding task is completely resolved.
Do not stop and ask "should I continue?" — implement fully, then present the result.

TOOL DISCIPLINE: Before stating any fact about the codebase, verify it using
read_file or glob. Never guess file contents, function signatures, or import paths.

PLANNING: Before each tool call, think through what you expect to find and why.
After each tool call, update your understanding before proceeding to the next step.
</instructions>
```

---

### R3 — XML Tag Structure for Complex Prompts

For prompts with more than 3 behavioral sections or per-request context injection, use XML tags to delineate sections:

```xml
<instructions>
  [behavioral rules — what to do and not do]
</instructions>
<context>
  [background information about the task, user, or system]
</context>
<constraints>
  [hard limits — things the agent must never do]
</constraints>
<examples>
  [3-6 few-shot examples for the primary interaction pattern]
</examples>
```

LLMs attend more reliably to content inside named XML tags than to prose sections delimited only by blank lines or headings. Named tags provide visual scannability for human reviewers and localize future edits to a specific section without risking unintended changes to adjacent content.

MAY omit XML tag structure for simple, single-purpose agents with 3 or fewer instructions and no per-request context injection. MUST still include all 3 non-negotiable elements regardless of prompt length.

---

### R4 — Data Placement Rule

Longform documents, retrieved context, and per-request data belong in the messages array — not in the system prompt.

**Placement:**
- System prompt: persistent behavioral instructions that apply to every turn
- Messages array: documents, retrieved chunks, per-request context — placed ABOVE the user query

**Format for injected context:**
```
[DOCUMENT: filename]
[content]
[/DOCUMENT]

User query: {query}
```

Research shows up to 30% quality improvement when retrieved context precedes the user query rather than follows it. The system prompt is for behavior; the messages array is for data.

**OFF-STANDARD:** System prompt includes a 2,000-token code file pasted inline. Every turn pays the token cost and the behavioral rules are diluted by document content.

**ON-STANDARD:** System prompt contains only behavioral instructions. The code file is injected as `[DOCUMENT: main.ts]...[/DOCUMENT]` in the messages array immediately before the user query.

---

### R5 — Action Posture Patterns

Every agent must declare exactly one action posture. These are mutually exclusive. Mixing them produces unpredictable behavior — the agent sometimes asks, sometimes acts, with no signal to the user.

**Default-to-action posture** (for autonomous agents):
```
When uncertain between two reasonable approaches, take the more cautious one and
document your choice. Do not ask for clarification unless you are completely blocked.
```

**Default-to-ask posture** (for interactive assistants):
```
Before taking any action that modifies data or sends messages, confirm your
understanding of the intended outcome with the user.
```

Choose one. Document the rationale in a `DESIGN-NOTES.md` alongside the agent definition.

---

### R6 — Reversibility Guardrails Block

Include the following block verbatim in any system prompt for agents with write, delete, send, commit, or deploy capabilities:

```
Before taking any irreversible action (deleting data, sending messages, executing
deployments), explicitly state what you are about to do and why. If the action is
destructive, ask for explicit confirmation.
```

MAY use a simplified one-sentence posture block for agents where action scope is narrow and irreversibility risk is demonstrably low (e.g., a read-only search agent with a single write tool that appends to a log). MUST use the full block for any agent with destructive or externally visible write capabilities.

---

### R7 — Provider-Specific Calibration

Apply the following calibrations for the target model. Do not use a single uncalibrated system prompt across providers.

**Claude (Anthropic):**
- Use the `effort` parameter to control thinking budget: `"low"` for fast, single-step tasks; `"high"` for complex planning with more than 3 dependent tool calls.
- Extended thinking produces better multi-step reasoning — enable for tasks requiring sequential tool calls where later steps depend on earlier results.
- Claude defaults to asking clarifying questions. For autonomous agents, explicitly override with the default-to-action posture block (R5).
- When using Claude Opus 4.6: add "Do not over-build. Implement only what is required for this specific task." Claude Opus 4.6 has a demonstrated tendency to gold-plate implementations beyond what was requested.

**GPT-4.1 (OpenAI):**
- GPT-4.1 is highly literal. Specify exactly what you want; do not rely on implied expectations or general guidance.
- Place behavioral overrides near the END of the system prompt — later instructions take precedence over earlier ones for GPT-4.1.
- Pin model version in production: `"gpt-4.1"` not `"gpt-4"`. Floating aliases can change behavior without notice.
- GPT-4.1 follows instructions more literally than Claude — effective for strict protocol adherence; problematic if instructions have unaddressed edge cases.

**Reasoning models (o1/o3/o4-mini):**
- Provide high-level objectives and acceptance criteria — not step-by-step procedures. Reasoning models generate their own internal procedure; supplying one creates conflict.
- Do not instruct reasoning models on how to think. Supply the "what" and "why," not the "how."
- For some reasoning model configurations, the `developer` role replaces the `system` role. Verify the API reference for the specific model.
- Reasoning models perform poorly with heavy few-shot examples. Provide clear success criteria and output format requirements instead.

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| System prompt with no persistence reminder | Agent stops early, asks "should I continue?" before task is complete, requiring multiple user follow-ups for work that should complete in a single turn | Add persistence block: "Keep working until the query is completely resolved before ending your turn" |
| Tool descriptions embedded in the system prompt as prose | Duplicates the tool schema; the LLM must reconcile prose description with the API definition; schema wins when they conflict, making prose guidance misleading | Put tool descriptions in the API `tools` field; use the system prompt only to say WHEN and WHY to use each tool |
| Same system prompt deployed across Claude and GPT-4.1 without calibration | Claude asks clarifying questions where GPT-4.1 acts; reasoning models ignore step-by-step procedures; one prompt produces inconsistent and untestable behavior across providers | Maintain provider-specific system prompt variants or use conditional blocks keyed to the target provider |
| Longform retrieved documents placed in the system prompt | System prompt is for persistent behavior, not per-request data; bloating it with documents degrades reasoning on the behavioral rules and adds token cost to every turn | Inject retrieved context into the messages array above the user query using the `[DOCUMENT]...[/DOCUMENT]` format |
| Default-to-action and default-to-ask postures mixed in the same prompt | Inconsistent posture produces unpredictable behavior — the agent sometimes asks, sometimes acts, with no reliable signal for the user about which to expect | Choose exactly one posture per agent; document the rationale in a DESIGN-NOTES.md alongside the agent definition |

## Deviation Guidance

**XML tag structure (R3):** MAY omit XML tags for simple, single-purpose agents with 3 or fewer instructions and no per-request context injection. The prompt may use plain prose with clear headings instead. MUST still include all 3 non-negotiable elements (R2) regardless of how the prompt is formatted.

**Reversibility guardrails (R6):** MAY use a simplified one-sentence posture block for agents where action scope is narrow and irreversibility risk is demonstrably low — for example, a read-mostly agent whose only write capability appends to an append-only log file. MUST use the full reversibility guardrails block for any agent with delete, send, deploy, commit, or any other externally visible or destructive write capability.

**Section ordering (R1):** MAY collapse Personality & Tone into Role & Identity for very short prompts where the distinction would create visual overhead without adding clarity. The collapsed section must still address both concerns. All other sections remain in canonical order.

## Compliance Test

1. Does the system prompt include all 3 non-negotiable elements: persistence reminder, tool-use discipline instruction, and planning/reflection instruction? (Y/N)
2. Are tool descriptions provided via the API `tools` field — not embedded as prose in the system prompt? (Y/N)
3. Is a clear action posture (default-to-action OR default-to-ask) specified — not both mixed? (Y/N)
4. For agents with write, delete, send, or deploy capabilities: is a reversibility guardrails block present? (Y/N)
5. Is the system prompt structure calibrated for the target provider (Claude effort parameter / GPT-4.1 instruction placement / reasoning model objectives vs. procedures)? (Y/N)

## References

- OpenAI, "GPT-4.1 Prompting Guide" (2025) — source of 3 non-negotiable elements, instruction placement ordering for GPT-4.1, literal instruction-following behavior
- Anthropic, Claude system prompt best practices (Claude 4.6 documentation) — XML tag attention, extended thinking enablement, clarifying question tendency
- Anthropic, extended thinking documentation — effort parameter, thinking budget configuration, multi-step reasoning improvement
- OpenAI, reasoning model documentation — developer role replacement for system role, high-level objective prompting, few-shot limitations
