# Runbook: DevOS MCP Infrastructure — Token Rotation

| Field | Value |
|-------|-------|
| Service | DevOS MCP Hub (lazy-mcp — 42 hub-proxied MCP servers) |
| Runbook type | Operational (scheduled / forced rotation) |
| Severity | P1 — expiry breaks ALL 42 hub-proxied MCP tools across ALL CLIs simultaneously |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-08 |
| Automation status | Partial — rotation script is semi-automated; sync step is fully automatable |

---

## 1. Trigger & Detection

This runbook is initiated by any of the following four conditions:

1. **Scheduled expiry warning** — fewer than 14 days remain until token expiry. Current expiry: `2026-07-07`. Set a calendar reminder 14 days prior (i.e., `2026-06-23`) to start this procedure.
2. **Forced rotation after suspected compromise** — bearer tokens have been exposed in logs, shared in a chat, or committed to version control.
3. **New MCP server added** — a new HTTP server was registered in `~/.config/mcp-hub/servers.json` and requires a fresh token.
4. **CLI tools returning 401 / 403 errors** — one or more AI CLIs (Claude Code, Codex, Gemini, Kimi, OpenCode) report authentication failures on hub-proxied tools.

### Detecting current expiry date

```bash
grep -i "expires\|expiry\|exp" ~/.config/mcp-hub/servers.json | head -5
```

Expected output (example):

```
  "expires": "2026-07-07",
```

If the field is absent, check the JWT payload directly:

```bash
# Extract the first token value from servers.json and decode its payload
python3 -c "
import json, base64, sys
data = json.load(open('${HOME}/.config/mcp-hub/servers.json'))
# Find first bearer token value
tokens = [v for v in str(data).split('Bearer ') if v.strip()]
if tokens:
    jwt = tokens[0].split()[0].strip('\\'\"')
    parts = jwt.split('.')
    if len(parts) == 3:
        pad = len(parts[1]) % 4
        payload = base64.urlsafe_b64decode(parts[1] + '=' * (4 - pad if pad else 0))
        print(json.dumps(json.loads(payload), indent=2))
"
```

---

## 2. Impact Assessment

### Blast radius

- **Scope:** ALL 42 hub-proxied MCP servers fail simultaneously. Direct entries (`memory`, `memory-http`, `reflection`) are NOT affected — they do not use the hub token.
- **Affected CLIs:** Claude Code, Codex, Gemini, Kimi, OpenCode.
- **Symptom:** MCP tool calls return `401 Unauthorized` or `403 Forbidden`. Claude Code may show tools as unavailable. Codex may show 0 servers loaded.

### Triage checklist — resolve severity in < 2 minutes

Work through these checks in order. Stop when severity is determined.

- [ ] **Are CLI tools returning 401/403 errors on hub-proxied calls?**
  → Yes: token is expired or wrong. Proceed to Section 4 (Investigation). Severity: **P1**.
  → No: error may be network or config issue — see Related Runbooks.

- [ ] **Do ALL 42 hub tools fail, or only a subset?**
  → All 42 fail: shared token is expired or revoked. Proceed with this runbook. Severity: **P1**.
  → Only 1–5 fail: individual server config issue, not a token-rotation problem. Check `servers.json` entry for that server specifically.

- [ ] **Is today within 14 days of the recorded expiry date?**
  → Yes: scheduled rotation. Severity: **P1 — planned**. Proceed with this runbook.
  → No, expiry is far out: forced rotation scenario (compromise or new server). Proceed with this runbook under Section 5 (forced path).

- [ ] **Is the compromise confirmed (token visible in logs/commits)?**
  → Yes: treat as **P1 — emergency**. Execute this runbook immediately. Also revoke the compromised token at the issuing service before generating a new one.
  → No: treat as **P1 — planned**. Proceed with the standard rotation procedure.

---

## 3. Prerequisites

### Required tools

| Tool | Check command | Expected output |
|------|--------------|----------------|
| `bash` | `bash --version` | `GNU bash, version 4.x` or higher |
| `antigravity-token-refresh.sh` | `which antigravity-token-refresh.sh \|\| ls ~/.local/bin/antigravity-token-refresh.sh` | Full path to script |
| `mcp-sync.sh` | `ls ~/.dev-os/scripts/sync/mcp-sync.sh` | File listed |
| `jq` | `jq --version` | `jq-1.x` |
| `python3` | `python3 --version` | `Python 3.x.x` |

### Required files

| File | Purpose |
|------|---------|
| `~/.config/mcp-hub/servers.json` | Hub server registry — tokens live here |
| `~/.codex/mcp-tokens.env` | Codex token mirror |
| `~/.codex/config.toml` | Codex MCP server config |
| `~/.claude.json` | Canonical MCP config for Claude Code |

### Backup before proceeding

```bash
cp ~/.config/mcp-hub/servers.json ~/.config/mcp-hub/servers.json.bak.$(date +%Y%m%d-%H%M%S)
cp ~/.codex/mcp-tokens.env ~/.codex/mcp-tokens.env.bak.$(date +%Y%m%d-%H%M%S)
```

Expected: two backup files created, no error output.

### Time estimate

- Planned rotation: 10–15 minutes.
- Emergency rotation (compromise): 20–30 minutes (includes revocation step at issuing service).

### Approval required

Forced rotation after compromise must be acknowledged by the dev-os team lead before execution. Scheduled rotation may proceed without explicit approval.

---

## 4. Investigation Steps

### Step I-1 — Confirm current token state

```bash
grep -c "Bearer\|token\|jwt" ~/.config/mcp-hub/servers.json
```

Expected output: a non-zero integer (e.g., `42`).
If output is `0`: tokens are not stored in the expected format — inspect the file manually with `jq . ~/.config/mcp-hub/servers.json | head -40`.

### Step I-2 — Check token expiry

```bash
grep "expires" ~/.config/mcp-hub/servers.json | head -3
```

Expected output (example):

```json
  "expires": "2026-07-07",
```

If no expiry field found: decode the JWT directly using the command in Section 1 (Detection).

### Step I-3 — Identify scope of failure

If tools are already failing, run a quick probe in Claude Code:

```bash
# In a new terminal — check mcp-hub process is running
pgrep -a mcp-hub
```

Expected output: a process line such as `12345 mcp-hub ...`.
If no output: mcp-hub is not running; start it or restart Claude Code.

### Step I-4 — Confirm antigravity script is available

```bash
antigravity-token-refresh.sh --help 2>&1 | head -5
# or if not in PATH:
bash ~/.local/bin/antigravity-token-refresh.sh --help 2>&1 | head -5
```

Expected output: usage instructions for the script.
If not found: the script may need to be located — check `find ~/.local/bin /usr/local/bin -name "antigravity*" 2>/dev/null`.

### Investigation decision tree

- **Expiry date is within 14 days or already past** → proceed to Section 5 (standard rotation).
- **401/403 errors on all 42 tools and expiry is past** → proceed to Section 5 (standard rotation, P1 priority).
- **401/403 errors on < 42 tools** → this is not a token rotation issue; check individual server entries in `servers.json` for malformed tokens.
- **Script `antigravity-token-refresh.sh` not found** → escalate to @Traderfuz via the dev-os team channel; do not attempt manual token generation.
- **Token confirmed compromised** → revoke at the issuing auth service first, then proceed to Section 5.

---

## 5. Resolution / Procedure Steps

> All commands are copy-pasteable. Substitute values shown in `<ANGLE_BRACKETS>` before running.

### Step 1 — Verify current token expiry (pre-rotation confirmation)

```bash
grep "expires" ~/.config/mcp-hub/servers.json | head -3
```

Expected output:

```json
  "expires": "2026-07-07",
```

If expiry is still > 14 days away and this is not a forced rotation, confirm intent before continuing. If < 14 days or past: proceed immediately.

---

### Step 2 — Create backups (if not done in Prerequisites)

```bash
cp ~/.config/mcp-hub/servers.json ~/.config/mcp-hub/servers.json.bak.$(date +%Y%m%d-%H%M%S)
cp ~/.codex/mcp-tokens.env ~/.codex/mcp-tokens.env.bak.$(date +%Y%m%d-%H%M%S)
```

Expected output: no output (silent success). Verify with:

```bash
ls -lt ~/.config/mcp-hub/servers.json.bak.* | head -3
```

If files not created: check write permissions on `~/.config/lazy-mcp/` and `~/.codex/`.

---

### Step 3 — Run token rotation

```bash
bash antigravity-token-refresh.sh --patch-servers-json
```

If the script is not in PATH:

```bash
bash ~/.local/bin/antigravity-token-refresh.sh --patch-servers-json
```

Expected output: progress lines per server token updated, then a summary such as:

```
[OK] 42 tokens rotated and written to ~/.config/mcp-hub/servers.json
New expiry: <NEW_EXPIRY_DATE>
```

If unexpected output (errors, partial rotation): stop here. Do NOT proceed to sync. Restore from backup (see Section 7 — Rollback) and escalate.

---

### Step 4 — Verify servers.json was updated

```bash
grep "expires" ~/.config/mcp-hub/servers.json | head -3
```

Expected output: the new expiry date — it must differ from the old date (`2026-07-07` or earlier).

If expiry date is unchanged: the rotation script did not write changes. Restore from backup and escalate.

---

### Step 5 — Sync tokens to all CLI configs

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json
```

Expected output: confirmation lines for each CLI target updated:

```
[OK] Gemini → ~/.gemini/settings.json updated
[OK] Antigravity → <path> updated
[OK] Codex → ~/.codex/config.toml updated (27 servers)
[OK] Kimi → ~/.kimi/mcp.json updated
[OK] OpenCode → ~/.config/opencode/config.json updated
```

If a specific CLI fails: note which one, continue with the others, then repair the failing CLI individually (re-run `mcp-sync.sh --cli <cli-name>`).

---

### Step 6 — Restart affected CLI processes

All AI CLI processes must be restarted to pick up the new tokens. They do not hot-reload MCP config.

```bash
# Confirm which CLIs are currently running
pgrep -a claude | head -5
pgrep -a codex | head -5
```

Close and reopen:
- **Claude Code** — close the terminal session and start a new one, or use the restart command in the Claude Code UI.
- **Codex** — close and reopen the terminal running Codex.
- **Gemini CLI / Kimi / OpenCode** — close and reopen those terminals.

Expected: each CLI starts without authentication errors.

---

### Step 7 — Send SIGHUP to mcp-hub (if running as a persistent process)

```bash
pkill -HUP mcp-hub
```

Expected output: no output (signal sent silently). If mcp-hub was not running, this is a no-op and the following message appears:

```
mcp-hub: no process found
```

That is acceptable — mcp-hub will pick up the new tokens on next start.

If mcp-hub does not reload after SIGHUP (tools still failing):

```bash
pkill mcp-hub && sleep 2
# Then restart your CLI to trigger mcp-hub restart
```

---

### Step 8 — Verify tools load in each CLI

Run the verification commands from Section 6 below in each CLI after restart.

---

### Step 9 — Update the expiry record in CLAUDE.md

Find the token rotation section in `~/.claude/CLAUDE.md` (search for "Token Rotation" or "2026-07-07") and update it with the new expiry date returned by `antigravity-token-refresh.sh` in Step 3.

```bash
# Find the expiry line
grep -n "2026-07-07\|expiry\|Tokens expire" ~/.claude/CLAUDE.md
```

Edit the line(s) found to reflect the new expiry date. Then commit:

```bash
cd ~/.dev-os  # or the repo that owns CLAUDE.md
git add ~/.claude/CLAUDE.md
git commit -m "chore: update MCP token expiry to <NEW_EXPIRY_DATE>"
```

---

## 6. Validation

All validation must pass before declaring the rotation complete.

### V-1 — Claude Code: all 42 hub tools visible

In a new Claude Code session, run:

```bash
# Ask Claude Code to list available MCP tools
# Or check via Claude Code's /mcp command if available
```

Expected: `mcp__mcp-hub__*` tools appear in the tool list. Minimum: 42 hub-proxied tools visible.

Threshold: **42 / 42 hub tools must be listed**. Fewer than 42 = partial failure; investigate which servers are missing.

### V-2 — Codex: 27 servers loaded

Open a new Codex session and verify the server count:

```bash
# In a Codex session, check the MCP status
grep -c "\[mcp_servers\." ~/.codex/config.toml
```

Expected output: `27` (or the expected count for the current Codex config).

Threshold: **count must be >= 27**. Lower = sync did not propagate to Codex correctly.

### V-3 — servers.json expiry updated

```bash
grep "expires" ~/.config/mcp-hub/servers.json | sort -u | head -3
```

Expected: new expiry date visible; old date (`2026-07-07` or earlier) no longer present.

Threshold: **100% of expiry fields must reflect the new date**. Any old date = partial rotation.

### V-4 — No authentication errors in mcp-hub logs

```bash
# If mcp-hub writes to a log file, check for 401/403 since rotation:
journalctl -u mcp-hub --since "5 minutes ago" 2>/dev/null | grep -i "401\|403\|unauthorized\|forbidden" | wc -l
# Or check process output directly if running in a terminal
```

Expected output: `0` (zero authentication errors since rotation).

Threshold: **0 auth errors**. Any 401/403 = token propagation incomplete for that server.

---

## 7. Rollback

### Rollback trigger condition

Initiate rollback if any of the following occur during or after Steps 3–5:

- `antigravity-token-refresh.sh` exits non-zero or produces error output.
- `servers.json` expiry date is unchanged after Step 4.
- More than 2 CLIs report tool loading failures after restart.
- A previously working CLI (not in the rotation scope) stops loading tools.

### Rollback steps

#### R-1 — Restore servers.json from backup

```bash
# List available backups
ls -lt ~/.config/mcp-hub/servers.json.bak.*

# Restore the most recent pre-rotation backup
# Replace <TIMESTAMP> with the timestamp from the backup filename
cp ~/.config/mcp-hub/servers.json.bak.<TIMESTAMP> ~/.config/mcp-hub/servers.json
```

Expected: `servers.json` is restored. Verify:

```bash
grep "expires" ~/.config/mcp-hub/servers.json | head -3
```

Should show the old expiry date.

#### R-2 — Restore Codex tokens from backup

```bash
cp ~/.codex/mcp-tokens.env.bak.<TIMESTAMP> ~/.codex/mcp-tokens.env
```

Expected: `mcp-tokens.env` restored to previous state.

#### R-3 — Re-sync old tokens to all CLIs

```bash
bash ~/.dev-os/scripts/sync/mcp-sync.sh --source servers.json
```

Expected: all CLIs updated with old token values.

#### R-4 — Restart CLI processes

Repeat Section 5, Step 6 to restart all AI CLI processes.

#### R-5 — Verify rollback success

Re-run all validation checks from Section 6. Expected: pre-rotation tool counts restored, no auth errors.

### Post-rollback action

After a successful rollback, file an investigation task before attempting rotation again:
- Document the exact failure output from the failed rotation attempt.
- Escalate to @Traderfuz with the failure log to diagnose `antigravity-token-refresh.sh` before retrying.

---

## 8. Communication

Token rotation is a maintenance task and does not require stakeholder communication unless:
- The rotation is triggered by a compromise (P1 emergency).
- Token expiry has already lapsed and tools have been down > 30 minutes.

### If communication is required (compromise or extended outage)

**Internal notification template** (post to dev-os team channel):

```
[MCP Token Rotation — In Progress]
Status: Rotating all 42 hub tokens due to [expiry / suspected compromise].
Impact: All hub-proxied MCP tools unavailable across all CLIs until rotation completes.
ETA: ~15 minutes.
Owner: @Traderfuz
Tracking: [link to task/ticket if applicable]
```

**Resolution notification:**

```
[MCP Token Rotation — Complete]
Status: All 42 tokens rotated and synced. CLIs restarted.
New expiry: <NEW_EXPIRY_DATE>
Validation: 42/42 hub tools confirmed in Claude Code. Codex shows <N> servers.
Next scheduled rotation: <NEW_EXPIRY_DATE - 14 days>
```

### Escalation path

| Condition | Contact | Channel | SLA |
|-----------|---------|---------|-----|
| `antigravity-token-refresh.sh` not found or errors | @Traderfuz | dev-os team direct message | < 1 hour |
| Rollback fails and tools remain down | @Traderfuz | dev-os team direct message | Immediately |
| Compromise confirmed and token revocation needed at issuing service | @Traderfuz | Secure channel | Immediately |

---

## 9. Post-Task

### Cleanup

```bash
# Remove backups older than 30 days (optional, after confirmed success)
find ~/.config/lazy-mcp/ -name "servers.json.bak.*" -mtime +30 -exec /usr/bin/rm {} \;
find ~/.codex/ -name "mcp-tokens.env.bak.*" -mtime +30 -exec /usr/bin/rm {} \;
```

### Record the new expiry

1. Update `~/.claude/CLAUDE.md` — find the "Token Rotation" section and replace the old expiry date with the new one (done in Step 9 of the procedure).
2. Commit the change (done in Step 9 of the procedure).

### Set calendar reminder

Set a calendar reminder for **14 days before the new expiry date** with the title:
`MCP Token Rotation — due in 14 days (<NEW_EXPIRY_DATE>)`.

```bash
# Calculate the reminder date (Linux)
python3 -c "
from datetime import datetime, timedelta
expiry = datetime.strptime('<NEW_EXPIRY_DATE>', '%Y-%m-%d')
reminder = expiry - timedelta(days=14)
print('Set reminder for:', reminder.strftime('%Y-%m-%d'))
"
```

### Runbook update note

If any step in this runbook behaved differently than described (different output format, script flags changed, new CLI targets added), update this file before closing the task. This runbook is the team's executable contract — keep it current.

### Postmortem trigger

If token expiry lapsed (tools were already broken before rotation started) and the outage exceeded 30 minutes, file a postmortem task:
- Label: `postmortem`, `mcp-infrastructure`
- Capture: how long tools were unavailable, root cause of late detection, prevention measures.

---

## 10. Related Runbooks

- **mcp-hub-onboarding** — procedure for adding a new MCP server to the hub registry (includes token generation steps that feed into this runbook's Step 3).
- **mcp-sync** — standalone sync procedure if only the CLI propagation step needs to be re-run without full token rotation.
- **dev-os-install** — full DevOS installation runbook, which includes initial token setup as a sub-step.

See `mcp-ops` for a live health check command that can be run at any time to verify hub tool availability without starting a full rotation.
