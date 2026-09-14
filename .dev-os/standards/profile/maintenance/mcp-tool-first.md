<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/mcp-tool-first.md and re-run profile-sync. -->
# MCP Tool-First Standard

## Purpose

Before proposing any manual verification or manual action step to the user, Claude must first check whether an available MCP tool can perform that action autonomously. This standard eliminates the failure mode where Claude asks users to do something manually — open a dashboard, run a CLI command, check a log — when an MCP server for that service is already configured and available in the session.

**Named methodology anchor:** This standard applies the ACI (Agent-Computer Interface) tool-preference principle from Anthropic's "Building Effective Agents" guidance — agents should exhaust available tool capabilities before escalating to human-in-the-loop steps, because tool use is faster, reproducible, and does not interrupt the user's flow.

## Scope

This standard covers the decision to propose a manual action vs. use an MCP tool when working with external services. It does NOT cover tool description quality (see `agents/tool-design.md`), MCP server configuration sync (see `mcp-registry-sync` pipeline), or the bx-* skill routing table (see `bx-tool-routing.md`).

## Principles

1. **Tool-first:** A manual step is always a fallback, never a first choice. If a tool can do it, the tool does it.
2. **Registry awareness:** The MCP registry in `CLAUDE.md` and the deferred tool list are both active registries. Absence from one does not mean absence from the other.
3. **Transparent fallback:** When no tool is available, state that explicitly before proposing a manual step — "No MCP tool found for Sentry — please verify manually in the Sentry dashboard."
4. **ToolSearch before giving up:** If unsure whether a tool exists, call `ToolSearch` with the service name before concluding no tool is available.

## Trigger Condition

Apply this standard any time Claude would propose a step that requires the user to:

- Open a web dashboard or service UI
- Run a CLI command that Claude has not run itself
- Check a log, error, or status in an external service
- Copy-paste output from a terminal or browser
- Verify something in a third-party service (Sentry, Vercel, Supabase, Linear, GitHub, Clerk, Cloudflare, etc.)

These are all signals that an MCP tool may be able to perform the action instead.

## Lookup Procedure

When the trigger condition is met, execute in order:

**Step 1 — Scan the CLAUDE.md MCP Registry**

Check the `## MCP Registry` table in the active CLAUDE.md (project or global). Look for a server name matching the service in question.

| Service example | Registry server name | Tool prefix |
|---|---|---|
| Sentry | `sentry` | `mcp__mcp-hub__sentry__*` |
| Vercel | `vercel` | `mcp__mcp-hub__vercel__*` |
| Supabase | `supabase` | `mcp__mcp-hub__supabase__*` |
| Linear | `linear` | `mcp__mcp-hub__linear__*` |
| GitHub | `github` | `mcp__mcp-hub__github__*` |
| Clerk | `clerk` | `mcp__mcp-hub__clerk__*` |
| Cloudflare | `cloudflare-self` | `mcp__mcp-hub__cloudflare-self__*` |
| Memory | `memory` | `mcp__memory__*` (direct — not via hub) |
| Reflection | `reflection` | `mcp__reflection__*` (direct — not via hub) |

**IMPORTANT — Hub prefix rule:** All servers except `memory`, `memory-http`, and `reflection` are proxied through mcp-hub. Their tools MUST use the `mcp__mcp-hub__<server>__<tool>` prefix. Using `mcp__<server>__<tool>` (without `mcp-hub`) will fail silently — the tool does not exist at that path.

**Step 2 — Discover tools via hub__list_server_tools**

ToolSearch cannot find individual hub-proxied tools (it only sees the hub's 2 built-in tools). To discover what tools a server provides, call:

```
mcp__mcp-hub__hub__list_server_tools({ server_name: "<server>" })
```

This returns all tool names, descriptions, call patterns, and input schemas for that server. If the server name is unknown, it returns the full list of available server names.

**Step 3 — Verify server availability via hub__capabilities**

If you need to check whether a server is up before calling its tools:

```
mcp__mcp-hub__hub__capabilities()
```

This returns all 42 servers with status (available/unavailable), type (http/stdio), and tool counts.

**Step 4 — Use the tool, not a manual step**

If a tool is found in Steps 1–3: invoke it directly with the `mcp__mcp-hub__<server>__<tool>` prefix. Do not ask the user to perform the action.

**Step 5 — Transparent fallback**

If the server is unavailable or the desired action has no matching tool: state the result before proposing the manual step:

> "No MCP tool found for [service] in the hub registry. Manual step required: [action]."

## Preference Rule

```
IF server_in_claude_md_registry(service):
    call hub__list_server_tools(server_name)  # discover exact tool names
    call mcp__mcp-hub__<server>__<tool>()     # invoke with hub prefix
ELSE IF hub__capabilities() shows server:
    call hub__list_server_tools(server_name)  # discover tools
    call mcp__mcp-hub__<server>__<tool>()     # invoke
ELSE:
    state_no_tool_available()
    propose_manual_step_with_explanation()
```

The user has already done the work of configuring the MCP server. Claude's job is to use it.

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| "Please open Sentry and check if the error was captured" | `sentry` is in the hub; this wastes the user's time and breaks flow | Call `mcp__mcp-hub__hub__list_server_tools({ server_name: "sentry" })` to find the right tool, then call it |
| "Run `vercel ls` in your terminal" | `vercel` MCP is in the hub; Claude can call it directly | Call `mcp__mcp-hub__vercel__list_deployments` |
| "Please verify in the Supabase dashboard" | `supabase` MCP is available via hub | Call `mcp__mcp-hub__supabase__get_table_data` or the relevant tool |
| "Check your Linear board" | `linear` MCP tools are in the hub | Call `mcp__mcp-hub__linear__linear_list_issues` |
| Using WebSearch to check service status when an API MCP tool exists | WebSearch returns stale HTML; the MCP API returns live structured data | Use the service's MCP tool for live state; use WebSearch only for documentation or public information |
| Calling `mcp__replicate__generate_image_recraft` (no hub prefix) | Hub-proxied tools MUST use `mcp__mcp-hub__` prefix; direct prefix silently fails | Always use `mcp__mcp-hub__<server>__<tool>` for hub-proxied servers |
| Skipping hub__list_server_tools because "I know the tool name" | Tool names change across server versions; discovery ensures accuracy | Call `hub__list_server_tools` at least once per session for unfamiliar servers |

## Deviation Guidance

MAY propose a manual step without running the full lookup when:
- The user has explicitly said "don't use MCP tools for this" or "just tell me what to do"
- The service is clearly not in scope for MCP (e.g., a proprietary internal tool the user hasn't mentioned configuring)
- The action requires a UI interaction that cannot be expressed as an API call (e.g., clicking through a wizard, filling out a human-verification form)

When deviating: state the reason explicitly — "Skipping MCP check because [reason]. Manual step: [action]."

## Registry Freshness

The MCP Registry in `CLAUDE.md` may be stale. For hub-proxied servers, `hub__capabilities` is the authoritative source for what is available right now — it returns live status from the running hub process. The `<available-deferred-tools>` block only shows the hub's 2 built-in tools (`hub__capabilities`, `hub__list_server_tools`), NOT the 785+ individual proxied tools.

**For tool discovery:** `hub__list_server_tools` is the authoritative source for a specific server's tools. `CLAUDE.md` is a reference for server names, not individual tool names.

## Related Standards

- `bx-tool-routing.md` — deterministic routing for bx-* skill domains
- `agents/tool-design.md` — tool description quality and schema standards
- `global/knowledge-pull.md` — knowledge source lookup before generating library-dependent output
- `CLAUDE.md § MCP Registry` — canonical server list (may be stale; use deferred list as ground truth)

## Compliance Test

- [ ] Before proposing any manual verification step, did I check the CLAUDE.md MCP Registry for a matching server?
- [ ] If the server exists in the hub, did I use `mcp__mcp-hub__<server>__<tool>` (not `mcp__<server>__<tool>`)?
- [ ] If unsure what tools a server has, did I call `hub__list_server_tools` to discover them?
- [ ] If a tool was found, did I use it instead of asking the user to act manually?
- [ ] If no tool was found, did I state that explicitly before proposing the manual step?
- [ ] Did I avoid using WebSearch to check live service state when an API MCP tool was available?

If any check fails: run the lookup procedure (Steps 1–3) before the manual step. Document deviations with a stated reason.

## References

- Anthropic, "Building Effective Agents" (2024) — ACI tool-preference principle; human-in-the-loop as last resort
- `bx-tool-routing.md` (sibling) — domain-to-tool routing for DevOS artifact domains
- `global/knowledge-pull.md` (sibling) — the equivalent standard for documentation/knowledge sources
