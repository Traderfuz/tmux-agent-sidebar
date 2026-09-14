<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skills-authoring-best-practices.md and re-run profile-sync. -->
# Skills Authoring Best Practices

## Overview

This standard defines how to author skills that are not only structurally valid, but consistently effective in the field. It governs trigger design, scope discipline, content layering, operational quality, resource organization, and change management — the authoring decisions that determine whether a skill is reliably invoked and correctly executed. A skill can pass all structural validation rules and still fail in practice if these practices are not followed.

## Scope

**Covers:** Writing effective `description` trigger fields, deciding what belongs in `SKILL.md` versus `references/`, structuring workflow steps for operational use, organizing supporting assets, verifying a skill before shipping, and managing changes to published skills.

**Does NOT cover:** Required frontmatter fields, YAML syntax rules, or platform contracts enforced by the Claude Code loader — see `skills-standards.md` and `claude-code-skills-official.md` for those requirements.

## Principles

**Trigger first, explain second.** The `description` field is the agent's entry point. If the trigger is imprecise, no amount of quality in the body can save the skill from activating at the wrong time or failing to activate at the right time.

**One skill, one coherent workflow.** Skills that attempt to cover multiple unrelated workflows become unpredictable. Scope discipline — splitting large branching skills into focused ones — is the primary tool for maintaining agent reliability at scale.

**Disclose progressively, not all at once.** Agents read skill content in layers. Frontmatter selects the skill; the opening section orients the agent; workflow steps execute it; references deepen it only when needed. Dumping all content at the top level degrades performance and readability.

**Operational quality means no dead ends.** Every command must be copy-paste ready. Every error state must tell the agent what to do next. Skills without fallback behavior and deterministic checkpoints leave agents guessing at the point of failure.

**Stability is a contract.** Once a skill is published, its `name` is an external identifier. Renaming it breaks references. Version bumps signal behavioral changes. These are not housekeeping tasks — they are contract updates that affect every agent using the skill.

## Rules

### Trigger Design

`description` should:
- Start with the core action.
- Include explicit trigger phrases ("use when …").
- Include expected output or outcome.
- Stay concise and loader-safe (`<=1024` chars).

OFF-STANDARD:
```
"General purpose utility for many workflows."
```

ON-STANDARD:
```
"Generate release notes from git history and categorize changes into customer-facing sections."
```

### Scope Discipline

- One skill should solve one coherent workflow.
- Do not overload a skill with unrelated capabilities.
- If branches become large, split into separate skills.

### Progressive Disclosure

Skill files should guide in layers:
1. When to use
2. Quick start
3. Workflow steps
4. Optional advanced modes

Avoid dumping all references at once. Load references only when needed.

### Operational Quality

- Provide copy-paste commands.
- Include fallback behavior for missing dependencies.
- Include error messages that explain next action.
- Include deterministic checkpoints for completion.

### Resource Hygiene

- Prefer scripts for repetitive/fragile operations.
- Keep references modular in `references/`.
- Keep reusable templates in `assets/`.
- Avoid huge inline instructions when a file reference is cleaner.

### Verification Gates

Before shipping a skill:
1. YAML valid.
2. Frontmatter complete.
3. Description under 1024 chars.
4. Commands tested.
5. Referenced files exist.
6. Script permissions correct (if executable).

### Change Management

- Bump `version` when behavior changes.
- Keep `name` stable.
- Document breaking changes in skill body or changelog.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `description` written as a generic capability summary with no trigger phrases | The agent has no signal for when to invoke the skill; it either never triggers or triggers on unrelated prompts | Rewrite to lead with the action and include explicit "use when" phrasing tied to realistic user language |
| Single skill covers authentication, rate limiting, and error reporting in one file | Unrelated capabilities bloat the skill, make trigger scope too broad, and cause the skill to activate for only one sub-task while carrying unused weight | Split into three focused skills, each owning one coherent workflow |
| All workflow detail, reference tables, and examples inlined at the top of `SKILL.md` | Agents receive an instruction wall before any orientation; large inline content makes the skill slow to parse and hard to maintain | Structure with layered sections (When to use → Quick start → Steps → Advanced); move deep detail to `references/` |
| Commands written as prose descriptions ("you can run the build script") instead of copy-paste blocks | Agent must interpret and reconstruct the command, introducing errors and inconsistency | Write commands in fenced code blocks, ready to execute without modification |
| `version` not bumped after changing behavior | Users of the skill cannot detect the change; catalog indexing and update checks produce stale results | Bump `version` following semantic versioning whenever observable behavior changes |
| Referenced files listed in body without verifying they exist at the declared path | Agent attempts to load a missing reference at execution time, producing a hard failure with no actionable error | Run the Verification Gates checklist before shipping; confirm all referenced paths resolve |

## Compliance Test

- [ ] Does `description` start with the core action and include at least one explicit "use when" trigger phrase?
- [ ] Does the skill address a single coherent workflow, with no unrelated capability branches that should be separate skills?
- [ ] Is the `SKILL.md` body structured in disclosure layers (orientation, quick start, steps, advanced), with deep detail in `references/` rather than inline?
- [ ] Are all commands provided as copy-paste-ready fenced code blocks with fallback notes for missing dependencies?
- [ ] Has the Verification Gates checklist been completed — YAML valid, description under 1024 chars, commands tested, referenced files confirmed to exist?

## References

- `skills-standards.md` — Required frontmatter structure and YAML safety rules
- `claude-code-skills-official.md` — Platform contract for valid skills (Anthropic guidance)
