<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/agent-directory-layout.md and re-run profile-sync. -->
# Agent Directory Layout Standard

## Overview

This standard defines how agent definitions are stored on disk within a dev-os profile.
It governs when to use a flat single file vs. a named subdirectory, and what files belong
in each case.

## Scope

**Covers:** On-disk layout for agent definitions under `profiles/<name>/agents/`.

**Does NOT cover:** System prompt content or compliance requirements — see `system-prompt-design.md`.
Architecture pattern selection — see `agent-architecture.md`.

## Rules

### R1 — Flat file for single-file agents

An agent that has only a description block (capabilities, skills, responsibilities, standards)
and no separate system prompt, DESIGN-NOTES, or CHANGELOG uses a single flat file:

```
profiles/<profile>/agents/<agent-name>.md
```

Examples: `implementer.md`, `spec-writer.md`, `skill-validator.md`

### R2 — Named subdirectory for multi-file agents

An agent with a formal system prompt, DESIGN-NOTES.md, or CHANGELOG.md MUST be stored in
a named subdirectory. The directory name matches the agent name exactly:

```
profiles/<profile>/agents/<agent-name>/
├── <agent-name>.md      ← entry point: one-line description + links to other files
├── system-prompt.md     ← compliant system prompt (7-section canonical order)
├── DESIGN-NOTES.md      ← architecture pattern, posture, tool access table, max_turns
├── agent-spec.md        ← human-readable spec for review and registration
└── CHANGELOG.md         ← version history (created on first Mode 3 upgrade)
```

The entry-point file (`<agent-name>.md`) contains:
- A `> vX.Y.Z — ...` banner with the current version
- One-line `See:` reference listing the companion files

### R3 — No loose companion files in the agents/ directory

Files named `system-prompt.md`, `DESIGN-NOTES.md`, `CHANGELOG.md`, or `agent-spec.md`
MUST NOT appear directly in `profiles/<profile>/agents/`. They belong inside a named
agent subdirectory. A loose companion file with no containing directory is a layout violation.

### R4 — Single-file agents may be promoted to subdirectory

When a single-file agent description is upgraded to a compliant multi-file description
(via `bx-agent-creator` Mode 3), it MUST be promoted to a subdirectory:

1. Create `agents/<agent-name>/`
2. Move `agents/<agent-name>.md` → `agents/<agent-name>/<agent-name>.md`
3. Add `system-prompt.md`, `DESIGN-NOTES.md`, `agent-spec.md`, `CHANGELOG.md` inside the subdirectory
4. Add the version banner to the entry-point file

## Layout reference

```
profiles/general/agents/
├── implementer.md              ← single-file (no system prompt yet)
├── spec-writer.md              ← single-file
├── skill-validator.md          ← single-file
├── skill-architect.md          ← single-file
└── git-automation/             ← multi-file agent (R2 layout)
    ├── git-automation.md       ← entry point
    ├── system-prompt.md
    ├── DESIGN-NOTES.md
    ├── agent-spec.md
    └── CHANGELOG.md
```

## Compliance Test

1. Are there any files named `system-prompt.md`, `DESIGN-NOTES.md`, `CHANGELOG.md`, or
   `agent-spec.md` loose in `profiles/<profile>/agents/` (not inside a named subdirectory)? → Must be No.
2. Does every multi-file agent directory contain an entry-point `<agent-name>.md` with a
   version banner and `See:` references? → Must be Yes.
3. Do all single-file agents contain only description content (no embedded system prompts)? → Must be Yes.
