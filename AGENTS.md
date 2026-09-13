## Project Overview

A tmux sidebar TUI (built with Ratatui + Crossterm) that monitors AI coding agents (Claude Code, Codex) across all tmux sessions/windows/panes in real-time. Distributed as a single binary via tmux plugin managers.

## Build & Development Commands

```bash
cargo build                    # Debug build
cargo build --release          # Release build (strip + lto enabled)
cargo test                     # Run all tests
cargo test <test_name>         # Run a single test
cargo clippy                   # Lint
cargo fmt                      # Format code
cargo fmt --check              # Check formatting (used in CI)
```

CI runs `cargo test`, `cargo clippy`, and `cargo fmt --check` on every push/PR.

**Before creating any git commit**, always run `cargo fmt` first to avoid CI formatting failures. This applies to every commit, not just the final one.

After implementation is complete, run `cargo build --release`. The plugin directory is usually a symlink to this repo, so the binary is picked up automatically; only a worktree build needs a manual copy (see "Debugging" section below).

## Architecture

### Entry Points

The binary has two modes controlled by CLI args (`src/cli/mod.rs`):
1. **TUI mode** — default. `src/main.rs` handles CLI arg parsing, SIGUSR1 signal wiring, and TUI session setup, then delegates to `app::run` (`src/app.rs`) for the event loop.
2. **CLI subcommands** — `setup`, `hook`, `toggle`, `toggle-all`, `auto-close`, `set-status`, `spawn`, `capture`, `--version` / `version`.

### Core Data Flow

```
Agent hooks (hook.sh) → CLI `hook` subcommand
                           ↓
        adapter/ normalizes raw JSON into AgentEventKind
                           ↓
        event/ builds an internal AgentEvent
                           ↓
        cli/hook/handlers dispatches on_* per event, which:
          • sets tmux pane options (@pane_status, @pane_attention, etc.)
          • appends to /tmp/tmux-agent-activity*.log
                           ↓
TUI event loop (app::run) → AppState::sync_global_state()
          • reads tmux panes via single `list-panes -a`
          • parses /tmp/tmux-agent-activity*.log
                           ↓
                ui::draw() renders frame
```

### Key Modules

- **`state.rs` + `state/`** — `AppState` central struct plus topical submodules (`activity`, `session`, `focus`, `scroll`, `pane_runtime`, `layout`, `popup`, `notices`, `timers`, `filter`, `global`, `refresh`, `tab`). All UI is computed from this state.
- **`app.rs` + `app/`** — TUI orchestration: `setup` (prime `AppState`), `workers` (background git/session/version threads), `input` (keyboard/mouse handling), `render` (per-frame render entry). Split out from `main.rs` so the binary entry point only handles CLI dispatch, signal wiring, and TUI session setup.
- **`tmux.rs`** — Tmux integration: queries all panes via single `list-panes -a` call, defines `PaneInfo`/`PaneStatus`/`AgentType`/`PermissionMode`/`WorktreeMetadata`.
- **`adapter/`** — Per-agent event adapters (`claude`, `codex`, `omp`, `opencode`). Each exposes a `HOOK_REGISTRATIONS` table binding upstream agent events to an internal `AgentEventKind`, plus a `parse()` that maps raw JSON payloads into `AgentEvent`. Single source of truth consumed by the setup wizard, README snippets, and tests.
- **`event.rs` + `event/`** — Internal event layer: `AgentEvent` (pre-extracted fields; handlers never touch raw JSON or agent names), `AgentEventKind` (compile-time enum for hook kinds), `EventAdapter` trait + `resolve_adapter`.
- **`cli/hook.rs` + `cli/hook/`** — Receives real-time status updates from agent hooks; dispatch in `hook.rs`, with submodules `context` (shared helpers + `AgentContext`), `handlers` (per-event `on_*` handlers), `activity` (activity log writing), `notifications` (desktop notification helpers).
- **`git.rs`** — Git operations (branch, ahead/behind, PR numbers via `gh` CLI, diff stats). Runs in a background polling thread.
- **`activity.rs`** — Parses `/tmp/tmux-agent-activity*.log` files, maps tool types to colors.
- **`group.rs`** — Groups panes by repository path.
- **`session.rs` / `worktree.rs` / `tool_name.rs` / `version.rs` / `port.rs` / `clipboard.rs` / `desktop_notification.rs`** — Leaf helpers used across modules (session name resolution, worktree metadata parsing, tool-name classification, version reporting, port detection, clipboard + desktop notification shims).
- **`ui/`** — Rendering layer: `mod.rs` (entry `draw`), `panes.rs` (agent list + repo filter) with submodules (`filter_bar`, `row`, `row_collector`, `click_targets`, `popups`); `bottom.rs` + `bottom/` with submodules (`activity`, `git`) for the activity/git tabs; `colors.rs` (256-color theme); `icons.rs` (agent/status glyphs); `notices.rs` (transient banner rendering); `text.rs` (text formatting/truncation).

### State Management

See `docs/state-management.md` for the full scope/update-frequency table, per-pane tmux options, data flow, and key type definitions.

Process-level detail not covered there: SIGUSR1 triggers an instant refresh on tmux pane focus change (handler in `src/main.rs` flips a shared `AtomicBool` that the `app::run` loop polls).

### Testing

Tests are in `/tests/` using Ratatui's `TestBackend` for UI rendering assertions. `test_helpers.rs` provides buffer-to-string conversion utilities. Heavy use of snapshot-style tests for UI regression prevention.

**UI test rule**: any test that renders a frame MUST use `insta::assert_snapshot!(output, @"...")` inline snapshots — never `assert!(output.contains(...))` or similar substring checks. A contains assertion only verifies that a specific string appears somewhere; it silently tolerates layout drift (border shifts, color changes, row reordering, new artifacts) that a snapshot diff would surface immediately. The stronger check is free — `cargo insta accept` regenerates the expected output when the change is intentional. Substring assertions are acceptable only for non-visual properties (`layout.repo_spawn_targets` contents, state struct fields, etc.) where there is no frame to snapshot.

## Debugging (Local tmux Plugin)

`~/.tmux/plugins/tmux-agent-sidebar` is typically a symlink to this repository, so `cargo build --release` alone updates the binary tmux loads. Just restart the sidebar (toggle off → on via the tmux keybinding) to pick up the new build.

```bash
cargo build --release
# Restart sidebar (toggle off → on via tmux keybinding)
```

**When working in a worktree**: Worktrees build into their own `target/release/`, which is not what the plugin directory points at, so the artifact must be copied manually AND re-signed. On macOS (Darwin 24+), `cargo` produces a `linker-signed` ad-hoc signature that the kernel will SIGKILL (signal 9) immediately after a `cp` — the kernel refuses to honor a linker-only signature on a file it didn't write itself. Replace it with a fresh ad-hoc signature to avoid the kill:

```bash
cp <worktree-path>/target/release/tmux-agent-sidebar ~/.tmux/plugins/tmux-agent-sidebar/target/release/tmux-agent-sidebar
codesign --force --sign - ~/.tmux/plugins/tmux-agent-sidebar/target/release/tmux-agent-sidebar
```

If tmux reports `terminated by signal 9` after a worktree build, you almost certainly skipped the `codesign` step. Clearing `com.apple.provenance` with `xattr -c` is not required — the kernel only cares about the signature flavor.

## Rust Edition

This project uses Rust edition 2024 (`Cargo.toml`).

## Writing Guidelines

- All documentation under `docs/` and all skill files under `.claude/skills/` must be written in English.

<!-- DEVOS_PROJECT_BRIEF_START -->
## Project Brief

Full guidance: `docs/context/DEVOS_PROJECT_GUIDANCE.md`

- **Project Purpose:** Define the mission and product goals.
- **Install Topology:** DevOS profile `cli`; project config lives in `.dev-os/config.yml`.
- **Tech Stack:** Primary implementation language is Rust.
- **Development Commands:** Run tests with `cargo test`.
- **Architecture Anchors:** `docs/context/codebase-map.md` describes file roles and hotspots; start there.
- **Operating Rules:** Before removing or overwriting config files, create a backup first
- **Operating Rules:** Never bulk-delete files without explicit approval
- **Operating Rules:** Do not commit secrets (`.env`, credentials, API keys) to git
- **Operating Rules:** Before staging files for a commit, verify they are inside the git repository root
- **Operating Rules:** Do not force-push to main/master
- **Operating Rules:** Project is prelaunch: prefer forward-compatible simplification; no legacy shims unless explicitly requested.
- **Operating Rules:** Preserve user-authored content outside DevOS managed blocks.
- **Gotchas:** No gotcha signal detected yet; record traps here as they surface.
<!-- DEVOS_PROJECT_BRIEF_END -->

<!-- DEVOS_CANONICAL_START -->
<!-- DevOS:section:project-context -->
## Project Context

- **Project:** tmux-agent-sidebar
- **DevOS profile:** `cli`
<!-- /DevOS:section:project-context -->

<!-- DevOS:section:execution-orientation -->
## Execution Orientation

- Resolve project, checkout/worktree, branch, workspace, dated spec, task/phase, host session, and execution owner before mutation.
- Use `worktrees` or `start-feature`; consume returned identity and path. Never derive paths or acceptance from names, `cd`, terminal titles, checkboxes, or summaries.
- Preserve read-only, answer-only, do-not-change, only/after, and stop constraints. hard-before-explicit-intent; named gates remain non-overridable.
- Ownership is direct or delegated. Posture is gated or autonomous; autonomous defaults to direct. suppressed-within-authorized-scope.
- Runtime `execution-alignment-public/v1` (1.0.0; omp adapter 1: supported); inspect with `project-status --alignment` when supported.
- Disclose non-success outcomes: failed,blocked,timed-out,interrupted,orphaned,unknown-outcome,degraded,unsupported,bypassed,skipped.
<!-- /DevOS:section:execution-orientation -->

<!-- DevOS:section:skill-invocation -->
## Skill Invocation Contract

DevOS capabilities are registry-routed skills, not executables or shell commands.
When a skill is invoked, read its `SKILL.md` and execute the workflow directly in
the current active session.

- A line such as `map --update` is a **skill invocation with arguments**. Do not
  search for a binary, runner, wrapper, `runner.sh`, `run.sh`, or `map.sh`.
- Bare names are not `$PATH` commands. Never use `command -v`, `which`, or bare
  `--help` to decide availability. Resolve `docs/context/DEVOS_SKILLS_INDEX.json`;
  an absent registry entry is unavailable.
- Use only flags and positional arguments declared by `SKILL.md` or the called
  helper's parser. Never invent flags or confuse accepted arguments with
  downstream arguments.
- The active session owns the full workflow. For an inter-skill dependency,
  read the target skill and continue executing its instructions in the same
  session. Do not look for a dispatch API, submit a nested slash command, or
  require a dispatch receipt.
- A delegated worker cannot invoke parent-session skills or probe `$PATH`. It
  returns `dependency_required` with the exact skill, arguments, dependent gate,
  and artifact. The active session then executes that dependency directly.
- Explicit skill or autonomous intent suppresses only a redundant generic
  confirmation. Present named operator/human/policy gates verbatim; never
  self-approve them.
- A script named by `SKILL.md` is a helper step, not a substitute for the skill.
  Run helpers only as instructed. Source DevOS shell libraries under Bash:
  `bash -lc 'source "$DEVOS_DIR/scripts/lib/<lib>.sh" && <fn>'`.
- In OMP, `/skill:<name> [args]` is the user-facing entry that loads a skill into
  the current session. `skill://<name>` only reads instructions.
- Execution evidence is the current session's tool output, artifacts, and
  required verification. Never fabricate provenance or claim success from a
  read alone.
<!-- /DevOS:section:skill-invocation -->

<!-- DevOS:section:orca-control -->
## Orca Control

When Orca is the requested control plane, use the public `orca` CLI (`orca-ide`
on Linux) and the `orca-cli` / `computer-use` skills before falling back to ad
hoc desktop tools.

- Codex and similar sandboxed sessions may be unable to reach Orca's runtime
  socket under the user's application-support directory. If `orca status --json`
  or `orca computer ... --json` reports `runtime_unavailable`,
  `stale_bootstrap`, or a connection failure from inside the sandbox, retry the
  same public `orca` / `orca-ide` command with the minimal approval/escalation
  needed before concluding Orca is down.
- Use `orca open --json` (`orca-ide open --json` on Linux) when Orca is not
  running. If the runtime points at a stale PID, prefer a graceful app
  quit/reopen, then rerun `orca status --json`.
- For read-only checks, use `orca status --json`,
  `orca computer capabilities --json`, `orca computer list-apps --json`,
  `orca computer list-windows --app <bundle> --json`,
  `orca computer get-app-state --app <bundle> --json`, `orca tab list --json`,
  `orca snapshot --page <pageId> --json`, and `orca terminal list/read --json`.
- Do not click, type, submit, send messages, delete data, change settings, or
  expose sensitive app content unless the user explicitly requested that action.
<!-- /DevOS:section:orca-control -->

<!-- DevOS:section:safety-rules -->
## Safety Rules

- Before removing or overwriting config files, create a backup first
- Never bulk-delete files without explicit approval
- Do not commit secrets (`.env`, credentials, API keys) to git
- Before staging files for a commit, verify they are inside the git repository root
- Do not force-push to main/master
- Run tests before claiming a fix works
<!-- /DevOS:section:safety-rules -->

<!-- DevOS:section:conventions -->
## Development Conventions

- Standards: see `.dev-os/standards/` and the active profile standard index.
<!-- /DevOS:section:conventions -->

<!-- DevOS:section:directory-structure -->
## Key Directories

- `.dev-os/` — project configuration, standards, and runtime state
- `product/` — specifications, reviews, and implementation planning
- `docs/context/codebase-map.md` — generated codebase ownership map (when present)
<!-- /DevOS:section:directory-structure -->

<!-- DevOS:section:devos-context -->
## DevOS Context

Reference these context files in every session:

- `docs/context/DEVOS_CONTEXT_BUNDLE.md` — project summary, profile, version
- `docs/context/DEVOS_CAPABILITIES_INDEX.md` — full capabilities inventory
- `docs/context/DEVOS_PUBLIC_SURFACE.md` — user-facing commands and entry points
- `docs/context/DEVOS_ARCHITECTURE.md` — system architecture and component relationships
- `docs/context/codebase-map.md` — file tree with role annotations
- `docs/context/DEVOS_OWNERSHIP_AUDIT.md` — who owns what across the codebase
- `docs/context/DEVOS_DEFERRED_TOOLS.md` — deferred HTTP MCP servers
- `docs/context/DEVOS_USER_FLOWS_STALENESS.md` — user flow freshness status
- `.dev-os/runtime/context-refresh-state.json` (logical path; resolve via `scripts/lib/runtime-state.sh`)

Already indexed in managed blocks below (no need to read separately):
Skills index, Chains index, MCP index, Standards index, Workflows index
<!-- /DevOS:section:devos-context -->

<!-- DevOS:section:compatibility-posture -->
## Compatibility Posture

- Temporary pre-launch rule. Remove or revise when this project goes live.
- This project is not live yet and has no production customers.
- Breaking changes are acceptable if they simplify the product or close correctness gaps.
- Default to the best forward version, not backwards compatibility.
- Treat unfinished, unused, or dead code as unbuilt features.
- Prefer deletion or replacement over shims, adapters, compatibility layers, or legacy fallbacks.
- Do not add legacy shims, compatibility layers, migrations, or old-contract support unless explicitly requested.
<!-- /DevOS:section:compatibility-posture -->

<!-- DevOS:section:context-artifact-commit-policy -->
## Context Artifact Commit Policy

The batchable artifact set is defined solely by the generated-artifact
classifier: `generated_artifact_classify` in `scripts/lib/generated-artifact-registry.sh`,
intent `context_commit_batch`. No surface may restate that set as a path list;
resolve it with `generated_artifact_partition_dirty` (batch and operator sets).

Commit modes — the decisive question is whether a commit is being made right now,
not whether a `session-end-context-commit` Stop hook might fire later:

- `--all` (default whenever a commit is made — interactive or headless): one
  commit containing both sets; the committing skill exports
  `DEVOS_CONTEXT_COMMIT_MODE=all`, recorded as a `Devos-Context-Commit-Mode: all`
  trailer. A commit that leaves context staged pays a second hook run later and
  can push a skill or spec whose registry entry never left the machine.
- `--split` (explicit opt-in; work not finished): commit the operator set; leave
  batchables staged for the Stop hook, which flushes them as `chore(context)`
  commits under a content-hash debounce. The Stop hook also covers the
  no-commit case on its own.
- `--none`: stage only; no commit. For preflight or deferred decisions.

The pre-commit hook rejects a staged set mixing batch and operator files unless
`DEVOS_CONTEXT_COMMIT_MODE` authorizes it. Env controls: `DEVOS_CONTEXT_COMMIT_FORCE=1`
flushes an active debounce immediately, `DEVOS_SKIP_CONTEXT_BATCH=1` disables the
hook batch for the session, `DEVOS_CONTEXT_BATCH_DEBOUNCE_SECONDS` overrides the
window. This block is generated from the registry — hand edits are lost on the
next refresh; change registry classes or commit mode instead.
<!-- /DevOS:section:context-artifact-commit-policy -->

<!-- DevOS:section:notepad-discipline -->
## Notepad Checkpoint Discipline

You have a durable, file-based notepad at `.dev-os/notepad.md` (project-local) or
`~/.dev-os/notepad.md` (global fallback). Three sections:

- `## PRIORITY` — always injected on session start (≤500 chars). Use for the
  current focus and active blockers, not a journal.
- `## WORKING MEMORY` — append-only, auto-pruneable. Use for milestone
  checkpoints and durable progress notes.
- `## MANUAL` — never auto-modified. Use for long-term observations.

### When to write to WORKING MEMORY

Call `notepad_write_working "<what you did and why>"` at:

1. **Task group completion** — after marking a task group `[x]` in `tasks.md`.
2. **Non-obvious decision** — after choosing between alternatives a future
   session would re-litigate without the rationale.
3. **Spec, architecture, or ADR written** — after persisting any of these.

Skip the write when the work was pure read-only research with no durable outcome.

### When to promote WORKING → PRIORITY

When a thought in WORKING MEMORY becomes a durable rule every future session
must know (an enforced convention, a project-wide constraint), call:

```bash
notepad_promote_working <timestamp_prefix>
```

This atomically moves the entry to PRIORITY (prepended, semicolon-separated)
and removes it from WORKING MEMORY. The 500-char PRIORITY cap is enforced
write-time; an over-long promotion fails loud via `notepad_enforce_priority_cap`
and you must shorten or split the entry before retrying.

### How to invoke

```bash
bash -c 'source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/notepad.sh" && \
  notepad_write_working "<content>"'
```

Inspect with `notepad_show_history "WORKING MEMORY" 7` (last week) or
`notepad_search "<term>"` (case-insensitive across all sections).

Do not hand-edit `.dev-os/notepad.md` — always go through the helpers to keep
the file layout and atomic-write guarantees intact.
<!-- /DevOS:section:notepad-discipline -->
<!-- DEVOS_CANONICAL_END -->

<!-- DEVOS_BUNDLE_INDEX_START -->
## Framework Bundle Index

Compact framework index for low-context providers. Read the referenced bundle files for full docs.

**claude-code-core** vlatest (23.2KB) — claude code settings, permissions, CLAUDE.md, memory, CLI flags, slash commands, interactive mode, configuration
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-core@latest.json` — read `compressed_docs` field

**claude-code-extensions** vlatest (23.2KB) — hooks, skills, MCP, subagents, plugins, SKILL.md, hook events, MCP servers
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-extensions@latest.json` — read `compressed_docs` field

**claude-code-automation** vlatest (23.2KB) — headless mode, agent SDK, GitHub Actions, agent teams, CI/CD, automation, best practices, workflows
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-automation@latest.json` — read `compressed_docs` field

**claude-code-config** vlatest (23.2KB) — model config, sandboxing, checkpointing, keybindings, fast mode, status line, output styles, model aliases
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-config@latest.json` — read `compressed_docs` field

**claude-code-automation** vlatest (23.2KB) — headless mode, agent SDK, GitHub Actions, agent teams, CI/CD, automation, best practices, workflows
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-automation@latest.json` — read `compressed_docs` field

**claude-code-config** vlatest (23.2KB) — model config, sandboxing, checkpointing, keybindings, fast mode, status line, output styles, model aliases
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-config@latest.json` — read `compressed_docs` field

**claude-code-core** vlatest (23.2KB) — claude code settings, permissions, CLAUDE.md, memory, CLI flags, slash commands, interactive mode, configuration
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-core@latest.json` — read `compressed_docs` field

**claude-code-extensions** vlatest (23.2KB) — hooks, skills, MCP, subagents, plugins, SKILL.md, hook events, MCP servers
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-extensions@latest.json` — read `compressed_docs` field

**github-rest-api** v2026-05 (4.9KB) — github-rest-api
> Full docs: `~/.dev-os/bundles/tier2_backend/github-rest-api@2026-05.json` — read `compressed_docs` field

**omp** v17.3.2 (6.5KB) — Priority APIs
> Full docs: `~/.dev-os/bundles/tier0_platform/omp@17.3.2.json` — read `compressed_docs` field

<!-- DEVOS_BUNDLE_INDEX_END -->

<!-- DEVOS_STANDARDS_START -->

## Project Standards

> 174 standards available. Use `standards-guide` to list/read standards; read only relevant standard files before work in that domain.

<!-- DEVOS_STANDARDS_END -->

<!-- DEVOS_CODEMAP_START -->

→ Codebase map not inlined here. Full map: docs/context/codebase-map.md

<!-- DEVOS_CODEMAP_END -->

<!-- DEVOS_SKILLS_INDEX_START -->

## Skills (526 available)

> Skills index on-demand. Use `find-skills` to discover (`docs/context/DEVOS_SKILLS_INDEX.json`).

<!-- DEVOS_SKILLS_INDEX_END -->

<!-- DEVOS_CHAINS_INDEX_START -->

## Chains Index (40 chains)

> Chains index moved to on-demand surface. Use `devos-chains` skill to list or run chains (`docs/context/DEVOS_CHAINS_INDEX.json`).

<!-- DEVOS_CHAINS_INDEX_END -->

<!-- DEVOS_WORKFLOWS_INDEX_START -->

## Workflows Index (240)

> Workflows index on-demand. Use `devos-workflows` skill (`docs/context/DEVOS_WORKFLOWS_INDEX.md`).

<!-- DEVOS_WORKFLOWS_INDEX_END -->

<!-- DEVOS_OS_PACKAGES_START -->

## OS Packages

> Use `os-orchestrate` for durable cross-OS planning and execution; consume Research/Marketing/Creative/Design handoffs only when task requires them.

<!-- DEVOS_OS_PACKAGES_END -->
