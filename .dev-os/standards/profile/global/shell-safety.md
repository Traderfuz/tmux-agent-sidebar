<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/shell-safety.md and re-run profile-sync. -->
# Shell Safety Standards

## Overview

This machine aliases common POSIX commands to interactive variants that block silently in non-interactive contexts. Any Bash tool call or generated script that uses `rm`, `cp`, or `mv` without a bypass prefix will hang indefinitely waiting for input that never arrives. This standard governs safe command invocation, script shebang discipline, and pipefail pairing for every shell script, Bash tool call, and BATS test produced by DevOS — across all profiles that inherit from `general`.

**Sibling standards:**
- [`bash-sourced-script-safety.md`](./bash-sourced-script-safety.md) — sourced-library invocation discipline (extends this standard)
- [`file-discovery.md`](./file-discovery.md) — file/directory discovery rules (extends this standard's alias-bypass requirement)
- [`runtime-standards.md`](./runtime-standards.md) — runtime context in which these shell scripts execute
- [`security.md`](./security.md) — shell injection prevention rules that depend on the alias-bypass rules in this standard
- [`awk-portability.md`](./awk-portability.md) — GNU awk vs BSD awk cross-platform patterns (all scripts using `awk` invocations)

## Scope

This standard covers safe command invocation, shebang selection, `set` flag usage, function export restrictions, output-parsing hygiene, and working-directory discipline for shell scripts and Bash tool calls. It does NOT cover application-level error handling in Python or TypeScript (see `error-handling.md`), nor CI/CD platform-specific shell configuration.

## Principles

1. **Alias-aware by default:** Every script and Bash tool call assumes aliases are active. Bypass them explicitly — never rely on the hope that the shell loaded without aliases.
2. **Fail visibly, not silently:** `set -euo pipefail` ensures failures surface immediately rather than propagating as garbage data through subsequent commands.
3. **Shell portability:** Scripts must run correctly in both bash (Bash tool) and zsh (user shell) without modification. Write to the intersection, not the superset.

## Rules

### Rule 1 — Interactive alias bypass

The aliases `rm -iv`, `cp -iv`, and `mv -iv` prompt for confirmation on every operation. The Bash tool has no interactive stdin, so the prompt blocks permanently.

**MUST** prefix `rm`, `cp`, `mv`, `mkdir`, `grep`, `ls`, `find`, and `ps` with `command` (or use the absolute path `/usr/bin/<name>`) in all scripts and Bash tool calls.

**Aliased command reference — always use safe form:**

| Command | Alias expands to | Safe form |
|---|---|---|
| `rm` | `rm -iv` (interactive — **BLOCKS** waiting for input) | `command rm` or `/usr/bin/rm` |
| `cp` | `cp -iv` (interactive — **BLOCKS** waiting for input) | `command cp` or `/usr/bin/cp` |
| `mv` | `mv -iv` (interactive — **BLOCKS** waiting for input) | `command mv` or `/usr/bin/mv` |
| `mkdir` | `mkdir -pv` | `command mkdir` |
| `grep` | `grep --color=auto` (breaks pipe output parsing) | `command grep` |
| `ls` | with color/flags | `command ls` |
| `find` | may be shadowed by `fd` | `command find` |
| `ps` | `ps aux` | `command ps` |

```bash
# OFF-STANDARD: will block — rm alias (-iv) waits for user confirmation
rm -rf dist/

# ON-STANDARD: bypasses alias, executes immediately
command rm -rf dist/
```

### Rule 2 — Script shebang

The path `/bin/bash` does not exist on macOS (Homebrew installs bash to a different prefix). Scripts using `#!/bin/bash` fail silently on macOS with "command not found" rather than a useful error.

**MUST** use `#!/usr/bin/env bash` in all generated shell scripts.

```bash
# OFF-STANDARD: path varies between Linux and macOS
#!/bin/bash

# ON-STANDARD: resolves bash from PATH regardless of install location
#!/usr/bin/env bash
```

### Rule 3 — Pipefail pairing

`set -e` exits on command failure but silently ignores failures in pipelines. A failing left-hand command in a pipe propagates its output as an empty or partial string to the next command. `set -o pipefail` makes the entire pipeline fail when any component fails.

**MUST** use `set -euo pipefail` together. **MUST NOT** use `set -e` alone in scripts with pipes.

```bash
# OFF-STANDARD: pipe failure swallowed — script continues with empty output
set -e
some-command | other-command

# ON-STANDARD: any failure in the pipeline exits immediately
set -euo pipefail
some-command | other-command
```

### Rule 4 — Function export restriction

`export -f function_name` is a bash-only extension. When a script is sourced in a zsh context (e.g., by DevOS hooks), `export -f` silently fails — the function is not exported and any subshell call to it returns "command not found".

**MUST NOT** use `export -f` in any script that will be sourced in cross-shell contexts. Source the file directly instead.

```bash
# OFF-STANDARD: bash-only, silently fails when sourced in zsh
export -f my_helper

# ON-STANDARD: source the file wherever the function is needed
source "$SCRIPT_DIR/helpers.sh"
```

### Rule 5 — Grep output parsing

The `grep --color=auto` alias injects ANSI escape codes into output. When `grep` output is captured in a variable or piped to another command, those escape codes corrupt the result — `grep -c` returns a color-wrapped number, not a plain integer.

**MUST** use `command grep` whenever grep output is captured in a variable or used in a conditional.

```bash
# OFF-STANDARD: color codes corrupt the count — result is "\e[01;31m3\e[0m" not "3"
count=$(grep -c "pattern" file.txt)

# ON-STANDARD: plain output, safe to use in arithmetic or conditionals
count=$(command grep -c "pattern" file.txt)
```

### Rule 6 — Zsh alias requirement

The Bash tool runs bash, not zsh. Zsh aliases and functions (`doppler-load`, `ll`, `g`, `fm`, etc.) are not available in bash subshells unless explicitly loaded. Scripts that assume these aliases silently fall back to the underlying command or fail with "command not found".

**MUST** use `zsh -ic '<command>'` when the command depends on zsh aliases or functions loaded from `~/.zshrc`.

```bash
# OFF-STANDARD: doppler-load is a zsh alias — not available in bash subshell
doppler-load && bun run dev

# ON-STANDARD: explicitly runs in interactive zsh where aliases are active
zsh -ic 'doppler-load && bun run dev'
```

### Rule 8 — Skill invocation blocks that source DevOS libraries

Claude Code's Bash tool runs in the user's default shell (typically zsh on macOS). DevOS libraries (`scripts/lib/*.sh`) source `logger.sh` on load, which contains a Bash 4.0+ version guard. When invoked from zsh, `BASH_VERSINFO` is unset, evaluates to 0, and the guard exits with an error — silently failing the entire invocation.

**MUST** use `bash -c '...'` (not bare `source`) in any skill invocation block that sources a `scripts/lib/*.sh` file.

`#!/usr/bin/env bash` in a markdown code block is documentation only — it has no effect when Claude Code copies the block into a Bash tool call. `bash -c` is the only enforcement mechanism.

```bash
# OFF-STANDARD: fails when Claude Code's shell is zsh, AND fails in any project
# that isn't the dev-os repo itself (scripts/lib/capture.sh doesn't exist there).
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
source "$PROJECT_ROOT/scripts/lib/capture.sh"
capture_write "my idea"

# ON-STANDARD: spawn bash explicitly AND resolve the library via a fallback chain
# (project → $DEVOS_DIR → ~/.dev-os). DevOS framework libraries live in the dev-os
# repo and are exposed to every project via the ~/.dev-os install symlink. Skill
# invocation blocks MUST use this resolver so they work in any project.
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LIB=""
for candidate in \
  "$PROJECT_ROOT/scripts/lib/capture.sh" \
  "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/capture.sh" \
  "$HOME/.dev-os/scripts/lib/capture.sh"; do
  if [[ -f "$candidate" ]]; then LIB="$candidate"; break; fi
done
[[ -z "$LIB" ]] && { echo "[capture] ✗ scripts/lib/capture.sh not found in project or ~/.dev-os"; exit 1; }
bash -c "source '$LIB' && capture_write 'my idea'"
```

This rule applies to every skill that documents library usage in an invocation block — not just at authoring time, but as a gap-analysis check during upgrades (`bx-skill-creator`) and creation (`bx-skill-creator`).

### Rule 7 — Absolute paths

The Bash tool's CWD does not update automatically when directories are renamed or moved mid-session. Relative paths that worked at the start of a session silently break after any directory operation.

**SHOULD** prefer absolute paths (`/home/tafadzwa/projects/...`) in scripts and Bash tool calls. **MUST** run `pwd` to verify CWD before constructing any relative path.

```bash
# OFF-STANDARD: breaks if CWD changes mid-session
cd ../other-dir && ./build.sh

# ON-STANDARD: always resolves correctly regardless of CWD
/home/tafadzwa/projects/my-project/scripts/build.sh
```

### Rule 9 — Rule 6 / Rule 8 conflict resolution

Rule 6 requires `zsh -ic` to access interactive zsh aliases. Rule 8 requires `bash -c` to source DevOS libraries. When an invocation needs both — a command only available via a zsh alias AND a DevOS lib function — the two rules conflict.

**Resolution: prefer `bash -c` with explicit alias bypass over `zsh -ic`.**

Any command that is only accessible as a zsh alias MUST be replaced with its absolute-path equivalent before being used alongside DevOS lib sourcing. An alias that cannot be expressed as an absolute path is not suitable for use in a script or skill invocation block.

```bash
# CONFLICT SCENARIO — needs a zsh alias AND a DevOS lib function
# Wrong: mix zsh -ic with DevOS lib (subshell kills lib context)
zsh -ic "source '$LIB' && my_zsh_alias arg"   # lib functions unavailable in zsh -ic subshell

# Wrong: wrap both in bash -c but use zsh alias name
bash -c "source '$LIB' && my_zsh_alias arg"    # alias not defined in bash

# CORRECT: resolve the alias to its real command, use bash -c
bash -c "source '$LIB' && /usr/local/bin/actual-command arg"

# If the real command is unknown, find it first (outside the skill invocation):
which_result=$(zsh -ic "which my_zsh_alias" 2>/dev/null)
bash -c "source '$LIB' && '$which_result' arg"
```

**MUST NOT** use `zsh -ic` in any invocation block that also sources a `scripts/lib/*.sh` file.

**MUST** document in a comment why `bash -c` is used instead of `zsh -ic` whenever this resolution is applied, so future maintainers understand the alias was intentionally bypassed.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `rm -rf dist/` without `command` prefix | `rm -iv` alias blocks silently waiting for input | `command rm -rf dist/` |
| `#!/bin/bash` shebang | Path mismatch on macOS — bash installed elsewhere | `#!/usr/bin/env bash` |
| `set -e` without `pipefail` | Pipe failures silently ignored; bad data propagates downstream | `set -euo pipefail` |
| `export -f helper_fn` in cross-shell scripts | bash-only feature; silently fails when sourced in zsh | `source "$SCRIPT_DIR/helpers.sh"` |
| Bare `grep` in output capturing | `--color=auto` alias injects ANSI codes that corrupt variable content | `command grep` |
| `cd subdir && ./script.sh` with relative paths | CWD becomes stale after directory operations; path resolves wrong | Use absolute path directly |

## Deviation guidance

**MAY** omit `set -euo pipefail` in short interactive scripts that meet all three conditions: fewer than 10 lines, no pipes, and intended to run only interactively in the user's shell (never called by DevOS hooks or CI). **MUST** include `set -euo pipefail` in all CI scripts, BATS tests, scripts called by DevOS hooks, and any script longer than 10 lines.

**MAY** use a relative path when the calling context guarantees a fixed CWD (e.g., inside a `Makefile` target where `CURDIR` is explicit). **MUST** document the CWD assumption in a comment on the same line.

## Profile inheritance notes

This standard lives in the `general` profile and is inherited by all child profiles: `webapp`, `pwa`, `cli`, `business`, `boxi-ops`, `cloudflare-workers`, `installable-os`, and `skills`. Child profiles do not need to restate these rules. Override only when a child profile's shell environment genuinely differs (e.g., a fully container-native profile where no user shell aliases are active).

## Compliance test

- [ ] All `rm`, `cp`, and `mv` calls in scripts and Bash tool calls use `command <name>` or `/usr/bin/<name>`?
- [ ] All generated scripts use `#!/usr/bin/env bash` (not `#!/bin/bash`)?
- [ ] All scripts with pipes use `set -euo pipefail` (not `set -e` alone)?
- [ ] No `export -f` appears in scripts intended for cross-shell or sourced contexts?
- [ ] All `grep` calls whose output is captured in a variable use `command grep`?
- [ ] All skill invocation blocks that source `scripts/lib/*.sh` use `bash -c "source '...' && ..."` (not bare `source`)?
- [ ] No invocation block uses `zsh -ic` alongside `source scripts/lib/*.sh` (Rule 9: if both are needed, use `bash -c` + absolute-path command, not `zsh -ic`)?

If any check fails: apply the safe form immediately. If deviation is intentional (e.g., a short interactive script without pipefail), record the justification in an inline comment on the line that deviates.

## References

- [GNU Bash Manual — Aliases](https://www.gnu.org/software/bash/manual/bash.html#Aliases) — how aliases are expanded and when `command` bypasses them
- [POSIX `set -e` specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#set) — defined behavior for errexit and its interaction with pipelines
- [ShellCheck SC2039](https://www.shellcheck.net/wiki/SC2039) — `export -f` portability warning
- [BATS documentation — sourcing libraries](https://bats-core.readthedocs.io/en/stable/writing-tests.html) — `$BATS_TEST_DIRNAME` relative path convention for test file sourcing
