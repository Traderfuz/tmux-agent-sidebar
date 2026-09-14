<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/README.md and re-run profile-sync. -->
# Skills Standards Index

## Core Standards

Foundation rules that apply to every skill file:

- `claude-code-skills-official.md` — Official Claude Code skill specification
- `anthropic-complete-guide-alignment.md` — Alignment with Anthropic's complete skill guide
- `skills-standards.md` — Frontmatter format, YAML rules, naming, validation
- `skill-structure.md` — Directory layout, entrypoint, linking rules
- `skill-content-standards.md` — Content completeness requirements per section
- `skill-workflow-patterns.md` — 4 workflow patterns (Spec-Build-Validate-Release, etc.)
- `stateful-operation-orchestration.md` — Selection gate and durable architecture contract for resumable, mutating, evidence-gated orchestrator skills

## Operational Standards

Standards for authoring, testing, and maintaining skills:

- `skills-authoring-best-practices.md` — Trigger design, progressive disclosure, authoring guidance
- `skills-testing-and-release-standards.md` — Validation gates, release checklist
- `skills-repair-playbook.md` — Detect-Repair-Revalidate pattern
- `hooks-standards.md` — Hook integration rules
- `self-contained-skills.md` — Self-containment rules; standalone without upstream dependencies

## Vibe Skill Quality Standards — Single-Skill Level

Production-tested standards for individual skill quality. Apply to every skill author:

- `vibe-skill-framework.md` — 11-element blueprint; every element with pattern, example, and rationale
- `vibe-skill-writing-standard.md` — Writing quality rules per element, anti-patterns, scope discipline, research quality signal

## Vibe Skill OS Standards — System Level

Standards for building a complete skill OS (orchestrator + shared memory + distribution). Apply to skill system authors — not required for authors of individual standalone skills:

- `vibe-orchestrator-standard.md` — Orchestrator design: routing, parallel dispatch, workflow confirmation, session state, context handoff
- `vibe-shared-memory-standard.md` — Shared memory layer: file ownership, read/write protocols, graceful degradation, voice injection
- `vibe-output-format-standard.md` — Terminal output visual design system: 4-section structure, character palette, template library
- `vibe-schema-contracts-standard.md` — Inter-skill JSON schema contracts: when to create, naming, ownership, versioning
- `vibe-distribution-standard.md` — Distribution pipeline: install.sh, doctor.sh, e2e-fresh-install.sh, package.sh

---

## Recommended Read Order

### For individual skill authors

1. `claude-code-skills-official.md`
2. `anthropic-complete-guide-alignment.md`
3. `skills-standards.md`
4. `skill-structure.md`
5. `skill-content-standards.md`
6. `vibe-skill-framework.md`
7. `vibe-skill-writing-standard.md`
8. `skills-testing-and-release-standards.md`
9. `skills-repair-playbook.md`
10. `stateful-operation-orchestration.md` when the skill coordinates interruptible or retryable multi-owner operations

### For skill OS authors (building a multi-skill system)

Read the individual skill author order first, then:

10. `vibe-orchestrator-standard.md`
11. `vibe-shared-memory-standard.md`
12. `vibe-output-format-standard.md`
13. `vibe-schema-contracts-standard.md`
14. `vibe-distribution-standard.md`

---

## Standard Levels

| Standard | Level | Who needs it |
|---|---|---|
| `skills-standards.md` | Single skill | All skill authors |
| `skill-structure.md` | Single skill | All skill authors |
| `skill-content-standards.md` | Single skill | All skill authors |
| `vibe-skill-framework.md` | Single skill | All skill authors |
| `vibe-skill-writing-standard.md` | Single skill | All skill authors |
| `stateful-operation-orchestration.md` | Single skill/system seam | Authors of resumable, mutating, evidence-gated orchestrators |
| `vibe-orchestrator-standard.md` | OS level | Skill system authors |
| `vibe-shared-memory-standard.md` | OS level | Skill system authors |
| `vibe-output-format-standard.md` | OS level | Skill system authors |
| `vibe-schema-contracts-standard.md` | OS level | Skill system authors |
| `vibe-distribution-standard.md` | OS level | Skill system authors |
