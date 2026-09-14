# Agent Infrastructure Build Workflow

Build agent-ready infrastructure for any AI SDK: define typed tools with `mcp-builder`, then author the system prompt, DESIGN-NOTES, and agent spec with `bx-agent-creator`. Works with OpenAI SDK, Vercel AI SDK, Anthropic SDK, or any provider that accepts system prompts and tool definitions.

## When to Use

Run when building an agent-powered feature that needs:
- Tool definitions with typed schemas (function calling / tool use)
- A system prompt that wires those tools with correct when/why-to-use instructions
- DESIGN-NOTES documenting loop pattern, posture, and guardrails

Do NOT run for:
- Agent description upgrades on an existing agent (use `bx-agent-creator` Mode 3 directly)
- Infrastructure with no tool use (no function calling → skip Step 1)
- Pure UI/API work with no autonomous behavior

## Step 1: Define Tools with mcp-builder

Use `mcp-builder` to produce typed tool definitions before writing any system prompt.

For each tool the agent needs:
1. Name the tool with a service prefix if multiple services are involved (`github_get_file`, `linear_create_issue`)
2. Write the description answering 4 questions:
   - What does it do?
   - When should the agent use it?
   - What does each parameter mean?
   - What does it explicitly NOT do?
3. Define the JSON schema: required fields, types, enum constraints, descriptions per field
4. Classify access: read (R) / write (W) / execute (E)
5. For W/E tools: note reversibility — free (local, undoable) vs confirmation-required (destructive, visible to others)

**Output:** Tool definition file at the path your SDK expects, or inline schema block for copy-paste.

**Anti-pattern:** Do not write 1-sentence tool descriptions. A tool with a vague description produces wrong selection. Every description must answer all 4 questions.

**If 20+ tools required:** Apply the Tool Search Tool pattern — define one meta-tool that returns tool definitions on demand. Surface this to `bx-agent-creator` in Step 2.

## Step 2: Select Architecture Pattern

Before writing the system prompt, pick the loop pattern:

| Signal | Pattern |
|--------|---------|
| Steps fixed at design time | Prompt Chain (not an agent — reconsider) |
| Ingests external data (web, email, docs) | Plan-and-Execute |
| Needs test-time learning from failure | Reflexion |
| Routes sub-tasks to exact-computation modules | MRKL |
| General, external-data-dependent task | ReAct |

State the pattern explicitly. Agent without a named loop pattern is not compliant.

**Multi-agent decision:** If the task needs parallel sub-tasks with independent context windows, select Opus 4 orchestrator + Sonnet 4 workers. Justify the ~15× token cost vs single-agent (~4×) before proceeding.

## Step 3: Author System Prompt + DESIGN-NOTES with bx-agent-creator

Invoke `bx-agent-creator` (Mode 1) with:
- Tool list from Step 1 (names + 4-question descriptions)
- Loop pattern from Step 2
- Action posture: default-to-action (autonomous) or default-to-ask (interactive)
- Multi-agent role: orchestrator / worker / standalone
- Deployment target: self-hosted (Claude Code headless) / Managed Agents API ($0.08/hr + tokens) / Claude Agent SDK (in-process)

`bx-agent-creator` produces:
- `system-prompt.md` — 7-section structure with 3 non-negotiable elements (PERSISTENCE, TOOL DISCIPLINE, PLANNING), tool usage rules per tool, action posture block, loop-pattern instructions, reversibility guardrails (if W/E tools)
- `DESIGN-NOTES.md` — pattern name + rationale, posture, tool access table (R/W/E + reversibility + HITL), max_turns + on-cap behavior, deployment target, token cost classification

**Write DESIGN-NOTES.md first.** Pattern and posture must be resolved before instructions can be written correctly.

## Step 4: Wire Tools into System Prompt

For each tool defined in Step 1, the system prompt Instructions section must include:

```
Use [tool-name] when [condition]. Do NOT use [tool-name] for [exclusion].
```

Verify every tool from Step 1 appears in the Instructions section. A tool not referenced by the system prompt will be called at random.

## Step 5: Run Pre-Delivery Gate

Before integrating into the SDK, verify all 8 compliance items:

| Check | Applies | Verify |
|-------|---------|--------|
| 3 non-negotiable elements (PERSISTENCE, TOOL DISCIPLINE, PLANNING) | Always | All 3 present in `<instructions>` |
| Named loop pattern | Always | Named in DESIGN-NOTES.md with rationale |
| Single action posture | Always | default-to-action OR default-to-ask, not both |
| Reversibility guardrails | If W/E tools | Block present in system prompt |
| max_turns set with on-cap behavior | Always | Cap value + on-cap action documented |
| Tool descriptions answer 4 questions | Always | All tools pass the 4-question test |
| Injection defense | If reads web/email/docs/API | Plan formed before ingesting external data |
| DESIGN-NOTES.md present | Always | File exists with pattern, posture, max_turns |

Any FAIL = blocker. Do not integrate until all applicable items pass.

## Step 6: Integrate into SDK

Map the agent artifacts to SDK conventions:

| Agent artifact | OpenAI SDK | Vercel AI SDK | Anthropic SDK |
|----------------|-----------|---------------|---------------|
| `system-prompt.md` content | `messages[0].role: "system"` | `system` param | `system` param |
| Tool definitions (Step 1) | `tools[]` array | `tools` object | `tools[]` array |
| `max_turns` value | `max_turns` or loop control | `maxSteps` | `max_tokens` + loop control |

**Provider-agnostic rule:** The system prompt and tool descriptions are SDK-independent. Only the schema wrapper (JSON shape) differs per provider.

## Display Format

```
=== Agent Infrastructure Build ===

Tools defined:    [N] tools (R: [N], W: [N], E: [N])
Loop pattern:     [ReAct / Plan-and-Execute / Reflexion / MRKL]
Action posture:   [default-to-action / default-to-ask]
Deployment:       [self-hosted / Managed API / SDK]
Token cost class: [~4× chat / ~15× chat]

Artifacts:
  system-prompt.md   — [path]
  DESIGN-NOTES.md    — [path]
  tool-definitions   — [path or inline]

Pre-Delivery Gate: [N]/[N] applicable checks pass

SDK integration: [OpenAI / Vercel AI / Anthropic] — [ready / blocked: item]
```

## Failure Handling

| Failure | Response |
|---------|---------|
| Tool description answers < 4 questions | Rewrite before Step 3. Do not pass vague descriptions to bx-agent-creator. |
| Cannot choose posture | Agent scope is undefined. Split into autonomous + interactive agents. |
| 20+ tools without Tool Search Tool | Apply Tool Search Tool pattern before Step 3. |
| Pre-Delivery Gate FAIL | Return to failing element. Do not integrate into SDK until all pass. |
| Multi-agent cost unjustified | Default to single-agent. Document decision in DESIGN-NOTES. |
