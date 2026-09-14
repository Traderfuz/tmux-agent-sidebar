<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/provider-agnostic-architecture.md and re-run profile-sync. -->
# Provider-Agnostic Architecture Standards

## Overview

Provider and service choices change faster than product architecture. LLM vendors, coding agents, MCP servers, hosted databases, auth providers, media model hosts, search APIs, and workflow services all shift in pricing, quality, limits, availability, and product fit. DevOS projects must therefore model capabilities first and bind providers through adapters, routing policy, and configuration.

This standard defines the cross-profile baseline for avoiding provider lock-in. Specific projects may still require a named MCP, model, API, or SaaS service. The requirement is that those choices are explicit routing policy, not hidden architecture.

## Scope

This standard applies to external provider-backed capabilities including AI models, MCP tools, coding agents, auth, storage, search, payments, queues, media generation, browser automation, notes, calendars, and other third-party services.

It does not require every integration to have multiple live providers. It requires each integration to declare whether it is swappable, required, or intentionally locked to one provider.

## Named Frameworks

### Ports and Adapters (Hexagonal Architecture)
Alistair Cockburn, 2005. Capabilities are ports owned by the application; providers, models, MCP servers, and transports are adapters behind them.
**Applied to:** Rules 1–2 (capability naming) and Rule 5 (normalization at the boundary).

### Convention over Configuration
DHH, Rails Doctrine (2004). Neutral capability defaults handle the common case; provider choice requires explicit routing policy.
**Applied to:** Rule 2 (selection as policy) and Rule 3 (required providers are documented, not assumed).

### RFC 2119 Normative Vocabulary
IETF RFC 2119. MUST/SHOULD/MAY authority levels make compliance checkable rather than interpretable.
**Applied to:** rule strength across all seven rules.


## Principles

1. **Capabilities are architecture; providers are implementations.** Name the stable thing the system needs before naming the vendor, transport, model, or server that satisfies it.
2. **Specific provider choices are allowed when explicit.** A project may require a named MCP or model when the output contract depends on it, but the requirement must be documented as policy.
3. **Routing belongs in one layer.** Provider selection, fallback order, model choice, auth readiness, and degraded behavior live in a router, registry, config file, or capability table.
4. **Outputs are normalized before consumption.** Downstream workflows consume stable local contracts, not vendor payloads or transport-specific response shapes.
5. **Failure semantics are part of the contract.** Required providers fail clearly. Optional providers degrade intentionally.

## Rules

### Rule 1: Provider-backed work MUST be named by capability first

Use capability names such as `image.generate`, `browser.navigate`, `memory.read`, `calendar.create_event`, `search.web`, `auth.identity`, or `llm.complete`.

**OFF-STANDARD**

```markdown
Call `mcp__replicate__runModel` with `black-forest-labs/flux-pro`.
```

**ON-STANDARD**

```markdown
Capability: `image.generate`

Route:
- primary: Replicate MCP
- model: `black-forest-labs/flux-pro`
- fallback: OpenAI image API or explicit manual artifact
```

### Rule 2: Provider and model selection MUST be routing policy

Provider names, model IDs, service URLs, and fallback order belong in configuration or a clearly named routing table. Call sites and skill logic should request the capability and pass domain inputs.

Acceptable routing homes include:

- project config (`.dev-os/config.yml`, profile config, or project-local route table)
- a provider registry or adapter registry
- a SKILL.md transport resolution table
- a composition root for the capability

### Rule 3: Required providers MUST declare why no fallback exists

When a project requires a specific provider, model, MCP server, or service, document:

- capability name
- required provider/transport/model
- reason the provider is required
- setup/auth prerequisite
- failure mode when unavailable

**ON-STANDARD**

```markdown
Capability: `image.generate.production`
Required provider: Replicate MCP
Required model: `black-forest-labs/flux-pro`
No fallback reason: brand output contract was approved against this model.
Failure mode: stop with a setup/auth diagnostic before generation.
```

### Rule 4: Optional providers SHOULD define fallback or degraded behavior

If the capability can proceed without the preferred provider, define fallback order and degraded output. Degraded output should preserve useful artifacts and explain what the operator must do manually.

### Rule 5: Provider payloads MUST be normalized at the boundary

Provider-specific response fields, error shapes, retry hints, and transport metadata must be translated into the local contract before they reach downstream code, skills, or workflows.

### Rule 6: Tests SHOULD target the local provider boundary

Application and workflow tests should mock or stub the capability boundary, not the vendor SDK internals. Adapter tests may stub provider clients or transports to verify normalization and failure semantics.

### Rule 7: Deliberate lock-in SHOULD be recorded as an ADR when strategic

If a provider choice is costly to reverse, long-lived, user-visible, or central to product quality, record the decision in an ADR. The ADR should state why portability is not the immediate goal and what would trigger revisiting the choice.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Naming workflow steps after MCP tool IDs | The transport becomes the architecture | Name the capability and route to the MCP tool |
| Defaulting neutral examples to one vendor | Readers copy the lock-in while thinking they copied abstraction | Resolve from explicit config or provider registry |
| Duplicating fallback order across skills | Provider behavior drifts by call site | Centralize route policy |
| Letting provider response objects pass downstream | Consumers become tied to SDK payloads | Normalize into a local result shape |
| Hiding required-provider assumptions | Missing providers fail late and opaquely | Declare prerequisites and failure modes |

## Deviation Guidance

You MAY bind to a single required provider without fallback when Rule 3 documentation exists, the output contract genuinely depends on that provider, and strategic lock-in is recorded (Rule 7 ADR). When you do: keep payload normalization at the boundary (Rule 5) so a future provider swap is additive, and record `# DEVIATION(provider-agnostic)` at the call site naming the revisit trigger.

You MAY skip the router/registry for a single low-risk integration when the local interface still exists, per the deviation guidance in `modular-provider.md`.


## Relationship to Other Standards

- `modular-provider.md` defines provider ports, adapters, routers, and tests for application code.
- `extensibility.md` defines interface contracts and registry behavior for all swappable primitives.
- `architecture/mcp-integration.md` applies this standard to MCP-backed capabilities and transports.
- `installable-os/dual-transport-provider.md` applies this standard to MCP/CLI/manual capability routing in installable OS packages.
- `tech-stack.md` records whether chosen services are swappable, required, or intentionally locked.

## Compliance Test

- [ ] Does every provider-backed integration name the capability before the provider?
- [ ] Is provider/model/service selection centralized as routing policy or explicit configuration?
- [ ] Are required providers documented with setup, reason, and failure mode?
- [ ] Do optional providers define fallback or degraded behavior?
- [ ] Are provider payloads normalized before downstream consumption?
- [ ] Are tests written against the local capability/provider boundary?
- [ ] Is strategic lock-in documented in an ADR?
