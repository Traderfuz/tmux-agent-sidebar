<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/skills-testing-and-release-standards.md and re-run profile-sync. -->
# Skills Testing and Release Standards

## Overview

This standard governs how Claude Code skills (SKILL.md files) are validated, tested, and promoted before use in autonomous workflows or publication to a skill catalog. It exists because a skill with broken triggers, unresolved references, or undocumented failure paths will silently misbehave in agent chains — often with no visible error until a critical workflow fails.

## Scope

**Covers:** YAML/frontmatter validation, trigger accuracy testing, structural reference checks, functional command verification, versioning discipline, and rollback readiness for all SKILL.md files.

**Does NOT cover:** Runtime errors inside skill-invoked tools (covered by the skill's own error handling), skill content quality (covered by `skill-content-standards.md`), or skill header repair (covered by `skills-repair-playbook.md`).

## Principles

1. **Gate before publish.** No skill reaches a catalog or autonomous workflow without passing all pre-release gates — a broken skill in production is harder to detect than a blocked publish.
2. **Test both positive and negative triggers.** A trigger description that is too broad causes false positives; too narrow causes missed invocations. Both directions must be tested explicitly.
3. **Failure paths are first-class.** Smoke tests for failure scenarios are mandatory, not optional. A skill without documented failure handling is incomplete.
4. **Version changes communicate intent.** Patch, minor, and major bumps are a contract with downstream consumers. Misusing them breaks agent expectations silently.

## Rules

Use this standard before publishing, syncing, or relying on skills in autonomous workflows.

### Test Levels

1. Syntax: `SKILL.md` parses and frontmatter validates.
2. Triggering: skill is invoked when expected and not invoked when irrelevant.
3. Structural: all referenced files, scripts, and assets exist.
4. Functional: commands in the skill run successfully in the target environment.
5. Behavioral: outputs match expected format and workflow checkpoints.

### Required Pre-Release Gates

1. YAML/frontmatter validation passes.
2. Description length is `<= 1024`.
3. No duplicate frontmatter blocks.
4. Description has clear "use when" trigger language.
5. Every referenced script/path resolves.
6. Example commands run without manual correction.
7. Failure paths are documented (missing tool, auth, network, permissions).
8. `SKILL.md` naming and folder conventions are respected.

### Smoke Test Protocol

For each skill:
1. Run one happy-path invocation.
2. Run one likely failure-path invocation.
3. Run one should-trigger prompt test.
4. Run one should-not-trigger prompt test.
5. Confirm error messaging is actionable (tells user exactly what to do next).
6. Confirm outputs are deterministic enough for agent chaining.

### Trigger Test Examples

- Should trigger:
  - direct feature request in scope
  - request mentioning expected file type/workflow
- Should not trigger:
  - generic request outside scope
  - request owned by a different specialized skill

Tune description based on false positives/negatives.

### Versioning and Promotion

#### Bump type selection

| Bump | When to use |
|------|-------------|
| `patch` | Structural fixes only: typos, formatting, broken references, YAML repair, doc-only changes |
| `minor` | Any content change: new framework, new generator entry, new worked example, updated instructions |
| `major` | Scope/description overhaul, interface change, removed workflows, breaking behavior |

**Tie-breaker:** when the same run includes both structural fixes and content changes, use `minor`. Content outranks structural in the same run.

#### Running the version bump

Every skill that uses `bx-skill-creator` or `bx-skill-creator` carries a self-contained copy of `scripts/bump-skill-version.sh`. Run it from the skill's own directory:

```bash
bash scripts/bump-skill-version.sh --bump patch|minor|major <path-to-SKILL.md>
```

- If the script exits non-zero: report the error, skip the CHANGELOG write, stop.
- Do NOT attempt a manual `sed` edit of the `version:` field — the script uses `awk` first-match replacement to avoid touching `version:` occurrences inside template blocks.

#### CHANGELOG.md format

Every skill directory must have a `CHANGELOG.md`. Entries are prepended (newest first):

```markdown
## vX.Y.Z — YYYY-MM-DD

**Bump type:** patch | minor | major | initial

**Changed:**
- <what was added, fixed, or updated>

**Unchanged:** <major sections not touched, or "N/A">

---
```

The `initial` bump type is used only for the first entry when a skill is created.

#### Self-containment requirement

`bump-skill-version.sh` must live inside the individual skill's `scripts/` directory. Skills are installed in isolation to `~/.claude/skills/<name>/` — cross-skill or repo-root script references will break in installed contexts. Each skill carries its own copy; do not symlink.

Promote only after all gates pass, smoke tests are recorded, and the version bump + CHANGELOG entry are written.

### Rollback Readiness

- Keep previous known-good skill version available.
- Avoid force-overwriting without backup.
- If loader errors appear after update, restore last good header and re-validate first.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Publishing without running smoke tests | Broken commands and missing assets only surface at runtime, often mid-workflow with no recovery path | Run all 6 smoke test steps before promoting |
| Skipping the should-not-trigger test | An over-broad description causes the skill to fire on unrelated requests, displacing the correct skill | Explicitly construct a prompt outside scope and verify the skill does not activate |
| Using a major bump for a typo fix | Signals a breaking change to consumers, triggers unnecessary re-validation and downstream caution | Use patch bump for cosmetic or doc-only changes |
| Promoting without recording smoke test results | Future maintainers cannot distinguish a tested release from an untested one | Document test results in the skill's changelog or release notes |
| Overwriting a skill without backup | If the new version has a loader error, the previous known-good version is lost | Keep the prior version accessible until the new version has passed all gates in the target environment |

## Deviation Guidance

MAY skip the behavioral smoke test (step 5 of Smoke Test Protocol) when the skill produces no structured output and operates purely as a procedural guide with no agent-chained artifacts.

MUST run all remaining smoke tests and all pre-release gates regardless of any other deviation.

MUST document any skipped test in the skill's changelog entry with a stated reason.

## Compliance Test

Answer yes/no before promoting any skill:

- [ ] Did YAML/frontmatter validation pass with no errors?
- [ ] Was at least one should-not-trigger prompt tested and confirmed negative?
- [ ] Do all referenced scripts and paths resolve in the target environment?
- [ ] Are failure paths (missing tool, auth, network, permissions) documented in the skill body?
- [ ] Does the version bump type (patch/minor/major) correctly reflect the nature of the change?

## References

- `skill-content-standards.md` — content quality requirements for SKILL.md body
- `skills-repair-playbook.md` — fixing YAML/frontmatter failures before testing
