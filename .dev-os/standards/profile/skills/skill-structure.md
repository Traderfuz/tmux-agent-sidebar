<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skill-structure.md and re-run profile-sync. -->
# Skill Structure

## Overview

This standard governs the physical layout, frontmatter, and internal organization of Claude Code skill packages (SKILL.md files). Consistent structure makes skills discoverable, testable, and maintainable across the DevOS skill library; inconsistent structure causes load failures, stale references, and scope bleed.

## Scope

**Covers:** directory layout, frontmatter keys and constraints, file linking conventions, maintainability rules for a single skill package.

**Does NOT cover:** multi-skill orchestration, trigger contract design, workflow pattern selection (see `skill-workflow-patterns.md`), or Anthropic guide alignment validation (see `anthropic-complete-guide-alignment.md`).

---

## Principles

**P1 — SKILL.md is the sole entrypoint.**
Every skill must have exactly one `SKILL.md` as its root. Claude Code resolves skills from this file; any other entrypoint creates ambiguity.

**P2 — Logic belongs in scripts, not inline.**
Executable shell or scripted logic embedded directly in `SKILL.md` creates maintainability debt. Scripts in `scripts/` are independently testable and reusable.

**P3 — Progressive disclosure through directory separation.**
Detail that does not aid the trigger decision should not appear in `SKILL.md`. Long references, deep rationale, and raw specification text belong in `references/` so the core file stays concise.

**P4 — Versioning signals breaking changes.**
Version bumps are the only reliable signal to consumers that behavior has changed. Bumping version on any behavioral change prevents silent breakage in environments that cache skill state.

**P5 — Every skill has deterministic help.**
`--help` and `-h` must explain purpose, invocation syntax, important inputs and flags, defaults, and examples without executing the workflow or causing side effects.


---

## Recommended Layout

```text
my-skill/
  SKILL.md          # Entrypoint — frontmatter + core instructions
  scripts/          # Executable logic (shell, Python, etc.)
  assets/           # Templates, snippets, static content
  references/       # Long-form guidance, deep references, specs
```

---

## Rules

### Structural Rules

**OFF-STANDARD — Logic embedded inline:**
```markdown
## Step 2
Run this:
```bash
set -euo pipefail
for f in $(find . -name "*.md"); do ...done
```
```

**ON-STANDARD — Logic delegated to scripts/:**
```markdown
## Step 2
Run the validation script shipped in this skill's `scripts/` directory to check all markdown files.
```

---

**OFF-STANDARD — Deep reference content in SKILL.md:**
```markdown
## Background
The history of this approach dates to the 2023 Anthropic internal review of...
[500 more words]
```

**ON-STANDARD — Reference moved to references/:**
```markdown
## Background
See `references/background.md` for full rationale and history.
```

---

### Frontmatter Rules

Required keys: `name`, `description`, `version`. The block must appear at line 1 and parse as valid YAML.

**OFF-STANDARD — Missing required keys or mid-file placement:**
```markdown
# My Skill

Some intro text.

---
name: my-skill
---
```

**ON-STANDARD — Frontmatter at line 1 with all required keys:**
```markdown
---
name: my-skill
description: Validates skill packages for structural compliance. Use when reviewing or releasing a skill.
version: 1.0.0
---
```

Keep `description` concise and triggerable. It should answer "what does this do" and "when should I use it" in one or two sentences.

---

### Help Rules

Every new or materially upgraded skill MUST include a `## Help` section.
Help handling is highest-precedence: when invocation contains `--help` or `-h`, return only the documented help surface and stop before context gathering, project-state reads, tool calls, file writes, session changes, or downstream skill invocation.

Required fields are the skill name and one-line purpose, `Purpose:`, slash-command `Usage:`, `Arguments:` and/or `Options:` including `--help, -h`, `Defaults:`, and at least one realistic entry under `Examples:`.
Instruction-only skills encode this behavior in `SKILL.md`; skills with executable wrappers SHOULD keep wrapper output byte-equivalent.

---

### Linking Rules

- Reference local files with relative paths only.
- Verify every referenced path exists before releasing the skill.
- Avoid references that depend on hidden external state (env vars, hardcoded absolute paths, remote URLs that may break).

**OFF-STANDARD — Absolute path reference:**
```markdown
See `/home/tafadzwa/.dev-os/skills/my-skill/references/deep.md` for details.
```

**ON-STANDARD — Relative path reference:**
```markdown
See `references/deep.md` for details.
```

---

### Maintainability Rules

- Keep each skill focused on one workflow. A skill that handles both "create" and "repair" flows should be split.
- Split large branching behavior into companion skills rather than conditional trees inside a single SKILL.md.
- Bump the `version` field for any behavioral change, including prompt rewording that changes trigger behavior.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Inline shell walls in SKILL.md | Untestable, hard to read, breaks if shell quoting is wrong in markdown | Move logic to `scripts/`; reference by filename |
| No frontmatter or incomplete frontmatter | Claude Code cannot parse or index the skill | Add a complete frontmatter block at line 1 with `name`, `description`, `version` |
| Hardcoded absolute paths in references | Breaks on any machine that is not the author's | Use relative paths from the skill root |
| One skill handling multiple unrelated workflows | Triggers become ambiguous; testing scope explodes | Split into focused companion skills, one per workflow |
| Version never bumped after behavior changes | Consumers cache stale behavior with no signal to refresh | Bump `version` on every behavioral change, including description edits |

---

## Deviation Guidance

You MAY deviate from the recommended layout when:
- The skill has no scripts (automation-free, instruction-only skills may omit the `scripts/` directory).
- The skill has no long-form reference material (the `references/` directory may be omitted).

You MUST do the following when deviating:
- Keep `SKILL.md` as the entrypoint regardless of what other directories are omitted.
- Document any non-standard layout choice in a comment near the top of `SKILL.md`.
- Ensure frontmatter is always present and complete even if directory structure is minimal.

---

## Compliance Test

Answer yes or no to each item before releasing a skill.

1. Does `SKILL.md` exist at the skill root with exact casing?
2. Does frontmatter appear at line 1 and include `name`, `description`, and `version`?
3. Are all referenced paths relative and verified to exist?
4. Is executable logic in `scripts/` rather than inline in `SKILL.md`?
5. Does the skill address exactly one workflow (no multi-workflow scope bleed)?
6. Does `--help`/`-h` return the required help surface without executing work or causing side effects?


A skill that answers "no" to any item is not releasable.

---

## References

- `anthropic-complete-guide-alignment.md` — Anthropic official guide validation checklist
- `skill-workflow-patterns.md` — Workflow pattern selection rules
- Anthropic Complete Guide to Building Skills for Claude: https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf
