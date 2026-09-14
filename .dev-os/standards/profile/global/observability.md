<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/global/observability.md and re-run profile-sync. -->
# CLI Observability Standards

Extends: [../../../general/standards/global/observability.md](../../../general/standards/global/observability.md)

## Overview

CLI tools communicate through two channels — stdout for program output and stderr for diagnostics — with exit codes as the only structured status signal. Unlike web applications where logs flow to aggregators, CLI telemetry must serve two audiences simultaneously: the human at the terminal who needs readable feedback, and the machine parsing output in pipelines or CI. This standard defines the logging, exit code, and timing conventions that make CLI tools observable in both contexts, using DevOS's `scripts/lib/logger.sh` as the canonical logging implementation.

## Scope

This standard covers structured logging via `logger.sh`, exit code semantics, command duration timing, session ID correlation, stderr/stdout channel discipline, and log file rotation for CLI tools and Bash projects. It does NOT cover interactive TUI rendering (prompts, spinners, progress bars), terminal color configuration, or shell completion scripts.

---

## Principles

1. **Stdout is for output, stderr is for diagnostics:** A CLI tool that mixes program output and log messages on stdout breaks every pipeline downstream. `log_info`, `log_warn`, `log_error` write to stderr. Only the tool's actual output (data, results, formatted reports) goes to stdout.

2. **Exit codes are contracts:** Exit code 0 means success. Exit code 1 means operational error. Exit code 2 means usage error (wrong arguments). Any other mapping must be documented. A tool that exits 0 on failure or exits 1 on bad arguments violates the pipeline contract and produces silent CI failures.

3. **Session context without runtime dependencies:** CLI observability must work with Bash 4.0+ and zero external dependencies. No Node.js, no Python, no compiled binaries. `logger.sh` and `date` are the entire toolkit.

---

## Rules

### 1. Use scripts/lib/logger.sh exclusively

- **All CLI tools MUST use `logger.sh` functions** for diagnostic output: `log_info`, `log_warn`, `log_error`, `log_debug` (`MUST`)
- **`echo` and `printf` MUST NOT be used for diagnostic messages** — only for program output to stdout (`MUST NOT`)
- **`logger.sh` MUST be sourced at the top of every script** after `set -euo pipefail` (`MUST`)

```bash
# OFF-STANDARD — echo for diagnostics, mixed with output
#!/usr/bin/env bash
echo "Starting backup..."
tar czf backup.tar.gz ./data
echo "Backup complete!"
echo "Error: something failed" >&2

# ON-STANDARD — logger.sh for diagnostics, echo for output
#!/usr/bin/env bash
set -euo pipefail
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/logger.sh"

SESSION_ID="backup-$(date +%s)-$$"
log_info "Starting backup" "$SESSION_ID"

if tar czf backup.tar.gz ./data 2>/dev/null; then
  log_info "Backup complete: backup.tar.gz" "$SESSION_ID"
  echo "backup.tar.gz"  # stdout: actual output for pipeline consumers
else
  log_error "Backup failed" "$SESSION_ID"
  exit 1
fi
```

---

### 2. Session ID generation

- **Every CLI entry point MUST generate a session ID** at startup (`MUST`)
- **Session IDs MUST follow the format:** `[command]-[epoch]-[pid]` (e.g., `deploy-1710000000-12345`) (`MUST`)
- **The session ID MUST be passed to all `log_*` calls** within that invocation (`MUST`)
- **Subcommands invoked by the entry point SHOULD inherit the parent session ID** via environment variable `DEVOS_SESSION_ID` (`SHOULD`)

```bash
# ON-STANDARD — session ID at entry point
#!/usr/bin/env bash
set -euo pipefail
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/logger.sh"

readonly SESSION_ID="${DEVOS_SESSION_ID:-"$(basename "$0")-$(date +%s)-$$"}"
export DEVOS_SESSION_ID="$SESSION_ID"

log_info "Session started" "$SESSION_ID"
# ... all subsequent log calls include $SESSION_ID
log_info "Session completed" "$SESSION_ID"
```

---

### 3. Exit code mapping

- **Exit code semantics MUST follow this contract** (`MUST`):

| Exit code | Meaning | Logger level |
|---|---|---|
| `0` | Success | `log_info` (completion message) |
| `1` | Operational error (runtime failure) | `log_error` |
| `2` | Usage error (bad arguments, missing required flags) | `log_error` + usage hint |
| `3-125` | Available for tool-specific error codes | `log_error` with code documentation |
| `126` | Command found but not executable | (system — do not use) |
| `127` | Command not found | (system — do not use) |
| `128+n` | Killed by signal `n` | (system — do not use) |

- **A tool MUST NOT exit 0 when an error occurred** (`MUST NOT`)
- **Usage errors (bad flags, missing args) MUST exit 2**, not 1 (`MUST`)

```bash
# OFF-STANDARD — exit 0 on failure, exit 1 on bad args
if [[ -z "$1" ]]; then
  echo "Missing argument"
  exit 1  # wrong: this is a usage error, not operational
fi

# ON-STANDARD — correct exit code mapping
if [[ -z "$1" ]]; then
  log_error "Missing required argument: <target>" "$SESSION_ID"
  echo "Usage: $(basename "$0") <target> [--force]" >&2
  exit 2  # usage error
fi

if ! deploy "$1"; then
  log_error "Deployment failed for target: $1" "$SESSION_ID"
  exit 1  # operational error
fi
```

---

### 4. Command duration timing

- **Every CLI command MUST log total execution duration** at completion (`MUST`)
- **Long operations (>5 seconds) MUST log intermediate progress** at `info` level (`MUST`)
- **Duration MUST be computed using `$SECONDS` or `date +%s` delta** — not external tools (`MUST`)

```bash
# ON-STANDARD — duration timing with SECONDS
#!/usr/bin/env bash
set -euo pipefail
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/logger.sh"

readonly SESSION_ID="build-$(date +%s)-$$"
SECONDS=0

log_info "Build started" "$SESSION_ID"

# ... build steps ...

log_info "Build completed in ${SECONDS}s" "$SESSION_ID"
```

---

### 5. Stdout / stderr channel discipline

- **Program output (data, results, paths, IDs) MUST go to stdout** (`MUST`)
- **Diagnostic output (progress, warnings, errors, debug) MUST go to stderr** (`MUST`)
- **`logger.sh` functions already write to stderr** — do not redirect their output to stdout (`MUST NOT`)
- **When `--quiet` / `-q` flag is supported, it MUST suppress `info` and `debug` on stderr** but not errors or warnings (`MUST`)

```bash
# OFF-STANDARD — diagnostic output on stdout breaks pipes
find_matching_files() {
  echo "Searching for pattern: $1"  # diagnostic on stdout — breaks pipeline
  command find . -name "$1" -type f
}
# Usage: find_matching_files "*.md" | wc -l → wrong count (includes diagnostic line)

# ON-STANDARD — diagnostics on stderr, output on stdout
find_matching_files() {
  log_debug "Searching for pattern: $1" "$SESSION_ID"  # stderr via logger.sh
  command find . -name "$1" -type f  # stdout: actual file list
}
# Usage: find_matching_files "*.md" | wc -l → correct count
```

---

### 6. Log file output

- **When `LOG_FILE` environment variable is set, `logger.sh` MUST also write to that file** (`MUST`)
- **Log file entries MUST be machine-parseable** — timestamp, level, session ID, message on each line (`MUST`)
- **Log rotation SHOULD be handled externally** (logrotate) — the CLI tool MUST NOT implement its own rotation logic (`SHOULD`)
- **Log file path MUST be an absolute path** (`MUST`)

```bash
# ON-STANDARD — enabling file logging
export LOG_FILE="/var/log/devos/deploy.log"
export DEVOS_SESSION_ID="deploy-$(date +%s)-$$"

# logger.sh checks LOG_FILE and tee's output to file automatically
log_info "Deployment started" "$DEVOS_SESSION_ID"
```

---

### 7. BATS test observability

- **BATS test names MUST describe observable behavior**, not mechanism (`MUST`)
- **Test setup/teardown SHOULD log test name and fixture state** at `debug` level (`SHOULD`)
- **Failed assertions SHOULD include context** (expected vs actual, relevant state) (`SHOULD`)

```bash
# OFF-STANDARD — mechanism-focused test name
@test "calls log_info function" {
  ...
}

# ON-STANDARD — behavior-focused test name with context
@test "deploy command exits 2 when target argument is missing" {
  run bash scripts/deploy.sh
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing required argument"* ]]
}
```

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `echo "Error: ..."` for error messages | Goes to stdout; breaks pipelines; no severity metadata | `log_error "..." "$SESSION_ID"` (writes to stderr) |
| Exit 0 on failure | CI/CD pipelines treat exit 0 as success; failures go undetected | Exit 1 for operational errors, exit 2 for usage errors |
| No session ID in log calls | Log lines from concurrent invocations are impossible to correlate | Generate session ID at entry; pass to all `log_*` calls |
| `date` command for sub-second timing | Bash `date` precision is 1 second; sub-second operations appear as 0s | Use `$SECONDS` for command-level timing; accept 1s granularity |
| `set -e` without `set -o pipefail` | Pipe failures silently succeed; `cmd1 | cmd2` ignores cmd1 failures | Always `set -euo pipefail` at script top |
| Implementing custom log rotation in Bash | Fragile, race-condition-prone, reinvents logrotate | Set `LOG_FILE`; configure logrotate externally |

---

## Deviation guidance

You MAY omit session ID generation for one-line utility scripts (< 10 lines) that perform a single atomic operation and produce no diagnostic output. MUST still use correct exit codes.

You MAY omit log file output for interactive CLI tools that are always run manually in a terminal and never in CI. MUST still write diagnostics to stderr via `logger.sh`.

You MAY omit `log_debug` calls in production builds where `DEBUG` is not set — `logger.sh` already suppresses debug output when the log level is `info` or higher.

---

## Profile inheritance notes

Extends: `general/standards/global/observability.md` (three-signal model, structured logging, severity discipline, correlation IDs, secrets/PII rules).
Adds: `logger.sh` as exclusive logging mechanism, session ID format and propagation, exit code contract (0/1/2), stdout/stderr channel discipline, `$SECONDS` timing, `LOG_FILE` support, BATS test naming.
Overrides: Logger recommendation — parent says "pino for Node.js"; this profile replaces with `scripts/lib/logger.sh` for Bash. Correlation ID format — parent uses `requestId` (UUID); this profile uses `[command]-[epoch]-[pid]`.

---

## Compliance test

Answer YES or NO. A single NO is a gap that must be resolved before the tool ships.

1. Does every script source `logger.sh` and use `log_info`/`log_warn`/`log_error`/`log_debug` — never `echo` for diagnostics? (Y/N)
2. Does every entry point generate a session ID in `[command]-[epoch]-[pid]` format and pass it to all log calls? (Y/N)
3. Does the tool exit 0 only on success, exit 1 on operational errors, and exit 2 on usage errors? (Y/N)
4. Does the tool log total execution duration at completion using `$SECONDS`? (Y/N)
5. Is program output on stdout and diagnostic output on stderr — never mixed? (Y/N)
6. Do BATS test names describe observable behavior, not internal mechanism? (Y/N)

---

## References

- [DevOS logger.sh](../../general/../../scripts/lib/logger.sh) — canonical Bash logging library with `log_info`, `log_warn`, `log_error`, `log_debug`
- [Bash `set` builtins](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html) — `set -euo pipefail` error handling modes
- [Exit codes — Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/exitcodes.html) — standard exit code conventions (0, 1, 2, 126, 127, 128+n)
- [BATS-core](https://github.com/bats-core/bats-core) — Bash Automated Testing System
- [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) — normative vocabulary (MUST, SHOULD, MAY)
- Parent standard: [general/standards/global/observability.md](../../../general/standards/global/observability.md)
