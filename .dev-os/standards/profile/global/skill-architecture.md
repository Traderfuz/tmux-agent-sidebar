<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/skill-architecture.md and re-run profile-sync. -->
# Skill Architecture Standards

## Overview

Skill invocation graphs must form directed acyclic graphs. Circular dependencies cause infinite loops, unpredictable execution order, and silent failures that only surface at runtime. This standard enforces acyclicity as a mechanical constraint — detected by `skill-circular-detector.sh` on every commit — and defines the contracts that make cross-skill dependencies safe to declare.

**Sibling standards:**
- [`modular-architecture.md`](./modular-architecture.md) — module-level dependency direction; this standard extends its Rule 4 CI enforcement to the skill layer

## Scope

This standard covers inter-skill invocation dependency structure within DevOS: how skills reference other skills, when a dependency is valid, what contracts must exist before a skill can be named as a dependency, and how breaking changes to skills with consumers are managed. It does NOT cover skill content standards (covered by bx-skill-creator SK1–SK12 checklist) or OS package file layout conventions (covered by installable-os profile standards).

## Principles

1. **Acyclicity is non-negotiable:** A skill invocation graph that contains a cycle cannot execute. Any cycle — A → B → A, or A → B → C → A — produces an infinite loop or a guard-triggered abort. Acyclicity must be mechanically enforced before every commit, not caught during execution.
2. **Explicit tool invocation only:** A skill invokes another skill via the `Skill` tool with `skill: "name"`. Bare `source` or direct file execution bypasses the invocation registry and makes the dependency invisible to cycle detection.
3. **Schema-before-dependency for OS-mode skills:** OS-mode skills expose runtime contracts via `_system/` files. A skill may not declare an OS-mode skill as a dependency until that OS-mode skill's `_system/schema.json` is present and versioned — preventing dependency on an undefined interface.
4. **Breaking changes must be announced:** A skill that changes its invocation signature, required inputs, or output format in a way that breaks existing callers must version the change and notify all documented consumers before merging.

## Rules

### Rule 1 — Skill invocation graphs MUST be directed acyclic graphs

All `skill:` references in SKILL.md files form a directed graph. This graph must have no cycles at any depth.

**Enforcement:** `scripts/lib/skill-circular-detector.sh` scans all SKILL.md files under the skills directory, extracts `skill: "name"` references, builds the graph, and runs DFS cycle detection. It exits non-zero on any cycle found. This script is wired into the pre-commit hook via `scripts/hooks/pre-commit-posture-validation.sh`.

```
# OFF-STANDARD — cycle: bx-skill-creator invokes bx-skill-creator, which invokes bx-skill-creator
# profiles/general/skills/bx-skill-creator/SKILL.md
skill: "bx-skill-creator"   # ← back-edge creates cycle

# ON-STANDARD — linear dependency only
# bx-skill-creator reads a SKILL.md and patches it; never invokes bx-skill-creator
```

**Self-references** (`skill: "same-skill"`) are cycle violations and are detected and rejected by the same script.

### Rule 2 — Skills invoke other skills via the Skill tool only (`MUST`)

A skill that depends on another skill MUST invoke it via the Skill tool in its wiring section:

```markdown
<!-- OFF-STANDARD: bare source bypasses invocation registry -->
source ~/.claude/skills/bx-skill-creator/SKILL.md

<!-- OFF-STANDARD: direct bash execution -->
bash ~/.claude/skills/bx-skill-creator/run.sh

<!-- ON-STANDARD: Skill tool invocation -->
Use the Skill tool with skill: "bx-skill-creator" to invoke the dependency.
```

**Why:** The Skill tool invocation is the signal that `skill-circular-detector.sh` scans for. Bare source or exec calls are invisible to cycle detection and create hidden dependency edges.

### Rule 3 — OS-mode skill dependencies require `_system/schema.json` (`MUST`)

A skill in any profile may invoke an OS-mode skill (a skill installed via an installable-os package) only if that OS-mode skill has a `_system/schema.json` file present at its skill root. This schema file defines:

- Input contracts (what the invoking skill must provide)
- Output format (what the OS-mode skill will return)
- Version field (for breaking-change detection)

```
# ON-STANDARD: OS-mode skill with declared schema
~/.claude/skills/research-os-web-researcher/
├── SKILL.md
└── _system/
    └── schema.json       ← required before this skill can be a dependency

# OFF-STANDARD: OS-mode skill with no _system/ directory
~/.claude/skills/research-os-web-researcher/
└── SKILL.md              ← no schema.json — cannot be declared as a dependency
```

**Rationale:** OS-mode skills are installed from external packages. Without a versioned schema contract, a package update can silently break all skills that depend on it.

### Rule 4 — Breaking changes to skills with consumers require versioned announcement (`MUST`)

A breaking change is any change to a skill that:
- Removes or renames a required input
- Changes the output format in a way callers cannot auto-adapt to
- Removes an invocation mode or trigger phrase that other skills document as a dependency

**Required process:**
1. Identify all skills that invoke this skill (run `command grep -r "skill: \"<name>\"" ~/.claude/skills/`)
2. Add a `BREAKING CHANGE:` entry to the skill's SKILL.md changelog section describing what breaks and the migration path
3. Bump the skill's version field in its frontmatter (`version: N+1`)
4. Update all consuming skills' SKILL.md files to use the new interface before merging

```
# OFF-STANDARD: rename a skill input with no announcement
# bx-workflow-creator used to accept "topic", now accepts "workflow_name" — all callers break silently

# ON-STANDARD: version the change and announce
---
version: 3
---
## Changelog
### v3
BREAKING CHANGE: `topic` parameter renamed to `workflow_name`. Update all callers:
  skill: "bx-workflow-creator", args: { workflow_name: "..." }  (was: topic: "...")
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Skill A invokes Skill B which invokes Skill A | Infinite loop / abort | Refactor shared logic into a utility skill with no dependencies; A and B both invoke the utility |
| `source ~/.claude/skills/foo/SKILL.md` in a skill's wiring section | Invisible to cycle detector; bypasses guard | Use `Skill tool: skill: "foo"` |
| Declaring a dependency on an OS-mode skill with no `_system/schema.json` | Interface is undefined; breaking on update | Wait for the OS package to publish `_system/schema.json` before declaring the dependency |
| Renaming a skill's required input without a BREAKING CHANGE entry | Silent breakage in all consumers | Add changelog entry, bump version, update consumers in same PR |
| A skill that invokes itself in a special-case branch | Self-reference cycle | Extract the recursive case into a separate helper skill or use a loop within the skill |

## Deviation guidance

MAY declare a temporary unversioned dependency on an OS-mode skill that lacks `_system/schema.json` when:
- The OS package is in active development under the same branch and schema publication is imminent
- The dependency is behind a runtime guard that checks for schema presence before invoking

MUST document the deviation with a comment in the consuming skill's SKILL.md:
```
# TEMPORARY: research-os-web-researcher has no _system/schema.json yet (tracked: <issue>)
# Guarded: [[ -f "$HOME/.claude/skills/research-os-web-researcher/_system/schema.json" ]] || return 0
```

## Profile inheritance notes

This standard lives at `general` level and propagates to all child profiles:
- `cli` profile: inherits as-is; `skill-circular-detector.sh` pre-commit gate applies to `.claude/skills/`
- `webapp` profile: inherits as-is; same enforcement applies
- `installable-os` profile: this standard governs OS-mode skills themselves — they must publish `_system/schema.json` to be usable as dependencies by any other profile

No child profile should restate these rules — link here instead. Only override if a child profile adds additional constraints (e.g., installable-os adding the `_system/` publication requirement is already captured in Rule 3).

## Compliance test

- [ ] Does `skill-circular-detector.sh` exit 0 on the full skills directory (no cycles detected)?
- [ ] Do all `skill:` invocation references in SKILL.md files use the Skill tool format — not `source` or bash exec?
- [ ] For every OS-mode skill listed as a dependency, does `_system/schema.json` exist at that skill's root?
- [ ] For every breaking change merged in the last release, does the changed skill have a `BREAKING CHANGE:` entry and a version bump in its frontmatter?
- [ ] Does `command grep -r "skill: " ~/.claude/skills/ | command grep -v "skill: \"[a-z]"` return zero results (no unquoted skill references that would evade cycle detection)?

If any check fails: do not merge. Fix the violation (remove the cycle, convert the bare source, wait for schema publication, add the breaking-change entry) or explicitly record the deviation with a justification comment in the affected SKILL.md.

## References

- [Acyclic Dependencies Principle (ADP)](https://wiki.c2.com/?AcyclicDependenciesPrinciple) — Robert C. Martin; the package dependency graph must be acyclic. Applied here to the skill invocation graph instead of compiled packages.
- `profiles/general/standards/global/modular-architecture.md` — companion standard for module-level dependency direction; this standard extends its Rule 4 CI enforcement to the skill layer
- `scripts/lib/skill-circular-detector.sh` — the mechanical enforcement tool for Rule 1
- `scripts/hooks/pre-commit-posture-validation.sh` — pre-commit wiring that runs cycle detection on every staged SKILL.md change
