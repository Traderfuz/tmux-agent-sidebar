<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/command-ux.md and re-run profile-sync. -->
# Command UX Standard

## Overview

All DevOS commands must support two universal flags for safe exploration: `--help` and `--dry-run` (where applicable). These lower the barrier for new users and make the command surface self-documenting without requiring external docs.

## Rules

### `--help` — universal, required on all commands

Every command must respond to `--help` by printing its usage and options, then exiting without performing any side effects.

**Implementation:** When `--help` is passed as the first or only argument, output:

```
Usage: <command> [options]
<one-line description from frontmatter>

For full documentation: help <command>
```

If the command has named options, list them. Then stop — do not execute the command body.

**Rationale:** `help <command>` is the canonical detailed reference. `--help` is the reflex a user reaches for first. Both should work. `--help` delegates to the same information rather than duplicating it.

### `--dry-run` — required on commands with side effects

Commands that create files, modify git state, send messages, or make external API calls must support `--dry-run`. When passed:
- Print every action that *would* be taken, prefixed with `[dry-run]`
- Make no changes to the filesystem, git history, or external services
- Exit 0

Commands that are read-only (status, help, list, inspect) are exempt from `--dry-run`.

### Existing command inventory

As of 2026-03-30, 16 of 103 commands explicitly document `--help` or `--dry-run`. The remaining 87 are covered by this standard going forward. When modifying an existing command, add `--help` support at that time (opportunistic, not a forced mass-update).

New commands written after this standard is published MUST include both flags in their `## Options` table.

## Compliance test

- [ ] Does the command's `## Options` section list `--help`?
- [ ] If the command has side effects, does it list `--dry-run`?
- [ ] When `--help` is passed, does the command print usage and exit without executing?
- [ ] When `--dry-run` is passed on a side-effect command, does it log `[dry-run]` lines and make no changes?

## Deviation guidance

You MAY omit `--dry-run` from purely read-only commands (those that only read files, display state, or inspect the repo without changing anything). Document the omission with a comment: `# No --dry-run needed: read-only command`.

You MUST NOT omit `--help`. Every command, regardless of complexity, supports `--help`.

---

## Rule: Next-Step Recommendation Format

When any skill, workflow, chain, command wrapper, or hook emits a "next step" recommendation, the **skill name is the canonical invocable**. Claude Code slash-command syntax is compatibility context only.

**Why:** Skills are cross-platform (Claude Code, Codex, Gemini, Kilo, OpenCode, Kimi, Hermes, Zed/ACP). Commands (`cmd`) are Claude Code-specific wrappers and are no longer generated as normal install aliases. The skill name is the only identifier that means something on every platform DevOS supports.

### Cross-platform invocation matrix

| Platform | Skill invocation | Skill discovery path |
|---|---|---|
| Claude Code | Skill name through the Skill tool or generated skill registry; legacy `cmd` only when a thin wrapper exists | `~/.claude/skills/` |
| Codex CLI | `$skill-name` or `/skills` selector | `~/.codex/skills/` |
| Gemini CLI | Implicit — description matching | `~/.agents/skills/` |
| Kilo Code | Implicit — description matching, SKILL.md-based | per config dir |
| OpenCode | Likely `$skill-name` (Codex fork — verify on next knowledge-pull) | `~/.config/opencode/skills/` |
| Kimi | Implicit from synced dir | `~/.kimi/skills/` |
| Hermes | Implicit from synced dir | `~/.hermes/skills/` |
| Zed ACP | Via `devos-agent.sh` — ACP dispatches skills/chains from registries | N/A — ACP transport |

**Canonical source:** `command-quality.md` — "skills work across CLIs (Claude Code, Codex, Gemini, opencode); commands are Claude Code-specific."

### Required format

**Single recommendation:**
```
→ Next: `<skill-name>` skill
```

**Multi-step sequence:**
```
1. `<skill-name>` skill
2. `<skill-name>` skill
3. `<skill-name>` skill --flag
```

### Rules

**Rule: Never surface `cmd` as the primary recommendation.**
Rationale: `cmd` is Claude Code-specific. Skill names are cross-platform.

**Rule: Use the skill name as the invocable in prose, `<<next>>`, and `NEXT STEP` markers.**
The runtime/prefill layer applies CLI-specific syntax when needed.

**Rule: For legacy commands with no backing skill,** use the command string alone and label it as legacy/Claude Code-only:
```
→ Next: Claude Code legacy command `help`
```

**Rule: `<<next>>` marker wraps the bare skill name plus flags** — not the Claude Code command string:
```
<<next>>gap-analysis --dalio --converge<</next>>
NEXT STEP 👉 gap-analysis --dalio --converge
```
The `next-command-prefill.sh` hook extracts the skill name and applies CLI-specific prefixes when needed.

**Rule: Include platform-specific examples only in platform docs or troubleshooting, never as the primary workflow recommendation:**
```
→ Next: `gap-analysis` skill
  Claude Code legacy wrapper, if present: gap-analysis
  Codex skill form: $gap-analysis
```

### Rule: The printed next-step line is the contract; prefill is enhancement-only

Grounded in clig.dev (Command Line Interface Guidelines): a CLI should *propose what to
run next*, but command **prefill only fires in an interactive context, and its absence
must never lose the suggestion.**

- **The human-readable line is the contract and MUST always print** — `→ Next: \`<skill>\``
  (and/or `NEXT STEP 👉 <skill>`). This works in every environment: terminal, Orca, tmux,
  headless logs. It is what the operator reads and acts on.
- **`<<next>>...<</next>>` is a progressive enhancement, not the contract.** The
  `next-command-prefill.sh` Stop hook auto-types the wrapped command into the pane via
  `tmux send-keys` — **but only when the session runs inside a tmux pane** (`$TMUX` set).
  Outside tmux (e.g. a plain Orca terminal) it is a silent no-op by design.
- **Therefore: never rely on `<<next>>` to convey the next step.** It must always sit
  alongside the printed `→ Next:` / `NEXT STEP 👉` line. If the prefill never fires, the
  operator still has the full, runnable command on screen. Emitting `<<next>>` without the
  printed line is a violation — non-tmux users would get nothing.

**Known limitation (documented, not a bug):** prefill is tmux-gated today. Operators not
running Claude Code inside tmux will never see auto-prefill; they read and run the printed
line. A future enhancement may broaden the prefill backend (TTY-gated rather than
tmux-gated), but the printed-line contract stands regardless.
