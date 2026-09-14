# Runbook: Dev Server — Startup Failure

| Field | Value |
|-------|-------|
| Service | Local Development Server (DevOS-managed) |
| Runbook type | Diagnostic |
| Severity | P2 — blocks local development; no production impact |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-13 |
| Automation status | Manual |
| Related runbooks | `port-conflict-resolution.md`, `doppler-local-dev-setup.md` |

---

## 1. Trigger & Detection

This runbook activates when the `local-dev-startup.md` pipeline fails at Step 5,
6, 7, or 8:
- **Step 5 failure:** Dev server process exits immediately after launch
- **Step 6 failure:** Registry write fails or command errors
- **Step 7 failure:** Health check times out (server running but not responding)
- **Symptom report:** Developer reports "server won't start" without running the
  pipeline explicitly

Infrastructure:
- Server launched via: `scripts/doppler-run.sh bun run dev`
- Registered via: `scripts/devos-dev-server-registry.sh register`
- Health check: `curl http://localhost:<PORT>` polling, 30s timeout
- Registry file: `~/.dev-os/runtime/server-registry.json`
- Shutdown library: `scripts/lib/dev-server.sh` (SIGTERM → 5s wait → SIGKILL)

---

## 2. Impact Assessment — Triage Checklist

Run these in order. Stop at the first match — that determines the failure scenario.

```bash
# T1 — Did the process start at all?
ps aux | grep "bun run dev" | grep -v grep
# Match → process is running; failure is health-check or port (→ Scenario C or D)
# No match → process exited immediately (→ Scenario A or B)

# T2 — Is the port in use?
ss -tlnp 2>/dev/null | grep ":3000 " || lsof -i :3000 2>/dev/null | head -3
# Match → port occupied (→ port conflict — see port-conflict-resolution.md)
# No match → port is free; process died before binding

# T3 — What does the registry show?
scripts/devos-dev-server-registry.sh list 2>/dev/null
# Entry with PID that matches ps aux → server started; health check failing (→ Scenario C)
# No entry or orphan entry → server never registered (→ Scenario A or B)

# T4 — Did Doppler inject any secrets?
doppler run --config dev -- env 2>/dev/null | grep -c "=" || echo "0"
# Count > 5 → Doppler injected secrets; failure is application-level (→ Scenario A)
# Count = 0 or error → Doppler injection failed (→ Scenario B)
```

**Severity matrix:**

| Finding | Scenario | Severity | Action |
|---------|----------|----------|--------|
| Process not running, no port conflict, Doppler works | A: App crash | P2 | Investigate app logs |
| Process not running, Doppler count = 0 | B: Secret missing | P2 | Set missing key in Doppler dev config |
| Process running, health check failing | C: App not listening | P2 | Check port binding in app code |
| Port occupied by another PID | D: Port conflict | P3 | See `port-conflict-resolution.md` |
| Convex process missing | E: Convex startup failure | P2 | Re-authenticate Convex CLI |

---

## 3. Investigation Steps

### Scenario A: Immediate process exit (app-level crash)

```bash
# Run server directly (not in background) to see full output
scripts/doppler-run.sh bun run dev
# Read the terminal output — the error is in the first 10 lines of the crash

# Common signals:
#   "Cannot find module" → missing dependency (run: bun install)
#   "SyntaxError" / "TypeError" → code error in source files
#   "listen EADDRINUSE" → port conflict (go to Scenario D)
#   "Invalid environment variable" → required env var not set (→ Scenario B)
```

**Expected output (success path — should NOT appear if in this runbook):**
```
→ Branch: feature/my-branch
→ Config: dev
→ Running: doppler run --config dev -- bun run dev

  ▲ Next.js 15.x
  - Local:   http://localhost:3000
  - Ready in 2.1s
```

**If "Cannot find module":**
```bash
bun install
scripts/doppler-run.sh bun run dev    # retry
```

**If SyntaxError or TypeError:**
Review the file path in the error; fix the code error before retrying.

---

### Scenario B: Missing Doppler secret causes crash

```bash
# Identify which secret is missing
bash scripts/lib/checks/doppler-validator.sh
# Look for "ISSUE: Required secret '...' not found"

# List all secrets currently in dev config
doppler secrets --config dev --only-names 2>/dev/null

# Set a missing secret
doppler secrets set <SECRET_NAME>="<VALUE>" --config dev
# Retry after setting all missing secrets
```

**Confirm the fix:**
```bash
bash scripts/lib/checks/doppler-validator.sh
# All lines should show no ISSUE entries
```

---

### Scenario C: Process running, health check timing out

The process started and is alive, but `http://localhost:<PORT>` is not responding.

```bash
# Step 1: Confirm the process is alive
DEV_PID=$(scripts/devos-dev-server-registry.sh list --format pid 2>/dev/null | head -1)
kill -0 "$DEV_PID" 2>/dev/null && echo "Process $DEV_PID alive" || echo "Process gone"

# Step 2: Check what port the app actually bound to
ss -tlnp 2>/dev/null | grep "$DEV_PID"
# OR
lsof -p "$DEV_PID" -i 2>/dev/null | grep LISTEN

# Step 3: Check if app reported a different port in its startup output
# (App may have auto-incremented to 3001 if 3000 was briefly occupied)
curl -s -o /dev/null -w "%{http_code}" http://localhost:3001
# If 200 → app bound to 3001, not 3000; re-register with correct port

# Step 4: Try hitting the app directly
curl -v http://localhost:3000 2>&1 | head -20
# "Connection refused" → process not listening on 3000
# "Timeout" → process listening but not responding (framework not initialized yet)
```

**If app bound to wrong port:**
```bash
# Unregister incorrect entry
scripts/devos-dev-server-registry.sh unregister <NAME>
# Re-register with correct port
scripts/devos-dev-server-registry.sh register <NAME> 3001 "$DEV_PID"
```

---

### Scenario D: Port conflict (EADDRINUSE)

Port is occupied before the server can bind.
→ See `profiles/general/runbooks/port-conflict-resolution.md` for the full procedure.

**Quick resolution:**
```bash
# Find and kill occupying process
lsof -ti:3000 | xargs kill -TERM 2>/dev/null
sleep 3
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
# Retry startup
```

---

### Scenario E: Convex-specific startup failure

```bash
# Check Convex auth status
npx convex whoami 2>/dev/null || echo "Not authenticated"

# Re-authenticate if needed
npx convex login

# Check CONVEX_DEPLOYMENT secret is set
doppler secrets --config dev --only-names 2>/dev/null | grep CONVEX_DEPLOYMENT

# Start Convex manually to see full error output
scripts/doppler-run.sh npx convex dev --local
# Read terminal — Convex will print specific error (e.g., "deployment not found")
```

**Common Convex errors:**

| Error | Fix |
|-------|-----|
| `deployment not found` | `CONVEX_DEPLOYMENT` secret value is wrong; update in Doppler |
| `unauthorized` | Run `npx convex login` |
| `Cannot connect` | Check if local Convex backend is already running on port 3210 |

---

## 4. Resolution Steps

### Path A: App crash fix

1. Run `scripts/doppler-run.sh bun run dev` in foreground to capture error
2. Resolve the specific error (install deps, fix code, set missing secrets)
3. Re-run the `local-dev-startup.md` pipeline from Step 5

### Path B: Missing secret fix

1. Run `bash scripts/lib/checks/doppler-validator.sh` to list all missing keys
2. For each ISSUE: `doppler secrets set <KEY>="<VALUE>" --config dev`
3. Confirm: `bash scripts/lib/checks/doppler-validator.sh` shows no ISSUE lines
4. Re-run pipeline from Step 3

### Path C: Port mismatch fix

1. Identify actual bound port: `ss -tlnp | grep <PID>`
2. Unregister incorrect entry: `scripts/devos-dev-server-registry.sh unregister <NAME>`
3. Re-register with correct port: `scripts/devos-dev-server-registry.sh register <NAME> <ACTUAL_PORT> <PID>`
4. Confirm: `scripts/devos-dev-server-registry.sh list` shows correct port with healthy status

### Path E: Convex fix

1. `npx convex login` (if unauthorized)
2. Verify `CONVEX_DEPLOYMENT` in Doppler dev config matches actual deployment
3. Re-run `multi-server-dev.md` pipeline from Step 2

---

## 5. Validation

After applying the fix, confirm the server is fully operational:

```bash
# Check 1: Process is alive
ps aux | grep "bun run dev" | grep -v grep
# Expected: one matching line with correct PID

# Check 2: Port responding
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Expected: 2xx or 3xx (not "connection refused" or timeout)

# Check 3: Registry shows healthy
scripts/devos-dev-server-registry.sh list
# Expected: row with STATUS=healthy for the server name

# Check 4: All required secrets injected (run inside the server process)
# (Only possible if server has a debug/health endpoint — otherwise skip)
```

**Success threshold:** All three checks (1, 2, 3) pass simultaneously.

---

## 6. Rollback

No state-modifying rollback required — startup failure leaves no persistent state.

**Cleanup if partial state was written:**
```bash
# Remove stale registry entries from failed startup attempt
scripts/devos-dev-server-registry.sh cleanup-orphans
# Verify registry is clean
scripts/devos-dev-server-registry.sh list
# Expected: "No servers registered." or only currently running servers
```

---

## 7. Escalation

This runbook covers all known startup failure modes. If all scenarios have been
exhausted and the server still won't start:

1. Run the full diagnostic dump:
   ```bash
   echo "=== doppler me ===" && doppler me 2>&1
   echo "=== registry ===" && scripts/devos-dev-server-registry.sh list 2>&1
   echo "=== port 3000 ===" && ss -tlnp 2>/dev/null | grep ":3000" || lsof -i :3000 2>/dev/null
   echo "=== bun version ===" && bun --version
   echo "=== node version ===" && node --version
   ```
2. File a GitHub issue in the dev-os repo with the dump output
3. Use offline fallback while waiting:
   ```bash
   # Export secrets snapshot
   doppler secrets download --no-file --format env --config dev > .env.local.doppler
   echo ".env.local.doppler" >> .gitignore
   set -a; source .env.local.doppler; set +a
   bun run dev    # bare start without registry
   ```

---

## 8. Post-Incident

- [ ] Server is running and responding (Validation section passed)
- [ ] Registry is clean (`scripts/devos-dev-server-registry.sh list` shows correct state)
- [ ] If a missing secret caused the failure: confirm `.dev-os/pre-deployment.yml` `required_vars:` now includes it so future key checks catch it proactively
- [ ] If the failure revealed a new failure mode: add a row to the Triage Checklist above
- [ ] Update `Last reviewed` date in the metadata table

---

## 9. Related Runbooks

- `profiles/general/runbooks/port-conflict-resolution.md` — port EADDRINUSE failure
- `profiles/general/runbooks/doppler-local-dev-setup.md` — first-time Doppler setup
- `profiles/general/workflows/pipelines/local-dev-startup.md` — startup pipeline
- `profiles/general/workflows/pipelines/dev-server-teardown.md` — clean teardown
