<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/browser-review-policy.md and re-run profile-sync. -->
# Browser Review Policy Standard

## Overview

DevOS browser-based QA and visual-review workflows separate four decisions that are often conflated:

1. **Automation driver** — the command interface issuing browser actions.
2. **Browser target** — the browser/session being controlled.
3. **Auth path** — how authenticated state is established.
4. **Visual backend** — how screenshots/diffs/reports are stored or compared.

## Routing Contract

```yaml
browser_review_policy:
  automation_driver_order:
    - playwright-cli
    - playwright-mcp
  local_review_target_order:
    - browser-cdp-visible
    - playwright-headed
    - playwright-headless
  ci_target_order:
    - playwright-headless
    - playwright-headed
  auth_order:
    - playwright-storage-state
    - playwright-cli-state-save-load
    - browser-cdp-real-profile
  visual_backend_order:
    local: backstopjs
    ci_pr: argos
    evidence_only: raw-screenshot-bundle
```

## Rules

1. **Playwright CLI is the default automation driver** for local and CI QA/review workflows.
2. **`browser-cdp` is the default visible local review target** when a human-watchable local browser run is appropriate.
3. **Playwright-managed headed/headless browsers are fallback targets** for local runs and the default targets for CI/PR.
4. **Playwright MCP is a fallback automation interface**, not the default local QA/review path.
5. **Auth starts with storage state.** Use Playwright project `storageState` or `playwright-cli state-save/state-load` before escalating to a real-profile CDP session.
6. **CDP is local-only.** CI/PR workflows MUST NOT require `browser-cdp` or a user profile.
7. **BackstopJS and Argos are visual backends**, not browser-control mechanisms. BackstopJS is the local baseline/diff backend; Argos is the CI/PR visual approval backend.
8. **Raw screenshots remain valid evidence** when baseline/diff infrastructure is unavailable or out of scope.

## Review Surface Routing

Review intent routing is owned by `.claude/skills/devos-review/SKILL.md`
(`Canonical Review Intent Table`). Other browser guidance MUST reference that
table rather than define a competing queue or artifact-opening route.

- Once that table selects `browser-cdp`, select a named persistent Chrome
  profile and verify that its loopback endpoint belongs to that profile before
  navigation. Pause for human login, CAPTCHA, or 2FA work, then reverify and
  resume the exact selected target. Never copy the normal Chrome profile.
- No second controller or automatic Helium launch is permitted. Browser
  guidance opens the target selected by `devos-review`; it does not create a
  queue, reinterpret its source artifact, or own verdict state.

Lifecycle definitions and evidence ownership remain canonical in the
`devos-review` table; browser exit status alone does not advance them.

## Report Contract

Every browser-review report MUST include:

- selected driver
- selected target
- auth path
- backend
- artifact paths
- degraded/fallback reason, or `none`

## Compliance Test

- [ ] Does the workflow use Playwright CLI as the default driver?
- [ ] Does local watchable review target `browser-cdp` before managed headed/headless fallback?
- [ ] Does CI explicitly skip CDP and real-profile auth?
- [ ] Is Playwright MCP documented only as fallback?
- [ ] Are BackstopJS and Argos described only as visual backends?
- [ ] Does the report include selected driver, selected target, auth path, backend, artifact paths, and fallback reason?

## References

- `visual-review-gate.md` — completion gates for visual output.
- `testing/playwright-auth.md` — storage-state-first authentication.
- `.claude/skills/playwright-cli/SKILL.md` — default browser automation driver.
- `.claude/skills/browser-cdp/SKILL.md` — default visible local review target and hard-auth escape hatch.
