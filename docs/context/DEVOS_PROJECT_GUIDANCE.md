# DevOS Project Guidance

## Project Purpose

- Define the mission and product goals.

## Install Topology

- DevOS profile `cli`; project config lives in `.dev-os/config.yml`.
- DevOS runtime state lives under `.dev-os/runtime/`; generated context renders into `CLAUDE.md`, `AGENTS.md`, and `docs/context/DEVOS_*.md`.
- Durable project guidance lives in this file; the Claude brief in `CLAUDE.md` is rendered from it.

## Tech Stack

- Primary implementation language is Rust.
- Tests use cargo-test.
- Package manager: cargo.
- Additional languages present: bash, javascript, typescript.

## Development Commands

- Run tests with `cargo test`.
- CI runs via GitHub Actions (`.github/workflows/`).

## Architecture Anchors

- `docs/context/codebase-map.md` describes file roles and hotspots; start there.
- `docs/context/DEVOS_ARCHITECTURE.md` describes component relationships.
- `scripts/` — build and utility scripts.
- `src/` — application source.
- `tests/` — test suites.

## Operating Rules

- Before removing or overwriting config files, create a backup first
- Never bulk-delete files without explicit approval
- Do not commit secrets (`.env`, credentials, API keys) to git
- Before staging files for a commit, verify they are inside the git repository root
- Do not force-push to main/master
- Project is prelaunch: prefer forward-compatible simplification; no legacy shims unless explicitly requested.
- Preserve user-authored content outside DevOS managed blocks.

## Gotchas

- No gotcha signal detected yet; record traps here as they surface.
