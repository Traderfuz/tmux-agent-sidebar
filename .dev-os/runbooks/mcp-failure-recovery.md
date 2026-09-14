# Runbook: MCP Server Failure Recovery

| Field | Value |
|-------|-------|
| Service | MCP (Model Context Protocol) servers — 43 HTTP + STDIO servers configured in `~/.claude.json` |
| Runbook type | Incident |
| Severity | P2 (P1 if core-tier server affects active workflow) |
| Owner team | DevOS operator |
| Last reviewed | 2026-04-03 |
| Automation status | Semi-automated (`mcp-smoke-check.sh`, `dev-os-cli`) |

---

## 1. Trigger & Detection

**Trigger:** An MCP tool call fails during a session, or `mcp-ops` reports one or more servers in a non-PASS state.

**Symptoms:**
- Tool call returns an error (timeout, 401, 403, 502)
- `project-status` shows an MCP Health warning in the status panel
- Multiple unrelated MCP tools fail in rapid succession (suggests barrier token expiry)
- A specific server's tools all return errors while other servers work fine (suggests upstream API issue)

**Detection commands:**

```bash
# Fast init probe — detects server down, barrier token expired, worker not deployed (~3s)
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --probe-init

# Thorough functional probe — detects upstream 403s, expired API keys, plan limits
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --probe-functional

# Probe a single server by name
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --server <name>

# Machine-readable output for scripting
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --probe-functional --json
```

Or use the slash command interactively:

```
mcp-ops                    # Fast init probe
mcp-ops --functional       # Thorough probe on core-tier servers
mcp-ops --server <name>    # Single server probe
```

**State file:** Results are cached at `~/.dev-os/runtime/mcp-health-state.json` after every run.

---

## 2. Triage — Classify the Failure

Run the smoke check and classify each failing server using the status codes below. The classification determines which recovery path to follow.

| Status | Meaning | Likely Cause | Recovery Path |
|--------|---------|--------------|---------------|
| `AUTH-FAIL` (401) | Barrier token or API key rejected | Barrier JWT expired or signing secret rotated | Path A — Barrier Token Refresh |
| `UPSTREAM-FAIL` (403) | Worker connected but upstream API rejecting | API key expired, revoked, or plan limit hit | Path B — Upstream API Key Fix |
| `UPSTREAM-FAIL` (402) | Payment required | Upstream service plan limit reached | Path B — Upstream API Key Fix |
| `UPSTREAM-FAIL` (429) | Rate limited | Too many requests to upstream API | Path C — Wait and Retry |
| `DOWN` (502) | Worker unreachable | Cloudflare Worker crashed or not deployed | Path D — Worker Redeploy |
| `TIMEOUT` | No response within timeout window | Network issue, DNS failure, or worker hanging | Path D — Worker Redeploy |
| `FAIL` | Other unexpected response | Unknown — investigate response body | Path E — Manual Investigation |

**Mass AUTH-FAIL pattern:** If 3+ servers return AUTH-FAIL simultaneously, the barrier JWT is almost certainly expired. Skip per-server triage and go directly to Path A.

### Triage decision tree

```
Is the failure on 3+ servers simultaneously?
  YES → Is the status AUTH-FAIL on all of them?
    YES → Path A (barrier token expired)
    NO  → Check network connectivity (curl -s -o /dev/null -w "%{http_code}" https://cloudflare.com)
  NO → Single server failure:
    AUTH-FAIL  → Path A (check this server's specific auth)
    UPSTREAM-* → Path B (upstream API issue)
    429        → Path C (wait and retry)
    DOWN/TIMEOUT → Path D (redeploy worker)
    FAIL       → Path E (manual investigation)
```

---

## 3. Recovery Steps

### Path A: Barrier Token Refresh

All custom Cloudflare workers use a shared barrier JWT for authentication. The signing secret lives at `~/.barrier-secret`. Tokens are JWTs with an expiry date.

**Step 1: Check current token expiry**

```bash
# The smoke check script reports JWT expiry automatically
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --probe-init 2>&1 | head -5
# Look for: "Barrier JWT EXPIRED Nd ago" or "Barrier JWT expires in Nd"
```

**Step 2: Regenerate the barrier token**

```bash
cd ~/projects/reusable-code/mcp-workers/mcp-barrier-auth
node bin/generate-token.js
```

**Expected output:** A new JWT printed to stdout. The script also updates the relevant config files.

**Step 3: Sync the new token to all AI CLIs**

```bash
dev-os-cli
```

This runs `mcp-sync.sh` (propagates the new token to `~/.claude.json` and all other CLI configs) followed by `context-sync.sh`.

**Step 4: Verify**

```bash
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --probe-init
# All previously AUTH-FAIL servers should now show PASS
```

> **Important:** The signing secret is `~/.barrier-secret`. Do NOT use `~/projects/reusable-code/mcp-workers/.barrier-secret` — that file is stale.

---

### Path B: Upstream API Key Fix

The worker itself is healthy, but the upstream API behind it is rejecting calls. This typically means an API key expired, was revoked, or the plan limit was hit.

**Step 1: Identify the failing server and its upstream**

```bash
# Run with --fix to get per-server remediation hints
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --fix --server <name>
```

**Step 2: Check the worker's environment variables**

```bash
# Navigate to the worker source (paths from mcp-probe-registry.yml)
cd ~/projects/reusable-code/mcp-workers/cloudflare-mcp-workers/<server-name>-mcp

# Check current secrets
wrangler secret list
```

**Step 3: Update the upstream API key**

Obtain a new API key from the upstream service's dashboard, then:

```bash
# Set the new key as a Cloudflare Worker secret
echo "<new-api-key>" | wrangler secret put API_KEY
# (the exact secret name varies per worker — check wrangler.toml or the worker source)
```

**Step 4: Verify**

```bash
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --server <name>
# Should return PASS
```

---

### Path C: Wait and Retry (Rate Limiting)

**Step 1: Confirm rate limiting**

```bash
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --server <name>
# Status should be UPSTREAM-FAIL with 429
```

**Step 2: Wait and retry**

Most MCP upstream APIs have rate limit windows of 60 seconds. Wait 60-120 seconds and re-probe:

```bash
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --server <name>
```

**Step 3: If persistent**

If the 429 persists after 5 minutes, the account may have hit a daily or monthly quota. Check the upstream service's dashboard for usage limits.

---

### Path D: Worker Redeploy

The Cloudflare Worker is unreachable or returning 502.

**Step 1: Check the worker's logs**

```bash
cd ~/projects/reusable-code/mcp-workers/cloudflare-mcp-workers/<server-name>-mcp
wrangler tail
# Watch for errors in real-time (Ctrl+C to stop)
```

**Step 2: Redeploy the worker**

```bash
cd ~/projects/reusable-code/mcp-workers/cloudflare-mcp-workers/<server-name>-mcp
wrangler deploy
```

**Expected output:** Deployment success message with the worker URL.

**Step 3: Verify**

```bash
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --server <name>
# Should return PASS
```

**Step 4: If redeploy fails**

Check for build errors in the worker source. Common issues:
- Missing dependencies: `npm install` or `bun install` in the worker directory
- Wrangler auth expired: `wrangler login`
- Worker size limit exceeded: check for accidentally bundled large files

---

### Path E: Manual Investigation

For `FAIL` status or unclassified errors.

**Step 1: Get the raw response**

```bash
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --server <name> --json 2>&1
```

**Step 2: Check the server's config in `~/.claude.json`**

```bash
# Extract the server's URL and headers
python3 -c "
import json
with open('$HOME/.claude.json') as f:
    cfg = json.load(f)
srv = cfg.get('mcpServers', {}).get('<name>', {})
print(json.dumps(srv, indent=2))
"
```

**Step 3: Test connectivity manually**

```bash
# For HTTP servers — test the URL directly
curl -s -o /dev/null -w "HTTP %{http_code} in %{time_total}s\n" <server-url>
```

**Step 4: Check for STDIO server issues**

STDIO servers (context7, filesystem, memory, remotion) run in-process. Failures are immediate call errors. Check:
- The binary exists at the path specified in `~/.claude.json`
- Node.js / the runtime is available: `node --version`
- Dependencies are installed in the server's directory

---

## 4. Verification

After any recovery action, confirm the fix with the functional probe (not just init):

```bash
# Full functional verification
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --probe-functional --server <name>
```

**Success criteria:**
- Server status is `PASS`
- HTTP response code is 200
- Response time is under 10 seconds

**Full fleet verification (after barrier token rotation or mass recovery):**

```bash
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh --probe-functional --all
# Expected: 0 failures
```

Confirm the state file was updated:

```bash
python3 -c "
import json
with open('$HOME/.dev-os/runtime/mcp-health-state.json') as f:
    state = json.load(f)
print(f\"Last check: {state.get('timestamp', 'unknown')}\")
failures = [s for s, v in state.get('servers', {}).items() if v.get('status') != 'PASS']
print(f'Failures: {len(failures)}' + (f' — {failures}' if failures else ''))
"
```

---

## 5. Disabling a Server (Temporary Bypass)

When recovery is not immediately possible and the failing server is blocking work.

**When to disable vs. fix:**
- **Disable** if: the server is extended-tier, the upstream service is having an outage, or the fix requires credentials you don't have right now
- **Fix** if: the server is core-tier and needed for the current workflow, or the fix is a token refresh (< 2 minutes)

**How to disable:**

Edit `~/.claude.json` and comment out (or remove) the failing server from `mcpServers`. Then sync:

```bash
# After editing ~/.claude.json
dev-os-cli
```

Alternatively, add the server's tools to the deny list in permissions:

```json
{
  "permissions": {
    "deny": ["mcp__<server-name>__*"]
  }
}
```

**Re-enable after fix:** Restore the server config in `~/.claude.json` and run `dev-os-cli` again.

---

## 6. Escalation

| Condition | Action |
|-----------|--------|
| Core-tier server DOWN for > 10 minutes after redeploy | Check Cloudflare status page; open Cloudflare support ticket if platform issue |
| Barrier JWT regeneration fails | Verify `~/.barrier-secret` exists and is readable; re-create from secure backup |
| Upstream API key rotation needed but credentials unknown | Check Doppler (`doppler secrets`) or the upstream service's team dashboard |
| Mass failure across all HTTP servers | Check internet connectivity first, then Cloudflare status, then barrier JWT |
| STDIO server (context7, memory, filesystem) fails repeatedly | Check Node.js installation (`node --version`), reinstall the server package |

---

## 7. Prevention

- Run `mcp-ops` at the start of sessions that depend on MCP tools
- The maintenance-session pipeline includes an MCP health check at Step 1.5 — do not skip it
- Monitor barrier JWT expiry: the smoke check script warns when the token is within 7 days of expiry
- After any `~/.claude.json` edit, always run `dev-os-cli` to sync all CLIs
- Keep upstream API keys in Doppler where possible for centralized rotation
- The probe registry (`scripts/sync/mcp-probe-registry.yml`) must have an entry for every HTTP server — add entries when onboarding new servers

---

## 8. Server Tiers Reference

Core-tier servers are always probed and are critical for most workflows. Extended-tier servers are probed only with `--all`.

**Core tier:** brave-search, cloudflare-self, exa, github, google-workspace, linear, memory-http, perplexity, sentry, supabase, tavily, todoist, trends, vercel

**Extended tier:** apify, chroma, clerk, convex, dataforseo, figma, firecrawl, glif, google-maps, hostinger, jina-reader, lighthouse, listmonk, nano-banana, posthog, postiz, remotion-mcp, replicate, scrapecreators, search-console, stitch, twilio

**STDIO (in-process):** context7, filesystem, memory, remotion
