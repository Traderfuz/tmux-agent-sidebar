# Local Dev Server Startup Pipeline

Orchestrates the full local development server startup sequence: Doppler auth verification,
project config pinning check, required API key surfacing, port availability gate, server
process start with secret injection, registry registration, and health-check confirmation.

All steps follow the local-first-development standard — secrets are injected via Doppler
before the process starts, and required API keys are surfaced to the developer before the
server is allowed to register as healthy.

## When to Use

- Starting the development server for any Doppler-enabled project
- After cloning a repository for the first time (`start` has been run)
- When returning to a project after the server was stopped or the machine restarted
- Before running `e2e` or `test` that require a live local server
- As the prerequisite step before Step 8 (test/harden) in `feature-delivery.md`

**Anti-triggers — do NOT use this pipeline when:**
- The project has no Doppler integration (no `.doppler.yaml`) — start server directly via `bun run dev`
- The project has no `package.json` (Bash/CLI-only projects have no `dev` script — this pipeline is web/Node-specific)
- Running in CI/CD (CI manages its own environment injection)
- The server is already running (`scripts/devos-dev-server-registry.sh list` shows it healthy)

## Prerequisites

- DevOS initialized in project (`.dev-os/config.yml` exists)
- Doppler CLI installed (`which doppler`)
- `bun` available (`which bun`)
- Project has a `dev` script in `package.json` (this pipeline is for Node/web projects only — see Anti-triggers above for Bash/CLI projects)

## Process

1. Verify Doppler authentication (`doppler me`).
2. Check project config pin and surface required API keys.
3. Gate on port availability.
4. Start dev server with Doppler secret injection.
5. Register server in `server-registry.json`.
6. Confirm health check passes.

## Steps

### Step 1: Doppler Authentication Check

**Input:** Active shell session
**Output:** Confirmed Doppler identity or halt with remediation
**Gate to next step:** `doppler me` exits 0
**Skip if:** `DEVOS_SKIP_DOPPLER_CHECK=1` is set (offline mode — see deviation guidance)

```bash
doppler me
```

**On success:** Continue to Step 2.

**On failure (not authenticated):**
```
✗ Doppler authentication required

  Run: doppler login
  Then retry this pipeline.

  Offline fallback (no network):
    set -a; source .env.local.doppler; set +a
    (see local-first-development.md offline section)
```
Halt. Do not proceed to Step 2.

### Step 2: `.doppler.yaml` Project Pin Check

**Input:** Project root directory
**Output:** Confirmed project pin or halt with scaffold instruction
**Gate to next step:** `.doppler.yaml` exists at project root with `project:` and `config:` keys
**Skip if:** `DEVOS_SKIP_DOPPLER_CHECK=1`

```bash
[ -f .doppler.yaml ] && grep -q "^project:" .doppler.yaml && grep -q "^config:" .doppler.yaml
```

**On success:** Read and display the pin:
```
✓ Doppler project pin found
  Project: my-app-supabase
  Config:  dev
```

**On failure (absent or incomplete):**
```
✗ .doppler.yaml not found or incomplete

  This file pins the Doppler project and config for all local tooling.
  It is safe to commit — it contains no secrets.

  Create it:
    doppler setup                                      # interactive (recommended)
    # OR
    printf 'project: <slug>\nconfig: dev\n' > .doppler.yaml

  Then commit:
    git add .doppler.yaml && git commit -m "chore: pin Doppler project config"

  Reference: profiles/general/standards/global/doppler-dev-config.md
```
Halt. Do not proceed to Step 3.

### Step 3: Required API Keys Check

**Input:** `.doppler.yaml` (project slug), `.dev-os/pre-deployment.yml` (required_vars)
**Output:** Key presence report surfaced to developer; ISSUE-level failures halt; WARNING-level continues
**Gate to next step:** Zero ISSUE-level missing keys
**Skip if:** `DEVOS_SKIP_KEY_CHECK=1`

```bash
bash scripts/lib/checks/doppler-validator.sh
```

**On all keys present:**
```
✓ Doppler dev secrets verified
  Project: my-app-supabase  Config: dev
  Required keys present (4/4):
    ✓ DATABASE_URL
    ✓ NEXTAUTH_SECRET
    ✓ NEXTAUTH_URL
    ✓ CONVEX_DEPLOYMENT
```
Continue to Step 4.

**On ISSUE-level missing keys (halt):**
```
✗ Required Doppler secrets missing — dev server blocked
  Project: my-app-supabase  Config: dev

  MISSING (required):
    ✗ DATABASE_URL
    ✗ NEXTAUTH_SECRET

  Fix:
    doppler secrets set DATABASE_URL="postgres://..." NEXTAUTH_SECRET="..." \
      --project my-app-supabase --config dev
    # OR
    doppler open dashboard   # manage in browser

  Retry after fixing.
```
Halt. Do not proceed to Step 4.

**On WARNING-level optional keys absent (non-blocking):**
```
  ⚠ Optional keys absent (degraded functionality):
    ⚠ POSTHOG_KEY   → Analytics disabled
    ⚠ RESEND_API_KEY → Email sending disabled
```
Continue to Step 4.

**On no `required_vars:` declared in `.dev-os/pre-deployment.yml`:**
```
  ⚠ No required_vars declared in .dev-os/pre-deployment.yml
    Auto-detecting from package.json and .env.example patterns.
    Declare required_vars explicitly for reliable key checking.
    Reference: profiles/general/standards/global/doppler-dev-config.md
```
Continue with auto-detected keys.

### Step 4: Port Availability Check

**Input:** Target port (read from `package.json` → `"dev"` script, default 3000)
**Output:** Confirmed port free, or occupying process identified
**Gate to next step:** Target port is not in use
**Skip if:** `DEVOS_SKIP_PORT_CHECK=1`

```bash
# Detect port from package.json dev script (grep for common port flags)
PORT=$(node -e "const p=require('./package.json'); const m=p.scripts?.dev?.match(/(?:--port|-p)\s+(\d+)/); console.log(m?.[1]||'3000')" 2>/dev/null || echo "3000")

# Check availability (Linux/macOS portable)
ss -tlnp 2>/dev/null | grep ":${PORT} " || lsof -i ":${PORT}" 2>/dev/null || true
```

**On port free:**
```
✓ Port 3000 available
```
Continue to Step 5.

**On port occupied:**
```
✗ Port 3000 is already in use

  Occupying process:
    PID: 12345   Name: node

  Options:
    kill 12345                                    # kill the process
    scripts/devos-dev-server-registry.sh cleanup-orphans  # clean stale registry entries
    PORT=3001 scripts/doppler-run.sh bun run dev  # use alternate port

  Reference: profiles/general/runbooks/port-conflict-resolution.md
```
Halt. Do not proceed to Step 5.

### Step 5: Start Dev Server

**Input:** `scripts/doppler-run.sh`, project `package.json` dev script
**Output:** Server process PID
**Gate to next step:** Process starts without immediate exit (PID exists after 2s)

**Single server (default):**
```bash
scripts/doppler-run.sh bun run dev &
DEV_PID=$!
sleep 2
kill -0 "$DEV_PID" 2>/dev/null || { echo "✗ Dev server exited immediately — check logs"; exit 1; }
```

**Multi-server variant (Convex + app):**
If `convex/` directory or `convex.config.ts` exists at project root:

```bash
# Terminal 1 equivalent — Convex backend
scripts/doppler-run.sh npx convex dev --local &
CONVEX_PID=$!

sleep 3   # allow Convex to initialize before app starts

# Terminal 2 equivalent — App server
scripts/doppler-run.sh bun run dev &
APP_PID=$!
```

**On immediate exit:**
```
✗ Dev server exited immediately (PID no longer alive)

  Check: the last few lines of terminal output above for the error.
  Common causes:
    - Missing required environment variable (re-check Step 3)
    - Port conflict (re-check Step 4)
    - Build error in source files
    - Missing dependency (run: bun install)
```
Halt.

### Step 6: Register with Dev Server Registry

**Input:** Server name (project directory name), port, PID
**Output:** Registry entry written to `~/.dev-os/runtime/server-registry.json`
**Gate to next step:** Registry command exits 0
**Skip if:** `DEVOS_SKIP_REGISTRY=1`

```bash
SERVER_NAME=$(basename "$PWD")
scripts/devos-dev-server-registry.sh register "$SERVER_NAME" "$PORT" "$DEV_PID"

# Multi-server variant:
# scripts/devos-dev-server-registry.sh register convex-dev 3210 "$CONVEX_PID"
# scripts/devos-dev-server-registry.sh register app-server 3000 "$APP_PID"
```

### Step 7: Health Check

**Input:** `http://localhost:<port>`
**Output:** HTTP 200 confirmation, or timeout with cleanup hint
**Gate to next step:** Server returns HTTP 200 within 30 seconds
**Poll interval:** 3 seconds (10 attempts)

```bash
MAX_WAIT=30
INTERVAL=3
elapsed=0

while [ $elapsed -lt $MAX_WAIT ]; do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}" 2>/dev/null | grep -q "^[23]"; then
    break
  fi
  sleep $INTERVAL
  elapsed=$((elapsed + INTERVAL))
done

if [ $elapsed -ge $MAX_WAIT ]; then
  echo "✗ Health check timed out after ${MAX_WAIT}s"
  echo "  Cleaning up registry entry..."
  scripts/devos-dev-server-registry.sh unregister "$SERVER_NAME"
  exit 1
fi
```

**Multi-server variant:** Health check both `http://localhost:3210` (Convex) and
`http://localhost:3000` (app) before emitting ready signal. Both must pass.

**On timeout:**
```
✗ Health check timed out — server did not respond within 30s

  Registry cleaned up. Server process may still be running:
    kill $DEV_PID   # if PID is known

  Cleanup orphans:
    scripts/devos-dev-server-registry.sh cleanup-orphans

  Reference: profiles/cli/runbooks/dev-server-startup-failure.md
```

### Step 8: Ready Signal

**Input:** Health check success from Step 7
**Output:** Ready confirmation + registry summary
**Gate to completion:** Step 7 passed

```
✓ Dev server ready

  http://localhost:3000 (app-server)
  http://localhost:3210 (convex-dev)   ← multi-server only

Running servers:
```

```bash
scripts/devos-dev-server-registry.sh list
```

Output format:
```
NAME          PORT   PID     STATUS   STARTED
app-server    3000   12345   healthy  2026-04-13T09:15:00Z
convex-dev    3210   12346   healthy  2026-04-13T09:14:57Z

Next: run test or open http://localhost:3000
```

## Dependency Graph

```
Step 1: doppler me
  │
  ▼
Step 2: .doppler.yaml check
  │
  ▼
Step 3: required API keys check (doppler-validator.sh)
  │
  ▼
Step 4: port availability check
  │
  ▼
Step 5: start dev server (doppler-run.sh bun run dev)
  │
  ▼
Step 6: register (devos-dev-server-registry.sh)
  │
  ▼
Step 7: health check (curl poll, 30s timeout)
  │
  ▼
Step 8: ready signal + registry list
```

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Doppler not authenticated | Run `doppler login`, retry |
| Step 2 | `.doppler.yaml` absent | Run `doppler setup`, commit file, retry |
| Step 3 | ISSUE-level keys missing | Set missing keys via `doppler secrets set`, retry |
| Step 3 | `pre-deployment.yml` absent | Scaffold file from `.env.example`, retry |
| Step 4 | Port occupied | Kill occupying process or use alternate port |
| Step 5 | Immediate process exit | Check build errors, missing deps (`bun install`), re-check Step 3 |
| Step 6 | Registry write fails | Check `~/.dev-os/runtime/` permissions; run with `DEVOS_SKIP_REGISTRY=1` to bypass |
| Step 7 | Health check timeout | Consult `runbooks/dev-server-startup-failure.md`; cleanup orphans |
| Step 7 | Server returns non-2xx/3xx | Check server logs for startup error; re-check Step 3 keys |

## Teardown

To stop the dev server cleanly after this pipeline, run the `dev-server-teardown.md` pipeline.
It gracefully signals the registered processes and cleans up registry entries.

```bash
# Quick teardown without the full pipeline:
scripts/devos-dev-server-registry.sh unregister app-server
scripts/devos-dev-server-registry.sh cleanup-orphans
```

## References

- `scripts/doppler-run.sh` — branch-aware Doppler runner (canonical dev invocation)
- `scripts/lib/dev-server.sh` — `dev_server_start()`, health check, registry locking
- `scripts/devos-dev-server-registry.sh` — server registry CLI (register, list, unregister, cleanup-orphans)
- `scripts/lib/checks/doppler-validator.sh` — required key checker
- `profiles/general/standards/global/local-first-development.md` — local-first standard
- `profiles/general/standards/global/doppler-dev-config.md` — Doppler project pin standard
- `profiles/cli/runbooks/dev-server-startup-failure.md` — failure recovery runbook
- `profiles/general/runbooks/port-conflict-resolution.md` — port conflict runbook
- `profiles/general/workflows/pipelines/dev-server-teardown.md` — teardown pipeline

## Display Format

```
Local Dev Server Startup
  Doppler:  authenticated ✓
  Config:   pinned ✓
  Port:     [N] available ✓
  Server:   started (PID [N])
  Health:   [healthy | checking...]
  Registry: registered ✓
```
