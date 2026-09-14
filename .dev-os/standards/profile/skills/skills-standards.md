<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skills-standards.md and re-run profile-sync. -->
# Skills Standards

## Overview

This standard defines the minimum valid structure and quality requirements for `SKILL.md` files. It governs frontmatter format, YAML safety, naming conventions, and body content so that skills load reliably across agents and runtimes. Without consistent structure, loaders silently reject skills or trigger them at the wrong time, eroding agent reliability.

## Scope

**Covers:** `SKILL.md` file structure, frontmatter fields, YAML syntax rules, naming conventions, and body content requirements for all skills in the DevOS skills catalog.

**Does NOT cover:** Skill trigger design strategy, progressive disclosure patterns, or how to write effective workflow steps — see `skills-authoring-best-practices.md` and `claude-code-skills-official.md` for those concerns.

## Principles

**Fail-loud on invalid structure.** A malformed frontmatter block causes silent load failure. Hard rules exist so authors catch errors before publishing, not at runtime.

**Stability over flexibility in naming.** Skill `name` and folder name are external identifiers referenced by other agents. Renaming breaks references; treat them as stable contracts from the moment of first publish.

**Minimal frontmatter, maximal discoverability.** The three required keys (`name`, `description`, `version`) are the minimum surface needed to load, identify, and trigger a skill. Adding more required fields increases the maintenance cost for authors without proportional benefit.

**Descriptions are runtime selectors, not documentation.** The `description` field is used by agents to decide whether to invoke the skill. It must be written to trigger correctly, not to explain the skill to a human reader.

**YAML validity is non-negotiable.** Invalid YAML in frontmatter does not produce a graceful error — it silently breaks the skill. Authors must validate YAML before committing.

## Rules

### Required Frontmatter

Every `SKILL.md` MUST begin with YAML frontmatter delimited by `---`:

```markdown
---
name: your-skill-name
description: "What this skill does and when to use it."
version: 1.0.0
---
```

Required keys:
- `name`
- `description`
- `version`

### Validation Rules

These are hard validation checks used in production loaders:

| Rule | Requirement |
|------|-------------|
| Frontmatter delimiters | Must start with `---` and close with `---` |
| YAML validity | Must parse as valid YAML |
| Description length | `description` must be `<= 1024` characters |
| Description type | Must be a plain string |
| Name presence | `name` must exist and be non-empty |
| Version presence | `version` must exist and be non-empty |

### YAML Safety Rules

- Quote `description` by default: `description: "..."`.
- Avoid unescaped colons in unquoted values.
- Avoid tabs; use spaces only.
- Keep one frontmatter block only at the top of file.
- Ensure body content starts after the closing `---`.

### Naming Rules

- Prefer lowercase kebab-case for `name` (for consistency and discoverability).
- Keep names stable once published.
- Use semantic versions for `version` (e.g. `1.0.0`, `1.2.3`).

### Description Rules

`description` should be:
- Triggerable: include clear "use when…" phrasing.
- Concise: short enough to stay far below the 1024-char hard limit.
- Specific: state scope and expected outcome.

Recommended target length:
- 120-400 characters.

### Body Content Rules

- Include a `#` heading matching the skill title.
- Include a "When to use this skill" section.
- Include a concrete workflow or steps.
- Keep commands and paths copy-paste ready.

### Loader Reliability Checklist

Before publishing or syncing:
1. Confirm a single valid frontmatter block exists.
2. Confirm `description` length is under 1024.
3. Confirm YAML parser passes.
4. Confirm markdown body still exists after frontmatter.
5. Confirm `name` and `version` are present.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Unquoted `description` with a colon inside | YAML parser treats the colon as a key separator, breaking the frontmatter block | Always quote `description`: `description: "..."` |
| `name` uses `PascalCase` or spaces | Breaks discoverability conventions and may fail regex-based lookups in the catalog | Use lowercase kebab-case: `name: my-skill-name` |
| Multiple `---` frontmatter blocks in one file | Loaders read only the first block; a second block is treated as markdown body content, producing silent data loss | Keep exactly one frontmatter block at the top of the file |
| `description` exceeds 1024 characters | Hard loader limit; skill is rejected silently at load time | Trim to 120-400 characters and move detail into the body |
| Body content placed before the closing `---` | Content before the close delimiter is parsed as YAML, not markdown, producing a parse error | Place all markdown body content strictly after the second `---` |
| `version` field omitted | Loader rejects the skill; version is required for update tracking and catalog indexing | Always include `version` using semantic versioning: `1.0.0` |

## Deviation Guidance

Authors MAY omit the `#` heading in the body when the skill is a pure automation script with no human-readable workflow steps. Authors MUST retain all three required frontmatter fields (`name`, `description`, `version`) without exception — the loader has no fallback for missing required keys.

## Compliance Test

- [ ] Does the file start with a valid `---`-delimited YAML frontmatter block?
- [ ] Are all three required keys (`name`, `description`, `version`) present and non-empty?
- [ ] Is `description` quoted and under 1024 characters?
- [ ] Is `name` in lowercase kebab-case and stable (not renamed from a prior published version)?
- [ ] Does the markdown body begin after the closing `---` and include at least a heading and a "When to use" section?

## References

- `claude-code-skills-official.md` — Platform contract for valid skills (Anthropic guidance)
- `skills-authoring-best-practices.md` — Trigger design, scope discipline, progressive disclosure
- `self-contained-skills.md` — Portability rules: no hardcoded absolute paths, no assumed project structure, explicit dependency declaration
