<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/cross-llm-portability.md and re-run profile-sync. -->
# Cross-LLM Portability Standard for Skills

Extends: [self-contained-skills.md](self-contained-skills.md)

## Overview

A skill that executes correctly in Claude Code but fails silently in Codex, Gemini CLI, or any other LLM CLI is not a portable skill — it is a Claude-specific script. This standard defines which constructs are permitted in SKILL.md content and which are platform-specific and therefore prohibited. The gate test (2026-05-16) proved that clean SKILL.md files execute cross-LLM without modification; dirty files fail at the section-execution level even when the plumbing is correct.

## Scope

This standard covers tool invocation syntax, CLI-specific references, and platform-API patterns in SKILL.md skill files.

It does NOT cover skill file structure (see `skill-structure.md`), MCP server availability declarations (see `self-contained-skills.md`), or skill content quality (see `skill-content-standards.md`).

## Principles

1. **Plain markdown is the universal interface.** Any construct that requires a specific LLM runtime to interpret must not appear in a SKILL.md. Instructions must be expressible as prose that any capable language model can follow.
2. **Declare, don't invoke.** A skill may state that an MCP tool is available and describe how to use it by name, but must not use platform-specific invocation syntax to call it.
3. **Degrade explicitly.** When a skill benefits from a platform-specific capability (e.g. parallel agent dispatch), the skill must declare a prose fallback for environments where that capability is absent.

## Rules

### Prohibited patterns

The following patterns are platform-specific and MUST NOT appear in any SKILL.md:

**Claude Code tool syntax:**
```
// OFF-STANDARD — Claude Code-specific tool invocation
Use the Task tool to dispatch skills as parallel agents.
use_mcp_tool("server", "tool", {...})
<tool>...</tool>
```

**Slash commands (Claude Code command namespace):**
```
// OFF-STANDARD — slash commands are Claude Code-specific
Run /mos-brand-voice to generate brand copy.
Invoke /cos-creative-brief before starting.
```

**Platform-specific API or product references:**
```
// OFF-STANDARD — platform product references
This skill uses Claude Code's native bash execution.
Requires claude.ai enterprise.
```

### References file links

Skills following the Progressive Disclosure Architecture (bx-skill-creator standard) put deep content in `references/` files. Local Claude Code loads these on demand via Read tool. Remote LLMs via skills-hub must call `skills/read-file` instead. The link itself is portable — the gap is whether the file is reachable.

**Two portability classes for `references/` links:**

| Class | Definition | Required action |
|-------|-----------|----------------|
| Supplementary | Skill runs correctly without the file; reference adds depth only | Add adjacent degradation sentence |
| Load-bearing | Skill cannot execute correctly without the file's content | Must be inlined into SKILL.md, OR skill declared `platform: claude-code` |

```
// OFF-STANDARD — load-bearing reference with no degradation path
See references/returning-mode.md for the full RETURNING MODE workflow.
[skill then says "execute the RETURNING MODE workflow" with no inline version]

// OFF-STANDARD — supplementary reference with no degradation sentence
See references/criteria-reference.md for full threshold derivation.
[no fallback declared — remote LLM doesn't know it can skip this]

// ON-STANDARD — supplementary reference with degradation sentence
See references/criteria-reference.md for full threshold derivation and counter-examples.
If this file is unavailable (remote session via skills-hub), the inline criteria above
are sufficient to execute the skill. Load the reference only for edge-case disambiguation.

// ON-STANDARD — load-bearing content inlined, reference for extended detail
[full RETURNING MODE workflow inline in SKILL.md]
See references/returning-mode.md for extended examples and edge cases.
If unavailable, use the inline workflow above.
```

**`_system/` file references** follow the same rule but with a different absence cause: `_system/` files are provisioned per-project by the OS installer, not bundled with the skill. When absent in a remote session, `skills/read-file` returns `{"status": "absent"}`. The skill's `## Context` table fallback behavior applies.

### Permitted patterns

**MCP tool declaration (prose form):**
```markdown
// ON-STANDARD — describes the tool without platform syntax
If a skills-hub MCP server is available, call `skills/read` with the skill name
to inject the referenced skill's content. If skills-hub is not available, ask
the user to paste the skill content directly.
```

**Parallel execution (prose form):**
```markdown
// ON-STANDARD — describes intent without Tool API syntax
Run the following analyses concurrently if the LLM supports parallel execution;
otherwise run them in sequence:
1. Scan for AI-tell criteria A1–A5
2. Scan for voice consistency criteria D9–D10
```

**Command invocation (generic form):**
```markdown
// ON-STANDARD — platform-neutral shell description
Run: grep -E "pattern" file.md
```

### MCP dependency declaration

When a skill uses an MCP tool, it MUST declare it in Prerequisites with an explicit fallback:

```markdown
## Prerequisites

**Optional (degrades gracefully without these):**
- `skills-hub` MCP server: used to inject referenced skills. Fallback: paste
  the referenced SKILL.md content directly into the session.
- `brave-search` MCP: used for web research step. Fallback: ask user to
  provide URLs or use training knowledge with explicit uncertainty flag.
```

A skill that requires an MCP tool with no fallback MUST list it as Required and document that the skill cannot proceed without it. Required MCP tools are acceptable for internal-only skills; they MUST NOT appear in skills intended for cross-LLM distribution.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `Use the Task tool to dispatch agents` | Claude Code-specific API; Codex has no Task tool by that name | Describe parallel work in prose with sequential fallback |
| `/skill-name` slash command references | Slash commands are Claude Code command namespace; not portable | Reference skills by name in prose: "invoke the `skill-name` skill" |
| `use_mcp_tool(...)` inline | Platform call syntax; other LLMs have no equivalent parse rule | Describe the tool call in prose with tool name and arguments listed as parameters |
| `<tool>` XML blocks | Claude Code tool-use format; invisible or literal text in other LLMs | Prose description of the action |
| Hardcoded `claude.ai` or `anthropic` API references | Product-specific; breaks on any other provider | Omit product references; describe capability generically |

## Deviation guidance

MAY reference a Claude Code-specific capability IF:
1. The skill is explicitly scoped as "Claude Code only" in its frontmatter: `platform: claude-code`
2. The skill's description section opens with: "This skill requires Claude Code and will not execute on other LLM CLIs."

When deviating, MUST add `platform: claude-code` to the YAML frontmatter and the explicit warning. Skills marked `platform: claude-code` are excluded from skills-hub cross-LLM distribution.

## Profile inheritance notes

Extends: `self-contained-skills.md` — adds cross-LLM portability layer on top of Claude Code self-containment rules.

All rules in `self-contained-skills.md` still apply. This standard adds the additional constraint that portability extends beyond Claude Code to any LLM CLI.

## Compliance test

Run before publishing or distributing any SKILL.md:

```bash
# Portability check — all should return 0 matches
grep -cE "Task tool|use_mcp_tool|<tool>|TOOL_USE" SKILL.md
grep -cE "claude\.ai|anthropic\.(com|api)" SKILL.md
grep -cE "^(Run |Invoke |Call )?/[a-z][a-z0-9-]+" SKILL.md
```

- [ ] `Task tool` / `use_mcp_tool` / `<tool>` / `TOOL_USE` — 0 matches?
- [ ] `claude.ai` / `anthropic.com` / `anthropic.api` — 0 matches?
- [ ] Slash command references (`/skill-name` at line start) — 0 matches?
- [ ] All MCP tool dependencies declared in Prerequisites with fallback?
- [ ] If any platform-specific construct is present: `platform: claude-code` in frontmatter AND warning in description?
- [ ] Every `references/` link has an adjacent degradation sentence OR the linked content is inlined?
- [ ] No load-bearing `references/` link exists without the content also being inline in SKILL.md?
- [ ] Every `_system/` file reference has a declared fallback in the `## Context` table (per `context-contract.md`)?

```bash
# References portability check — manual review required for flagged lines
grep -n "references/" SKILL.md
# For each result: confirm adjacent line contains "unavailable", "not available", "remote session", or "fallback"
```

If any check fails: either remove the platform-specific construct and replace with prose equivalent, or add `platform: claude-code` to frontmatter and the explicit portability warning.

## References

- [self-contained-skills.md](self-contained-skills.md) — parent standard: dependency declaration, runtime environment assumptions
- [skill-structure.md](skill-structure.md) — SKILL.md file structure and required sections
- [Write Once Run Anywhere (WORA)](https://en.wikipedia.org/wiki/Write_once,_run_anywhere) — Java portability principle: platform-specific constructs belong in the platform layer, not the business logic layer
- Gate test findings (2026-05-16): `anti-ai-tells` (clean) executed fully in Codex; `mos-orchestrator` (dirty: Task tool, slash commands) failed at section-execution level despite correct plumbing
