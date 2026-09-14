<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skill-workflow-patterns.md and re-run profile-sync. -->
# Skill Workflow Patterns

## Overview

Skills implement one of four defined workflow patterns: Spec-Build-Validate-Release, Detect-Repair-Revalidate, Refactor-Split-Stabilize, or Observe-Harden-Automate. Choosing the wrong pattern causes scope creep (a skill that tries to do too much), missing behavior (a skill that stops before its natural endpoint), or ambiguous triggering (a skill whose description does not match what it actually executes).

## Scope

**Covers:** workflow structure within a single skill, pattern selection criteria, correct and incorrect pattern application, and mode boundary documentation.

**Does NOT cover:** multi-skill orchestration, slash command routing, trigger contract design (see `anthropic-complete-guide-alignment.md`), or directory structure (see `skill-structure.md`).

---

## Principles

**P1 — Choose the pattern before writing the skill.**
The pattern is not an implementation detail — it determines what phases exist, what the entry and exit conditions are, and what the skill's trigger description should say. Selecting the pattern first prevents mid-authoring scope drift.

**P2 — One pattern per skill.**
Mixing patterns in a single skill (e.g., creating and repairing in the same SKILL.md) produces ambiguous triggers and untestable execution paths. When both patterns are needed, write two skills.

**P3 — Mode boundaries are explicitly documented.**
If a pattern has distinct modes (e.g., "dry run" vs. "apply"), the boundary between them must be documented in the skill, not inferred from context. Undocumented mode boundaries cause inconsistent execution.

**P4 — Every pattern has an explicit exit condition.**
A skill that has no defined endpoint runs indefinitely or terminates arbitrarily. Each phase in a pattern must have a pass/fail gate that determines whether execution continues or stops.

---

## Rules

### Pattern 1: Spec -> Build -> Validate -> Release

**Use when:** creating a new skill from scratch.

**Phases:**
1. Specify scope, trigger contract, and success criteria.
2. Build `SKILL.md` and all support resources (`scripts/`, `assets/`, `references/`).
3. Validate syntax, references, trigger tests, and execution tests.
4. Release only after all validation gates pass.

**OFF-STANDARD — Skipping the spec phase:**
```markdown
## My New Skill
[Jumps directly into instructions without defining trigger contract or success criteria]
```
Result: The skill has no defined trigger, no test cases, and no way to know if it succeeded.

**ON-STANDARD — Spec phase completed before building:**
```markdown
## Skill Spec
- Trigger: "validate skill structure", "check skill compliance"
- Anti-trigger: "validate my code", "check my tests"
- Success: All 5 compliance test items return yes
- Failure: Any compliance item returns no; output lists failing items

## Instructions
[Built from the spec above]
```

**Exit condition:** Release is permitted only when all validation gates (syntax, references, trigger tests, execution tests) return pass.

---

### Pattern 2: Detect -> Repair -> Revalidate

**Use when:** a skill fails to load, produces a parse error, or has broken references.

**Phases:**
1. Capture the loader or parser error precisely.
2. Apply targeted structural fixes to the identified issue only.
3. Re-run validation gates to confirm the fix resolved the root cause without introducing new failures.

**OFF-STANDARD — Broad rewrites instead of targeted repair:**
```markdown
## Step 1
Rewrite the entire SKILL.md to fix the frontmatter error.
```
Result: Repair scope exceeds the actual error; introduces new issues; original behavior is lost.

**ON-STANDARD — Targeted fix scoped to the detected error:**
```markdown
## Step 1
Read the error: "YAML parse error at line 1 — unexpected character".
Inspect frontmatter only. Fix the offending character. Do not modify any other section.

## Step 3
Re-run the validation gate for frontmatter only. Confirm no new errors were introduced.
```

**Exit condition:** Revalidation passes for the repaired component. If new errors appear, cycle back to Detect.

---

### Pattern 3: Refactor -> Split -> Stabilize

**Use when:** a skill has grown too broad — multiple unrelated workflows, ambiguous triggers, or branching behavior that cannot be tested as a unit.

**Phases:**
1. Identify the overloaded scope: list each distinct workflow the skill currently handles.
2. Split into focused skills, one per workflow. Extract shared resources into `assets/` or a helper skill.
3. Stabilize: verify that each new skill has its own versioning, its own trigger contract, and no circular references to the original skill.

**OFF-STANDARD — Refactor that keeps everything in one file:**
```markdown
## Refactored Skill
[Adds conditional branches to separate the two workflows instead of splitting]
```
Result: Triggers remain ambiguous; testing still requires exercising both code paths together.

**ON-STANDARD — True split into focused companion skills:**
```text
Before: skill-validator/ (validates structure AND tests triggers)
After:
  skill-structure-validator/ (validates structure only)
  skill-trigger-tester/      (tests trigger contract only)
  assets/shared-checks.sh   (common checks extracted to shared asset)
```
Each resulting skill has its own frontmatter, version, and trigger description.

**Exit condition:** Each split skill loads independently, has its own trigger tests, and the original overloaded skill is deprecated or removed.

---

### Pattern 4: Observe -> Harden -> Automate

**Use when:** operational experience reveals recurring manual steps, fragile checks, or repeated failures in an existing skill.

**Phases:**
1. Observe: document the specific recurring failure or manual step with evidence (frequency, context, error output).
2. Harden: add explicit guards, error handling, or validation steps to the identified weak point.
3. Automate: where the hardened check is still manual, move it into `scripts/` and reference it from SKILL.md.

**OFF-STANDARD — Automating without observing:**
```markdown
## Improvement
Added automation for all validation steps without identifying which ones were actually failing.
```
Result: Automation scope is speculative; may introduce overhead for steps that were not broken.

**ON-STANDARD — Observation drives targeted hardening:**
```markdown
## Observed Failure (2026-03-01, 3 occurrences)
`validate-references.sh` silently passes when `references/` directory is missing.
Impact: Released skills with broken reference links.

## Hardening
Added existence check for `references/` before running link validation.
Added explicit error message: "references/ directory not found — add it or remove reference links".

## Automation
Moved existence check to `scripts/validate-references.sh` line 12.
SKILL.md now calls script instead of relying on manual inspection.
```

**Exit condition:** The recurring failure no longer appears in post-hardening runs. The automated check is included in the skill's validation gate.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Mixing Pattern 1 and Pattern 2 in one skill (create and repair) | Trigger is ambiguous — "should I use this to create or to fix?" | Write two skills: one for creation (P1), one for repair (P2) |
| No exit condition defined for a pattern phase | Skill runs indefinitely or stops arbitrarily with no signal | Define a binary pass/fail gate for each phase before authoring begins |
| Pattern 3 refactor that does not result in a true split | Scope remains the same; triggers remain ambiguous | Each workflow must become its own skill with its own frontmatter |
| Pattern 4 automation without an observation record | Automation targets speculative problems, not real ones | Document the observed failure with evidence before writing any automation |
| Applying Pattern 4 to a new skill | Pattern 4 requires operational history; new skills have none | Use Pattern 1 for creation; apply Pattern 4 only after the skill is in use |

---

## Deviation Guidance

You MAY deviate from single-pattern discipline when:
- A skill explicitly models a lifecycle that spans two patterns sequentially (e.g., create then immediately validate). In this case, document both patterns as named phases with a clear handoff boundary.

You MUST do the following when deviating:
- Name each pattern phase explicitly in `SKILL.md` so the scope of each is visible.
- Document the entry and exit condition for each pattern phase.
- Write separate test cases for each phase rather than a single end-to-end test that obscures phase boundaries.

---

## Compliance Test

Answer yes or no to each item before releasing a skill.

1. Has exactly one pattern been selected and named in the skill design?
2. Does each phase in the selected pattern have an explicit exit condition?
3. If the skill has multiple modes (e.g., dry run / apply), are the mode boundaries documented in `SKILL.md`?
4. Does the skill's trigger description accurately reflect the selected pattern (not a broader or narrower scope)?
5. If two patterns are present, is each named as a distinct phase with a documented handoff boundary?

A skill that answers "no" to any item is not releasable.

---

## References

- `skill-structure.md` — Directory layout and frontmatter rules
- `anthropic-complete-guide-alignment.md` — Anthropic guide validation checklist
- Anthropic Complete Guide to Building Skills for Claude: https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf?hsLang=en
