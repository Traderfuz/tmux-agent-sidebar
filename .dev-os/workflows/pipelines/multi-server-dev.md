# Multi-Server Dev Startup Pipeline

Coordinates startup of multiple interdependent development servers (e.g., Convex backend + Next.js
application) with Doppler secret injection, sequenced startup order, combined health checks, and
unified registry registration. Extends `local-dev-startup.md` for projects requiring more than
one concurrent process.

## When to Use

- Projects with a Convex backend (`convex/` directory or `convex.config.ts` present)
- Projects with a separate API server running alongside the frontend
- Any setup where the app server depends on a backend service being available first
- When `local-dev-startup.md` Step 5 detects multiple server requirements

**Anti-triggers:**
- Single-server projects — use `local-dev-startup.md` directly
- CI/CD environments
- Projects where the app connects to a hosted (non-local) backend


- Anti-trigger: do NOT use for single-server projects — use `local-dev-startup.md` instead

## Prerequisites

- All `local-dev-startup.md` prerequisites met (Doppler auth, `.doppler.yaml`, required keys, ports)
- Steps 1–4 of `local-dev-startup.md` completed and passed
- `bun`, `npx`, and `convex` CLI available (for Convex variant)

## Standard Multi-Server Configuration

### Convex + Next.js (most common)

| Server | Command | Port | Registry Name | Start Order |
|--------|---------|------|---------------|-------------|
| Convex backend | `npx convex dev --local` | 3210 | `convex-dev` | First |
| Next.js app | `bun run dev` | 3000 | `app-server` | After Convex ready |

### Generic API + Frontend

| Server | Command | Port | Registry Name | Start Order |
|--------|---------|------|---------------|-------------|
| API server | `bun run dev:api` | 4000 | `api-server` | First |
| Frontend | `bun run dev` | 3000 | `app-server` | After API ready |

## Process

1. Detect required servers from project config.
2. Start each server with Doppler secret injection in the correct order.
3. Register each server in the dev server registry.
4. Confirm health check passes for all servers.

## Steps

### Step 1: Run `local-dev-startup.md` Steps 1–4

Complete all preflight checks from `local-dev-startup.md`:
- Step 1: Doppler auth check
- Step 2: `.doppler.yaml` pin check
- Step 3: Required API keys check
- Step 4: Port availability check for ALL required ports

```bash
# Check both ports before starting anything
ss -tlnp 2>/dev/null | grep ":3210 " && echo "✗ Port 3210 occupied" || echo "✓ Port 3210 free"
ss -tlnp 2>/dev/null | grep ":3000 " && echo "✗ Port 3000 occupied" || echo "✓ Port 3000 free"
```

**Gate:** Both ports free and all preflight checks passed.

### Step 2: Start Backend Server First

**Input:** Doppler-injected environment, backend start command
**Output:** Backend process PID; server beginning initialization
**Gate to next step:** Backend PID alive after 2s

```bash
# Convex variant:
echo "→ Starting Convex backend..."
scripts/doppler-run.sh npx convex dev --local &
BACKEND_PID=$!
sleep 2
kill -0 "$BACKEND_PID" 2>/dev/null || { echo "✗ Convex exited immediately"; exit 1; }

# Register immediately (health check follows)
scripts/devos-dev-server-registry.sh register convex-dev 3210 "$BACKEND_PID"
echo "✓ Convex backend started (PID: $BACKEND_PID)"
```

### Step 3: Wait for Backend to Signal Ready

**Input:** Backend health endpoint or log signal
**Output:** Backend confirmed accepting connections
**Gate to next step:** Backend health check passes within 60s
**Timeout:** 60 seconds (Convex initialization is slower than a typical HTTP server)

```bash
MAX_WAIT=60
INTERVAL=3
elapsed=0

echo "→ Waiting for Convex backend to be ready..."
while [ $elapsed -lt $MAX_WAIT ]; do
  # Convex HTTP API check
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3210" 2>/dev/null | grep -qE "^[23]"; then
    echo "✓ Convex backend ready at http://localhost:3210"
    break
  fi
  sleep $INTERVAL
  elapsed=$((elapsed + INTERVAL))
done

if [ $elapsed -ge $MAX_WAIT ]; then
  echo "✗ Convex backend did not respond within ${MAX_WAIT}s"
  echo "  Stopping Convex (PID $BACKEND_PID)..."
  kill "$BACKEND_PID" 2>/dev/null || true
  scripts/devos-dev-server-registry.sh unregister convex-dev
  exit 1
fi
```

### Step 4: Start App Server

**Input:** Doppler-injected environment, app start command
**Output:** App process PID
**Gate to next step:** App PID alive after 2s

```bash
echo "→ Starting app server..."
scripts/doppler-run.sh bun run dev &
APP_PID=$!
sleep 2
kill -0 "$APP_PID" 2>/dev/null || { echo "✗ App server exited immediately"; exit 1; }

scripts/devos-dev-server-registry.sh register app-server 3000 "$APP_PID"
echo "✓ App server started (PID: $APP_PID)"
```

### Step 5: Health Check Both Servers

**Input:** Both registered server URLs
**Output:** Combined health confirmation
**Gate to completion:** Both return HTTP 2xx/3xx within 30s

```bash
for check in "convex-dev:3210" "app-server:3000"; do
  name="${check%%:*}"
  port="${check##*:}"
  MAX_WAIT=30
  elapsed=0

  while [ $elapsed -lt $MAX_WAIT ]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}" 2>/dev/null | grep -qE "^[23]"; then
      echo "✓ ${name} healthy at http://localhost:${port}"
      break
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done

  if [ $elapsed -ge $MAX_WAIT ]; then
    echo "✗ ${name} health check timed out"
    scripts/devos-dev-server-registry.sh cleanup-orphans
    exit 1
  fi
done
```

### Step 6: Combined Ready Signal

```
✓ All dev servers ready

  http://localhost:3000  (app-server)
  http://localhost:3210  (convex-dev)

Running servers:
NAME          PORT   PID     STATUS   STARTED
app-server    3000   12345   healthy  2026-04-13T09:15:03Z
convex-dev    3210   12346   healthy  2026-04-13T09:14:57Z

Next: run test or open http://localhost:3000
To stop: run dev-server-teardown.md pipeline
```

## Dependency Graph

```
local-dev-startup Steps 1–4 (preflight: auth, pin, keys, ports)
  │
  ▼
Step 2: start backend (Convex / API)
  │
  ▼
Step 3: wait for backend ready (health check, 60s timeout)
  │
  ▼
Step 4: start app server
  │
  ▼
Step 5: health check both servers
  │
  ▼
Step 6: combined ready signal
```

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Either port occupied | See `port-conflict-resolution.md` runbook |
| Step 2 | Backend exits immediately | Check Convex auth (`npx convex whoami`), check CONVEX_DEPLOYMENT key |
| Step 3 | Backend health timeout | Stop backend, check logs, re-run |
| Step 4 | App server exits immediately | Re-check Step 3 key check; run `bun install` |
| Step 5 | App health timeout | Check for port bind errors in app logs |
| Any | Partial startup (one server up, other failed) | Run `dev-server-teardown.md` to clean up before retrying |

## References

- `profiles/general/workflows/pipelines/local-dev-startup.md` — single-server startup (Steps 1–4 run first)
- `profiles/general/workflows/pipelines/dev-server-teardown.md` — teardown pipeline
- `scripts/devos-dev-server-registry.sh` — registry CLI
- `scripts/doppler-run.sh` — canonical Doppler runner
- `scripts/lib/dev-server.sh` — `dev_server_start()` with health check internals

## Display Format

```
Multi-Server Dev Pipeline
  Servers started: [N] ([list of names])
  Ports:           [list]
  Health:          [all healthy | [N] unhealthy]
  Status:          [running | failed]
```
