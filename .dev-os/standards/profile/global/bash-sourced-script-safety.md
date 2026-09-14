<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/bash-sourced-script-safety.md and re-run profile-sync. -->
<!-- source: profile:cli -->
# Bash Sourced Script Safety Standards

**Sibling standards:**
- [`shell-safety.md`](./shell-safety.md) — alias bypass + general `set -euo pipefail` rules (this standard extends those)
- [`file-discovery.md`](./file-discovery.md) — file/directory discovery rules (parallel alias-bypass coverage for `find`/`grep`)

## Overview

Bash scripts serve two distinct roles: **runnable executables** invoked from a terminal or hook, and **sourced libraries** loaded into a parent shell's namespace via `source` or `.`. The two roles have incompatible requirements. A script written as a runnable can corrupt the caller's shell when sourced; a library written for sourcing fails silently when run directly. This standard governs the authoring discipline that lets a script safely inhabit one or both roles without surprising its caller.

This matters because bugs in dual-mode scripts surface only at the wrong callsite — a helper tested with `bash script.sh` passes, then crashes the hook that sources it. The cost of each bug is a broken pre-commit hook, a failed session-start injection, or a killed caller shell. The rules below eliminate that class of bug.

## Scope

This standard covers authoring discipline for bash scripts that are sourced — including pure libraries and dual-mode scripts — under `scripts/`, `scripts/lib/`, `scripts/hooks/`, and `.claude/skills/*/scripts/`. It does NOT cover POSIX sh portability (this project targets bash 4.0+), zsh-specific scripting, Python/Node script authoring, or alias bypass (see [shell-safety.md](shell-safety.md)).

## Principles

1. **One role, one contract:** A script declares at the top whether it is runnable-only, sourced-only, or dual-mode. That contract drives every other decision in the file.
2. **The caller owns the shell:** A sourced library MUST NOT mutate the caller's shell strictness, exit codes, or namespace beyond the functions it intentionally exports.
3. **Fail at the right level:** A runnable script exits on error. A sourced library returns a code. Using `exit` inside a sourced function kills the caller — that is a bug, never a feature.

## Rules

### Rule 1 — Declare the role with a contract comment

Every bash file MUST start with a one-line contract comment naming its role.

```bash
#!/usr/bin/env bash
# role: runnable
# ...

#!/usr/bin/env bash
# role: dual-mode (runnable + sourceable)
# ...

# role: library (sourced only — no shebang)
# ...
```

Role values: `runnable`, `library`, `dual-mode`. Readers, linters, and this standard's compliance check all key off this line.

### Rule 2 — Shebang by role

| Role | Shebang | Rationale |
|---|---|---|
| `runnable` | `#!/usr/bin/env bash` | Required for direct execution. |
| `dual-mode` | `#!/usr/bin/env bash` | Required for direct execution; sourcing ignores the shebang. |
| `library` | NO shebang; add `# shellcheck shell=bash` instead | Libraries are not executed. A shebang misleads readers and tooling. |

### Rule 3 — `set` flags by role

| Role | Top-level `set` | Rationale |
|---|---|---|
| `runnable` | `set -euo pipefail` (SHOULD) | Caller wants strict-mode failures to surface. |
| `dual-mode` | `set -euo pipefail` (SHOULD, with guard rules 5 + 6) | Same reason as runnable; dual-mode is invoked both ways. |
| `library` | NONE (MUST NOT) | The caller owns shell strictness. Top-level `set -e` in a sourced file kills the caller's shell on first non-zero. |

Libraries that need local strictness MUST scope it inside functions:

```bash
my_strict_fn() {
  local old_opts
  old_opts="$(set +o)"
  set -euo pipefail
  # ... work ...
  eval "$old_opts"
}
```

### Rule 4 — `exit` versus `return`

- **Runnable / dual-mode (outside the guarded direct-invocation block):** MAY call `exit N`.
- **Library functions AND dual-mode functions called when sourced:** MUST use `return N`. Never `exit`.

`exit` inside a sourced function terminates the caller's shell. This is the single most common dual-mode bug.

```bash
# OFF-STANDARD — kills the caller shell when sourced
my_lib_fn() {
  [[ -z "$1" ]] && exit 1
}

# ON-STANDARD — returns an error code
my_lib_fn() {
  [[ -z "$1" ]] && return 1
}
```

### Rule 5 — Guard the direct-invocation block (dual-mode only)

Dual-mode scripts that have code to run when invoked directly MUST guard it with the `BASH_SOURCE` sentinel. Under `set -u`, `BASH_SOURCE[0]` is unset when the file is sourced into certain contexts — the default expansion is required.

```bash
# OFF-STANDARD — breaks under `set -u` when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  my_fn "$@"
fi

# ON-STANDARD — default expansion survives set -u
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  my_fn "$@"
fi
```

The `:-` default expansion is MANDATORY. A grep for `${BASH_SOURCE[0]}` without `:-` in any dual-mode file is a hard fail.

### Rule 6 — Double-source guard for libraries

Libraries that declare `readonly` constants or register traps MUST guard against being sourced twice. Bash has no module system; `source file.sh` runs the top level again every time.

```bash
# library: my_lib.sh

[[ -n "${__MY_LIB_SOURCED:-}" ]] && return 0
readonly __MY_LIB_SOURCED=1

readonly MY_LIB_VERSION="1.0.0"
# ... function definitions ...
```

The guard variable MUST use an underscore-prefixed, library-scoped name (`__<LIBNAME>_SOURCED`) to avoid colliding across libraries.

### Rule 7 — Variable scoping

- Every function-scoped variable MUST be declared `local`. Bash variables default to global; unscoped vars pollute the caller's namespace and create subtle action-at-a-distance bugs.
- `readonly` at top level is permitted ONLY in runnable scripts (run once per process). Libraries that define `readonly` MUST wrap them inside the Rule 6 double-source guard — re-sourcing a file that re-declares a `readonly` var raises an error.
- `export` is permitted when the library intentionally passes values to child processes, and MUST be documented with a comment naming the consumer.

```bash
# OFF-STANDARD — pollutes caller
my_fn() {
  tmp_file="$(mktemp)"
  # ...
}

# ON-STANDARD — scoped to function
my_fn() {
  local tmp_file
  tmp_file="$(mktemp)"
  # ...
}
```

### Rule 8 — `$0` versus `${BASH_SOURCE[0]}`

- Use `${BASH_SOURCE[0]:-}` to refer to the current script's path — in libraries, dual-mode scripts, and anywhere the file might be sourced. `$0` returns the caller's name when sourced, not the file being sourced.
- `$0` is permitted ONLY inside the Rule 5 direct-invocation block, where the script is being executed directly.

```bash
# OFF-STANDARD — when sourced, $0 is "bash" or the parent script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ON-STANDARD — works in both modes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
```

### Rule 9 — Testing contract

Every dual-mode script MUST have at least two tests:

1. One test that invokes it directly: `bash script.sh <args>` (or invokes the binary via PATH).
2. One test that sources it and calls a public function: `source script.sh; my_fn <args>`.

Libraries MUST have a sourcing test that verifies the file can be sourced a second time without error (double-source guard check).

Tests live under `tests/bats/` with the same subdirectory structure as the script.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `set -e` at top of a library | Kills caller shell on first non-zero | Scope `set` inside functions |
| `exit 1` inside a sourced function | Terminates caller's entire shell | `return 1` |
| `${BASH_SOURCE[0]}` without `:-` guard | Raises "parameter not set" under `set -u` when sourced into some contexts | `${BASH_SOURCE[0]:-}` |
| `readonly FOO=` at library top without double-source guard | Re-sourcing fails with "readonly variable" | Rule 6 `__<LIB>_SOURCED` guard |
| `SCRIPT_DIR=$(dirname "$0")` in a library | Resolves to the caller, not the library | `dirname "${BASH_SOURCE[0]:-.}"` |
| Undeclared function-local variables | Leaks into caller's shell | `local var` at start of function |
| Shebang on a sourced-only library | Misleads readers; tooling treats it as runnable | `# shellcheck shell=bash` directive instead |

## Deviation guidance

You MAY deviate from these rules when:

- Writing a throwaway one-off script in `/tmp` for manual debugging. The rules target committed scripts only.
- Authoring a script for an external environment (e.g. a CI container) where the target bash version is known and the constraint above doesn't apply. MUST document the environment assumption in the contract comment.

When you deviate in a committed script: add a comment above the deviation naming which rule and why. A deviating script without a justification comment fails audit.

## Profile inheritance notes

Extends: [shell-safety.md](shell-safety.md)
Adds: Role declaration, dual-mode guards, library sourcing rules, `exit`-vs-`return` contract, `BASH_SOURCE` discipline.
Overrides: Nothing from shell-safety.md.

## Compliance test

- [ ] Every committed bash file starts with a `# role: <runnable|library|dual-mode>` comment?
- [ ] No library file (`role: library`) has a shebang line?
- [ ] No library file has `set -e`, `set -u`, or `set -o pipefail` at top level?
- [ ] No library or sourced-function call uses `exit` (only `return`)?
- [ ] Every `${BASH_SOURCE[0]}` reference uses the `:-` default expansion under `set -u`?
- [ ] Every dual-mode script guards its direct-invocation block with `[[ "${BASH_SOURCE[0]:-}" == "${0}" ]]`?
- [ ] Every library that declares `readonly` has a `__<LIB>_SOURCED` double-source guard?
- [ ] Every function-scoped variable uses `local`?
- [ ] Every dual-mode script has both a direct-invocation test AND a sourcing test in `tests/bats/`?

If any check fails: fix it, or add an inline deviation comment naming the rule and justifying the exception.

## Enforcement

A pre-commit hook SHOULD scan staged `*.sh` files:

```bash
# Fail if unguarded BASH_SOURCE[0] appears anywhere
command grep -rn '\${BASH_SOURCE\[0\]}' --include='*.sh' | command grep -v ':-' && exit 1

# Fail if a file declaring `role: library` contains `set -e` or `exit N` at top level
# (implementation: scripts/hooks/pre-commit-bash-safety.sh — future work)
```

## References

- [bash(1) manpage — BASH_SOURCE](https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html) — defines BASH_SOURCE array and its behavior under sourcing.
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — shebang discipline, function-local variables, `${var:-}` default expansion.
- [BashFAQ/105 — errexit](https://mywiki.wooledge.org/BashFAQ/105) — why `set -e` is unsafe in library contexts.
- [ShellCheck SC2317, SC2034, SC2154](https://www.shellcheck.net/wiki/) — unreachable code, unused vars, unset vars under `set -u`.
- [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) — MUST / SHOULD / MAY normative vocabulary used throughout this standard.
- Real bug in this repo: `.claude/skills/caveman/scripts/compress.sh` — `${BASH_SOURCE[0]}` without `:-` guard caused `parameter not set` when sourced. Fixed in commit following `7b8f7717`.
