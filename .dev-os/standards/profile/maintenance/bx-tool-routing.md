<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/bx-tool-routing.md and re-run profile-sync. -->
# bx-* Deterministic Tool Routing Standard

## Overview

DevOS has specialized `bx-*` skills for creating, improving, and auditing specific artifact types. This standard pins each domain to its authoritative tool so that commands, workflows, and sessions route work to the correct skill deterministically — no guessing, no ad-hoc approaches.

Inline work — writing a SKILL.md manually, authoring a workflow without `bx-workflow-creator`, writing standards prose without `bx-standards-creator` — skips the research phases and structural validators those tools enforce. The result is generic output that fails the artifact's own quality checklist. This standard exists because the cost of routing correctly is low; the cost of routing incorrectly compounds across every artifact that inherits from the broken one.

## Scope

This standard covers which `bx-*` skill is the authoritative tool for each DevOS artifact domain, when routing is triggered, what mechanical gates enforce the routing, and what falls through to AI-only behavioral enforcement. It does NOT cover the internal structure of individual `bx-*` skills (each skill's SKILL.md governs that), command wrapper conventions (see `command-skill-split.md`), or debugging escalation routing (see `debugging-escalation.md`).

## Principles

1. **One domain, one tool:** Each artifact domain has exactly one authoritative tool. Routing ambiguity — "should I use bx-skill-creator or write it manually?" — is resolved by this table, not by context-dependent judgment.
2. **Research phases cannot be skipped:** The `bx-*` skills run mandatory framework research, scope definition, and structural validation steps. Inline work bypasses all of these. The routing rule exists to prevent bypassing them.
3. **Fallback is explicit and logged:** When the authoritative tool is unavailable, the fallback is a logged deviation — not a silent inline attempt. The log creates a debt record that tracks where the routing guarantee was not met.
4. **Gates enforce what behavior cannot:** Behavioral compliance (AI choosing the right tool) is unreliable across sessions and agents. Mechanical gates — pre-commit hooks, CLAUDE.md bx-tool-routing rules — catch violations that behavioral compliance misses.

## Domain-to-Tool Mappings

| Domain | Authoritative Tool | When to Route |
|---|---|---|
| Agent creation or upgrade | `bx-agent-creator` | Creating a new agent description, upgrading an existing agent prompt, auditing agent compliance |
| Skill creation | `bx-skill-creator` | Creating a new skill from scratch with research and vibe framework |
| Skill improvement | `bx-skill-creator` | Auditing an existing skill, upgrading to vibe framework, patching missing elements |
| Command improvement | `bx-improve-commands` | Auditing command files against the command quality standard, batch command audits |
| Standards writing | `bx-standards-creator` | Authoring a new standards document, refining extracted standards into authoritative references |
| Workflow creation | `bx-workflow-creator` | Creating a new workflow file, updating workflow structure, extracting shared snippets |
| Debugging escalation | `systematic-debugging` or `diagnose-first` | Root cause unknown, fix attempts stalling, or same error persisting after 2 tries — see `debugging-escalation.md` |
| MCP tool availability check | `mcp-tool-first` standard + `{{workflows/_shared/mcp/registry-check-step}}` | Before any step that would ask the user to manually verify something in an external service — see `mcp-tool-first.md` |

## Self-Application Rule

DevOS uses these tools on its own artifacts. When a DevOS spec, task, or maintenance workflow requires work in one of the domains above, it must delegate to the named skill rather than performing the work inline.

**Example:** A spec that includes "create a new skill for command auditing" must invoke `bx-skill-creator`, not write the SKILL.md manually.

For command surfaces that keep a public `` contract while delegating beneath it, pair this standard with `command-skill-split.md`.

## Routing Enforcement

### What gates routing mechanically

The following mechanisms enforce routing without relying on AI behavioral compliance:

**1. CLAUDE.md bx-tool-routing block (primary gate)**
The `bx-* Tool Routing` section in `~/.claude/CLAUDE.md` is a BLOCKING REQUIREMENT for Claude Code. It lists trigger phrases and maps them to skills. Claude Code reads CLAUDE.md at session start; the rule fires for every matching request in that session. This is the highest-reliability gate because it runs in every session automatically.

**2. Pre-commit hook enforcement** (`scripts/hooks/pre-commit-posture-validation.sh`)
The pre-commit hook validates staged SKILL.md files against SK1–SK12 and workflow files against C1–C14. If a skill or workflow was authored inline (bypassing `bx-skill-creator` or `bx-workflow-creator`), it will often fail must-fix checks and be blocked at commit time. This gate catches routing violations that got past the CLAUDE.md behavioral gate.

**3. Validate scripts (audit-only, not blocking)**
`scripts/lib/validate-skill.sh` and `scripts/lib/validate-workflow.sh` can be run manually or in CI to audit existing artifacts. They report PASS/FAIL/MISSING per check. These scripts do not prevent inline authoring — they surface it after the fact.

### What falls through to AI-only behavioral gates

The following routing requirements are enforced only by the CLAUDE.md rule — there is no structural check that catches violations:

- Standards documents authored inline instead of via `bx-standards-creator` — the output is a Markdown file; no schema validator catches a missing compliance test or principles section unless Mode 2 audit is explicitly run
- Agent prompts authored inline instead of via `bx-agent-creator` — agent system-prompt.md has no automated structural validator
- Commands improved inline instead of via `bx-improve-commands` — frontmatter is checked by `validate-command-category.sh` for `category:` only; quality checks are not automated

**Escalation path when routing fails:**
If an artifact was authored inline and discovered later (via Mode 2 audit or manual review), use the appropriate `bx-*` skill in Mode 2 (audit) or Mode 3 (optimize) to bring it up to standard. Do not rewrite from scratch unless the gap report shows ≥5 must-fix failures.

### Before/after routing examples

```markdown
# OFF-STANDARD — inline skill authoring
# (user asks: "create a skill for X")
# Claude writes SKILL.md directly without invoking bx-skill-creator
# Result: missing frameworks section, no Works-when list, no compliance test

# ON-STANDARD — routed authoring
# (user asks: "create a skill for X")
# Claude invokes: Skill tool with skill: "bx-skill-creator"
# bx-skill-creator runs: scope → framework research → principle excavation → SK1–SK12 validated output
```

```markdown
# OFF-STANDARD — inline standards authoring
# Claude writes a standards .md without invoking bx-standards-creator
# Result: no named framework, no compliance test, fails Mode 2 audit at STD1/STD3

# ON-STANDARD — routed authoring
# Claude invokes: Skill tool with skill: "bx-standards-creator"
# bx-standards-creator runs: ISO scope → Context7 research → principle vs rule balance → 10/10 structure
```

Commands and workflows that perform work in a mapped domain should:

1. Check if the authoritative tool exists in the skills catalog
2. Delegate to it with the appropriate inputs
3. Document the delegation in the command/workflow (e.g., "Delegates to `bx-skill-creator` for skill creation")

If the authoritative tool is unavailable (not installed, skill missing), fall back to manual implementation but log a warning:

> bx-tool-routing: `<tool>` not found — falling back to manual implementation. Install with `import-skill <tool>`.

## Adding New Mappings

To add a new domain-to-tool mapping:

1. Add a row to the table above
2. Update CLAUDE.md to reference the new mapping
3. Ensure the tool exists in `.claude/skills/` or is importable via `find-skills`

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Writing SKILL.md manually when asked to "create a skill" | Skips bx-skill-creator's research phase; produces artifacts that fail SK1–SK12 structural checks | Invoke `bx-skill-creator` via the Skill tool; let it run the research + validation workflow |
| Writing a standards doc inline when asked to "write a standard" | Skips ISO scope + Context7 framework research; produces docs that fail Mode 2 audit at STD1/STD3 | Invoke `bx-standards-creator` via the Skill tool |
| Routing to bx-skill-creator for workflow creation | Wrong tool; bx-skill-creator does not validate C1–C14 workflow structure | Invoke `bx-workflow-creator` for all workflow .md files |
| Falling back silently to inline work when bx-* tool is unavailable | Creates an invisible deviation; no debt record; next audit finds an artifact with no clear lineage | Log the fallback warning explicitly and create a task to re-author with the correct tool when available |
| Running Mode 2 audit and not acting on must-fix findings | Auditing without fixing turns the standard into performance — the gap exists, it's just documented | Follow Mode 2 audit with Mode 3 optimization for each must-fix gap, or schedule it as a tracked task |

## Compliance test

- [ ] For every SKILL.md created or modified in the last sprint, was `bx-skill-creator` invoked — or is a fallback log entry present?
- [ ] For every workflow .md created or modified, was `bx-workflow-creator` invoked — or is a fallback log entry present?
- [ ] For every standards document created or modified, was `bx-standards-creator` invoked — or is a fallback log entry present?
- [ ] Does `scripts/lib/validate-skill.sh` pass on all SKILL.md files (zero must-fix failures)?
- [ ] Does `scripts/lib/validate-workflow.sh` pass on all workflow .md files (zero must-fix failures)?
- [ ] Are all inline-authored artifacts from before this standard was in place tracked as tasks for Mode 3 optimization?

If any check fails: identify which artifacts bypassed routing, run the appropriate `bx-*` tool in Mode 2 to audit them, and schedule Mode 3 patches for must-fix gaps.

## Zero-Gap Dalio Posture (creator delivery gate)

Every artifact produced by a `bx-*` creator skill must pass a `gap-analysis --dalio` run with **zero open gaps** before it is committed or delivered. This applies to all bx-* creators:

| Creator skill | Applies to |
|---|---|
| `bx-agent-creator` | `system-prompt.md`, `DESIGN-NOTES.md`, `agent-spec.md` |
| `bx-skill-creator` | `SKILL.md` + all `references/` files |
| `bx-workflow-creator` | Workflow `.md` files |
| `bx-command-creator` | Command `.md` files |
| `bx-standards-creator` | Standards `.md` files |
| `bx-pipeline-creator` | Pipeline definition files |

The Dalio gap-analysis run is the final delivery gate — it catches machine-layer gaps (designer/manager/worker) that structural validators (SK1–SK12, C1–C14) do not cover. Zero open gaps = ready to commit.

## Related Standards

- `command-skill-split.md` for ownership boundaries between commands, skills, workflows, and `scripts/lib`
- `command-quality.md` for baseline command wrapper structure
- `debugging-escalation.md` for when to route error-fixing work to systematic-debugging or diagnose-first
