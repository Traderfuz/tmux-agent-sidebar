# Chrome CDP Browser Session Workflow

Automate authenticated or watchable local-review dashboards through a named persistent Chrome profile and Chrome DevTools Protocol. Per `profiles/general/standards/global/browser-review-policy.md`, CDP is the visible local hard-auth escape hatch; `chrome-devtools-axi` is the control surface after selected-profile verification.

## When to Use

- A target login must persist across Chrome or agent sessions
- Separate accounts need isolated named profiles
- CAPTCHA, 2FA, OAuth, or extensions require a visible browser
- Dashboard configuration is unavailable through an API
- Managed browser automation cannot satisfy the authenticated task


Do not use CDP in CI/PR workflows. Do not use it for API-accessible operations. For non-watchable public-page checks where a managed browser is sufficient, follow the browser-review policy fallback target order instead of forcing CDP.
## Prerequisites

- Google Chrome installed
- `chrome-devtools-axi` installed
- `chrome-cdp-*` functions sourced from `${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/chrome-cdp.sh`
- One named profile created and manually authenticated when required

## Constraints

- **Chromium-only** — Firefox/Gecko browsers do not expose Chrome CDP
- **Loopback-only** — every profile binds its assigned port to `127.0.0.1`
- **Isolated state** — never read or copy the normal Chrome profile
- **Verified navigation** — no browser command before selected-profile identity verification

## Steps

### Step 1: Check / start CDP session

```bash
# List named profiles, then select the intended account boundary.
chrome-cdp-profile-list
chrome-cdp-profile-select boxiagency.com

# Launch or reuse only after endpoint/profile identity verification.
chrome-cdp-profile-reuse || chrome-cdp-profile-launch

# Optional: check auth cookies in the selected profile before navigating.
chrome-cdp-check-cookies app.example.com

# Verify window is visible in Hyprland
hyprctl clients 2>/dev/null | grep -i "google-chrome" \
  && echo "Window confirmed" \
  || echo "WARNING: Chrome window not detected. Check /tmp/chrome-cdp-launch.log"
```

> **Resume guidance:** Select the intended named profile and run `chrome-cdp-profile-reuse`. Navigate only after it confirms the profile and loopback endpoint.
>
> **Profile isolation:** Each name owns a separate directory under `~/.chrome-cdp-profiles/`. Never copy the normal Chrome profile.

### Step 2: Navigate to target URL

```bash
CHROME_DEVTOOLS_AXI_BROWSER_URL="http://127.0.0.1:$CDP_BROWSER_PORT" chrome-devtools-axi open https://example-dashboard.com
CHROME_DEVTOOLS_AXI_BROWSER_URL="http://127.0.0.1:$CDP_BROWSER_PORT" chrome-devtools-axi wait networkidle
```

> **Auth check:** If the snapshot shows a login form, the session cookie expired. Follow the co-work protocol below — announce a co-work pause, let the user log in manually, then resume.

### Step 3: Snapshot and interact

```bash
# Check current URL without full snapshot (fast orientation check)
# Check current URL after selected-profile verification.
chrome-cdp-url

# List open tabs on the selected profile.
chrome-cdp-tabs

# Full snapshot — pin chrome-devtools-axi to the verified selected endpoint.
CHROME_DEVTOOLS_AXI_BROWSER_URL="http://127.0.0.1:$CDP_BROWSER_PORT" chrome-devtools-axi snapshot

# Interact using refs or semantic locators
CHROME_DEVTOOLS_AXI_BROWSER_URL="http://127.0.0.1:$CDP_BROWSER_PORT" chrome-devtools-axi click @e5
CHROME_DEVTOOLS_AXI_BROWSER_URL="http://127.0.0.1:$CDP_BROWSER_PORT" chrome-devtools-axi fill @e10 "value"
CHROME_DEVTOOLS_AXI_BROWSER_URL="http://127.0.0.1:$CDP_BROWSER_PORT" chrome-devtools-axi wait "Success"

# Screenshot for verification
CHROME_DEVTOOLS_AXI_BROWSER_URL="http://127.0.0.1:$CDP_BROWSER_PORT" chrome-devtools-axi screenshot screenshots/cdp-current.png
```

**Snapshot guidance:** Only snapshot after navigation or when element refs become stale. Within the same page, reuse refs from the last snapshot — re-snapshotting every turn wastes 3–5 seconds and re-parses unchanged DOM.

### Step 4: Co-work handoff (when manual action is needed)

When a task requires manual action in the Chrome window (login, CAPTCHA, 2FA, OAuth, manual navigation):

```
AI announces: "Taking a co-work pause. I need you to [specific action] in the Chrome window.
               Tell me when you're done and I'll take a snapshot and continue."
```

1. **AI stops all browser commands** — no navigation, click, or fill until resume
2. **User performs the action** in the selected profile's Chrome window
3. **User signals ready** — types "done" or "ready"
4. **AI resumes** — runs `chrome-cdp-profile-reuse`, pins the explicit loopback endpoint, snapshots, then continues

> **User taking over:** The agent issues no browser commands until the user says "done."

### Step 5: Save context (for cross-session continuity)

If the task will continue in a new Claude Code conversation:

```bash
# Save current state with a label and optional task description
chrome-cdp-save-context work-invoice-dashboard "Auditing BetterStack monitors — completed step 3"

# In the next conversation, load it:
chrome-cdp-load-context work-invoice-dashboard
```

Context files are saved to `~/.chrome-cdp-contexts/<label>.json` and persist across reboots.

### Step 6: Clean up

```bash
# Stop saves session state to /tmp/cdp-session-state.json before killing Chrome
chrome-cdp-stop
```

## Helper Functions

| Function | What it does |
|----------|-------------|
| `chrome-cdp-profile-create <name> [port]` | Create an isolated persistent profile |
| `chrome-cdp-profile-list` | List profiles, ports, selection, and running state |
| `chrome-cdp-profile-select <name>` | Persist the intended account boundary |
| `chrome-cdp-profile-launch [name]` | Launch or reuse a named profile |
| `chrome-cdp-profile-reuse [name]` | Fail closed unless the endpoint belongs to the selected profile |
| `chrome-cdp-stop` | Verify ownership, save tab state, then stop the selected profile |
| `chrome-cdp-status` | Show verified profile, endpoint, URL, tabs, and window state |
| `chrome-cdp-url` / `chrome-cdp-tabs` | Inspect the verified selected profile |
| `chrome-cdp-save-context <label>` | Save current tabs + URL to `~/.chrome-cdp-contexts/<label>.json` |
| `chrome-cdp-load-context <label>` | Print saved context for a label |
| `chrome-cdp-list-contexts` | List all saved contexts |

## Key Gotchas

| Gotcha | Root Cause | Fix |
|--------|-----------|-----|
| Chrome opens to profile picker | `--profile-directory=Default` missing | Re-source `chrome-cdp.sh` and `chrome-cdp-restart` |
| Login page shown instead of dashboard | Session cookie expired | Co-work pause: log in manually, tell Claude "done" |
| CDP port not binding | Port conflict or Chrome launch failure | Read `<profile-dir>/.devos-cdp-launch.log`; choose an unused profile port |
| Wrong profile owns live port | Endpoint identity check fails | Stop navigation; select the correct profile or resolve the conflicting process |
| Chrome starts but no window appears | Missing `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` | Ensure `chrome-cdp.sh` is sourced in the interactive shell |
| Separate accounts conflict | Same named profile selected for both | Create distinct named profiles; each receives its own directory and port |
| OAuth popup goes black | OAuth opens popup windows that hijack CDP tab | Complete OAuth manually in Chrome window |

## When NOT to Use

- Public review pages with no auth — use the browser-review policy order, starting with `playwright-cli`
- API-accessible operations — call the API directly
- CI/CD environments — use Playwright-managed Chromium
- Firefox-only sites — CDP does not apply

## Related

- `scripts/lib/chrome-cdp.sh` — named profile and endpoint helpers
- `.claude/skills/browser-cdp/SKILL.md` — authoritative operator contract
- Named profiles: `~/.chrome-cdp-profiles/<slug>/`
- Session state: `/tmp/cdp-session-state.json` (ephemeral, cleared on reboot)
- Context files: `~/.chrome-cdp-contexts/` (persistent, cross-session task context)

## Display

Session lifecycle output:

```text
[CDP] Profile selected — boxiagency.com
[CDP] Endpoint verified — http://127.0.0.1:<port>
[CDP] Session attached — tab: <url>
[CDP] Action: <description>
[CDP] Session closed
```
