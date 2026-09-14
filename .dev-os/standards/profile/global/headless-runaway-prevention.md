<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/headless-runaway-prevention.md and re-run profile-sync. -->
# Headless Runaway Prevention Standards

## Overview

Every headless DevOS automation — cron jobs, systemd timers, agent-CLI invocations from non-interactive contexts — is a process that can fail without a human watching. The cost of failure is asymmetric: a script that exits silently is harmless; a script that loops indefinitely consumes RAM, CPU, API credits, and disk until something else breaks. This standard defines the baseline guards every headless run MUST install so the failure mode is "exit early" rather than "consume resources until kicked."

## Scope

This standard covers runaway prevention for **all** DevOS-initiated background processes:

- **Headless automation** — cron jobs, systemd user/system timers, agent-CLI invocations (`claude -p`, `codex exec`, etc.) running from non-interactive contexts
- **Session-spawned processes** — test runners, MCP servers, background validators, and any other command a skill or hook starts in the background during an interactive Claude session

It does NOT cover long-running daemons (continuous services intentionally running forever — those have a separate supervision standard), or container orchestration manifests (Kubernetes pod limits, Docker `--memory` flags).

> **Why session-spawned processes are in scope:** A `bun test` hung for 2 days at 94% CPU because it was invoked without a timeout during a Claude session. The process had no deadline and no registry entry — the same failure mode this standard prevents for cron jobs. The scope exclusion "does not cover interactive sessions" was too broad; it was intended to exclude the Claude CLI process itself, not the child processes Claude spawns.

## Principles

1. **Every unsupervised process needs a deadline.** Without a wall-clock cap, a hang is indistinguishable from progress. Define when the process is allowed to give up.
2. **Concurrent firings compound, not parallelize.** If a previous run is still going when the next fires, two instances make the problem worse. Single-instance lock is non-optional.
3. **External output is adversarial input.** Anything captured from a probe, API, or LLM can be unbounded — cap it before it crosses a process boundary.
4. **Fail loud to a log; fail silent to the user.** A failed run MUST leave a structured trace; it MUST NOT page or interrupt unless severity demands it.
5. **Disable without editing.** Operators need a kill-switch that doesn't require crontab edits or systemd reloads — a single envvar or sentinel file.

## Rules

### Wall-clock deadlines

- **Every external command MUST have a `timeout` wrapper.** (`MUST`)
- **Every LLM-CLI invocation MUST set a turn budget** (`--max-turns`, `--max-iterations`, or equivalent). (`MUST`)
- Default wall: 300 seconds for top-level cron entries unless the work demonstrably needs more. (`SHOULD`)

```bash
# OFF-STANDARD
RESULT="$(claude -p --permission-mode bypassPermissions <<< "$PROMPT")"

# ON-STANDARD
RESULT="$(timeout 300 claude -p \
    --permission-mode bypassPermissions \
    --max-turns 5 \
    <<< "$PROMPT" 2>>"$LOG" || true)"
```

### Single-instance locking

- **Every cron entry that writes shared state MUST acquire an exclusive `flock`** before doing work. (`MUST`)
- **Lock must use `-n` (non-blocking)** so overlapping fires exit immediately rather than queue. (`MUST`)
- Lock files belong under `~/.dev-os/runtime/` and SHOULD share a `cron-<name>.lock` naming pattern.

```bash
# ON-STANDARD
LOCK="$HOME/.dev-os/runtime/cron-cross-cli-drift.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    log "another instance holding lock — exiting"
    exit 0
fi
```

### Output size caps

- **Output captured from any external tool that flows into an LLM prompt MUST be size-capped** with `head -c <bytes>`. Default: 4KB per probe. (`MUST`)
- **Output captured from an LLM that flows into structured storage** (jsonl append, db insert) MUST be capped at 16KB per record AND validated (parseable JSON / known schema) before write. (`MUST`)
- Document the cap value inline so future readers know it is intentional, not arbitrary. (`SHOULD`)

```bash
# OFF-STANDARD
PROBE_OUT="$(bash run-probe.sh 2>&1)"
echo "$LLM_OUTPUT" >> "$INBOX"

# ON-STANDARD
PROBE_OUT="$(bash run-probe.sh 2>&1 | head -c 4096)"  # 4KB cap — prompt-blowup defense
JSON_LINE="$(echo "$LLM_OUTPUT" | grep -E '^\{.*\}$' | tail -n1 | head -c 16384)"
if echo "$JSON_LINE" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
    echo "$JSON_LINE" >> "$INBOX"
fi
```

### Log/path discipline

- **Cron entry MUST redirect both stdout and stderr** to a log file: `>> /path/to/log 2>&1`. (`MUST`)
- **Script MUST anchor `PATH` explicitly** (cron strips most of it). (`MUST`)
- Log path SHOULD live under `~/.dev-os/runtime/cron-<name>.log` for discoverability.

```bash
# OFF-STANDARD (in crontab)
0 13 * * 1 /home/user/scripts/drift.sh

# ON-STANDARD (in crontab)
0 13 * * 1 /home/user/scripts/drift.sh >> ~/.dev-os/runtime/cron-drift.log 2>&1

# ON-STANDARD (top of script)
export PATH="/home/user/.superset/bin:/home/user/.local/bin:/usr/local/bin:/usr/bin:/bin"
```

### Strict mode

- **Every script MUST start with `set -euo pipefail`** (or equivalent — for non-bash, document the strict-mode mechanism in use). (`MUST`)
- **Cron-invoked scripts SHOULD `unalias` interactive aliases** that may exist in user shell profiles (`find`, `grep`, `cp`, `mv`, `rm`).

```bash
#!/usr/bin/env bash
set -euo pipefail
unalias find grep ls cp mv rm 2>/dev/null || true
```

### Kill-switch

- **Every cron entry MUST honour a kill-switch envvar** (e.g., `DEVOS_CRON_DISABLED=1`) OR a sentinel file (`~/.dev-os/runtime/cron-disabled`). (`MUST`)
- Check kill-switch BEFORE acquiring lock or doing work.

```bash
# ON-STANDARD
if [[ "${DEVOS_CRON_DISABLED:-0}" == "1" ]] || [[ -f "$HOME/.dev-os/runtime/cron-disabled" ]]; then
    log "cron globally disabled — exiting"
    exit 0
fi
```

### Memory/CPU bounds (optional, situational)

- **For scripts that invoke binaries known to leak (long-running Node/Python loops, image processing):** wrap with `systemd-run --user --scope -p MemoryMax=512M -p CPUQuota=50%` OR use `ulimit -v` / `ulimit -t` before exec. (`SHOULD`)
- For `claude -p` and other LLM CLIs: the `--max-turns` budget is the primary memory bound (each turn has a context-window cap); explicit memory limits are usually unnecessary unless empirical leak observed.

```bash
# Optional hardening for known-leaky binaries
systemd-run --user --scope --quiet \
    -p MemoryMax=512M -p CPUQuota=50% -p TimeoutStopSec=10 \
    bash known-leaky-script.sh
```

### Idempotency

- **Scripts MUST be safe to re-run** if a previous fire crashed mid-write. (`MUST`)
- Append-only logs are inherently idempotent; mutating writes (state files, registry updates) MUST use atomic `mv tmp final` OR `flock`-protected critical sections.

## Session-Spawned Process Rules

These rules apply to any command a DevOS skill or hook starts in the background during an interactive Claude Code session.

### Mandatory timeout wrapper

- **Every background command MUST have a `timeout` wrapper.** (`MUST`)
- Use `DEVOS_TEST_TIMEOUT` (default: 300s) for test runners. Use `DEVOS_BG_TIMEOUT` (default: 600s) for MCP servers and long-running background tasks.

```bash
# OFF-STANDARD — hangs indefinitely on network-dependent test
output=$(cd "$project" && bun test 2>&1)

# ON-STANDARD
output=$(cd "$project" && timeout "${DEVOS_TEST_TIMEOUT:-300}" bun test 2>&1)
exit_code=$?
if [[ $exit_code -eq 124 ]]; then
  echo "Tests timed out after ${DEVOS_TEST_TIMEOUT:-300}s" >&2
fi
```

### Process registry

- **Every background PID MUST be registered** in the DevOS process registry before the skill returns control. (`MUST`)
- Use `dev_server_register <pid> 0 "<project>" "<command>" "<skill>" "<type>"` where `type` is one of `server | test | mcp | background`.
- Skills that fork-and-forget without registering the PID are non-compliant.

```bash
# Register a test runner
bun test &
local bg_pid=$!
dev_server_register "$bg_pid" 0 "$PWD" "bun test" "my-skill" "test"
```

### Session-start orphan scan

- Projects MUST have the `session-start-orphan-scan.sh` hook wired into `SessionStart` in `.claude/settings.json`. (`MUST`)
- The hook surfaces stale registered processes older than `DEVOS_ORPHAN_SCAN_MAX_AGE_HOURS` (default: 4h) at session start so the user can kill them before starting new work.

### MCP server supervision

- MCP servers started by skills or hooks SHOULD have a per-operation timeout configured. (`SHOULD`)
- CPU-intensive MCP servers (crawlers, renderers) SHOULD be wrapped with `ulimit -t <cpu-seconds>` or `systemd-run --user --scope -p CPUQuota=80%`. (`SHOULD`)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `claude -p "$PROMPT"` (no timeout, no max-turns) | Agentic loop can run forever consuming credits | `timeout 300 claude -p --max-turns 5 <<< "$PROMPT"` |
| Cron entry without `>> log 2>&1` | Failures emit email or vanish into syslog | `>> ~/.dev-os/runtime/cron-<name>.log 2>&1` |
| Setting `flock` only on success path | Errors bypass lock release; concurrent runs accumulate | `exec 9>"$LOCK"; flock -n 9` at top before any work |
| `cat huge-output.txt \| llm-cli` | Prompt blow-up exceeds context window or token budget | `head -c 4096 huge-output.txt \| llm-cli` |
| `echo "$LLM_OUTPUT" >> file.jsonl` | Malformed output corrupts append-only log | Validate parseable + size-cap before append |
| Script relies on inherited `PATH` | Cron's minimal PATH lacks user binaries; silent `command not found` | `export PATH="<explicit>"` at top of script |
| Disabling a job by editing crontab | Loses scheduling history; risk of typo breaking other entries | Honour `DEVOS_CRON_DISABLED=1` or sentinel file |

## Cron vs systemd-user timer

When the schedule is expressed in **local-time wall-clock** (e.g. "Monday 9am"), prefer systemd-user timers over cron. Cron schedules are interpreted in UTC (or system timezone, which varies); a `0 13 * * 1` entry that means "9am EDT" silently fires at 8am EST after DST ends. systemd `OnCalendar=Mon 09:00` honours the system timezone and is DST-aware.

Reference assets in the DevOS repository: `scripts/cron/systemd/<name>.{service,timer}` + `scripts/cron/install-systemd-timer.sh`. Use cron when (a) the schedule is UTC-anchored intentionally, (b) the script is third-party-owned and you can't modify how it's scheduled, or (c) you need only one fire and `at` would be overkill. Otherwise default to systemd-user.

## Deviation guidance

You MAY exceed the 300s default wall when the work genuinely requires it (large data transforms, multi-stage pipelines). When you do: document the chosen wall in the script header with a one-line rationale (e.g., `# wall=1800 — full BATS suite + integration tests`).

You MAY skip `flock` for read-only probes that produce no shared-state side effects. When you do: confirm in the script header that no writes occur (e.g., `# read-only — no flock`).

You MAY use a longer `--max-turns` budget for legitimately agentic workflows. When you do: set `--max-turns 20` is the upper recommended bound; beyond that, reconsider whether the workflow should be human-supervised.

## Profile inheritance notes

This standard lives under `global/` and applies to all DevOS profiles. Child profiles MAY add language- or framework-specific extensions (e.g., a `webapp` profile add-on for Node.js process limits) but MUST NOT override the core principles.

## Compliance test

For each cron entry / headless invocation:

- [ ] Does the script start with `set -euo pipefail` (bash) or equivalent strict mode?
- [ ] Does the script acquire an `flock -n` lock before any shared-state write?
- [ ] Is every external command wrapped with `timeout <seconds>`?
- [ ] If invoking an LLM CLI, is `--max-turns N` (or equivalent budget cap) set?
- [ ] Are captured outputs from external tools size-capped (`head -c N`) before LLM ingestion?
- [ ] Does the cron entry redirect stdout AND stderr to a log file (`>> log 2>&1`)?
- [ ] Does the script export `PATH` explicitly at the top?
- [ ] Are records appended to log/inbox files validated (e.g., JSON parse) before write?
- [ ] Is there a kill-switch (envvar OR sentinel file) honoured before work begins?
- [ ] Is the script safe to re-run if a previous fire crashed mid-write?

If any check fails: fix the script, OR explicitly document the deviation in a comment at the top of the script with the reason and risk acknowledged.

## References

- [POSIX `timeout(1)`](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/timeout.html) — wall-clock deadline utility
- [POSIX `flock(1)`](https://man7.org/linux/man-pages/man1/flock.1.html) — advisory file locking
- [systemd Service unit options](https://www.freedesktop.org/software/systemd/man/systemd.service.html) — `RuntimeMaxSec`, `TimeoutStartSec`, `MemoryMax` (when migrating cron → systemd timer)
- [cgroups v2 — memory.max, pids.max](https://docs.kernel.org/admin-guide/cgroup-v2.html) — kernel-level resource caps
- [Twelve-Factor App XII (Disposability)](https://12factor.net/disposability) — fast startup + graceful shutdown principle
- [Google SRE Book — Handling Overload](https://sre.google/sre-book/handling-overload/) — deadline propagation, fail-fast
- [Crash-only Software (Candea & Fox, USENIX HotOS 2003)](https://www.usenix.org/legacy/event/hotos03/tech/full_papers/candea/candea.pdf) — crash-only as a design principle
- [Anthropic Claude Code CLI](https://docs.claude.com/claude-code) — `--max-turns`, `--permission-mode` flags

---

*Reference implementation:* `scripts/cron/cross-cli-drift-weekly.sh` exemplifies all 10 compliance items.
*Related primitives:* `scripts/lib/circuit-breaker.sh` (per-hook breaker), `scripts/lib/github-issues.sh` + `scripts/lib/capture.sh` (existing `flock` patterns).
