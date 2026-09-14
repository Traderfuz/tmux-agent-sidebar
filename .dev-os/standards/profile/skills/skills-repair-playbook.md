<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skills-repair-playbook.md and re-run profile-sync. -->
# Skills Repair Playbook

## Overview

This playbook governs how to diagnose and repair SKILL.md files that fail to load due to YAML/frontmatter errors. It exists because loader failures block skill activation silently — Claude Code will not invoke a skill with an invalid header, and without a systematic repair procedure, authors waste time on trial-and-error header edits that introduce new errors.

## Scope

**Covers:** Diagnosing and repairing YAML parse errors, missing or duplicate frontmatter blocks, oversized descriptions, and invalid key formatting in SKILL.md files.

**Does NOT cover:** Skill content quality issues (covered by `skill-content-standards.md`), trigger tuning (covered by `skills-testing-and-release-standards.md`), or runtime errors in skill-invoked commands.

## Principles

1. **Fix forward, never guess.** Work through the canonical repair procedure in order rather than making speculative edits. Guessing which field is broken typically introduces a second error while leaving the first unresolved.
2. **Minimal footprint.** Change only the fields required to fix the failure. Do not rewrite the skill body, rename the skill, or alter the version while performing a header repair.
3. **Validate before claiming fixed.** Run the command-line validation snippet after every repair. A skill that passes the visual inspection but fails the validator is not fixed.

## Rules

Use this playbook when skills fail to load with errors like:
- invalid YAML
- missing frontmatter
- description exceeds max length

### Fast Repair Procedure

1. Open `SKILL.md`.
2. Ensure it starts with one YAML frontmatter block.
3. Ensure keys `name`, `description`, and `version` exist.
4. Shorten `description` to `<= 1024` characters.
5. Quote `description` with double quotes.
6. Remove duplicate frontmatter blocks.
7. Validate YAML parsing.

### Canonical Header Template

```markdown
---
name: my-skill
description: "Short triggerable summary with clear use case."
version: 1.0.0
---
```

### Command-Line Validation Snippet

Use this to validate repaired files:

```bash
ruby -e 't=File.read(ARGV[0]); abort("no frontmatter") unless t.start_with?("---\n"); parts=t.split("---\n",3); fm=parts[1]; require "yaml"; y=YAML.safe_load(fm); d=y["description"]||""; abort("desc too long") if d.length>1024; abort("missing name") unless y["name"]; abort("missing version") unless y["version"]; puts "ok"' /path/to/SKILL.md
```

### Hard Rule

Never rewrite a skill header without checking for existing frontmatter first. Strip leading frontmatter safely, then insert exactly one canonical block.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `missing YAML frontmatter` — file starts directly with markdown body | Claude Code expects the file to begin with `---\n`; a body-first file will never be recognized as a valid skill | Add the canonical header at the top of the file before any other content |
| `invalid YAML` — unquoted colon, malformed mapping, or tabs used for indentation | YAML parsers treat bare colons as key-value separators and tabs as illegal indentation characters, causing a parse error | Quote all string values that contain colons, fix indentation to use spaces only |
| `description exceeds maximum length` — trigger text is over 1024 characters | The loader rejects descriptions above this limit regardless of content quality; the skill will not activate | Replace with a concise summary that fits within 1024 characters and retains the core "use when" signal |
| Duplicate or nested frontmatter headers — old header was left in place when a new one was appended | The parser sees two `---` blocks and either fails or silently ignores the second; skill metadata is unpredictable | Strip all leading frontmatter blocks first, then insert exactly one canonical block |
| Rewriting the skill body during a header repair | Introduces unrelated changes that make it impossible to isolate whether the repair succeeded or a new content issue was introduced | Scope header repairs to the frontmatter block only; commit body changes separately |

## Deviation Guidance

MAY use a language-specific YAML validator other than the Ruby snippet if Ruby is unavailable in the environment, provided the replacement validates all four checks: frontmatter presence, `name` key, `version` key, and `description` length.

MUST NOT skip validation after repair regardless of how simple the fix appears. Visual inspection is insufficient — YAML parsing errors are non-obvious.

## Compliance Test

Answer yes/no after completing a repair:

- [ ] Does the file begin with exactly one `---` frontmatter block before any markdown content?
- [ ] Are `name`, `description`, and `version` all present in the frontmatter?
- [ ] Is `description` quoted with double quotes and within 1024 characters?
- [ ] Were duplicate or stale frontmatter blocks removed before inserting the canonical header?
- [ ] Did the command-line validation snippet return `ok` for the repaired file?

## References

- `skill-content-standards.md` — content quality requirements once the header is valid
- `skills-testing-and-release-standards.md` — pre-release gates including YAML validation as gate 1
