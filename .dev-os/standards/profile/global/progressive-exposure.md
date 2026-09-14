<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/progressive-exposure.md and re-run profile-sync. -->
# Progressive Exposure for Context Engineering

## Overview

LLM Progressive Exposure is an information architecture strategy that reveals complexity — tool definitions, standards, instructions, data — gradually rather than loading everything into the prompt at once. Every token in an agent's context window competes with runtime state. Dumping all available knowledge upfront produces context rot: accuracy degrades, the model loses focus on irrelevant information, and responses drift. Progressive exposure inverts this — the agent receives the minimum viable context at session start, and additional knowledge is surfaced only when the task demands it.

DevOS implements progressive exposure across three tiers for standards injection into AGENTS.md: catalog-level awareness (the agent knows categories exist), priority-ordered activation (highest-value categories injected first within a token budget), and on-demand loading (full standards loaded via `{{standards/*}}` only when specific commands execute).

## Scope

This standard covers the progressive exposure model for standards injection into AGENTS.md via the `standards_injection` config block in `.dev-os/config.yml`. It does NOT cover framework bundle injection (separate pipeline), the `{{standards/*}}` on-demand template system (Tier 3 — always loads full set), or provider-level context lifecycle management (see `context-lifecycle/` module).

## Principles

1. **Smallest viable context.** Find the minimum set of high-signal tokens that maximizes the likelihood of correct output. Every additional token beyond that set degrades attention, increases cost, and risks the U-shaped accuracy curve (high at start/end of context, 30%+ lower in the middle — Liu et al., Stanford).
2. **Relevance over completeness.** A CLI project injecting frontend accessibility standards wastes tokens on knowledge the agent will never apply. Priority ordering and profile exclusions ensure the injected set matches the project type.
3. **Graceful degradation.** When the context budget is tight (128K GLM-5 vs 1M Opus), the system drops the least relevant categories first — not all-or-nothing. The agent always gets core conventions; niche meta-standards are the first to go.
4. **Two-gate safety.** The user's intent cap (`max_tokens`) and the provider's physical limit (budget gate) are independent constraints. Both must pass. This prevents accidental overflow on small-window providers while letting large-window providers receive more context.
5. **Zero-config discovery.** New standard categories added to a profile are auto-discovered and injected without config changes. The system adapts to profile evolution without operator intervention.

## The Three-Tier Model

DevOS standards reach the agent through three tiers, each with increasing token cost and decreasing frequency:

```
Tier 1: Catalog Awareness          (zero tokens — implicit from AGENTS.md structure)
  The agent sees category names in AGENTS.md section headers.
  It knows "backend standards exist" without reading them.

Tier 2: Priority-Ordered Injection  (budget-controlled — standards_injection config)
  Highest-priority categories are injected into AGENTS.md at session start.
  Token cost: 10K-100K depending on config. Always available in context.

Tier 3: On-Demand Loading          (per-command — {{standards/*}} templates)
  Full standards loaded when specific DevOS commands execute.
  Token cost: full set. Only present during command execution.
```

Tier 2 is where the progressive exposure tuning happens. The config controls which categories enter Tier 2 (always in context) vs remaining at Tier 1 (known but not loaded).

## Rules


### Memory-to-skill routing

Large indexes and conditional instructions MUST NOT be loaded in full in always-loaded memory files. Keep one-line pointers in `CLAUDE.md` / `AGENTS.md` and route details to on-demand skills:

- Skills index → `find-skills`
- Chains index → `devos-chains`
- Workflows index → `devos-workflows`
- Standards index → `standards-guide`
- OS package handoff context → `os-orchestrate` / `consume-*`
- MCP availability details → `mcp-hub-context` / `mcp-health`

This preserves discovery while avoiding token spend on every session. Any pointer-capable reference block loaded in full and exceeding the always-loaded WARN threshold is a routing violation, surfaced by `scripts/lib/context-footprint.sh`.

### Config schema

```yaml
standards_injection:
  enabled: true                # master switch (MUST)
  max_tokens: 100000           # user intent cap in tokens (SHOULD, default: 0 = no cap)
  priority: [global, ...]      # injection order (MAY, default: see below)
  categories:                  # per-category toggles (MAY, default: all true)
    global: true
    agents: false
```

- `enabled: false` — all standards remain at Tier 1 (catalog only). AGENTS.md contains framework bundles only.
- `max_tokens: 0` or absent — no user cap; only the provider budget gate limits Tier 2 injection.
- `priority` absent — default order: `global, maintenance, product, testing, backend, deployment, auth, agents, skills, root`.
- `agents` and `skills` default to `false` — these are meta-standards for building agents and skills. The knowledge they contain is already embedded in the corresponding skills (`bx-agent-creator`, `bx-skill-creator`, `bx-skill-creator`, etc.). Injecting them into AGENTS.md duplicates what the skills already provide via Tier 3 on-demand loading.
- All other categories not listed — treated as enabled. Only explicit `false` disables.

### The Coherence Cascade (injection algorithm)

Categories are injected in priority order. Each successful injection makes the agent's subsequent reasoning more coherent — the cascade effect. The algorithm:

1. Build ordered list from `priority` config (or default). Append any on-disk categories not in the list alphabetically.
2. For each category in order:
   - Skip if `categories.<name>: false`
   - Estimate token cost: `sum(file_sizes) / chars_per_token`
   - Check user cap: if `tokens_used + cost > max_tokens` → **skip, continue to next**
   - Check provider budget gate: if would exceed remaining provider budget → **skip, continue to next**
   - Both pass → inject all files from this category into AGENTS.md
3. Log summary: categories injected (with token counts), categories skipped (with reasons).

The skip-and-continue behavior is the key differentiator from all-or-nothing injection. When a large category doesn't fit, smaller categories later in the list may still fit:

```
max_tokens=60000, priority=[global, maintenance, product, agents]

global:      50K → cumulative 50K → fits    → INJECT
maintenance:  8K → cumulative 58K → fits    → INJECT
product:      1K → cumulative 59K → fits    → INJECT
agents:      36K → cumulative 95K → exceeds → SKIP (stays at Tier 1)

Result: 3 categories at Tier 2 (~59K tokens), 1 remains at Tier 1
```

### Two-gate budget model

```
User cap (max_tokens)          Provider budget gate
        |                              |
  "How much do I want            "How much can this
   in Tier 2?"                    provider handle?"
        |                              |
        +--------- lower wins ---------+
                     |
              actual Tier 2 limit
```

On a 200K provider with 62K tokens remaining after bundles, `max_tokens: 100000` still caps at 62K (budget gate is binding). On a 1M provider with 538K remaining, `max_tokens: 100000` is binding. The developer controls intent; the provider gate prevents crashes.

### Auto-discovery

The hook scans `.dev-os/standards/profile/` subdirectories at runtime. New categories (e.g., a profile adds `security/`) are discovered, appended after listed priorities, and injected if budget permits. No config change required — convention over configuration.

### Profile exclusions (Tier 0 — never synced)

Profile exclusions operate below the three tiers. The `exclude_inherited_files` field in `profile-config.yml` prevents files from reaching disk during `start`:

```yaml
# profiles/cli/profile-config.yml
exclude_inherited_files:
  - standards/frontend/*
```

Excluded files never enter `.dev-os/standards/profile/`. They don't exist at any tier. This is the correct layer for profile-level architectural decisions ("CLI projects never need frontend standards").

Category toggles (`categories: agents: false`) operate at the Tier 1→2 boundary — files exist on disk but stay at catalog awareness, not injected into AGENTS.md. This is the correct layer for session-level decisions ("I don't need agent meta-standards right now").

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Dumping all standards into the system prompt | The llmtxt anti-pattern — agents drown in irrelevant context, accuracy drops in the middle of long contexts | Use priority ordering + `max_tokens` to inject only what fits |
| Setting `max_tokens` to the full provider window | Leaves no room for conversation, tool outputs, or runtime state | Set to 100K (default); let the budget gate handle provider limits |
| Manually toggling categories off to fit budget | Fragile — must recalculate when standards change size | Enable all, set `max_tokens`, let the coherence cascade decide |
| Putting niche categories first in priority | Core conventions get dropped first when budget is tight | Universal categories (global, maintenance) always first |
| Using `DEVOS_INJECTION_BYPASS=1` to force all standards | Bypasses the budget gate — crashes on small-window providers | Increase `max_tokens` instead; the budget gate is a safety net |

## Deviation guidance

You MAY set `max_tokens: 0` when using a 1M+ context provider exclusively. The provider budget gate remains active as a safety net.

You MAY set `enabled: false` to test whether removing Tier 2 standards affects output quality. Note that Tier 3 (`{{standards/*}}`) still loads the full set during command execution — only always-available context is removed.

You MAY reorder `priority` per-project. The default order optimizes for general-purpose development. Domain-specific projects benefit from surfacing their domain categories first.

## Recommended priority orderings

| Project type | Priority order | Rationale |
|---|---|---|
| CLI / tools | `[global, maintenance, product, testing, backend, deployment, auth, agents, skills, root]` | Core conventions first; domain standards before meta-standards |
| Webapp / SaaS | `[global, backend, testing, deployment, maintenance, product, auth, agents, skills, root]` | Backend and testing surfaced early for full-stack work |
| Agent / skill dev | `[agents, skills, global, maintenance, testing, product, backend, deployment, auth, root]` | Meta-standards for building agents/skills take priority |

## Compliance test

- [ ] Does `.dev-os/config.yml` contain a `standards_injection` block with `max_tokens` set?
- [ ] Is `max_tokens` set to a value that leaves at least 40% of the provider's injection budget for conversation and tool outputs?
- [ ] Are all categories set to `true` in `categories:` (letting `max_tokens` + priority handle the budget, not manual toggles)?
- [ ] Does the `priority` list put universally relevant categories before domain-specific ones?
- [ ] If the profile has `exclude_inherited_files`, are the excluded standards absent from `.dev-os/standards/profile/` after `start`?

If any check fails: update `.dev-os/config.yml` or re-run `start` to re-sync.

## References

- [Progressive Disclosure: Controlling Context and Tokens in AI Agents](https://medium.com/@martia_es/progressive-disclosure-the-technique-that-helps-control-context-and-tokens-in-ai-agents-8d6108b09289) — the foundational technique applied to agent context management
- [Skills: The Art of Progressive Disclosure in Context Engineering](https://marcelcastrobr.github.io/posts/2026-01-29-Skills-Context-Engineering.html) — three-tier model for skill loading (catalog → activation → resource loading)
- [The Meta-Tool Pattern: Progressive Disclosure for MCP](https://blog.synapticlabs.ai/bounded-context-packs-meta-tool-pattern) — bounded context packs and the 85-95% token reduction from deferred tool schema loading
- [Effective Context Engineering for AI Agents (Anthropic)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — context engineering as the discipline of curating the optimal token set during inference
- [Context Rot: Why LLMs Degrade as Context Grows](https://www.morphllm.com/context-rot) — U-shaped accuracy curve, 30%+ degradation in mid-context, and mitigation strategies
- [Fighting Context Rot (Inkeep/Anthropic)](https://inkeep.com/blog/fighting-context-rot) — compaction, structured note-taking, filesystem offloading, and context isolation patterns
- [Progressive Context Enrichment for LLMs](https://www.inferable.ai/blog/posts/llm-progressive-context-encrichment) — progressive enrichment as the alternative to upfront context loading
- [Standards Injection Tuning Guide](../../../docs/guides/standards-injection-tuning.md) — operational guide with worked examples, token budgets per provider, and troubleshooting
