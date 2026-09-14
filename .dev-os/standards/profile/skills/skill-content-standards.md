<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skill-content-standards.md and re-run profile-sync. -->
# Skill Content Standards

## Overview

These standards govern the content structure, writing style, workflow organization, error handling, and output specification inside SKILL.md files. They exist because a skill that is structurally valid but poorly written produces ambiguous agent behavior — instructions that are not copy-paste ready, steps that backtrack, or failure modes that are undocumented cause autonomous workflows to stall or produce incorrect outputs.

## Scope

**Covers:** Required section presence and ordering, writing style rules, workflow sequencing discipline, failure handling completeness, and output artifact specification for all SKILL.md body content.

**Does NOT cover:** YAML/frontmatter correctness (covered by `skills-repair-playbook.md`), pre-release testing protocol (covered by `skills-testing-and-release-standards.md`), or trigger description accuracy.

## Principles

1. **Imperative and unambiguous.** Every instruction must be a direct command a reader — or an agent — can execute without interpretation. Hedged language like "sometimes" or "usually" without explicit criteria leaves the agent unable to decide.
2. **Complete failure coverage.** A skill that only documents the happy path is half-written. Failure modes, their causes, and exact remediation steps are mandatory content, not optional additions.
3. **Single objective per skill.** Each skill must be narrow enough that its entire workflow points toward one deliverable. Broad skills with multiple goals are harder to trigger correctly and harder to chain in autonomous workflows.
4. **Outputs define done.** A skill is complete only when it specifies what artifacts it produces and how to verify they meet quality criteria. Without this, neither a human nor an agent can confirm the skill succeeded.

## Rules

These standards ensure skill content is clear, actionable, and reusable in autonomous execution.

### Required Sections

Every skill should contain:
1. Title
2. When to use this skill
3. Prerequisites
4. Quick start
5. Full workflow
6. Failure handling
7. Outputs

### Writing Rules

- Use direct imperative steps.
- Keep instructions copy-paste ready.
- Avoid ambiguous terms like "sometimes" or "usually" without criteria.
- Define any domain-specific terms once.

### Workflow Rules

- Order steps to minimize backtracking.
- Include checkpoints after critical operations.
- Separate mandatory steps from optional enhancements.
- Keep workflows narrow to a single objective.

### Error Handling Rules

- Include likely failure modes.
- Provide exact remediation steps.
- Prefer deterministic checks over subjective checks.

### Output Rules

- Name expected artifacts explicitly.
- Include output quality criteria.
- Specify how to verify completion.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Using hedged language ("sometimes", "usually", "may need to") without stated criteria | An agent cannot branch on ambiguous conditions and will either always or never take the action, producing inconsistent results | Replace with a deterministic condition: "If X is present, do Y; otherwise do Z" |
| Omitting the Failure handling section | When a command fails mid-workflow, the agent has no recovery path and either halts or retries indefinitely | Include likely failure modes with exact remediation steps for each |
| Writing steps in passive voice or noun phrases instead of imperative commands | Passive constructions require interpretation; noun phrases are not executable instructions | Start each step with an action verb: "Run", "Open", "Verify", "Copy" |
| Combining multiple objectives into a single skill workflow | Broad skills are over-triggered (firing when only part of their scope is needed) and produce partial outputs that break downstream chaining | Split into focused single-objective skills; reference sibling skills where handoffs occur |
| Listing expected outputs without specifying verification criteria | An agent can produce an artifact of the wrong type or quality and still consider the skill complete | State the artifact name, its required properties, and a check command or criterion to confirm it meets quality standards |

## Deviation Guidance

MAY omit the "Quick start" section for skills that have no abbreviated execution path — for example, skills whose full workflow is already short (4 steps or fewer).

MAY omit the "Prerequisites" section only when the skill has no external dependencies, required tools, or environment state assumptions.

MUST include all remaining required sections regardless of skill complexity. A short skill that omits "Failure handling" is non-compliant.

MUST NOT use the deviations above as justification to omit "When to use this skill" or "Outputs" — these two sections are unconditionally required.

## Compliance Test

Answer yes/no before marking a skill's content complete:

- [ ] Does the skill include all 7 required sections (or a documented deviation for any omitted section)?
- [ ] Are all workflow steps written as direct imperative commands starting with an action verb?
- [ ] Is every ambiguous term ("sometimes", "usually", "may") either removed or replaced with a deterministic condition?
- [ ] Does the Failure handling section name at least one failure mode with an exact remediation step?
- [ ] Does the Outputs section name each expected artifact and specify how to verify it meets quality criteria?

## References

- `skills-repair-playbook.md` — fixing YAML/frontmatter before content review
- `skills-testing-and-release-standards.md` — validating content behaves correctly at runtime
