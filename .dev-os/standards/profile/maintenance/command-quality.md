<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/command-quality.md and re-run profile-sync. -->
# Command Quality Standard

## Purpose

Every DevOS command in `profiles/general/commands/` must meet a minimum quality bar. This standard defines required fields, content structure, and category rules so commands are consistent, discoverable, and maintainable.

## Required Frontmatter

Every command `.md` file must have YAML frontmatter with these fields:

```yaml
---
name: <command-name>          # REQUIRED — must match filename without .md
description: <one-line desc>  # REQUIRED — concise, starts with verb
category: <recognized-key>    # REQUIRED — must be a recognized category key
---
```

## Recognized Category Keys

Commands must use one of these category keys in the `category:` frontmatter field. Using an unrecognized key causes the command to appear as "Uncategorized" in `help`.

### Standard Categories (preferred)

| Key | Display Label |
|---|---|
| `Getting Started` | Getting Started |
| `Development` | Development |
| `Code Quality` | Code Quality |
| `Project Management` | Project Management |
| `Documentation` | Documentation |
| `Utilities` | Utilities |
| `Info & Config` | Info & Config |

### Legacy Categories (accepted, mapped to display labels)

| Key | Display Label |
|---|---|
| `setup` | Setup & Configuration |
| `plan` | Planning & Specification |
| `build` | Implementation |
| `quality` | Quality & Review |
| `deploy` | Deployment & Release |
| `recover` | Recovery & Diagnostics |
| `admin` | Administration |
| `auto` | Autonomous Workflow |

**Rule:** Use a standard category for new commands. Legacy keys are accepted for backward compatibility but should be migrated to standard keys when commands are updated.

## Minimum Content Structure

Every command must contain:

1. **Heading** — `# <name>` matching the frontmatter `name`
2. **Description** — 1-2 sentence summary of what the command does
3. **Usage section** — code block showing invocation patterns
4. **At least one of:**
   - Flags/options table
   - Workflow reference (`{{workflows/...}}`)
   - Implementation section describing the command's behavior

## Depth Rules

| Line count | Requirement |
|---|---|
| **<20 lines** | Must document delegation target — which skill or library handles the work |
| **20-30 lines** | Acceptable as a thin wrapper if behavior is clear |
| **>30 lines** | Should include a `{{workflows/...}}` reference for the core logic |

## Thin Wrapper Pattern

When a skill exists in `.claude/skills/` with the same name as a command (or covering the same domain), the command **must** be a thin wrapper — not a duplicate of the skill content. Skills are portable across CLIs; commands are Claude Code namespace wrappers.

### Canonical template

```yaml
---
name: <command-name>
description: <one-line description>
category: <recognized-category>
---

# <command-name>

Use the `<skill-name>` skill.

See `.claude/skills/<skill-name>/SKILL.md` for full documentation.
```

### Why thin wrappers?

- **Single source of truth** — domain expertise lives in the skill, not duplicated in the command
- **Portability** — skills work across CLIs (Claude Code, Codex, Gemini, opencode); commands are Claude Code-specific
- **Maintenance** — one file to update instead of two when the domain evolves

For orchestration surfaces that keep a public command while delegating to a different backing skill, see `command-skill-split.md`.

### Rule

If `.claude/skills/<name>/SKILL.md` exists, the command at `profiles/general/commands/<name>.md` must be a thin wrapper (<15 lines). Never duplicate skill content in the command file.

### Examples of correct thin wrappers

- `diagnose-first.md` — delegates to `diagnose-first` skill
- `systematic-debugging.md` — delegates to `systematic-debugging` skill
- `code-review.md` — delegates to `code-review` skill
- `docs-architect.md` — delegates to `docs-architect` skill

## Delegation Documentation

Commands that delegate to a skill must state this explicitly:

```markdown
Use the `<skill-name>` skill.

See `.claude/skills/<skill-name>/SKILL.md` for full documentation.
```

## Command Naming

- Filenames: `kebab-case.md` (e.g., `merge-feature.md`)
- Namespace: all commands accessed as `<name>` except the 5 global exceptions (`start`, `check-skills-updates`, `find-skills`, `import-skill`, `list-importable`)
- No duplicate names across the command surface

## Known Limitations

- **`export -f` in library scripts:** 22 of 75 scripts in `scripts/lib/` use `export -f` (bash-only). This is an architectural decision, not a bug. Commands that source these libraries must be invoked in a bash context. See `recovery.sh` for the documented rationale for avoiding `export -f`.

## Related Standards

- `command-skill-split.md` for public command surfaces that delegate to distinct backing skills and workflows
- `bx-tool-routing.md` for choosing the authoritative bx-* authoring tool

## Compliance test

- [ ] Does every command file in `profiles/general/commands/` contain a `description:` field in its YAML frontmatter (`command grep -rL "^description:" profiles/general/commands/` returns zero files)?
- [ ] Does every command file invoke a skill or workflow rather than implementing logic inline (`command grep -rL "skill:\|{{workflow" profiles/general/commands/` returns zero files, per command-skill-split.md)?
- [ ] Does the command surface count in `help.md` match the count from `command find profiles/general/commands -name "*.md" | wc -l`?

If any check fails: add the missing frontmatter field or extract the inline logic to a skill before merging.
