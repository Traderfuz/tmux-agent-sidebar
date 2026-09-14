<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/architecture/mcp-integration.md and re-run profile-sync. -->
# MCP Provider Integration Standards

## Overview

MCP servers are provider transports, not application architecture. A project may prefer or require specific MCP servers and models, but workflows should name stable capabilities first and route those capabilities to MCP tools, CLIs, APIs, or degraded/manual paths through configuration.

Generated MCP inventories are useful operational reports. They are not standards. This standard defines how MCP-backed capabilities remain portable when servers, tool names, hosts, models, or client runtimes change.

## Scope

This standard applies to MCP-backed capabilities in skills, agents, hooks, commands, and project workflows. It covers capability naming, MCP probing, fallback routing, required-provider declarations, and output normalization.

It does not require every MCP capability to have a fallback. It requires every no-fallback capability to say so explicitly.

## Principles

1. **Capabilities are stable; MCP servers are replaceable.** Use names like `browser.navigate`, `memory.read`, `search.web`, or `image.generate`.
2. **MCP is one transport path.** CLI, direct API, local cache, or manual artifact paths may also satisfy the same capability.
3. **Specific models remain allowed as policy.** Model IDs belong in route tables or required-provider declarations, not scattered workflow prose.
4. **Probe before mutation.** A read-only/status operation should establish MCP availability before a mutating call runs.
5. **Normalize outputs.** Downstream logic should not care whether the result came from MCP, CLI, API, or manual degradation.

## Rules

### Rule 1: MCP-backed work MUST declare a capability name

**OFF-STANDARD**

```markdown
Use `mcp__playwright__browser_navigate`.
```

**ON-STANDARD**

```markdown
Capability: `browser.navigate`

Route:
- primary: Playwright MCP (`mcp__playwright__browser_navigate`)
- fallback: Playwright CLI
- degraded: emit URL/action instructions
```

### Rule 2: MCP route tables SHOULD include provider, model, fallback, and degraded behavior

When an MCP-backed capability uses a specific model or service, capture it in the route table.

```markdown
Capability: `image.generate`

Route:
- primary transport: Replicate MCP
- primary model: `black-forest-labs/flux-pro`
- fallback transport: OpenAI image API
- degraded path: write prompt and asset brief to `artifacts/image-request.md`
```

### Rule 3: MCP availability MUST be probed before mutating calls

Probe with the lowest-cost read-only/status/list/snapshot call available. If the probe fails because the tool is unavailable, route to fallback or degraded behavior. If the probe fails because auth is misconfigured, warn clearly before fallback.

### Rule 4: Required MCP dependencies MUST be explicit

If no fallback is valid, declare:

- capability
- required MCP server/tool family
- required model or service, when relevant
- setup/auth prerequisite
- no-fallback reason
- failure mode

```markdown
Capability: `image.generate.production`
Required MCP: Replicate
Required model: `black-forest-labs/flux-pro`
No fallback reason: approved brand output contract depends on this model.
Failure mode: stop before generation with setup/auth instructions.
```

### Rule 5: Outputs MUST be normalized across transports

All route paths should produce the same artifact path, confirmation shape, and error/warning format. Do not require downstream logic to branch on the MCP server or transport that executed.

### Rule 6: Generated MCP inventory MUST stay separate from standards

Detected server lists, health snapshots, sync state, and transport counts should live in generated runtime/context reports. They should not replace this normative contract.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Calling MCP tool IDs directly from workflow logic | Tool IDs become architecture | Route a named capability to the MCP tool |
| Treating detected MCP server inventory as the standard | Current state overwrites desired contract | Keep inventory as generated report, standards as rules |
| Omitting fallback and no-fallback reason | Missing MCP fails late and opaquely | Declare fallback or required-provider failure mode |
| Embedding model IDs in many skill steps | Model swaps require broad edits | Put model selection in route policy |
| Letting MCP response shapes leak downstream | Consumers couple to one server implementation | Normalize at the capability boundary |

## Compliance Test

- [ ] Does each MCP-backed workflow name the capability before the MCP tool?
- [ ] Is provider/model selection captured in a route table or config?
- [ ] Does each mutating MCP call have a read-only/status probe or documented required-provider precheck?
- [ ] Does every optional MCP route define fallback or degraded behavior?
- [ ] Does every required MCP route state no-fallback reason and failure mode?
- [ ] Are generated MCP inventories kept out of normative standards text?
