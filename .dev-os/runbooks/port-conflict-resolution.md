# Runbook: Local Dev Server — Port Conflict Resolution

| Field | Value |
|-------|-------|
| Service | Local Development Server (port binding) |
| Runbook type | Diagnostic |
| Severity | P3 — blocks specific port; alternate port fallback available |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-13 |
| Automation status | Manual |
| Related runbooks | `dev-server-startup-failure.md`, `doppler-local-dev-setup.md` |

---

## 1. Trigger & Detection

This runbook activates when:
- `local-dev-startup.md` Step 4 (Port Availability Check) detects an occupied port
- Dev server exits immediately with `listen EADDRINUSE :::3000` in output
- Dev server exits immediately with `listen EADDRINUSE :::3210` (Convex backend)
- Any script reports `✗ Port 3000 is already in use` or `✗ Port 3210 occupied`

**Infrastructure:**
- Ports: 3000 (app/Next.js), 3210 (Convex backend)
- Registry: `~/.dev-os/runtime/server-registry.json`
- Registry CLI: `scripts/devos-dev-server-registry.sh`
- Shutdown library: `scripts/lib/dev-server.sh` (SIGTERM → 5s wait → SIGKILL)

---

## 2. Impact Assessment — Triage Checklist

Run in order. Stop at first match — that determines the resolution scenario.

```bash
# Step 0: Identify which port is occupied and who owns it
PORT=3000   # change to 3210 for Convex port conflicts
ss -tlnp 2>/dev/null | grep ":${PORT} " || lsof -i ":${PORT}" 2>/dev/null | head -5
# Note: record the PID from this output — needed for T1-T4
```

```bash
# T1 — Is the occupying PID listed in the DevOS registry?
scripts/devos-dev-server-registry.sh list 2>/dev/null
# Match (PID in output) → go to T2 to check if it's alive
# No match / "No servers registered" → Orphan entry or foreign process → go to T3
```

```bash
# T2 — Is the registered PID still alive?
REGISTERED_PID=$(scripts/devos-dev-server-registry.sh list --format pid 2>/dev/null | head -1)
kill -0 "$REGISTERED_PID" 2>/dev/null && echo "ALIVE" || echo "DEAD"
# "DEAD" → Stale registry entry (→ Scenario A: cleanup-orphans)
# "ALIVE" → Active DevOS server still running (→ Scenario B: teardown pipeline)
```

```bash
# T3 — Who owns the occupying process?
OCCUPYING_PID=$(ss -tlnp 2>/dev/null | grep ":${PORT} " | grep -oP 'pid=\K[0-9]+' \
  || lsof -ti ":${PORT}" 2>/dev/null)
ps aux | grep "^$USER" | grep -w "${OCCUPYING_PID}" | grep -v grep
# Match (your user owns it) → Foreign user-owned process (→ Scenario C: graceful kill)
# No match → System or root-owned process (→ Scenario D: alternate port)
```

```bash
# T4 — Confirm final ownership
ps -p "${OCCUPYING_PID}" -o pid,user,comm 2>/dev/null
# PID  USER     COMMAND
# Shows root or system user → Cannot kill → Scenario D
# Shows your username → Can kill → Scenario C
```

**Severity matrix:**

| Finding | Scenario | Severity | Resolution |
|---------|----------|----------|------------|
| Registry entry exists; PID dead | A: Stale entry | P3 | `cleanup-orphans`, retry |
| Registry entry exists; PID alive | B: Active DevOS server | P3 | `dev-server-teardown.md` pipeline |
| No registry entry; user owns PID | C: Foreign user process | P3 | Graceful kill, retry |
| No registry entry; root/system owns PID | D: System process | P3 | Use alternate port |

---

## 3. Investigation Steps

### Identify the occupying process in detail

```bash
PORT=3000   # or 3210 for Convex

# Linux — ss with process info
ss -tlnp 2>/dev/null | grep ":${PORT} "
# Example output:
# LISTEN 0 511 *:3000 *:* users:(("node",pid=12345,fd=22))

# macOS / Linux fallback — lsof
lsof -i ":${PORT}" 2>/dev/null
# Example output:
# COMMAND   PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
# node    12345   tafadzwa  22u  IPv6  12345   0t0  TCP *:3000 (LISTEN)

# Get just the PID (Linux)
OCCUPYING_PID=$(ss -tlnp 2>/dev/null | grep ":${PORT} " | grep -oP 'pid=\K[0-9]+')
# Get just the PID (macOS/fallback)
OCCUPYING_PID=$(lsof -ti ":${PORT}" 2>/dev/null)

echo "Occupying PID: ${OCCUPYING_PID}"

# Full process details
ps -p "${OCCUPYING_PID}" -o pid,user,ppid,comm,args 2>/dev/null
```

Expected output (stale DevOS server):
```
PID   USER     PPID  COMM   ARGS
12345 tafadzwa 1     node   bun run dev
```

Expected output (foreign process):
```
PID   USER     PPID  COMM   ARGS
9876  tafadzwa 1     python python3 -m http.server 3000
```

---

## 4. Resolution Steps

### Scenario A: Stale Registry Entry (registered PID is dead)

The server crashed or was killed outside the teardown pipeline, leaving a ghost entry.

```bash
# Step 1: Confirm the registered PID is dead
REGISTERED_PID=$(scripts/devos-dev-server-registry.sh list --format pid 2>/dev/null | head -1)
kill -0 "$REGISTERED_PID" 2>/dev/null \
  && echo "ERROR: PID alive — use Scenario B instead" \
  || echo "Confirmed: PID ${REGISTERED_PID} is dead"

# Step 2: Clean up stale entries
scripts/devos-dev-server-registry.sh cleanup-orphans
# Expected output:
# ✓ Removed orphan entry: app-server (PID 12345 — dead)
# ✓ Registry clean

# Step 3: Verify port is now free
ss -tlnp 2>/dev/null | grep ":3000 " \
  && echo "✗ Port still occupied" \
  || echo "✓ Port 3000 free"
# Expected: "✓ Port 3000 free"

# Step 4: Retry dev server startup
# Follow local-dev-startup.md from Step 5
```

**Expected output after cleanup:**
```
✓ Port 3000 free
```

**If port is still occupied after cleanup-orphans:** A second process (not in the registry) may be using the port. Proceed to Scenario C.

---

### Scenario B: Active DevOS Server (registered PID is alive)

A registered dev server is still running and bound to the port. Use the teardown pipeline.

```bash
# Step 1: Confirm the active server
scripts/devos-dev-server-registry.sh list
# Expected output:
# NAME          PORT   PID     STATUS   STARTED
# app-server    3000   12345   healthy  2026-04-13T09:00:00Z

# Step 2: Run teardown pipeline
# Follow profiles/general/workflows/pipelines/dev-server-teardown.md
# Quick path (send SIGTERM, wait 5s, then verify):
for pid in $(scripts/devos-dev-server-registry.sh list --format pid 2>/dev/null); do
  kill -TERM "$pid" 2>/dev/null && echo "→ SIGTERM sent to PID $pid"
done
sleep 5

# Step 3: Check if process exited
for pid in $(scripts/devos-dev-server-registry.sh list --format pid 2>/dev/null); do
  if kill -0 "$pid" 2>/dev/null; then
    echo "→ PID $pid did not exit — sending SIGKILL"
    kill -KILL "$pid" 2>/dev/null || true
  fi
done

# Step 4: Prune registry
scripts/devos-dev-server-registry.sh prune
# Expected output: "✓ Registry cleared"

# Step 5: Verify port released
ss -tlnp 2>/dev/null | grep ":3000 " \
  && echo "✗ Port still occupied" \
  || echo "✓ Port 3000 free"

# Step 6: Retry dev server startup
# Follow local-dev-startup.md from Step 5
```

---

### Scenario C: Foreign User-Owned Process

A process you own (not a DevOS server) is binding the port.

```bash
PORT=3000
OCCUPYING_PID=$(lsof -ti ":${PORT}" 2>/dev/null \
  || ss -tlnp 2>/dev/null | grep ":${PORT} " | grep -oP 'pid=\K[0-9]+')

echo "Will terminate PID ${OCCUPYING_PID}:"
ps -p "${OCCUPYING_PID}" -o pid,user,comm,args 2>/dev/null

# Step 1: Graceful kill (SIGTERM — gives the process time to clean up)
kill -TERM "${OCCUPYING_PID}" 2>/dev/null \
  && echo "→ SIGTERM sent to PID ${OCCUPYING_PID}" \
  || echo "✗ Could not send SIGTERM"

# Step 2: Wait 5 seconds
sleep 5

# Step 3: Verify exit
kill -0 "${OCCUPYING_PID}" 2>/dev/null \
  && echo "Still running — force kill" \
  || echo "✓ Process exited"

# Step 4: Force kill if still alive
kill -0 "${OCCUPYING_PID}" 2>/dev/null \
  && kill -KILL "${OCCUPYING_PID}" 2>/dev/null \
  && echo "→ SIGKILL sent" \
  || true

# Step 5: Verify port released
sleep 2
ss -tlnp 2>/dev/null | grep ":${PORT} " \
  && echo "✗ Port ${PORT} still occupied" \
  || echo "✓ Port ${PORT} free"

# Step 6: Retry dev server startup
```

**Alternative — use lsof shorthand (Linux/macOS):**
```bash
# Graceful kill shorthand
lsof -ti:3000 | xargs kill -TERM 2>/dev/null; sleep 5
# Force kill if needed
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
```

**If the process restarts automatically** (e.g., a process manager or systemd service): identify the parent process and stop the service manager, not just the child:
```bash
ps -p "${OCCUPYING_PID}" -o ppid= | xargs -I{} ps -p {} -o pid,user,comm,args
# If managed by systemd:
systemctl list-units --type=service | grep <relevant-name>
systemctl stop <service-name>
```

---

### Scenario D: System / Root-Owned Process (Cannot Kill)

The port is held by a system process or a process owned by root or another user.

```bash
# Confirm the ownership
ps -p "${OCCUPYING_PID}" -o pid,user,comm,args
# Shows root or different user → cannot kill without sudo

# Option 1: Use an alternate port (preferred — no escalation needed)
export PORT=3001
scripts/doppler-run.sh bun run dev &
APP_PID=$!
sleep 2
kill -0 "$APP_PID" 2>/dev/null || { echo "✗ Server exited immediately"; exit 1; }

# Register under the alternate port
SERVER_NAME=$(basename "$PWD")
scripts/devos-dev-server-registry.sh register "${SERVER_NAME}" 3001 "$APP_PID"
echo "✓ App server started on alternate port 3001 (PID: $APP_PID)"

# Validate on alternate port
curl -s -o /dev/null -w "%{http_code}" http://localhost:3001
# Expected: 2xx or 3xx

# Option 2: Identify and request system service stop (if you know it's safe)
systemctl status <service>   # inspect the service
# Ask system admin or use sudo if authorized:
sudo systemctl stop <service>
```

**For Convex port 3210 conflict with a system process:**
```bash
# Check if Convex backend is already running (expected if multi-server started twice)
curl -s -o /dev/null -w "%{http_code}" http://localhost:3210
# If 200 → Convex is already running — skip starting it again
# If connection refused → different process owns 3210 — use alternate port 3211:
export CONVEX_PORT=3211
scripts/doppler-run.sh npx convex dev --local --port 3211
```

---

## 5. Validation

After applying any resolution scenario:

```bash
# Check 1: Primary port is free (or alternate port is confirmed)
ss -tlnp 2>/dev/null | grep ":3000 " \
  && echo "⚠ Port 3000 still occupied" \
  || echo "✓ Port 3000 free"

# Check 2: Registry is clean
scripts/devos-dev-server-registry.sh list 2>/dev/null
# Expected: "No servers registered." OR only active, expected servers

# Check 3: Dev server starts successfully
scripts/doppler-run.sh bun run dev &
NEW_PID=$!
sleep 10
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Expected: 200 or 3xx
kill "$NEW_PID" 2>/dev/null || true   # stop test server
```

**Success threshold:** Port is free (or alternate port confirmed), registry is clean, and server binds successfully on first attempt.

---

## 6. Rollback

**For Scenario C (killed a foreign process):**
- No rollback available if the process was killed — restart it manually if needed
- Record what you killed before terminating: `ps -p "${PID}" -o pid,comm,args > /tmp/killed-process.txt`

**For Scenario D (alternate port):**
- If the alternate port causes issues (hardcoded URLs, OAuth callbacks): revert to default port by stopping the system service and restarting on port 3000
- If using port 3001, update any hardcoded `localhost:3000` references in OAuth redirect URIs, CORS configs, or `.env` overrides

**Registry cleanup (any scenario):**
```bash
# If registry was left in a bad state during resolution
scripts/devos-dev-server-registry.sh cleanup-orphans
# Verify:
scripts/devos-dev-server-registry.sh list
# Expected: "No servers registered." or only active entries
```

---

## 7. Post-Task

- [ ] Target port is free: `ss -tlnp | grep ":3000"` shows nothing
- [ ] DevOS registry is clean: `scripts/devos-dev-server-registry.sh list` shows no stale entries
- [ ] Dev server starts and responds: `curl http://localhost:3000` returns 2xx/3xx
- [ ] If alternate port was used: confirm OAuth/CORS configs are updated to match
- [ ] If a stale registry entry was the root cause: confirm the teardown pipeline is being used for future session endings (see `dev-server-teardown.md`)
- [ ] If the failure revealed a new process type that creates port conflicts: add it to this runbook's investigation section

---

## 8. Related Runbooks

- `profiles/cli/runbooks/dev-server-startup-failure.md` — dev server fails after port is cleared
- `profiles/general/runbooks/doppler-local-dev-setup.md` — Doppler setup if secrets also failing
- `profiles/general/workflows/pipelines/local-dev-startup.md` — full startup pipeline (port check is Step 4)
- `profiles/general/workflows/pipelines/dev-server-teardown.md` — clean shutdown to prevent future port conflicts
- `profiles/general/workflows/pipelines/multi-server-dev.md` — Convex + app dual-port coordination
