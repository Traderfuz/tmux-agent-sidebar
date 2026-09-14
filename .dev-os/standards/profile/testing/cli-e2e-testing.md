<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/testing/cli-e2e-testing.md and re-run profile-sync. -->
# CLI E2E Testing Standard

**Profile:** cli
**Category:** testing
**Version:** 1.0.0

## Overview

This standard defines the quality criteria for CLI end-to-end testing via `e2e` CLI mode. It covers 10 usability dimensions that every CLI tool should satisfy before shipping.

### When to Use Which Command

| Goal | Command |
|------|---------|
| Unit and integration tests | `test` (`bun test`) |
| Full CLI E2E usability testing | `e2e` (CLI mode auto-detected) |
| Pre-deploy safety gate | `validate` |

`e2e` CLI mode orchestrates three passes:
- **Pass 1:** Non-interactive command testing (exit codes, output, config state)
- **Pass 2:** Interactive TUI testing (screen nav, input flows, error states)
- **Pass 3:** 10 usability dimension checks (below)

## The 10 Usability Dimensions

### U1: Help Text Completeness

Every command and subcommand must have `--help` output containing:
- **Usage line** — how to invoke the command
- **Description** — what it does (1-2 sentences)
- **Arguments/options** — if any, with types and defaults

**Pass criteria:** All commands return exit 0 for `--help` with all three elements present.

### U2: Error Message Quality

Invalid input must produce errors that are:
- Written to **stderr** (not stdout)
- Include **what went wrong** (the specific error)
- Include **how to fix it** (suggestion, correct usage, or pointer to `--help`)

**Pass criteria:** All error paths produce actionable messages on stderr with exit code 1.

### U3: Performance (Startup Time)

CLI commands must start quickly. Measured as median of 5 `--help` runs.

| Threshold | Result |
|-----------|--------|
| < 500ms | PASS |
| 500ms–2000ms | WARN |
| > 2000ms | FAIL |

Override with `--perf-threshold <ms>`.

### U4: Signal Handling

Long-running commands (TUI, servers, watch modes) must:
- Exit cleanly on **SIGINT** (Ctrl+C) — exit code 130
- Exit cleanly on **SIGTERM** — exit code 143
- Leave no orphaned child processes
- Clean up temp files / lock files

**Pass criteria:** Both signals cause clean exit within 1 second.

### U5: Pipe Compatibility

When output is piped (not a TTY):
- **JSON output** must be valid JSON (`JSON.parse()` succeeds)
- **No ANSI escape codes** when `NO_COLOR=1` is set
- **Errors go to stderr only** — stdout remains clean for piping

**Pass criteria:** All 3 pipe checks pass.

### U6: Terminal Resize (TUI Only)

TUI applications must render correctly at:

| Size | Expected |
|------|----------|
| 80x24 (standard) | Layout intact, no overflow |
| 200x50 (large) | Uses space appropriately |
| 40x10 (tiny) | Graceful degradation or size warning |

**Pass criteria:** No crashes at any size. Rendering artifacts at extreme sizes are WARN, not FAIL.

**Skipped** for CLIs without a TUI framework.

### U7: State Consistency

Config/state operations must be:
- **Atomic** — interrupted writes don't corrupt state
- **Valid** — file is always parseable JSON/YAML after operations
- **Complete** — rapid sequential writes don't lose data

**Pass criteria:** 5 state consistency checks all pass (create, switch, rapid batch, delete, interrupt recovery).

### U8: NO_COLOR / TERM Respect

CLI must respect standard terminal environment variables:
- `NO_COLOR=1` → suppress all ANSI colour codes
- `TERM=dumb` → suppress colour and advanced formatting

Reference: https://no-color.org/

**Pass criteria:** Both environment variables suppress ANSI output.

### U9: Exit Code Correctness

Exit codes must follow convention:

| Scenario | Exit Code |
|----------|-----------|
| Success | 0 |
| User error (bad args) | 1 |
| Runtime error | 1 |
| `--help` / `--version` | 0 |
| SIGINT termination | 130 (128+2) |
| SIGTERM termination | 143 (128+15) |

**Pass criteria:** All command paths return the correct exit code.

### U10: Idempotency

- **Read-only commands** (status, list, help) produce identical output across repeated runs
- **Write commands** handle duplicates gracefully (meaningful error, not crash)
- **Overwrite operations** complete cleanly without corruption

**Pass criteria:** All 6 idempotency checks pass.

## Tool Requirements

| Tool | Purpose | Required? |
|------|---------|-----------|
| Bun.spawn | Subprocess execution for command testing | Yes (built-in) |
| ink-testing-library | Component-level TUI testing for Ink apps | If Ink detected |
| POSIX `script` | PTY wrapping for non-Ink TUIs | Fallback |
| POSIX `kill` | Signal handling tests | Yes (standard) |

## Compliance Checklist

For `validate-standards`:

- [ ] U1: Every command has `--help` with Usage + Description + Args
- [ ] U2: All error paths write to stderr with actionable messages
- [ ] U3: Startup time median < 500ms (or configured threshold)
- [ ] U4: SIGINT and SIGTERM cause clean exit
- [ ] U5: JSON output valid when piped; no ANSI with NO_COLOR=1
- [ ] U6: TUI renders at 80x24, 200x50, 40x10 without crashing
- [ ] U7: Config operations atomic and recoverable after interrupt
- [ ] U8: NO_COLOR=1 and TERM=dumb suppress ANSI
- [ ] U9: All exit codes follow convention (0/1/130/143)
- [ ] U10: Read commands idempotent; write commands handle duplicates
