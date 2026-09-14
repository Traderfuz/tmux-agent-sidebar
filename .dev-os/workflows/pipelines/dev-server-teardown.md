# Dev Server Teardown Pipeline

Gracefully stops all registered dev server processes, cleans stale registry entries, and
confirms the port is released. Inverse of `local-dev-startup.md`.

## When to Use

- Ending a development session cleanly
- Before switching projects or branches that require a different port
- When a dev server is unresponsive and needs to be replaced
- Before running `local-dev-startup.md` if old entries exist in the registry

**Anti-triggers:**
- CI/CD environments (no registry involved)
- Server was never started via `local-dev-startup.md` (nothing to unregister)

## Prerequisites

- `scripts/devos-dev-server-registry.sh` accessible
- Server was started and registered via the `local-dev-startup.md` pipeline

## Process

1. List registered servers from `~/.dev-os/runtime/server-registry.json`.
2. Send graceful shutdown signal (SIGTERM) to each registered PID.
3. Confirm process exit and port release.
4. Remove stale registry entries.

## Steps

### Step 1: List Registered Servers

**Input:** `~/.dev-os/runtime/server-registry.json`
**Output:** Table of currently registered servers with PID and port
**Gate to next step:** At least one server registered
**Skip if:** Registry is empty (nothing to tear down)

```bash
scripts/devos-dev-server-registry.sh list
```

Output:
```
NAME          PORT   PID     STATUS   STARTED
app-server    3000   12345   healthy  2026-04-13T09:15:00Z
convex-dev    3210   12346   healthy  2026-04-13T09:14:57Z
```

If registry is empty:
```
No servers registered. Nothing to tear down.
```
Stop.

### Step 2: Send Graceful Shutdown Signal

**Input:** PID for each registered server
**Output:** SIGTERM sent; process given 5 seconds to exit cleanly
**Gate to next step:** PIDs sent SIGTERM (does not wait for confirmation — Step 3 verifies)

```bash
# For each registered server:
for pid in $(scripts/devos-dev-server-registry.sh list --format pid); do
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid"
    echo "→ SIGTERM sent to PID $pid"
  else
    echo "→ PID $pid already gone (orphan)"
  fi
done
```

### Step 3: Wait and Force-Kill if Needed

**Input:** PIDs from Step 2
**Output:** All processes confirmed stopped
**Gate to next step:** No registered PIDs still alive after 5s
**Timeout:** 5 seconds before SIGKILL escalation

```bash
sleep 5

for pid in $(scripts/devos-dev-server-registry.sh list --format pid); do
  if kill -0 "$pid" 2>/dev/null; then
    echo "→ PID $pid did not exit — sending SIGKILL"
    kill -KILL "$pid" 2>/dev/null || true
  fi
done
```

### Step 4: Unregister All Entries

**Input:** Server names from Step 1
**Output:** Registry cleared
**Gate to next step:** Registry reports zero servers

```bash
scripts/devos-dev-server-registry.sh prune
# OR individually:
# scripts/devos-dev-server-registry.sh unregister app-server
# scripts/devos-dev-server-registry.sh unregister convex-dev
```

### Step 5: Port Release Verification

**Input:** Ports that were registered
**Output:** Confirmed ports no longer occupied
**Gate to completion:** `ss`/`lsof` shows ports free

```bash
# Verify port is free (replace PORT with actual port)
ss -tlnp 2>/dev/null | grep ":3000 " && echo "⚠ Port 3000 still occupied" || echo "✓ Port 3000 released"
ss -tlnp 2>/dev/null | grep ":3210 " && echo "⚠ Port 3210 still occupied" || echo "✓ Port 3210 released"
```

**On port still occupied after SIGKILL:**
```
⚠ Port still occupied after force-kill. Find and kill the remaining process:
  lsof -ti:3000 | xargs kill -9
```

### Step 6: Teardown Confirmation

```
✓ Dev server teardown complete

  Stopped:
    app-server   (PID 12345, port 3000) — terminated
    convex-dev   (PID 12346, port 3210) — terminated

  Registry: empty
  Ports 3000, 3210: released
```

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Registry file missing | Nothing to do — server was not started via this pipeline |
| Step 2 | PID already gone | Mark as orphan, continue to Step 4 |
| Step 3 | SIGKILL fails (permission) | Process owned by different user — identify with `ps aux \| grep <pid>` |
| Step 4 | Prune command fails | Delete registry file directly: `rm ~/.dev-os/runtime/server-registry.json` |
| Step 5 | Port still occupied | `lsof -ti:PORT \| xargs kill -9` |

## Orphan Cleanup (fast path)

When the registry is stale from a previous crash:

```bash
scripts/devos-dev-server-registry.sh cleanup-orphans
```

This removes entries where the registered PID is no longer alive. Faster than the full pipeline
when the processes are already gone.

## References

- `scripts/devos-dev-server-registry.sh` — registry CLI (prune, unregister, cleanup-orphans)
- `scripts/lib/dev-server.sh` — `dev_server_stop()`, graceful shutdown (SIGTERM → SIGKILL)
- `profiles/general/workflows/pipelines/local-dev-startup.md` — startup pipeline (inverse)
- `profiles/general/runbooks/port-conflict-resolution.md` — if ports remain occupied post-teardown

## Display Format

```
Dev Server Teardown
  Stopped: [N] server(s) ([name] on port [port])
  Registry entries removed: [N]
  Ports confirmed free: [list]
  Status: complete
```
