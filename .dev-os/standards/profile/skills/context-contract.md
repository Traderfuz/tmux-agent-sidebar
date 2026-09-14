<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/context-contract.md and re-run profile-sync. -->
# Context Contract Standard for Skills

Extends: [self-contained-skills.md](self-contained-skills.md)

## Overview

A skill that reads `_system/brand-memory.md` without declaring it has an invisible dependency. If the file is absent, stale, or renamed, the skill silently degrades or fails with a cryptic error. A skill that declares its context dependencies up front lets operators know what to provision, lets orchestrators pre-validate readiness, and lets cross-LLM runners (Codex, Gemini, etc.) surface the right files before execution begins.

This standard defines the `## Context` table — the universal declaration format every SKILL.md uses to enumerate which shared context files it reads and writes.

## Scope

This standard covers the `## Context` table format in SKILL.md files and the behavioral rules for handling declared context files. It does NOT cover the content or schema of `_system/` files themselves (that is each OS's domain responsibility), nor the file discovery mechanism (how `_system/` files are found at runtime), nor cross-OS handoff schemas (see `handoff-schema.md` when written).

## Principles

1. **Declare before you read.** Every `_system/` file a skill touches must appear in the `## Context` table. Undeclared reads are invisible dependencies — they break silently and cannot be validated.
2. **Explicit absence handling.** A skill must state in prose what it does when an optional context file is absent. "Skip" and "ask user" are both valid — but silence is not.
3. **Freshness is a contract, not a hint.** A freshness threshold declared in the table is the skill's stated tolerance. Exceeding it is a warning, not a hard failure — but it must be surfaced to the user, not ignored.
4. **Relative paths only.** Context file paths are relative to the OS package root. Absolute paths break portability across machines and OS install locations.

## Rules

### The `## Context` table

Every SKILL.md that reads or writes any `_system/` file MUST include a `## Context` section with this table:

```markdown
## Context

| File | Role | Required? | Freshness |
|------|------|-----------|-----------|
| _system/brand-memory.md | voice, audience, positioning | optional | 30d |
| _system/campaigns/active.md | active campaign context | optional | 7d |
```

**Skills with no `_system/` dependencies** MAY omit the `## Context` section entirely, OR include it with an explicit empty declaration:

```markdown
## Context

None. This skill has no shared context dependencies.
```

The empty declaration is preferred for skills in OS packages where `_system/` files exist but this skill deliberately ignores them — it signals intent rather than omission.

### Column definitions

| Column | Type | Rules |
|--------|------|-------|
| `File` | Path | Relative to OS package root. MUST start with `_system/`. No absolute paths. No `~/` or `$HOME`. |
| `Role` | Description | 1–5 words. What this skill uses the file for. Not the file's full description. |
| `Required?` | `required` or `optional` | `required` = skill cannot proceed without it. `optional` = skill degrades gracefully. |
| `Freshness` | Duration or `static` | Max age before warning: `7d`, `30d`, `90d`, `static`. See thresholds below. |

### Freshness thresholds

| Signal | Threshold |
|--------|-----------|
| Campaign / time-sensitive content | `7d` |
| Brand voice, positioning, audience | `30d` |
| Style system, design tokens | `30d` |
| Knowledge base, research synthesis | `90d` |
| Evergreen reference (templates, schemas) | `static` |

`static` means the file is expected to be updated only by intentional human edit, not by time passage. No freshness warning is emitted for `static` files.

When a file's mtime exceeds the declared threshold, the skill MUST warn the user:

```
⚠ _system/brand-memory.md is 45 days old (threshold: 30d).
  Context may be stale. Proceed anyway or update _system/brand-memory.md first.
```

The skill MUST NOT silently proceed without surfacing the warning.

### Required file absence behavior

When a `required` file is absent, the skill MUST halt with an explicit message:

```
✗ Required context file missing: _system/brand-memory.md
  This skill cannot proceed without brand-memory.md.
  Create it at: <OS-package-root>/_system/brand-memory.md
  See: _system/README.md for the expected format.
```

The skill MUST NOT attempt to infer or guess the missing content. The skill MUST NOT proceed silently.

### Optional file absence behavior

When an `optional` file is absent, the skill MUST declare its fallback in prose near the `## Context` table:

```markdown
## Context

| File | Role | Required? | Freshness |
|------|------|-----------|-----------|
| _system/brand-memory.md | voice + positioning | optional | 30d |

**When _system/brand-memory.md is absent:** Apply voice criteria D9–D10 as N/A.
Report them as `N/A (no brand voice profile)` rather than failing or guessing.
```

Acceptable fallback behaviors:
- Skip the criteria that depend on the file
- Ask the user to provide the content inline
- Use training knowledge with an explicit uncertainty flag

Unacceptable fallback:
- Silent skip (no mention to the user)
- Guessing file content from training data without disclosure

### Multiple files

When a skill reads multiple `_system/` files, list each as a separate row. Do not combine rows.

```markdown
## Context

| File | Role | Required? | Freshness |
|------|------|-----------|-----------|
| _system/brand-memory.md | voice + positioning | optional | 30d |
| _system/campaigns/active.md | active campaign | optional | 7d |
| _system/style-tokens.md | visual language | required | 30d |
```

### Write declarations

If a skill writes to a `_system/` file (e.g., an update skill that refreshes brand-memory), declare it with role `write` or `read/write`:

```markdown
| _system/brand-memory.md | brand memory update | required | 30d |
```

Note in the role column that this is a write operation. Declare the file whether read, write, or both.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Reads `_system/brand-memory.md` with no `## Context` table | Invisible dependency — breaks silently, cannot be validated | Declare in `## Context` table |
| `File` column uses absolute path `/home/user/os/_system/...` | Breaks on any other machine or install location | Relative path: `_system/brand-memory.md` |
| `Required?` = `optional` with no fallback prose | Reader has no idea what happens when the file is absent | Add "When X is absent:" sentence after table |
| `Freshness` = `1y` or blank | No meaningful staleness signal | Use domain-appropriate threshold from table above |
| Skill halts silently when required file is missing | User sees cryptic failure, no repair path | Emit explicit message with file path and fix instructions |
| Lists `_system/` file in prose but not in table | Table is the contract — prose alone is not machine-readable | Move to table row |

## Deviation guidance

A skill MAY omit the `## Context` section entirely when it has no `_system/` dependencies AND is clearly a standalone utility skill (e.g., a text formatter with no brand context). When omitting: the absence of the section is the declaration. Adding a comment in the SKILL.md frontmatter is encouraged for clarity:

```yaml
context_dependencies: none
```

A skill MUST NOT omit the `## Context` section when it reads any `_system/` file, regardless of how small or "obvious" the dependency seems.

## Profile inheritance notes

Extends: `self-contained-skills.md` — adds context declaration layer on top of self-containment rules.

`installable-os` provides this pattern (the HOW). Each OS provides its own `_system/` files (the WHAT):

| OS | `_system/` domain files |
|----|------------------------|
| marketing-os | `brand-memory.md`, `campaigns/active.md`, `assets.md` |
| creative-os | `style-system.md`, `campaign-assets.md` |
| research-os | `knowledge-base.md`, `sources.md`, `synthesis.md` |
| design-os | `design-system.md`, `tokens.md`, `brand-guidelines.md` |
| dev-os | (no `_system/` — skills are domain-agnostic) |

Skills in each OS declare which of their OS's `_system/` files they depend on. The `## Context` table format is identical across all OSes.

## Compliance test

Run before publishing or distributing any SKILL.md that touches `_system/` files:

- [ ] Does the SKILL.md have a `## Context` section (or explicit `context_dependencies: none` frontmatter)?
- [ ] Does every `_system/` file the skill reads or writes appear as a row in the table?
- [ ] Does each row have all 4 columns: File, Role, Required?, Freshness?
- [ ] Does the `File` column use relative paths only (no `~/`, `$HOME`, or absolute paths)?
- [ ] Does the `Freshness` column use a value from the approved threshold list (`7d`, `30d`, `90d`, `static`)?
- [ ] For every `optional` file: is there prose after the table declaring what the skill does when the file is absent?
- [ ] For every `required` file: does the skill halt with an explicit message (not silent failure) when the file is absent?
- [ ] Does the skill surface a warning (not silent proceed) when a file's mtime exceeds the declared freshness threshold?

If any check fails: add the missing declaration, fallback prose, or absence-handling behavior before publishing.

## References

- [Interface Segregation Principle (ISP)](https://en.wikipedia.org/wiki/Interface_segregation_principle) — clients should not depend on interfaces they don't use; applied here: skills declare only what they actually read/write, making dependencies explicit and minimal
- [OpenAPI `components/schemas`](https://swagger.io/specification/) — dependency declaration pattern: name the resource, its role, and whether it is required; same pattern applied to SKILL.md context files
- [self-contained-skills.md](self-contained-skills.md) — parent standard: dependency declaration, runtime environment assumptions
- [cross-llm-portability.md](cross-llm-portability.md) — sibling standard: portability constraints that context declarations must also satisfy (no platform-specific paths or syntax)
- `universal-os-architecture/plan.md` — design decision: `installable-os` provides context-contract pattern; each OS provides domain `_system/` content
