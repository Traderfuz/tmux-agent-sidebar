<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/command-execution-authority.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/command-execution-authority.md and re-run profile-sync. -->
# Command Execution Authority

## Overview

Every command that invokes an external MCP tool is the **sole execution authority** for that operation. AI agents MUST execute the command workflow top to bottom — never extract a tool name from a command doc and call it directly. This standard exists because agents that shortcut to raw MCP calls bypass context loading, validation gates, output path routing, and approval flows, producing incorrect or unverifiable output.

This applies to all DevOS profiles and all OS packages — any command file (`.claude/commands/*.md`) that references an MCP tool is covered.

Derived from a production incident in Creative OS where `mcp__replicate__generate_logo_recraft` was called 4x directly during a `cos-logo-design` session — brand colors were described in words rather than bound from the brand kit, Recraft approximated hex values, and WCAG validation, token consistency checks, and output path logic were all skipped. The same class of failure applies to any command that wraps MCP tools: research commands that skip source-tier cost ladders, deployment commands that skip preflight checks, design commands that skip token binding.

## Scope

This standard covers the relationship between command files (`.claude/commands/*.md`, `.claude/commands/{prefix}-*.md`) and the MCP tools they invoke. It does NOT cover MCP tool configuration, tool routing hierarchies (documented in CLAUDE.md), or the internal implementation of skills referenced by commands.

## Frameworks

### The Gate Pattern (Command-as-Gate Architecture)

Anchored to the **Convention over Configuration** principle (DHH, 2004) applied to AI agent execution: the command file defines the default execution path; only the command file may invoke the underlying tools; deviation requires an explicit flag (`--autonomous`, `--brief-first`) rather than silent shortcutting.

The command doc is not documentation — it is a behavioral contract. The agent reads it, follows it, and produces output through the prescribed gates. This is analogous to how a CI pipeline enforces that tests run before deploy — the steps exist to enforce correctness, not add ceremony.

### RFC 2119 Normative Vocabulary

This standard uses RFC 2119 authority levels (MUST, SHOULD, MAY, MUST NOT) because partial compliance produces real risk: off-brand assets delivered to clients, unlogged generations that can't be reproduced, and output saved to wrong paths that break downstream pipeline consumers.

## Principles

1. **Command supremacy:** The command file is the sole execution authority for its operation. No agent, skill, or orchestrator may bypass a command by calling its underlying MCP tools directly.
2. **Gates enforce correctness:** Workflow steps exist because skipping them produces incorrect output — not because they add process. Every gate has a concrete failure mode it prevents.
3. **Explicit deviation over silent shortcutting:** When a workflow step should be skipped, the command provides a named flag (`--autonomous`, `--brief-first`). Unnamed deviation is a bug.

## Rules

### G-001: Agent Execution Rule Header (`MUST`)

Every command that calls one or more MCP tools MUST contain a `## Agent Execution Rule` section immediately after the description block. This section:

1. Names the specific MCP tools that are prohibited from direct invocation
2. Lists the workflow steps that would be bypassed by direct calls
3. Ends with: "If you are an AI agent reading this command — execute it top to bottom."

```markdown
// OFF-STANDARD (no enforcement header — agent will shortcut)
---
name: generate-image
skill: ai-image-generation
---
# Generate Image
Generate high-quality images.

## Model Routing
...

// ON-STANDARD
---
name: generate-image
skill: ai-image-generation
---
# Generate Image
Generate high-quality images.

## Agent Execution Rule

**NEVER call `mcp__nano-banana__generate_image`, `mcp__replicate__generate_image_recraft`,
or any image generation MCP tool directly as a substitute for running this command.**

This command is the sole execution authority for image generation. Calling tools
directly bypasses:
- Step 1a: Trend-informed prompt enrichment
- Step 2: Creative brief check (brand palette, imagery style, tone)
- Step 3: Structured prompt construction
- Step 5: Image type classification (hero vs illustration vs section-graphic)
- Step 6: Correct output path routing per type

If you are an AI agent reading this command — execute it top to bottom. Do not shortcut
to the generation tool.

## Model Routing
...
```

**Template for new commands:**

```markdown
## Agent Execution Rule

**NEVER call `mcp__[namespace]__[tool]` or any [operation type] MCP tool directly
as a substitute for running this command.**

This command is the sole execution authority for [operation]. Calling tools
directly bypasses:
- Step N: [what gets skipped — be specific about the failure mode]
- Step N: [what gets skipped]
- Step N: [what gets skipped]

If you are an AI agent reading this command — execute it top to bottom. Do not shortcut
to the [tool category]. The workflow exists to enforce correctness, not add ceremony.
```

### G-002: Path Selection Gate (`SHOULD` — when multiple generation strategies exist)

Commands with more than one valid execution strategy SHOULD surface a `## Step 0: Path Selection` section presenting a comparison table with a stated default. The agent MUST announce the selected path to the user before proceeding.

```markdown
## Step 0: Path Selection

| Path | Approach | Tool | Output | Best for |
|------|----------|------|--------|----------|
| **A — Constraint-first** *(default)* | Technical requirements drive shape | `tool_a` | SVG | Brand kit exists |
| **B — Brief-first** | Personality drives shape | `tool_b` | PNG | New brand, no kit |

**Default:** Path A unless `--brief-first` flag is passed or precondition is unmet.
```

**When to apply:** Any command where the wrong path selection wastes generation credits or produces output in the wrong format. If there's only one valid path, omit this section entirely — do not create a single-row table.

### G-003: Review Gate (`MUST` — between generation and irreversible output)

Every command that generates assets MUST include a review halt between generation and irreversible file operations (extraction, color remapping, final writes). The gate:

1. Presents generated output for user review
2. Requires explicit user selection or approval
3. Supports `--autonomous` flag in frontmatter to skip the human pause for CI/headless runs
4. MUST still run output quality review (Step 7B pattern) even in autonomous mode

```markdown
## Review Gate

**HALT.** Present all generated concepts to the user. Do not proceed until:
- User selects a concept (or `--autonomous` flag auto-selects the strongest)

**Even in `--autonomous` mode:** Run output review (check colors, legibility, quality)
before proceeding. `--autonomous` skips the human pause, not the quality check.
```

**Rationale:** Generation tools are non-deterministic. The review gate prevents irreversible downstream operations (SVG extraction, color remapping, file system writes) from locking in a bad generation.

### G-004: Canonical Path References (`MUST`)

All glob patterns, file paths, and directory references within command docs MUST use the OS package's actual output directory structure — not legacy paths from prior implementations or other OS packages.

```
// OFF-STANDARD (references a legacy path layout)
brand-kits/*/02-logos/concepts/*brief-first.svg

// ON-STANDARD (matches Creative OS output structure)
creative/brand/{client}/logo/concepts/**/*.svg
```

**Compliance check:** Search each command doc for glob patterns and verify every path segment matches a directory that actually exists in the OS output structure documented in CLAUDE.md.

### G-005: Session Log Requirement (`SHOULD` — for multi-step commands with 5+ steps)

Commands with 5 or more sequential steps SHOULD require a session log file created before Step 1. The log contains a step checklist that is updated incrementally as each step completes.

```markdown
## Session Log — Write This First

**Before Step 1 — create this file:**

`{output_root}/{area}/{client}/{date}/session-log.md`

Write the full checklist:
- [ ] Step 1: [description]
- [ ] Step 2: [description]
...

Update each checkbox: `[>]` in progress, `[x]` complete.
Do not mark a step complete without producing its required output artifact.
```

**Purpose:** Enables session recovery after interruption. The agent resumes from the last incomplete step rather than restarting the entire workflow.

### G-006: State Tracking Initialization (`SHOULD` — for commands that produce multi-artifact output)

Commands that produce multiple related output artifacts SHOULD initialize a JSON state file at the start of execution. The state file tracks which artifacts have been produced and which validation checks have passed.

```json
{
  "brand": "example",
  "slug": "example-brand",
  "date": "2026-03-28",
  "validation": {
    "wcagCompliant": false,
    "tokenConsistency": false
  }
}
```

**Update the state file** after each validation step. This enables:
- Session recovery without re-running completed validations
- Downstream commands to check preconditions (`"wcagCompliant": true`) before consuming output

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Agent reads command doc, extracts tool name, calls tool directly | Bypasses brand context, validation, output routing, logging | Execute the command workflow top to bottom |
| Command doc lists tools but has no prohibition statement | Agent has no signal that direct calls are forbidden | Add G-001 Agent Execution Rule header |
| Review gate exists but `--autonomous` skips quality check too | Bad generations get locked into final output without review | `--autonomous` skips human pause only; quality review always runs |
| Glob patterns reference paths from a different OS or legacy layout | Cross-pollination and file discovery silently fail | Audit all globs against actual output directory structure |
| No session log for 8+ step workflow | Interruption means full restart; lost work | Add session log with incremental checkbox updates |
| State file never updated after validation | Downstream commands can't verify preconditions | Update JSON state immediately after each validation pass |

## Deviation Guidance

You MAY omit G-002 (Path Selection) when the command has exactly one generation strategy with no alternatives.

You MAY omit G-005 (Session Log) for commands with fewer than 5 steps where interruption recovery is trivial (re-run is faster than maintaining state).

You MAY omit G-006 (State Tracking) for commands that produce a single output artifact with no downstream consumers.

You MUST NOT omit G-001 (Agent Execution Rule), G-003 (Review Gate), or G-004 (Canonical Paths). These are non-negotiable for any command that invokes MCP tools.

When deviating, add a comment to the command file: `<!-- G-00N omitted: [reason] -->`.

## Profile Inheritance Notes

This standard lives in the `default` profile (root of the inheritance chain). All profiles inherit it: `general`, `webapp`, `cli`, `installable-os`, `agents`, `cloudflare-workers`, and any custom profiles.

Child profiles MAY extend this standard with domain-specific additions (e.g., `installable-os` adds OS-specific output path conventions). Child extensions SHOULD link back to this file and state only the delta.

## Compliance Test

- [ ] Every command that calls an MCP tool has a `## Agent Execution Rule` header listing the specific prohibited tools? (G-001)
- [ ] Every Agent Execution Rule header lists the workflow steps that would be bypassed by direct tool calls? (G-001)
- [ ] Commands with multiple generation strategies have a `## Step 0: Path Selection` table with a stated default? (G-002)
- [ ] Every generation command has a review gate between generation and irreversible output operations? (G-003)
- [ ] The `--autonomous` flag (if present) skips only the human pause, not the output quality review? (G-003)
- [ ] All glob patterns and file paths in command docs match the actual OS output directory structure? (G-004)
- [ ] Commands with 5+ sequential steps have a session log requirement? (G-005)
- [ ] Commands producing multi-artifact output initialize a JSON state file? (G-006)
- [ ] No command doc contains a tool name without also containing an Agent Execution Rule header? (cross-check)

If any check fails: add the missing enforcement element to the command doc before shipping. A command that names its tools but doesn't enforce execution authority is a shortcut invitation.

## References

- [RFC 2119 — Key words for use in RFCs](https://datatracker.ietf.org/doc/html/rfc2119) — normative vocabulary for authority levels (MUST, SHOULD, MAY)
- [Convention over Configuration](https://rubyonrails.org/doctrine#convention-over-configuration) — sensible defaults handle common cases; only deviation requires explicit specification
- Creative OS spec: `product/specs/2026-03-28-command-enforcement-pattern/spec.md` — origin specification documenting the production incident and 5-part remediation
- Creative OS gap analysis: `product/gap-analysis/creative-os-logo-design-gap-analysis-2026-03-28.md` — severity-scored gap analysis that identified G-001 through G-006
