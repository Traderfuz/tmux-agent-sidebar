<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/anthropic-complete-guide-alignment.md and re-run profile-sync. -->
# Anthropic Complete Guide Alignment

## Overview

This standard ensures every skill in the DevOS library aligns with Anthropic's official "Complete Guide to Building Skills for Claude." Alignment with the guide is required because the guide defines the platform contract: skills that violate it may fail to load, trigger incorrectly, or break across Claude Code versions.

## Scope

**Covers:** frontmatter compliance, description quality, trigger contract design, test coverage requirements, distribution readiness, and composability rules as defined by the Anthropic guide.

**Does NOT cover:** internal directory layout (see `skill-structure.md`), workflow pattern selection (see `skill-workflow-patterns.md`), or any tooling or runtime not part of the Claude Code skill platform.

Source: https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf?hsLang=en

---

## Principles

**P1 — Platform alignment is non-negotiable.**
The Anthropic guide defines the authoritative contract between skills and the Claude Code runtime. Treating guide requirements as optional leads to silent failures that are hard to diagnose.

**P2 — Progressive disclosure reduces cognitive load.**
The `description` field is the primary trigger surface. Burying detail there increases parse cost for the model and degrades trigger precision. Long material belongs in `references/`.

**P3 — Composability prevents conflicts.**
Skills that assume exclusive control of a tool, a resource, or a file pattern will silently conflict with other active skills. Every skill must be designed to coexist.

**P4 — Iterate on observed trigger behavior.**
Over-triggering and under-triggering are the primary failure modes for deployed skills. Both require observed evidence (real phrasing from users) to resolve — not guesswork at authoring time.

---

## Rules

### Core Alignment Checks

All items below are required. A skill that fails any item is not compliant.

1. `SKILL.md` exists with exact casing (`SKILL.md`, not `skill.md` or `Skill.md`).
2. Frontmatter begins at line 1 and parses as valid YAML.
3. Required keys exist: `name`, `description`, `version`.
4. `description` is under 1024 characters.
5. `description` includes clear "what it does" and "when to use it" language.
6. `description` avoids XML angle brackets (`<`, `>`).
7. Skill directory uses kebab-case naming (e.g., `my-skill`, not `MySkill` or `my_skill`).
8. Long details are moved to `references/` (progressive disclosure — not embedded in `SKILL.md`).
9. Scripts and assets are referenced with valid relative paths.
10. Trigger tests include both positive cases (phrases that should trigger) and negative cases (phrases that should not).
11. Execution tests include the happy path and at least one failure path.
12. Release decision includes rollback readiness (version can be reverted without data loss).

---

### Quality Patterns from the Guide

**OFF-STANDARD — Generic description that does not aid trigger precision:**
```yaml
description: This skill helps with skill-related tasks.
```

**ON-STANDARD — Specific description with trigger phrasing:**
```yaml
description: >
  Validates a skill package for structural and Anthropic guide compliance.
  Use when reviewing a skill before release, importing a third-party skill,
  or diagnosing a skill that fails to load. Do not use for runtime debugging
  of Claude Code itself.
```

---

**OFF-STANDARD — No anti-trigger language (causes false positives):**
```yaml
description: Helps write skills.
```

**ON-STANDARD — Anti-trigger language included:**
```yaml
description: >
  Authors a new SKILL.md from a template. Use when creating a skill from scratch.
  Do not use when editing an existing skill — use the skill-refactor skill instead.
```

---

**OFF-STANDARD — Instruction bloat in SKILL.md:**
```markdown
## Background
[300 words of rationale, history, and edge cases that are not needed to execute the skill]
```

**ON-STANDARD — Concise core instructions; detail in references/:**
```markdown
## Instructions
[5-10 lines of actionable steps]

See `references/rationale.md` for background and edge case detail.
```

---

**OFF-STANDARD — Skill assumes exclusive file ownership:**
```markdown
## Step 1
Delete all `.env` files in the project root to reset state.
```

**ON-STANDARD — Skill is composable and non-destructive by default:**
```markdown
## Step 1
Check for existing `.env` files. If present, confirm before modifying.
This skill can coexist with secrets-management skills that also read `.env`.
```

---

### Distribution Readiness

- Include compatibility notes for any environment assumptions (OS, shell version, tooling).
- Include license metadata in frontmatter if sharing the skill publicly.
- Keep versioning explicit and semver-oriented (`MAJOR.MINOR.PATCH`).

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `description` over 1024 characters | Truncated by the platform; trigger contract is incomplete | Summarize in `description`; move detail to `references/` |
| XML angle brackets in `description` | Parsed as markup; corrupts frontmatter on some loaders | Use plain text; replace `<arg>` with `[arg]` or `{arg}` |
| No negative trigger examples in tests | Over-triggering goes undetected until production | Add at least two "should NOT trigger" phrases to trigger tests |
| Skill modifies shared state without guards | Conflicts silently with other active skills | Add existence checks and confirmation prompts before mutating shared resources |
| Version stays at `1.0.0` across behavior changes | Consumers cannot detect when a cached skill is stale | Bump version on every behavioral change, including description rewording |

---

## Deviation Guidance

You MAY deviate from distribution readiness requirements when:
- The skill is for personal use only and will never be published or shared.
- The skill is a prototype under active iteration (mark it `version: 0.x.x` to signal pre-release status).

You MUST do the following when deviating:
- Ensure all 12 core alignment checks pass regardless of distribution readiness status.
- Document in the skill's frontmatter that distribution readiness is deferred (e.g., add a `status: draft` key).

---

## Compliance Test

Answer yes or no to each item before releasing a skill.

1. Does the skill pass all 12 core alignment checks listed in the Rules section?
2. Does `description` include both "what it does" and "when to use it" without exceeding 1024 characters?
3. Do trigger tests include at least one positive and one negative case?
4. Is the skill designed to coexist with other active skills (no exclusive resource ownership)?
5. Is the version field semver-formatted and bumped relative to the last release?

A skill that answers "no" to any item is not releasable.

---

## References

- `skill-structure.md` — Directory layout and frontmatter rules
- `skill-workflow-patterns.md` — Workflow pattern selection
- Anthropic Complete Guide to Building Skills for Claude: https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf?hsLang=en
