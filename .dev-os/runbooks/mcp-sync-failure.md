# Runbook: DevOS MCP Sync — Sync Failure Recovery

| Field | Value |
|-------|-------|
| Service | `mcp-sync.sh` — syncs MCP server configs from `~/.claude.json` or `~/.config/mcp-hub/servers.json` to Gemini, Antigravity, Codex, Kimi, and OpenCode |
| Runbook type | Incident + Operational |
| Severity | P2 (multiple CLIs broken) / P3 (single CLI broken) |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-08 |
| Automation status | Manual investigation; sync script automated once cause identified |

> **Scope boundary:** This runbook covers failures in the *sync pipeline* — configs not propagating to CLIs, wrong keys written, 0-server outputs. For MCP *tool call* failures during active sessions, see [`mcp-failure-recovery.md`](./mcp-failure-recovery.md).

---

## 1. Trigger & Detection

**Trigger conditions (any one initiates this runbook):**

1. `project-status` or `mcp-ops` reports one or more CLIs out of sync with the canonical registry
2. Antigravity MCP panel shows an error — specifically: `Error: serverURL or command must be specified`
3. After adding a new server, the server does not appear in Gemini/Codex/Kimi/OpenCode/Antigravity
4. After token rotation — CLIs still report the old server count or stale tokens

**Detection commands:**

```bash
# 1. Check sync health across all CLIs (~5s)
bash ~/.dev-os/scripts/sync/mcp-smoke-check.sh

# 2. Check Antigravity config directly
python3 -c "import json; d=json.load(open('$HOME/.gemini/antigravity/mcp_config.json')); print(f'Antigravity servers: {len(d.get(\"mcpServers\",{}))}')"

# 3. Check Codex server count
grep -c '^\[mcp_servers\.' ~/.codex/config.toml 2>/dev/null || echo "0 mcp_servers sections"

# 4. Check Kimi server count
python3 -c "import json; d=json.load(open('$HOME/.kimi/mcp.json')); print(f'Kimi servers: {len(d.get(\"mcpServers\",{}))}')"
```

**Expected baseline counts (after full sync from servers.json):**
- Gemini: ~27 servers
- Antigravity: ~27 servers
- Codex: ~27 servers (core-tier only — eager filter)
- Kimi: ~46 servers

---

## 2. Impact Assessment

**Triage checklist** — complete in order; stop when severity is confirmed:

- [ ] Is `~/.claude.json` itself working (Claude Code tools responding normally)? → Yes: Claude Code is unaffected; this is a CLI-sync-only issue (P2 or lower). No: escalate, root cause is upstream of sync.
- [ ] Are ALL five CLIs broken (Gemini, Antigravity, Codex, Kimi, OpenCode)? → Yes: likely a full-sync failure — go to **Step 5E** (full resync). No: one CLI broken — go to the matching path (5A–5D).
- [ ] Does Antigravity show `Error: serverURL or command must be specified`? → Yes: **P2 key-mismatch bug** — go to **Step 5A**.
- [ ] Does Codex show 0 `[mcp_servers.*]` sections? → Yes: go to **Step 5B**.
- [ ] Is the server count correct but specific servers are missing after adding a new one? → Yes: likely a missing-token or malformed-entry issue — go to **Step 5C** or **5D**.

**Blast radius:** Claude Code sessions are unaffected. All workflows that rely on Gemini, Codex, Kimi, Antigravity, or OpenCode for MCP tool access will see errors or missing tools. P2 applies when two or more CLIs are broken simultaneously.

---

## 3. Prerequisites

| Tool | Purpose | Install note |
|------|---------|--------------|
| `bash` | Run sync script and investigation commands | System default |
| `python3` | Embedded in `mcp-sync.sh`; used for JSON validation | System default |
| `jq` | Optional — faster JSON inspection | `apt install jq` / `brew install jq` |
| `~/.dev-os/scripts/sync/mcp-sync.sh` | The sync script | Must be executable: `chmod +x ~/.dev-os/scripts/sync/mcp-sync.sh` |
| `~/.config/mcp-hub/servers.json` | Hub registry (used with `--source servers.json`) | Created by mcp-hub setup |
| `~/.claude.json` | Canonical fallback source | Must exist and be valid JSON |

---

## 4. Investigation Steps

### Step 4.1 — Identify which CLI is broken

Run each check and note which returns an unexpected count:

```bash
# Gemini
python3 -c "import json; d=json.load(open('$HOME/.gemini/settings.json')); print(f'Gemini servers: {len(d.get(\"mcpServers\",{}))}')"

# Antigravity
python3 -c "import json; d=json.load(open('$HOME/.gemini/antigravity/mcp_config.json')); print(f'Antigravity servers: {len(d.get(\"mcpServers\",{}))}')"

# Codex
grep -c '^\[mcp_servers\.' ~/.codex/config.toml 2>/dev/null || echo "0"

# Kimi
python3 -c "import json; d=json.load(open('$HOME/.kimi/mcp.json')); print(f'Kimi servers: {len(d.get(\"mcpServers\",{}))}')"

# OpenCode
python3 -c "import json; d=json.load(open('$HOME/.config/opencode/config.json')); print(f'OpenCode servers: {len(d.get(\"mcp\",{}))}')"
```

**Decision tree:**

- Antigravity count is correct but panel shows `Error: serverURL or command must be specified` → **go to Step 5A**
- Codex count is 0 or dramatically lower than ~27 → **go to Step 5B**
- Any CLI count is 0 and sync has been run recently → **go to Step 4.2** (validate source JSON)
- A specific new server is missing from all CLIs → **go to Step 5D** (missing bearer token)
- All counts are wrong after token rotation → **go to Step 5E** (full resync)

### Step 4.2 — Validate source JSON

```bash
# Validate servers.json
python3 -c "import json; json.load(open('$HOME/.config/mcp-hub/servers.json')); print('servers.json: valid JSON')"

# Validate ~/.claude.json
python3 -c "import json; json.load(open('$HOME/.claude.json')); print('claude.json: valid JSON')"
```

Expected output: `servers.json: valid JSON` and `claude.json: valid JSON`

- If `JSONDecodeError` on `servers.json` → **go to Step 5C**
- If `JSONDecodeError` on `claude.json` → stop; restore `~/.claude.json` from backup before proceeding

### Step 4.3 — Verify sync script is executable

```bash
ls -la ~/.dev-os/scripts/sync/mcp-sync.sh
```

Expected: `-rwxr-xr-x` permissions. If not executable:

```bash
chmod +x ~/.dev-os/scripts/sync/mcp-sync.sh
```

### Step 4.4 — Run dry-run to preview sync output

```bash
MCP_SYNC_DRY_RUN=true bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json 2>&1 | head -60
```

- If dry-run output shows Python syntax errors → **go to Step 5E** (script bug)
- If dry-run shows "0 servers" for a CLI → **go to Step 5B** or **5D**
- If dry-run output looks correct but production run still fails → **go to Step 5E** (permissions or path issue)

---

## 5. Resolution Steps

### Path A — Antigravity `serverUrl` key mismatch

**Symptom:** Antigravity panel shows `Error: serverURL or command must be specified`. Config may have `url` instead of `serverUrl`.

**Root cause:** Antigravity requires `serverUrl` (camelCase capital U). A regression in `mcp-sync.sh` may have changed this to `url` (lowercase).

**Step 1 — Confirm the key in the written config:**

```bash
python3 -c "
import json
d = json.load(open('$HOME/.gemini/antigravity/mcp_config.json'))
servers = d.get('mcpServers', {})
first = next(iter(servers.values()), {}) if servers else {}
print('Keys in first HTTP entry:', list(first.keys()))
"
```

Expected output includes `serverUrl`. If you see `url` instead of `serverUrl`, the writer block has regressed.

**Step 2 — Confirm the sync script uses `serverUrl`:**

```bash
grep -n "serverUrl\|server_url\|serverURL" ~/.dev-os/scripts/sync/mcp-sync.sh
```

Expected line (~517): `entry = {"serverUrl": cfg["url"]}  # Antigravity schema uses serverUrl (camelCase)`

If the line reads `"url": cfg["url"]` instead, edit the script:

```bash
# Find the exact line
grep -n '"url": cfg\["url"\]' ~/.dev-os/scripts/sync/mcp-sync.sh
```

Then open `~/.dev-os/scripts/sync/mcp-sync.sh` and change:
```python
entry = {"url": cfg["url"]}
```
to:
```python
entry = {"serverUrl": cfg["url"]}  # Antigravity schema uses serverUrl (camelCase)
```

**Step 3 — Re-run sync for Antigravity only:**

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json --cli antigravity
```

Expected output: `[mcp-sync] antigravity — N servers, M skipped`

**Step 4 — Restart Antigravity** to pick up the new config (Antigravity reads config at startup).

---

### Path B — Codex getting 0 servers

**Symptom:** `grep -c '^\[mcp_servers\.' ~/.codex/config.toml` returns 0 or unexpectedly low count.

**Root cause candidates:**
1. Codex writer's `--source servers.json` logic branch is not executing
2. All servers are being skipped by the tier filter (none match `CORE_SERVERS`)
3. `~/.codex/config.toml` is being written but to wrong path

**Step 1 — Verify environment variable is set before Codex Python block runs:**

```bash
MCP_SYNC_SOURCE_SERVERS_JSON=true python3 -c "print('env var readable')"
```

**Step 2 — Run Codex sync with verbose output:**

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json --cli codex 2>&1
```

Look for `[SKIP]` lines — if every server is being skipped, the tier filter is excluding them all.

**Step 3 — Check tier config:**

```bash
python3 -c "
import json, os
tiers_path = os.path.expanduser('~/.dev-os/scripts/sync/mcp-tiers.json')
d = json.load(open(tiers_path))
print(f'Core servers: {d.get(\"core_servers\", [])}')
"
```

If `core_servers` is empty or missing, the Codex writer will skip everything.

**Step 4 — Verify config.toml path:**

```bash
ls -la ~/.codex/config.toml
```

If the file does not exist: `touch ~/.codex/config.toml` then re-run sync.

**Step 5 — Re-run Codex sync:**

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json --cli codex
```

Expected: `[mcp-sync] codex — N servers, M skipped` where N > 0.

---

### Path C — `servers.json` malformed or missing entry

**Symptom:** Sync runs but one or more servers are absent from all CLIs; or `python3` raises `JSONDecodeError` when loading servers.json.

**Step 1 — Validate JSON and identify the bad entry:**

```bash
python3 -c "
import json
with open('$HOME/.config/mcp-hub/servers.json') as f:
    content = f.read()
try:
    d = json.loads(content)
    print(f'Valid JSON. {len(d.get(\"servers\", []))} servers listed.')
except json.JSONDecodeError as e:
    print(f'JSON error: {e}')
    # Print surrounding lines
    lines = content.splitlines()
    lineno = e.lineno - 1
    for i in range(max(0, lineno-3), min(len(lines), lineno+4)):
        marker = '>>>' if i == lineno else '   '
        print(f'{marker} {i+1}: {lines[i]}')
"
```

**Step 2 — If a bad entry is identified**, open the file and fix the malformed JSON:

```bash
# Check which entry is problematic
python3 -c "
import json
d = json.load(open('$HOME/.config/mcp-hub/servers.json'))
for s in d.get('servers', []):
    name = s.get('name', 'UNNAMED')
    has_url = bool(s.get('url'))
    has_cmd = bool(s.get('command'))
    if not has_url and not has_cmd:
        print(f'[WARN] {name}: no url and no command — will be skipped')
"
```

**Step 3 — Repair** the entry by adding the missing `url` or `command` field, then re-run:

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json
```

---

### Path D — Missing bearer token (server skipped silently)

**Symptom:** A specific server appears in `servers.json` but does not appear in Codex or Kimi after sync (silent skip due to missing `Authorization` header).

**Step 1 — Confirm the server has no token in servers.json:**

```bash
python3 -c "
import json
d = json.load(open('$HOME/.config/mcp-hub/servers.json'))
target = '<SERVER_NAME>'  # replace with server name
for s in d.get('servers', []):
    if s.get('name') == target:
        headers = s.get('headers', {})
        auth = headers.get('Authorization', '')
        print(f'{target} auth header: {repr(auth) or \"MISSING\"}')"
```

**Step 2 — Add the token to `~/.codex/mcp-tokens.env`** (for Codex; Kimi uses inline headers):

```bash
# Find the current token from ~/.claude.json
python3 -c "
import json
d = json.load(open('$HOME/.claude.json'))
srv = d.get('mcpServers', {}).get('<SERVER_NAME>', {})
headers = srv.get('metadata', {}).get('headers', srv.get('headers', {}))
print(headers.get('Authorization', 'NOT FOUND'))
"
```

Then append to mcp-tokens.env:

```bash
echo 'export CODEX_MCP_TOKEN_<SAFE_SERVER_NAME>="<TOKEN_VALUE>"' >> ~/.codex/mcp-tokens.env
```

Where `<SAFE_SERVER_NAME>` = server name uppercased with hyphens replaced by underscores (e.g., `my-server` → `MY_SERVER`).

**Step 3 — Re-run sync:**

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json
```

---

### Path E — Full resync (all CLIs or unknown cause)

Use this path when: (a) multiple CLIs are broken, (b) dry-run shows errors, (c) after any token rotation, or (d) as a clean-slate fix when the specific cause is unclear.

**Step 1 — Dry run first (non-destructive):**

```bash
MCP_SYNC_DRY_RUN=true bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json 2>&1
```

Review output for errors. If the dry run shows Python tracebacks, the script has a syntax or logic error — do NOT proceed to step 2; investigate the script itself at `~/.dev-os/scripts/sync/mcp-sync.sh`.

If dry run output looks clean (lists server counts per CLI), proceed.

**Step 2 — Back up existing configs (before overwriting):**

```bash
BACKUP_DIR="$HOME/.mcp-sync-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
/usr/bin/cp ~/.gemini/settings.json "$BACKUP_DIR/gemini-settings.json" 2>/dev/null || true
/usr/bin/cp ~/.gemini/antigravity/mcp_config.json "$BACKUP_DIR/antigravity-mcp_config.json" 2>/dev/null || true
/usr/bin/cp ~/.codex/config.toml "$BACKUP_DIR/codex-config.toml" 2>/dev/null || true
/usr/bin/cp ~/.codex/mcp-tokens.env "$BACKUP_DIR/codex-mcp-tokens.env" 2>/dev/null || true
/usr/bin/cp ~/.kimi/mcp.json "$BACKUP_DIR/kimi-mcp.json" 2>/dev/null || true
/usr/bin/cp ~/.config/opencode/config.json "$BACKUP_DIR/opencode-config.json" 2>/dev/null || true
echo "Backup written to: $BACKUP_DIR"
```

**Step 3 — Run full sync:**

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json
```

Expected output (one line per CLI):

```
[mcp-sync] gemini — 27 servers, X skipped
[mcp-sync] antigravity — 27 servers, X skipped
[mcp-sync] codex — 27 servers, X skipped
[mcp-sync] kimi — 46 servers, X skipped
[mcp-sync] opencode — 46 servers, X skipped
[mcp-sync] Done. Canonical: 46 servers.
```

If any CLI shows 0 servers → go to the matching path (A–D) for that CLI.

---

## 6. Validation

After any resolution step, verify each affected CLI shows the correct count:

```bash
# Gemini
python3 -c "import json; d=json.load(open('$HOME/.gemini/settings.json')); n=len(d.get('mcpServers',{})); ok='OK' if n>=25 else 'LOW'; print(f'Gemini: {n} servers [{ok}]')"

# Antigravity
python3 -c "import json; d=json.load(open('$HOME/.gemini/antigravity/mcp_config.json')); n=len(d.get('mcpServers',{})); ok='OK' if n>=25 else 'LOW'; print(f'Antigravity: {n} servers [{ok}]')"

# Codex (core-tier only — ~27 expected)
N=$(grep -c '^\[mcp_servers\.' ~/.codex/config.toml 2>/dev/null || echo 0); [ "$N" -ge 20 ] && echo "Codex: $N servers [OK]" || echo "Codex: $N servers [LOW]"

# Kimi
python3 -c "import json; d=json.load(open('$HOME/.kimi/mcp.json')); n=len(d.get('mcpServers',{})); ok='OK' if n>=40 else 'LOW'; print(f'Kimi: {n} servers [{ok}]')"

# OpenCode
python3 -c "import json; d=json.load(open('$HOME/.config/opencode/config.json')); n=len(d.get('mcp',{})); ok='OK' if n>=40 else 'LOW'; print(f'OpenCode: {n} servers [{ok}]')"
```

**Success thresholds:**
| CLI | Minimum acceptable count |
|-----|--------------------------|
| Gemini | ≥ 25 servers |
| Antigravity | ≥ 25 servers |
| Codex | ≥ 20 servers (core-tier filter) |
| Kimi | ≥ 40 servers |
| OpenCode | ≥ 40 servers |

All outputs must show `[OK]`. Any `[LOW]` result means sync did not fully succeed — return to investigation.

**Antigravity key validation (Path A specific):**

```bash
python3 -c "
import json
d = json.load(open('$HOME/.gemini/antigravity/mcp_config.json'))
http_entries = [(n, list(v.keys())) for n, v in d.get('mcpServers',{}).items() if 'serverUrl' in v or 'url' in v]
if any('url' in keys and 'serverUrl' not in keys for _, keys in http_entries):
    print('FAIL: found url key without serverUrl — Antigravity will reject these entries')
else:
    print('OK: all HTTP entries use serverUrl key')
"
```

---

## 7. Rollback

**Trigger condition for rollback:** After running sync, one or more CLIs shows a server count of 0 or the backup count was higher than the new count.

**Step 1 — Identify the backup directory:**

```bash
ls -ltd ~/.mcp-sync-backup-* | head -5
```

**Step 2 — Restore from the most recent backup:**

```bash
BACKUP_DIR="<BACKUP_PATH>"  # e.g. ~/.mcp-sync-backup-20260408-143022

/usr/bin/cp "$BACKUP_DIR/gemini-settings.json" ~/.gemini/settings.json
/usr/bin/cp "$BACKUP_DIR/antigravity-mcp_config.json" ~/.gemini/antigravity/mcp_config.json
/usr/bin/cp "$BACKUP_DIR/codex-config.toml" ~/.codex/config.toml
/usr/bin/cp "$BACKUP_DIR/codex-mcp-tokens.env" ~/.codex/mcp-tokens.env
/usr/bin/cp "$BACKUP_DIR/kimi-mcp.json" ~/.kimi/mcp.json
/usr/bin/cp "$BACKUP_DIR/opencode-config.json" ~/.config/opencode/config.json
echo "Rollback complete from $BACKUP_DIR"
```

**Step 3 — Re-validate counts** using the validation commands in Section 6. All CLIs should return to pre-sync counts.

> **Note:** If no backup was taken before sync (you went straight to Step 5E without Step 5E.2), the last-known-good configs are not restorable via this runbook. In that case, restore from `git log` if the configs are tracked, or re-run sync after fixing the root cause script bug.

---

## 8. Communication

**P2 (multiple CLIs broken):** No external stakeholders. This is a single-operator workstation. Log the incident in the session notes.

**P3 (single CLI broken):** No communication required; fix inline.

**If the root cause was a script bug in `mcp-sync.sh`**, file a bug report:

> Title: `fix(mcp-sync): <writer name> key mismatch — <symptom>`
> Body: which key was wrong, which CLI was affected, the exact error message seen, the fix applied.

---

## 9. Post-Incident / Post-Task

**Cleanup:**

```bash
# Remove backup dirs older than 7 days (once incident is confirmed resolved)
find ~/.mcp-sync-backup-* -maxdepth 0 -mtime +7 -exec /usr/bin/rm -rf {} \; 2>/dev/null || true
```

**If the root cause was a writer bug (Path A or B):**
1. Commit the fix to `mcp-sync.sh` with a `fix(mcp-sync):` prefix commit message
2. Add a regression test: after sync, verify the Antigravity config contains `serverUrl` not `url` in at least one HTTP entry
3. Consider adding the key-validation check from Section 6 to `mcp-smoke-check.sh` so future regressions are caught automatically

**If the root cause was a malformed `servers.json` entry (Path C):**
1. Identify which tool wrote the bad entry (mcp-hub, manual edit, token refresh script)
2. Add a JSON validation step to `antigravity-token-refresh.sh` before it writes to servers.json

**Runbook update note:** If you fixed a step that did not work as described, edit this file to reflect the actual working procedure before closing the incident.

---

## 10. Related Runbooks

| Runbook | When to use |
|---------|-------------|
| [`mcp-failure-recovery.md`](./mcp-failure-recovery.md) | MCP *tool call* failures during an active session (timeouts, 401, 503) — not sync failures |
| [`version-upgrade-rollback.md`](./version-upgrade-rollback.md) | If `mcp-sync.sh` itself was recently updated and the new version introduced the bug |
| [`symlink-repair.md`](./symlink-repair.md) | If `~/.dev-os/` symlink is broken and `mcp-sync.sh` cannot be found at its expected path |
