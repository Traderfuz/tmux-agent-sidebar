<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/tool-design.md and re-run profile-sync. -->
# Tool Design Standards

## Overview

This standard defines how to design and define tools (function-calling tools and MCP tools) for AI agents. Tool design is the primary determinant of agent reliability at the interface level — a poorly designed tool produces more wrong tool selections and hallucinated parameters than a weak model. The cost of fixing a bad tool definition after deployment is high; the cost of getting it right before deployment is low.

## Scope

**Covers:** Designing and defining tools — naming, description quality, schema structure, consolidation, response design, and model selection for tool use.

**Does NOT cover:** Tool selection logic inside an agent's system prompt — see `agent-loop-design.md`. Tool execution infrastructure, rate limiting, or retry handling — these are runtime concerns.

## Principles

**ACI (Agent-Computer Interface) framing.** Tool design deserves the same rigour as API design. The tool definition is the contract between the agent and the external system; a vague or incomplete contract produces unreliable behavior regardless of model capability. Treat every tool definition as a public API with real consumers.

**Description quality is the primary lever.** The description is the only signal the agent uses to decide whether and how to call a tool. A 1-sentence description produces measurably worse selection accuracy than a 4-sentence description covering what the tool does, when to use it, what each parameter means, and what the tool explicitly does not do. Writing good descriptions is not documentation overhead — it is model tuning.

**Poka-yoke — eliminate error classes by design.** Use `enum` types instead of free-text strings for controlled vocabularies. Use absolute paths for file system parameters. Use ISO 8601 with explicit timezone for all date/time fields. When the wrong input is structurally impossible to express in the schema, the agent cannot produce it.

**Minimum surface, maximum clarity.** Prefer fewer tools with broader scope over many narrow tools. Selection quality degrades measurably above 20 tools in a single context window. Every additional tool is a classification burden on the model; every tool that survives consolidation review must justify its presence.

## Rules

### R1 — Tool Definition Required Fields

Every tool definition MUST include these three fields:

- **`name`** — verb-noun format; service-prefixed for namespacing (see R3). Example: `github_list_prs`, `slack_send_message`, `db_query_users`.
- **`description`** — minimum 3-4 sentences answering all four questions in R2.
- **`input_schema` / `parameters`** — strict JSON Schema; no `any` types; all fields typed explicitly.

Recommended for tools with non-obvious parameter values:

- **`input_examples`** — 1-2 concrete call examples showing expected parameter values, not schema descriptions.

### R2 — The Description Quality Standard

Every tool description MUST answer all four questions:

1. **What does this tool DO?** The action and its direct effect on state or data.
2. **WHEN should the agent use it?** Specific trigger conditions — not "when you need X."
3. **What does each key parameter MEAN?** Semantics and accepted formats, not just the name.
4. **What does it NOT return / NOT do?** Explicit exclusions prevent the agent from expecting outputs the tool cannot produce.

**OFF-STANDARD — 1-sentence description that answers none of the four questions:**

```json
{
  "name": "get_weather",
  "description": "Gets the current weather.",
  "parameters": {
    "location": { "type": "string" }
  }
}
```

**ON-STANDARD — 4-sentence description that answers all four:**

```json
{
  "name": "weather_get_current",
  "description": "Returns the current temperature, humidity, and weather condition for a specified location. Use this tool when the user asks about current weather or when weather data is needed for scheduling or planning decisions. The 'location' parameter accepts city names ('London'), coordinates ('51.5,−0.1'), or IATA airport codes ('LHR'). This tool returns current conditions only — it does NOT provide forecasts; use weather_get_forecast for future weather data.",
  "parameters": {
    "location": {
      "type": "string",
      "description": "City name, lat/lon coordinate pair, or IATA airport code"
    },
    "units": {
      "type": "string",
      "enum": ["celsius", "fahrenheit"],
      "default": "celsius"
    }
  }
}
```

### R3 — Naming Conventions

Tool names MUST follow `{service}_{verb}_{noun}` for any context where tools from multiple services appear in the same tool list. Verb choices are fixed:

- `get_` — idempotent single-resource read
- `list_` — collection read
- `create_` — resource creation
- `update_` — resource mutation
- `delete_` — resource removal
- `send_` — message or notification dispatch
- `execute_` — trigger a process or job

No abbreviations in tool names: `get_user_profile` not `get_usr_prof`. MCP tools: follow the server's naming convention; do not rename MCP tools when importing them into an agent context.

### R4 — Consolidation Rule

Prefer one tool with an `action` enum parameter over separate `create_X`, `update_X`, `delete_X` tools when operations share the same resource schema. Above 20 tools in a single context, use the Tool Search Tool pattern: provide one meta-tool `search_tools(query: string)` that returns relevant tool definitions on demand; the agent loads only the tools it needs per step.

**OFF-STANDARD (TypeScript) — 4 separate tools for the same resource adds selection noise:**

```typescript
tools: [
  { name: "create_calendar_event", ... },
  { name: "update_calendar_event", ... },
  { name: "delete_calendar_event", ... },
  { name: "get_calendar_event", ... },
]
```

**ON-STANDARD (TypeScript) — one tool with action enum:**

```typescript
{
  name: "calendar_event",
  description: "Create, read, update, or delete a calendar event. Use 'create' to add new events, 'get' to retrieve event details by ID, 'update' to modify existing events, 'delete' to remove events permanently. The 'event_id' field is required for get, update, and delete; omit it for create. This tool does NOT send invitations — use calendar_invite_send after creating an event.",
  parameters: {
    action: { type: "string", enum: ["create", "get", "update", "delete"] },
    event_id: { type: "string", description: "Required for get, update, delete. Not used for create." },
    title: { type: "string" },
    start_time: { type: "string", description: "ISO 8601 with timezone, e.g. 2026-03-04T14:00:00+00:00" },
    end_time: { type: "string", description: "ISO 8601 with timezone" },
  },
  required: ["action"],
}
```

**ON-STANDARD (Python) — Tool Search Tool pattern for large tool libraries:**

```python
def search_tools(query: str) -> list[dict]:
    """
    Returns tool definitions relevant to the given query string.
    Use this tool before attempting any task to discover which tools are available.
    The 'query' parameter accepts natural-language descriptions of the action needed
    (e.g., 'send a slack message', 'query the database').
    This tool returns tool schemas only — it does NOT execute any action.
    """
    return vector_search(query, tool_registry, top_k=5)
```

### R5 — Poka-yoke Principles

Eliminate error classes structurally rather than relying on the agent to infer valid values:

- Use `enum` for all controlled-vocabulary string parameters (status, action, format, unit, environment).
- Use absolute paths for file system tools — eliminates the entire CWD-relative error class.
- Use ISO 8601 with explicit timezone for all date/time parameters — eliminates ambiguous local-time errors.
- Never accept raw SQL or arbitrary code strings — parameterize queries or use allowlists.

**OFF-STANDARD — free-text string forces the agent to guess valid values:**

```typescript
{ "status": { "type": "string", "description": "The status to set" } }
```

**ON-STANDARD — enum makes invalid values structurally impossible:**

```typescript
{ "status": { "type": "string", "enum": ["active", "paused", "cancelled", "archived"] } }
```

### R6 — Strict Mode and Schema Validation

Enable `strict: true` on all function definitions (OpenAI API) — this eliminates type mismatches at the model level before they reach execution. For Anthropic tools: use exact JSON Schema with explicit `required` arrays and no `additionalProperties: true`. Schema validation catches type errors before they reach tool execution; do not rely on runtime error handling as the first line of defense.

### R7 — Parallel Tool Execution

When tools have no data dependency between them, call them in parallel in a single `tool_use` block. Never serialize independent calls — it wastes latency. Never use placeholder values for dependent parameters — if tool B needs the output of tool A, those calls are sequential by definition. State this explicitly in the agent's system prompt: "When multiple independent tools can be called simultaneously, call them in a single response."

### R8 — Tool Response Design

Return only the fields the agent will use in subsequent reasoning steps. Strip metadata, pagination tokens, and fields that do not contribute to the agent's next decision. Use semantic stable identifiers (UUIDs, slugs) not display names in ID fields. Include a `success: boolean` field when the operation can fail silently. For large responses, return a summary and a `fetch_detail_id` the agent can use to retrieve specifics in a follow-up call.

### R9 — Model Selection for Tool Use

Match model capability to tool orchestration complexity:

- **Opus 4.6 / GPT-4.1** — complex multi-tool orchestration; tools with conditional logic; tools requiring reasoning about parameter values before calling.
- **Sonnet 4.6 / GPT-4o** — balanced; the default for most production agent use cases with 5–20 tools.
- **Haiku 4.5 / GPT-4o-mini** — simple classification; single-tool calls; screening or routing steps where the tool set is small and well-defined.

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| 1-sentence tool description ("Gets the weather.") | Agent cannot determine when to use the tool, what parameters mean, or what NOT to expect; produces wrong tool selection and hallucinated parameters | Write 3-4 sentence descriptions covering: what it does, when to use it, parameter semantics, and explicit exclusions |
| Free-text string parameters for controlled vocabularies (status, type, format) | Agent guesses valid values; typos in generated strings cause hard-to-debug tool failures at execution time | Use `enum` types to make invalid values structurally impossible |
| 20+ tools in a single context window without a Tool Search Tool | Selection quality degrades measurably above 20 tools; agent calls wrong tools or skips relevant ones | Add a meta-tool `search_tools(query)` that returns relevant tool definitions on demand |
| Calling dependent tools in parallel (tool B needs tool A's output) | Race condition: tool B runs with undefined input; produces subtle failures that are hard to reproduce and debug | Identify data dependencies before scheduling; only parallelize truly independent tool calls |
| Bloated tool responses (full API payloads with metadata) | Large tool responses consume context budget; irrelevant fields increase hallucination risk on later reasoning steps | Return only the fields the agent will use; summarize large responses and provide a follow-up fetch tool |

## Deviation Guidance

MAY use shorter descriptions (2 sentences minimum) for internal utility tools that the agent always calls in a fixed, well-understood pattern and where the development team maintains both the tool and the agent definition. MUST use the full 3-4 sentence standard for any tool exposed in production or consumed by an external team.

MAY skip service-prefixed naming for single-service agents where all tools are unambiguously scoped to one service. MUST use service-prefixed naming whenever tools from multiple services appear in the same tool list.

## Compliance Test

1. Does every tool description answer all four questions: what it does, when to use it, parameter semantics, and explicit exclusions? (Y/N)
2. Do all controlled-vocabulary string parameters use `enum` types instead of free-text `string`? (Y/N)
3. Is `strict: true` (OpenAI) or exact JSON Schema with `required` fields (Anthropic) enabled on all tool definitions? (Y/N)
4. For tool libraries with 20+ tools: is a Tool Search Tool or equivalent dynamic loading pattern in place? (Y/N)
5. Are independent tool calls executed in parallel — not serialized unnecessarily? (Y/N)

## References

- Anthropic, "Building Effective Agents" (2024) — ACI framing and poka-yoke principles
- OpenAI Agents SDK, tools documentation — strict mode, function tools, tool categories
- Tool Search Tool pattern — Anthropic documentation, dynamic tool loading
- OpenAI, function calling guide — parallel tool use, schema validation
