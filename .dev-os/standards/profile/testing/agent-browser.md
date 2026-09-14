<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/agent-browser.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/testing/agent-browser.md and re-run profile-sync. -->
# agent-browser Testing Standards

## Overview

`agent-browser` is the default browser-verification tool for DevOS projects when the goal is to validate behavior in a real running application without paying the maintenance cost of brittle scripted selectors. It is strongest for smoke tests, flow verification, and exploratory confirmation of user-facing changes. This standard defines when to use it and what counts as a trustworthy browser check.

## Scope

This standard covers `agent-browser` usage for smoke tests, flow verification, visual checks, responsive checks, and browser-based regression confirmation. It does NOT cover traditional Playwright test authoring or general E2E strategy outside the `agent-browser` workflow.

## Principles

1. **Behavior over command theater:** A successful click command proves nothing by itself; the test proves value only when it verifies the resulting user-visible outcome.
2. **Fresh DOM state beats stale references:** Browser references are disposable and must be refreshed whenever the page meaningfully changes.
3. **Evidence matters:** Good browser verification leaves behind enough evidence that another reviewer can understand what was actually checked.
4. **Use the browser for browser problems:** Prefer `agent-browser` when sequencing, rendering, navigation, or auth state is the real risk.

## Framework Basis

This standard combines four named frameworks:

- **ISO Scope Pattern:** keeps this document focused on `agent-browser` as a verification tool.
- **RFC 2119 Normative Vocabulary:** turns browser-check expectations into testable requirements.
- **Behavior-Based E2E Testing:** verify outcomes and workflows, not just DOM presence.
- **Risk-Based Testing:** use browser verification when the failure mode depends on real user flow sequencing.

## Rules

### Rule 1: Use agent-browser for real browser-risk changes

`agent-browser` SHOULD be used when the change affects:

- authentication and session flow
- form submission and validation behavior
- navigation, redirects, or deep links
- responsive layout behavior
- end-to-end command or app workflows that depend on sequencing

It is not required for purely internal logic changes with no browser-facing risk.

### Rule 2: Every check MUST verify an outcome, not just an interaction

An `agent-browser click` or `fill` step is only setup. The test is not complete until it checks the resulting behavior.

**OFF-STANDARD**

```bash
agent-browser open http://localhost:3000/login
agent-browser snapshot -i
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"
agent-browser click @e3
```

**ON-STANDARD**

```bash
agent-browser open http://localhost:3000/login
agent-browser snapshot -i
agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "password123"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser get title
agent-browser screenshot
```

Acceptable outcome checks include:

- URL changes
- visible success or error text
- changed page title
- presence of post-action controls
- screenshot evidence where visual state matters

### Rule 3: Refs MUST be refreshed after page-changing actions

`@e1`, `@e2`, and similar refs are tied to a specific DOM snapshot. They must be treated as invalid after navigation or significant DOM changes.

**OFF-STANDARD**

```bash
agent-browser click @e5
agent-browser click @e1
```

**ON-STANDARD**

```bash
agent-browser click @e5
agent-browser snapshot -i
agent-browser click @e1
```

Re-snapshot after:

- navigation
- form submission
- modal or drawer open/close
- dynamic content loads
- any interaction that materially re-renders the page

### Rule 4: Locator strategy SHOULD prefer meaning before fragility

Preferred order:

1. fresh snapshot refs for the current page
2. semantic locators such as visible text, label, role, placeholder, or test id
3. scoped selectors only when meaning-based targeting is insufficient

**ON-STANDARD**

```bash
agent-browser find label "Email" fill "user@example.com"
agent-browser find role button click --name "Sign in"
```

Avoid relying on brittle implementation details when a semantic locator exists.

### Rule 5: Waiting MUST be tied to the expected state transition

Use waits that correspond to the behavior being verified.

**OFF-STANDARD**

```bash
agent-browser click @e3
agent-browser wait 5000
```

**ON-STANDARD**

```bash
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser wait --load networkidle
```

Fixed sleeps MAY be used only when the tool or platform lacks a state-based wait, and the limitation should be noted.

### Rule 6: Browser verification SHOULD leave behind usable evidence

For any meaningful smoke or regression check, capture at least one of:

- screenshot
- title or URL confirmation
- extracted text proving the expected state
- saved browser state when auth/session setup is part of the flow

Examples:

```bash
agent-browser screenshot smoke-login.png
agent-browser get url
agent-browser get text @e4
agent-browser state save auth.json
```

### Rule 7: Mobile and responsive checks MUST run in a real target viewport when layout is in scope

If the change affects responsive layout, touch interactions, or mobile-specific flows, run `agent-browser` against the actual target viewport or device profile rather than assuming desktop correctness implies mobile correctness.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Stopping after `click`/`fill` without checking results | Verifies command execution, not product behavior | Assert URL, text, page state, or screenshots after the action |
| Reusing stale refs after navigation | Produces flaky or invalid checks | Re-snapshot after page-changing interactions |
| Waiting with arbitrary sleeps only | Creates slow and flaky verification | Wait for URL, load state, or a concrete element |
| Using brittle selectors when semantic locators exist | Ties the check to DOM implementation details | Prefer label, text, role, placeholder, or test id |
| Running desktop-only checks for responsive changes | Misses the actual risk surface | Verify in the real mobile or target viewport |

## Deviation Guidance

- Teams MAY use `agent-browser` for exploratory debugging or scraping outside formal test flows, but those sessions do not count as regression verification unless outcomes are checked.
- Teams MAY combine `agent-browser` with Playwright or other tools when a project needs both scripted regression suites and AI-driven exploratory confirmation.
- Teams MUST NOT claim a browser flow is verified based solely on successful tool commands.
- Teams MUST NOT rely on stale refs across page transitions.

## Related Standards

- `e2e.md` for behavior-based E2E expectations
- `verification-scope.md` for when browser verification is required
- `test-writing.md` for non-browser test structure

## Compliance Test

- [ ] Was `agent-browser` used because the change had real browser or user-flow risk?
- [ ] Did the verification check an outcome rather than only execute browser commands?
- [ ] Were refs refreshed after any page-changing interaction?
- [ ] Were waits tied to expected state transitions instead of arbitrary sleeps?
- [ ] If layout or mobile behavior changed, was verification run in the target viewport or device context?
