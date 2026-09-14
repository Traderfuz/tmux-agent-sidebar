<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/devos-lib-sourcing.md and re-run profile-sync. -->
# DevOS Library Sourcing Standards

## Overview

DevOS shell libraries in `scripts/lib/` use `BASH_SOURCE[0]` for self-location and declare explicit inter-library dependencies. Sourcing them incorrectly — from the wrong shell, wrong CWD, or without dependencies — causes cascading failures. This standard defines the canonical pattern agents and scripts must follow when invoking DevOS libraries.

## Scope

This standard covers how to source `scripts/lib/*.sh` files from Bash tool calls, shell scripts, and agent-executed commands. It does NOT cover how libraries internally source each other (that is the library author's responsibility), nor does it cover BATS test setup (see `testing/` standards).

## Principles

1. **Shell identity is explicit:** DevOS libraries are bash scripts. Never source them from a zsh context — always invoke via `bash -c`.
2. **Absolute paths eliminate CWD ambiguity:** All source calls use `$DEVOS_DIR`-anchored absolute paths. Relative paths break when CWD is not the repo root.
3. **Discover before you call:** Never guess function names. After sourcing, run `declare -F` to enumerate what is available.
4. **Dependency order is mandatory:** Libraries that depend on others must source those dependencies first, in the documented order.

## Rules

### Rule 1: Always invoke via `bash -c`, never from zsh

The Bash tool runs in zsh by default on this machine. `BASH_SOURCE[0]` is a bash-only variable — it is unset in zsh, causing `profile-resolver.sh` line 6 to fail immediately.

```bash
# OFF-STANDARD — sourced from zsh context (Bash tool default)
source "${HOME}/.dev-os/scripts/lib/profile-resolver.sh"
# Error: BASH_SOURCE[0]: parameter not set

# ON-STANDARD — explicit bash subshell
bash -c "
  DEVOS_DIR='${HOME}/.dev-os'
  source \"\${DEVOS_DIR}/scripts/lib/logger.sh\"
  source \"\${DEVOS_DIR}/scripts/lib/profile-resolver.sh\"
  # ... call functions here
"
```

### Rule 2: Set `DEVOS_DIR` before any source call

`profile-resolver.sh` uses `DEVOS_DIR` to locate profiles. Without it, the variable falls back to `$HOME/.dev-os` (correct on this machine), but setting it explicitly makes the intent clear and safe across contexts.

```bash
# OFF-STANDARD — relying on fallback
bash -c "source ~/.dev-os/scripts/lib/profile-resolver.sh"

# ON-STANDARD — DEVOS_DIR set explicitly
bash -c "
  DEVOS_DIR='\$HOME/.dev-os'
  source \"\${DEVOS_DIR}/scripts/lib/profile-resolver.sh\"
"
```

### Rule 3: Source dependencies in order before the target library

`profile-resolver.sh` requires three dependencies. They must be sourced in this order before the resolver itself:

```bash
# ON-STANDARD — correct dependency order
bash -c "
  DEVOS_DIR='\${HOME}/.dev-os'
  LIB=\"\${DEVOS_DIR}/scripts/lib\"
  source \"\${LIB}/logger.sh\"
  source \"\${LIB}/wildcard-matcher.sh\"
  source \"\${LIB}/circular-detector.sh\"
  source \"\${LIB}/profile-resolver.sh\"
  # now call resolver functions
  get_inheritance_chain 'webapp'
"
```

Dependency map for common libraries:

| Library | Depends on (source in this order first) |
|---|---|
| `profile-resolver.sh` | `logger.sh`, `wildcard-matcher.sh`, `circular-detector.sh` |
| `template-processor.sh` | `logger.sh`, `include-resolver.sh`, `workflow-resolver.sh` |
| `agent-coordinator.sh` | `logger.sh` |
| `cache.sh` | `logger.sh` |
| `auto.sh` | `logger.sh`, `task-queue.sh`, `git-workflow.sh`, `agent-coordinator.sh`, `recovery.sh` |
| `recovery.sh` | `logger.sh`, `cache.sh` |

### Rule 4: Discover available functions with `declare -F` — never guess

After sourcing, run `declare -F` to see what functions are available. Do not assume a function exists based on its intuitive name.

```bash
# OFF-STANDARD — guessing a function name
bash -c "
  source \"\${DEVOS_DIR}/scripts/lib/profile-resolver.sh\"
  activate_profile 'webapp'   # Does not exist — will fail with 'command not found'
"

# ON-STANDARD — discover first
bash -c "
  DEVOS_DIR='\${HOME}/.dev-os'
  LIB=\"\${DEVOS_DIR}/scripts/lib\"
  source \"\${LIB}/logger.sh\"
  source \"\${LIB}/wildcard-matcher.sh\"
  source \"\${LIB}/circular-detector.sh\"
  source \"\${LIB}/profile-resolver.sh\"
  declare -F | awk '{print \$3}' | sort
"
```

**Available functions in `profile-resolver.sh`** — regenerate from source (never rely on a dated snapshot):

```bash
bash -c "source \"${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/profile-resolver.sh\" \
  && declare -F | awk '{print \$3}' | sort"
```

`activate_profile` does **not** exist. Profile activation (refreshing standards/workflows/agents) is handled by the `start` command script, not by `profile-resolver.sh`.

### Rule 5: Use `export -f` only in bash, never in scripts targeting zsh

`export -f function_name` is bash-only. If a script needs to export functions, it must run under `#!/usr/bin/env bash` and confirm `BASH_VERSION` is 4.0+. Never call `export -f` in a zsh-compatible script.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `source profile-resolver.sh` from Bash tool | Runs in zsh; `BASH_SOURCE[0]` is unset → immediate exit | `bash -c "source ..."` |
| `source "$DEVOS_DIR/scripts/lib/profile-resolver.sh"` without deps | `logger.sh` etc. not loaded → undefined functions | Source `logger.sh`, `wildcard-matcher.sh`, `circular-detector.sh` first |
| Calling `activate_profile` | Function does not exist in any lib | Use `start` command or call `get_inheritance_chain` + manual refresh |
| Sourcing from `~/projects/<project>/` CWD | Relative dep lookups resolve to wrong dir | Always use `$DEVOS_DIR`-absolute paths |
| `export -f func` in a mixed bash/zsh script | bash-only syntax; crashes in zsh | Remove `export -f`; call function directly in the bash subshell |

## Canonical sourcing template

Copy this template when you need to invoke any DevOS library from a Bash tool call or shell script:

```bash
bash -c "
  set -euo pipefail
  DEVOS_DIR='\${HOME}/.dev-os'
  LIB=\"\${DEVOS_DIR}/scripts/lib\"

  # Source dependencies in order, then the target library
  source \"\${LIB}/logger.sh\"
  source \"\${LIB}/wildcard-matcher.sh\"
  source \"\${LIB}/circular-detector.sh\"
  source \"\${LIB}/profile-resolver.sh\"

  # Verify available functions before calling
  # declare -F | awk '{print \$3}' | sort

  # Call the actual function
  get_inheritance_chain 'webapp'
"
```

## Deviation guidance

You MAY omit dependency libraries if you have verified via `declare -F` that the target library sources them internally AND your invocation context guarantees they are already loaded. When doing so, add a comment: `# deps pre-loaded by <library>`.

## Compliance test

- [ ] All DevOS lib source calls are wrapped in `bash -c "..."`, not run bare from the Bash tool?
- [ ] `DEVOS_DIR` is set explicitly before any source call?
- [ ] Dependencies are sourced in the documented order before the target library?
- [ ] No function names are assumed — `declare -F` is used to verify availability when uncertain?
- [ ] `activate_profile` does not appear in any agent or script (it does not exist)?
- [ ] `export -f` is absent from any script that may run under zsh?

If any check fails: fix the source invocation using the canonical template above.

## References

- `BASH_SOURCE[0]` — [Bash Reference Manual: Special Parameters](https://www.gnu.org/software/bash/manual/bash.html#index-BASH_005fSOURCE) — explains why this variable is bash-only
- `scripts/lib/profile-resolver.sh:6` — the exact line that fails when sourced from zsh
- `profiles/general/standards/maintenance/bx-tool-routing.md` — when to delegate to bx-* tools vs inline scripting
