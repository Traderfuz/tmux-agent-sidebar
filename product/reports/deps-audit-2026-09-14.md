# Dependency Audit — tmux-agent-sidebar

Date: 2026-09-14
Manifest: `Cargo.toml`
Method: crates.io `cargo search` for direct dependencies; `cargo update --dry-run` for lockfile drift; source scan for deprecated SDK patterns.

## Result

No direct dependency drift was found. Every direct dependency in `Cargo.toml` matches the current crates.io release searched today.

| Dependency | Declared | Current | Status |
|---|---:|---:|---|
| ratatui | 0.30.2 | 0.30.2 | Current |
| crossterm | 0.29.0 | 0.29.0 | Current |
| unicode-width | 0.2.2 | 0.2.2 | Current |
| libc | 0.2.189 | 0.2.189 | Current stable |
| indexmap | 2.14.2 | 2.14.2 | Current |
| serde_json | 1.0.151 | 1.0.151 | Current |
| arboard | 3.6.1 | 3.6.1 | Current |
| vte | 0.15.0 | 0.15.0 | Current |
| indoc | 2.0.7 | 2.0.7 | Current |
| insta | 1.48.0 | 1.48.0 | Current |
| tempfile | 3.27.0 | 3.27.0 | Current |
| scopeguard | 1.2.0 | 1.2.0 | Current |

## Lockfile drift

`cargo update --dry-run` found updates only among transitive lockfile packages. No manifest constraint requires a change. This audit does not update transitive dependencies.

## Deprecated API scan

No matches for Anthropic, OpenAI, or Vercel AI deprecated API patterns were found in `src/` or `tests/`.

## Findings

None. No Critical findings remain unresolved.

## Verification evidence

- `cargo test`: 1277 passed; 2 ignored.
- `cargo update --dry-run`: completed without changing `Cargo.lock`.
