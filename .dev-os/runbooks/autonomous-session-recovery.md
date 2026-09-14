# Runbook: Autonomous Session Recovery

| Field | Value |
|-------|-------|
| Service | DevOS autonomous sessions — `scripts/lib/auto.sh`, `scripts/lib/recovery.sh`, `scripts/lib/circuit-breaker.sh` |
| Runbook type | Operational |
| Severity | P2 |
| Owner team | DevOS operator |
| Last reviewed | 2026-04-03 |
| Automation status | Semi-automated (`resume`, `recover`) |

---

## 1. Trigger & Detection

**Trigger:** An autonomous session (`autonomous`) has stopped making progress — the operator expects forward motion but the session is stalled, failed, or stuck in a loop.

**Symptoms:**

| Symptom | Likely cause |
|---------|-------------|
| `.dev-os/runtime/session-state.yml` shows `status: running` but no work is happening | Session process exited without updating state |
| `status: paused` with `circuit_breaker_state: OPEN` | Too many consecutive phase failures tripped the circuit breaker |
| `status: failed` with a `last_action` referencing a specific phase | Unrecoverable error in that phase |
| `status: aborted` | `abort` was run or `abort.signal` was written |
| Same phase name appears in `phase:` field for over 30 minutes with no file changes | Session is stuck in a loop or hung |
| `.dev-os/runtime/abort.signal` exists but no session is running | Stale abort signal from a previous run |
| Multiple `.state` files in `product/runtime/circuit-breaker/` with today's date | Repeated failures triggering circuit breaker writes |

**Quick detection commands:**

```bash
# Check session state
cat .dev-os/runtime/session-state.yml

# Check circuit breaker state files for this project
ls -lt product/runtime/circuit-breaker/devos-autonomous-*.state 2>/dev/null | head -5

# Check for abort signal
ls -la .dev-os/runtime/abort.signal 2>/dev/null

# Check if any autonomous process is actively running
ps aux | grep -i "auto_run\|autonomous" | grep -v grep
```

---

## 2. Impact Assessment

**Low impact (resume possible):**
- Session state file exists with a valid `phase:` and `checkpoint_sha:`
- Git log shows commits from the autonomous session (branch `auto/*`)
- Spec and tasks files exist and show partial completion

**High impact (restart required):**
- No session state file or session state is corrupt
- Git working tree has uncommitted conflicts
- Circuit breaker is OPEN and the underlying issue has not been resolved

---

## 3. Diagnosis

### Step 1: Read session state

```bash
cat .dev-os/runtime/session-state.yml
```

Key fields to check:

| Field | What to look for |
|-------|-----------------|
| `status` | `running` (stale), `paused`, `failed`, `aborted`, `completed` |
| `phase` | Which phase the session stopped at (`planning`, `spec`, `tasks`, `implementation`, `test`, `complete`) |
| `checkpoint_sha` | Last git commit SHA — verify it exists: `git log --oneline <sha> -1` |
| `circuit_breaker_state` | `CLOSED` (healthy), `OPEN` (tripped), `HALF_OPEN` (recovering) |
| `last_action` | Human-readable description of what was happening |
| `next_action` | What the session intended to do next |
| `loop_iteration` | If present, which harden-loop iteration was running |
| `last_update` | Timestamp — if stale by >30 min with `status: running`, session is dead |

### Step 2: Check circuit breaker state

```bash
# List all circuit breaker state files for autonomous sessions
ls -lt product/runtime/circuit-breaker/devos-autonomous-*.state 2>/dev/null

# Read a specific state file (pick the most recent)
cat product/runtime/circuit-breaker/devos-autonomous-auto-*.state | head -20
```

State file format is `key=value` per line. Key fields:
- `state=OPEN` means the breaker tripped — too many failures (threshold: `AUTO_CIRCUIT_THRESHOLD`, default 3)
- `failure_count=N` shows how many consecutive failures occurred
- `last_failure_time=EPOCH` shows when the last failure was recorded
- `timeout=SECONDS` (default 300) — breaker auto-resets to `HALF_OPEN` after this

### Step 3: Check for abort signal

```bash
ls -la .dev-os/runtime/abort.signal 2>/dev/null
```

If present, this file was created by `abort` or manually. The `auto_run_loop` function checks for this file at each iteration and exits with code 2 when found.

### Step 4: Check last checkpoint

```bash
# List session checkpoints
ls -lt ~/.dev-os/auto/sessions/*/checkpoint-*.yml 2>/dev/null | head -5

# Read the most recent checkpoint
cat "$(ls -t ~/.dev-os/auto/sessions/*/checkpoint-*.yml 2>/dev/null | head -1)"
```

Checkpoints contain: timestamp, phase, spec path, branch, and a copy of the session state at that point.

### Step 5: Check git state

```bash
git status
git log --oneline -10
git stash list
```

Verify whether the autonomous branch (`auto/*`) has uncommitted changes, merge conflicts, or stashed work.

---

## 4. Recovery Options

Choose the recovery path based on diagnosis:

### Option A: Resume from checkpoint (`resume`)

**Use when:** Session state exists, checkpoint SHA is valid, no git conflicts.

```
resume
```

This command:
1. Reads `.dev-os/runtime/session-state.yml`
2. Restores the session to the last known phase
3. Preserves circuit breaker state and wave state
4. Continues from where the session left off

**Expected output:** Session resumes at the phase shown in `session-state.yml`.

**If it fails:** The session state may be corrupt. Try Option B or C.

### Option B: Unified recovery scan (`recover`)

**Use when:** You are unsure what state the session is in, or multiple sessions may exist.

```
recover --list          # List all recoverable sessions
recover --spec          # Filter to DevOS spec sessions only
recover --all           # Include older sessions beyond default age limit
recover --quick         # Fast scan, skip content inspection
```

This command scans for all recoverable sessions (specs, plans, agent plans) and presents them for selection. Pick the session to resume.

### Option C: Git stash + manual restart

**Use when:** Git working tree has uncommitted changes you want to preserve, but session state is corrupt.

```bash
# Save current work
git stash push -m "autonomous-session-recovery-$(date +%Y%m%d)"

# Verify stash was created
git stash list

# Clean session state
rm -f .dev-os/runtime/session-state.yml
rm -f .dev-os/runtime/abort.signal

# Restart autonomous session
# autonomous --from spec   (if spec exists)
# autonomous --from tasks  (if tasks exist)
```

After the new session completes or reaches a stable point:

```bash
# Apply stashed changes if needed
git stash pop
```

### Option D: Abort + fresh start

**Use when:** The session is fundamentally broken — wrong spec, wrong approach, or the circuit breaker keeps tripping on a real issue.

```
abort
```

Then clean up (see Section 6) and start fresh:

```
autonomous "<goal>"
```

### Option E: Reset circuit breaker only

**Use when:** The underlying issue has been fixed but the circuit breaker is still OPEN, blocking the session from resuming.

```bash
# Remove circuit breaker state files for this session
rm -f product/runtime/circuit-breaker/devos-autonomous-auto-*.state

# Resume the session
# resume
```

The circuit breaker will start fresh in CLOSED state.

---

## 5. Verification

After any recovery action, verify success:

```bash
# 1. Session state should show running or completed
cat .dev-os/runtime/session-state.yml | grep "^status:"

# 2. Circuit breaker should be CLOSED
ls product/runtime/circuit-breaker/devos-autonomous-*.state 2>/dev/null | wc -l
# Expected: 0 or files showing state=CLOSED

# 3. No stale abort signal
test ! -f .dev-os/runtime/abort.signal && echo "OK: no abort signal" || echo "WARN: abort signal still present"

# 4. Git working tree is clean or has expected changes
git status --short

# 5. Task progress is advancing (check tasks.md)
grep -c "\- \[x\]" product/specs/*/tasks.md 2>/dev/null
grep -c "\- \[ \]" product/specs/*/tasks.md 2>/dev/null
```

---

## 6. Cleanup

Remove stale artifacts from failed sessions. Run these only after confirming no active session needs them.

```bash
# Remove stale session state
rm -f .dev-os/runtime/session-state.yml

# Remove abort signal
rm -f .dev-os/runtime/abort.signal

# Remove all circuit breaker state files for autonomous sessions
rm -f product/runtime/circuit-breaker/devos-autonomous-*.state

# Remove old session archives (older than 7 days)
find ~/.dev-os/auto/sessions/ -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null

# Remove stale checkpoint files (older than 7 days)
find ~/.dev-os/auto/sessions/ -name "checkpoint-*.yml" -mtime +7 -delete 2>/dev/null
```

---

## 7. Prevention

### Circuit breaker thresholds

The circuit breaker trips after `AUTO_CIRCUIT_THRESHOLD` (default: 3) consecutive failures. Timeout before auto-reset is `AUTO_CIRCUIT_TIMEOUT` (default: 300 seconds). Adjust in the environment if sessions trip too easily or not fast enough:

```bash
# More tolerant (5 failures before trip, 10 min timeout)
export AUTO_CIRCUIT_THRESHOLD=5
export AUTO_CIRCUIT_TIMEOUT=600

# More aggressive (2 failures, 2 min timeout)
export AUTO_CIRCUIT_THRESHOLD=2
export AUTO_CIRCUIT_TIMEOUT=120
```

### Loop iteration limits

`auto_run_loop` defaults to `AUTO_LOOP_MAX_ITERATIONS=5`. If the implementation-test cycle needs more attempts:

```bash
export AUTO_LOOP_MAX_ITERATIONS=10
```

### Stuck-loop detection

The loop runner detects stuck sessions by comparing failure fingerprints across iterations. If the same phase fails twice consecutively, the loop exits with an error and recommends `systematic-debugging`. This prevents infinite loops burning context on the same bug.

### Best practices

- Run `checkpoint` manually before long implementation phases
- Use `--max-iterations` flag when running harden loops to cap retry attempts
- Monitor `.dev-os/runtime/session-state.yml` periodically during long sessions
- If a session will be interrupted (closing terminal, switching tasks), run `abort` cleanly rather than force-killing

---

## 8. Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `resume` says "No active session" | `session-state.yml` missing or corrupt | Use `recover` to scan for recoverable sessions |
| Circuit breaker keeps tripping after reset | Underlying issue not fixed | Run `systematic-debugging` on the failing phase before retrying |
| Session resumes but repeats completed work | Checkpoint SHA outdated or tasks.md not updated | Run `sync-completed-work` to align task state with git |
| `abort.signal` keeps reappearing | Another process or hook is writing it | Check `.claude/hooks/` for hooks that write abort signals |
| Multiple sessions competing for same state file | Parallel autonomous runs on same project | Only run one autonomous session per project at a time |
| Loop exits with "max iterations reached" | Tests keep failing across all attempts | Diagnose the test failure manually; the loop cannot fix what it cannot identify |

---

## 9. Escalation

If none of the recovery options resolve the issue:

1. Capture diagnostic output: `cat .dev-os/runtime/session-state.yml` and `ls -la product/runtime/circuit-breaker/`
2. Check learnings log for related entries: `tail -20 product/runtime/learnings-log.jsonl`
3. Run `runtime-diagnostics` for a full runtime health summary
4. If the issue is a DevOS framework bug, file it in the dev-os repository with the diagnostic output attached
