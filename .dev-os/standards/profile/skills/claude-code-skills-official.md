<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/claude-code-skills-official.md and re-run profile-sync. -->
# Claude Code Skills Official

## Overview

This standard captures canonical compatibility and quality requirements from Anthropic's skill guidance. It defines the platform contract that Claude Code enforces when loading, triggering, and executing skills — requirements that are non-negotiable regardless of authoring style or project context. Authors who violate these contracts produce skills that fail silently, over-trigger, or conflict with co-active skills.

## Scope

**Covers:** File and folder naming enforced by the Claude Code runtime, frontmatter field requirements, trigger contract rules, progressive disclosure expectations, composability constraints, execution quality requirements, and quality validation before release.

**Does NOT cover:** Internal business logic within a skill's workflow steps, choice of supporting tools or scripts, or how skill libraries are organized at the catalog level — those are authoring decisions left to the author.

## Principles

**The platform reads frontmatter before the author's instructions.** Claude Code uses `name`, `description`, and `version` as machine-readable selectors. If these fields are malformed or absent, the skill does not exist from the platform's perspective, regardless of how well the body is written.

**Trigger precision is a first-class quality requirement.** An over-broad description activates a skill in the wrong context and degrades agent behavior for the entire session. Trigger design is not a stylistic choice — it is a reliability contract.

**Skills must be composable, not sovereign.** A skill runs alongside other active skills. Assuming exclusive control of a workflow, hardcoding environment paths without declaring them as dependencies, or failing to document side effects creates conflicts that are difficult to diagnose at runtime.

## Rules

### Required File and Folder Contract

- Skill folder name must be kebab-case.
- `SKILL.md` filename must be exact and case-sensitive.
- Keep all skill documentation in `SKILL.md` or `references/`.
- Do not place a skill-level `README.md` inside the skill folder.

### Required Frontmatter Contract

- Frontmatter must start the file and be delimited by `---`.
- Required keys:
  - `name`
  - `description`
  - `version`
- `name` should be kebab-case and match folder name.
- `description` must be under 1024 characters.
- `description` must include:
  - what the skill does
  - when to use it (trigger conditions)
- `description` must not include XML angle brackets (`<` or `>`).
- Use one top-level frontmatter block only.

### Optional Frontmatter Fields

- `license`: for open-source distribution.
- `compatibility`: environment/runtime requirements.
- `metadata`: key-value metadata such as author, version, and MCP notes.

### Skill Trigger Contract

- `description` must be concrete and operational.
- Include realistic phrases users would actually say.
- Include relevant file types when useful.
- Add negative triggers for over-triggering scenarios.
- Avoid broad descriptions that overlap unrelated workflows.

### Progressive Disclosure Contract

- Keep frontmatter minimal and trigger-oriented.
- Keep `SKILL.md` focused on core instructions.
- Move detailed guidance into `references/` and link to it.
- Prefer concise `SKILL.md`; keep large detail out of inline instruction walls.

### Composability and Portability Contract

- Skill should compose cleanly with other enabled skills.
- Do not assume it is the only active capability.
- Document environment dependencies clearly for portability across surfaces.

### Execution Contract

- Provide deterministic ordered steps.
- Include prerequisites and environment assumptions.
- Include expected outputs and completion checkpoints.
- Include explicit failure handling and next actions.
- For critical validations, prefer deterministic scripts over ambiguous prose.

### Quality Contract

- Validate syntax, structure, and behavior before release.
- Include triggering tests (should trigger and should not trigger).
- Include execution tests (happy path and failure path).
- Preserve rollback readiness for production skill sets.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `README.md` placed inside the skill folder instead of `SKILL.md` | The platform looks for `SKILL.md` exactly; `README.md` is ignored by loaders | Use the exact filename `SKILL.md` inside a kebab-case folder |
| `description` contains XML angle brackets (`<example>`) | Angle brackets in frontmatter break YAML parsing on some loaders and are explicitly prohibited by the platform contract | Remove all `<` and `>` characters from the `description` field |
| `description` written as a capability summary ("This skill can handle many types of data processing") | Vague descriptions trigger in wrong contexts; the platform uses description as a selector, not a summary | Write trigger-first: "Use when the user asks to process CSV data and output a summary report" |
| Skill assumes it is the only active skill and hardcodes global state or shared resource paths | Conflicts silently with co-active skills that use the same paths; produces unpredictable behavior | Declare all dependencies in `compatibility` frontmatter; use isolated, scoped paths |
| Entire detailed workflow inlined in `SKILL.md` with no use of `references/` | Large inline instruction walls make the skill hard to maintain and slow to parse; detail belongs in `references/` | Keep `SKILL.md` to core trigger and quick-start steps; link to `references/detail.md` for depth |
| Skill ships without triggering tests or execution tests | Silent failures in production; author cannot know if skill activates correctly or completes the happy path | Add explicit "should trigger" / "should not trigger" examples and happy/failure path tests before release |

## Compliance Test

- [ ] Is the skill folder named in kebab-case and does the file use the exact name `SKILL.md`?
- [ ] Does frontmatter include `name`, `description`, and `version`, with `description` under 1024 characters and free of XML angle brackets?
- [ ] Does `description` include concrete trigger phrases and at least one negative trigger or scope boundary?
- [ ] Does `SKILL.md` stay focused on core instructions, with detailed guidance moved to `references/`?
- [ ] Has the skill been validated with both a triggering test and an execution test (happy path and failure path) before release?

## References

- `skills-standards.md` — Minimum structure and YAML safety rules
- `skills-authoring-best-practices.md` — Trigger design, scope discipline, progressive disclosure
