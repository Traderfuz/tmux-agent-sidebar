<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/hook-path-portability.md and re-run profile-sync. -->
# Hook Path Portability Standards

## Overview

A hook that works on the author's machine but fails silently on every other machine is worse than no hook — it creates a false sense of safety. The root cause is always the same: a bare relative path (`bash scripts/hooks/foo.sh`) that assumes CWD equals the repository root. Claude Code, Codex, and other AI CLI tools do not guarantee CWD for hook execution. This standard governs how hook commands resolve paths so they work regardless of working directory.

**Sibling standards:**
- [`shell-safety.md`](./shell-safety.md) — command invocation safety (alias bypass, pipefail)
- [`installer-propagation.md`](./installer-propagation.md) — ensuring new hooks are registered in install scripts

## Scope

This standard covers path resolution patterns in hook `command` fields within `.claude/settings.json`, `.codex/hooks.json`, and any install script that writes hook registrations to settings files. It does NOT cover hook script internal logic, hook event selection, hook ordering, or hook performance.

## Principles

1. **Absolute resolution at invocation:** Every hook command must resolve to an absolute path before the shell interprets the script path. A relative path is a bet on CWD — and that bet loses in CI, subagents, and worktrees.
2. **Explicit shell prefix:** Hook commands use `bash "..."` to ensure bash execution. Omitting the prefix relies on shebang dispatch, which fails when the hook runner doesn't honor shebangs or invokes `sh` instead of `bash`.
3. **Two path domains, two patterns:** Project-local hooks resolve via `git rev-parse --show-toplevel`. User-global hooks resolve via `$HOME`. No other patterns are permitted.

## Rules

### Rule 1 — Project-level hook paths (`MUST`)

Hook commands in project config files (`.claude/settings.json`, `.codex/hooks.json`) that reference repo-local scripts MUST use `git rev-parse --show-toplevel` for path resolution.

```json
// OFF-STANDARD — bare relative path, breaks when CWD ≠ repo root
"command": "bash scripts/hooks/post-start-verification.sh"

// OFF-STANDARD — hardcoded absolute path, breaks on other machines
"command": "bash /Users/traderfuz/projects/dev-os/scripts/hooks/post-start-verification.sh"

// ON-STANDARD — resolves from git root regardless of CWD
"command": "bash \"$(git rev-parse --show-toplevel)/scripts/hooks/post-start-verification.sh\""
```

### Rule 2 — User-level hook paths (`MUST`)

Hook commands in user-level config (`~/.claude/settings.json`) that reference installed scripts MUST use `$HOME` for path resolution. Never expand `$HOME` to the literal home directory at install time.

```json
// OFF-STANDARD — expanded at install time, not portable across users
"command": "bash /Users/traderfuz/.dev-os/scripts/hooks/bundle-injection.sh"

// OFF-STANDARD — bare path without bash prefix
"command": "$HOME/.dev-os/scripts/hooks/bundle-injection.sh"

// ON-STANDARD — bash prefix + $HOME for runtime resolution
"command": "bash \"$HOME/.dev-os/scripts/hooks/bundle-injection.sh\""
```

### Rule 3 — Install script registration (`MUST`)

Install scripts that write hook entries to settings files MUST emit the `bash "$HOME/..."` form. The `_normalize_cmd` function (or equivalent) MUST convert any bare paths or expanded home directories to the portable form before writing JSON.

```bash
# OFF-STANDARD — bare path, no bash prefix
_add_hook_if_present 'Stop' '' '$HOME/.dev-os/scripts/hooks/foo.sh' '...'

# ON-STANDARD — bash prefix + quoted $HOME path
_add_hook_if_present 'Stop' '' 'bash "$HOME/.dev-os/scripts/hooks/foo.sh"' '...'
```

### Rule 4 — Explicit `bash` prefix (`MUST`)

Every hook command that invokes a `.sh` script MUST include the `bash` prefix. This is required because:
- The user's login shell may be zsh or fish — not bash
- Claude Code hook runners may use `sh` for command execution
- Hook scripts use `set -euo pipefail` and associative arrays, which require bash

```json
// OFF-STANDARD — relies on shebang dispatch
"command": "$(git rev-parse --show-toplevel)/scripts/hooks/foo.sh"

// ON-STANDARD — explicit bash invocation
"command": "bash \"$(git rev-parse --show-toplevel)/scripts/hooks/foo.sh\""
```

### Rule 5 — Hook scripts resolve their own root internally (`SHOULD`)

Hook scripts that source other files SHOULD resolve their own location via `BASH_SOURCE` or `DEVOS_DIR`, never via CWD.

```bash
# OFF-STANDARD — assumes CWD
source scripts/lib/runtime-state.sh

# ON-STANDARD — resolves from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/runtime-state.sh"

# ON-STANDARD — resolves from DEVOS_DIR
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/runtime-state.sh"
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `bash scripts/hooks/foo.sh` | CWD may not be repo root in hook context | `bash "$(git rev-parse --show-toplevel)/scripts/hooks/foo.sh"` |
| `/Users/john/projects/repo/scripts/hooks/foo.sh` | Hardcoded user path, breaks on other machines | `bash "$(git rev-parse --show-toplevel)/scripts/hooks/foo.sh"` |
| `$HOME/.dev-os/scripts/hooks/foo.sh` (no bash prefix) | Relies on shebang dispatch which may invoke sh | `bash "$HOME/.dev-os/scripts/hooks/foo.sh"` |
| Expanding `$HOME` to literal path at install time | Non-portable across users and machines | Keep `$HOME` literal in JSON; shell expands at runtime |
| `cd "$(git rev-parse --show-toplevel)" && bash scripts/hooks/foo.sh` | Unnecessary two-step; `cd` may fail silently | Single command with embedded path resolution |

## Deviation guidance

You MAY use a conditional guard pattern for hooks that depend on external tools:

```json
"command": "[ -x \"$HOME/.dev-os/scripts/hooks/foo.sh\" ] && bash \"$HOME/.dev-os/scripts/hooks/foo.sh\" || true"
```

This is permitted when the hook is optional and its absence should not block execution. MUST NOT use this pattern to suppress errors from hooks that are required.

## Compliance test

- [ ] Every `"command"` field in `.claude/settings.json` referencing `scripts/hooks/` or `.claude/hooks/` uses `$(git rev-parse --show-toplevel)` or `$HOME` — no bare relative paths?
- [ ] Every `"command"` field in `.codex/hooks.json` follows the same rule?
- [ ] Every hook command invoking a `.sh` file includes the `bash` prefix?
- [ ] `install.sh` hook registrations emit `bash "$HOME/..."` form, not bare paths?
- [ ] BATS test exists that rejects bare relative paths and hardcoded `/home/` paths in all hook config files?
- [ ] No hook command contains a literal `/Users/` or `/home/` path segment?

If any check fails: fix the path to use the correct resolution pattern, then re-run the BATS test (`bats tests/bats/hooks.bats`) to confirm.

## References

- [`git rev-parse --show-toplevel`](https://git-scm.com/docs/git-rev-parse) — Git-native absolute path resolution to repository root
- [POSIX Shell `$HOME`](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap08.html) — Portable home directory variable, expanded at runtime
- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) — Hook execution model and command field semantics
- Incident: 2026-05-06 — 5 hooks in `.claude/settings.json` and 5 in `.codex/hooks.json` used bare relative paths; all failed with "No such file or directory" when CWD diverged from repo root
