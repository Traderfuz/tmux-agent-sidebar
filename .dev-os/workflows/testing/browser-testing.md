# Browser Testing Workflow

Shared browser-review orchestration workflow for DevOS commands that perform browser automation. Routing follows `profiles/general/standards/global/browser-review-policy.md`: Playwright CLI default driver, `browser-cdp` visible local target when watchable review is appropriate, Playwright-managed headed/headless fallback/CI targets, and Playwright MCP fallback automation. Used by `e2e` and `usability-audit`.

---

## When to Use

Use this workflow in any command that performs browser automation (e.g., `e2e`, `usability-audit`) to ensure consistent browser interaction and error recovery. Record selected driver, selected target, auth path, backend, artifact paths, and degraded/fallback reason in the report.

Do not invoke this workflow directly from the user prompt — it is a shared workflow included by other commands. Do not use it for non-browser testing (unit tests, BATS tests, API tests).

## Interaction Loop (Mandatory)

Every browser interaction step follows this exact sequence. Never skip a step.

```
Step N:
1. SNAPSHOT   — capture a fresh snapshot with the selected policy driver (`playwright-cli snapshot`, `agent-browser snapshot -i`, or MCP fallback).
                Always re-snapshot before any interaction.
                Never reuse refs (@e1, @e2, etc.) from a previous snapshot.

2. INTERACT   — use the selected driver to click/fill/press/select/check <ref-or-semantic>

3. WAIT       — wait for network idle or target URL using the selected driver

4. SCREENSHOT — capture screenshot evidence with the selected driver to <path>/<step-N>.png

5. ANALYZE    — Read the screenshot file via the Read tool.
                Describe what is visible. Check for: blank areas, error messages,
                missing content, broken layout, unexpected redirects.

6. CHECK      — agent-browser errors
                Note any JavaScript/console errors in the test log.
```

---

## Ref Lifecycle Rules (Critical)

Refs (`@e1`, `@e2`, etc.) are **invalidated** after any of:

- Clicking a link or button that navigates to a new page
- Form submission
- Dynamic content load (modals, dropdowns, tabs opening)
- Any AJAX request that updates the DOM

```
# WRONG — using stale refs
agent-browser click @e5
agent-browser click @e1  # @e1 is invalid after the click above navigated the page

# CORRECT — re-snapshot after navigation
agent-browser click @e5
agent-browser snapshot -i
agent-browser click @e1  # Fresh ref from new snapshot
```

**Rule:** Call `agent-browser snapshot -i` before EVERY interaction. No exceptions.

---

## Semantic Locators

Use semantic locators when refs are unreliable (shadow DOM, dynamically positioned elements):

```
agent-browser find text "Sign In" click
agent-browser find label "Email" fill "user@test.com"
agent-browser find role button click --name "Submit"
agent-browser find placeholder "Search" type "query"
agent-browser find testid "submit-btn" click
```

Prefer semantic locators for stable, long-lived elements (navigation links, primary CTAs).
Prefer ref-based interaction for form fields within a single form step.

---

## Auth Session Save and Load

When testing authenticated journeys, save the session after the first successful login to avoid
repeated login steps across journeys.

```
# After successful login — save session
agent-browser state save e2e-screenshots/.auth-session.json

# At the start of a subsequent authenticated journey — load session
agent-browser state load e2e-screenshots/.auth-session.json
agent-browser open <protected-url>
agent-browser wait --load networkidle
```

The `.auth-session.json` file persists the browser's cookie/storage state. If the session
expires or a fresh login is needed, delete the file and re-run the login step.

---

## Screenshot Naming Convention

Organize screenshots by journey and step:

```
e2e-screenshots/
├── 00-initial-load.png          # Phase 2 initial load
├── <journey-slug>/
│   ├── 01-homepage.png
│   ├── 02-signup-form.png
│   ├── 03-form-submitted.png
│   └── ...
└── responsive/
    ├── mobile/
    │   ├── homepage.png
    │   └── dashboard.png
    ├── tablet/
    └── desktop/
```

Use `kebab-case` for all file and directory names. Step numbers are zero-padded to two digits.

---

## Viewport Testing

For responsive testing, set viewport dimensions before opening each route:

```
# Mobile
agent-browser set viewport 375 812
agent-browser open <url>
agent-browser wait --load networkidle
agent-browser screenshot --full e2e-screenshots/responsive/mobile/<route-slug>.png

# Tablet
agent-browser set viewport 768 1024
agent-browser open <url>
agent-browser wait --load networkidle
agent-browser screenshot --full e2e-screenshots/responsive/tablet/<route-slug>.png

# Desktop
agent-browser set viewport 1440 900
agent-browser open <url>
agent-browser wait --load networkidle
agent-browser screenshot --full e2e-screenshots/responsive/desktop/<route-slug>.png
```

After each responsive screenshot, read it via the Read tool and check:
- Layout intact at this viewport
- Navigation accessible (hamburger menu visible on mobile)
- Text readable (no overflow or truncation)
- Touch targets have adequate size on mobile (≥44×44px)

## Display Format

```
Browser test step [N]:
  Snapshot: taken ✅
  Action:   [click | fill | navigate] → [target]
  Wait:     networkidle ✅
  Result:   [pass | fail | retry]
```
