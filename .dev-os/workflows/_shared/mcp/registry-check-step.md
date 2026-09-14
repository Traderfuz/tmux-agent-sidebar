# MCP Registry Check Step

<!-- Shared snippet: profiles/general/workflows/_shared/mcp/registry-check-step.md -->
<!-- Reference via: {{workflows/_shared/mcp/registry-check-step}} -->
<!-- Full standard: profiles/general/standards/maintenance/mcp-tool-first.md -->

Before proposing any manual verification or external service action, check whether an MCP tool can perform it:

1. **Scan the CLAUDE.md MCP Registry** — check the `## MCP Registry` table for a server matching the service. Common mappings:

   | Service | Server name | Tool prefix |
   |---------|-------------|-------------|
   | Sentry | `sentry` | `mcp__sentry__*` |
   | Vercel | `vercel` | `mcp__vercel__*` |
   | Supabase | `supabase` | `mcp__supabase__*` |
   | Linear | `linear` | `mcp__linear__*` |
   | GitHub | `github` | `mcp__github__*` |
   | Clerk | `clerk` | `mcp__clerk__*` |
   | Cloudflare | `cloudflare-self` | `mcp__cloudflare-self__*` |
   | Sentry (errors) | `sentry` | `mcp__sentry__sentry_list_issues` |
   | NotebookLM | `notebooklm-mcp` | `mcp__notebooklm-mcp__*` |
   | Twilio | `twilio` | `mcp__twilio__*` |

2. **Scan the deferred tool list** — if the server name appears in `<available-deferred-tools>`, the tool is available on demand. The deferred list is the authoritative source for current session availability — it overrides the registry table if they disagree.

3. **Call ToolSearch if uncertain** — if not found in steps 1–2, run `ToolSearch(query="<service name>")` before concluding no tool exists.

**Preference rule:**
- Tool found → use it directly. Do not ask the user to perform the action manually.
- Tool found in deferred list → call ToolSearch to load the schema, then invoke the tool.
- No tool found after all three steps → state explicitly: *"No MCP tool found for [service] — manual step required: [action]."*

**Non-blocking:** This check must never stall a workflow. If ToolSearch itself fails, proceed to the manual step and note the lookup failure.
