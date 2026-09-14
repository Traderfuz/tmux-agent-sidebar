# Design Polish

Elevate a functional but mediocre UI to production quality through a structured review → prioritize → iterate → verify cycle. Unlike fix-broken-design (which fixes regressions against a spec), this workflow improves a design that technically works but lacks visual polish, consistent micro-interactions, or satisfying UX details.

## When to Use

- A feature is functional but "doesn't feel right" — the design is correct but unpolished
- End-of-sprint polish pass before release
- After a rapid prototype was shipped and now needs refinement
- When usability testing reveals friction that isn't a bug but a quality gap
- When design review returns "Approved with conditions" and the conditions are polish items

**Do NOT use when:** The UI is visually broken or regressions exist (use fix-broken-design). Do not use when the design direction itself needs to change (use redesign-page). Do not use for accessibility-only fixes (use the accessibility remediation path in design-qa).

## Process

### Step 1: Run full design review

Run `ui-review --scope full` to score the UI against the 6 design principles (visual hierarchy, contrast, consistency, spacing, typography, accessibility).

- **Input:** Live URL or local dev server URL
- **Scans:** All routes/pages in the app (auto-discovery via sitemap or route config)
- **Output:** Per-page severity report with 6-criterion scores

```
Display:
  Design Review — full app
  Pages scanned: 8

  /app/dashboard      — 5/6 pass (typography: needs work)
  /app/settings       — 4/6 pass (consistency: needs work, spacing: needs work)
  /app/profile        — 6/6 pass
  /app/billing        — 3/6 pass (hierarchy: fail, spacing: needs work, a11y: needs work)
  /app/onboarding     — 5/6 pass (consistency: needs work)
  /app/team           — 4/6 pass (hierarchy: needs work, typography: needs work)
  /app/integrations   — 5/6 pass (spacing: needs work)
  /app/help           — 6/6 pass
```

### Step 2: Run usability audit

Run `usability-audit` to identify UX friction beyond visual quality.

- **Input:** Primary user journeys (onboarding, core task, settings change)
- **Analyzes:** Click paths, cognitive load, feedback loops, error recovery
- **Output:** Friction points with severity and location

```
Display:
  Usability Audit — 3 journeys analyzed
  Friction points: 5

  High:   Onboarding — no progress indicator (user doesn't know how many steps remain)
  High:   Billing — save button doesn't show loading state (user clicks multiple times)
  Medium: Settings — form validation only on submit (should be inline)
  Low:    Dashboard — metric cards have no empty state (shows "0" instead of helpful message)
  Low:    Team page — invite flow has no success confirmation
```

### Step 3: Prioritize fixes

Sort all findings from Steps 1 and 2 into priority tiers:

- **P0 — Broken:** Failing contrast, unreadable text, layout breaks, accessibility failures
- **P1 — Inconsistent:** Mismatched spacing/tokens, missing hover/focus states, inconsistent component styling across pages
- **P2 — Polish:** Motion, micro-interactions, empty states, loading states, transitions, delightful details

```
Display:
  Priority matrix — 12 items total
  P0 (fix now):      2 items — billing hierarchy, billing a11y
  P1 (fix this sprint): 6 items — spacing (3), consistency (2), typography (1)
  P2 (polish):       4 items — loading states, empty states, progress indicator, success confirmations
```

### Step 4: Apply improvements iteratively

Use `design-iteration` to fix one priority tier at a time: P0 → P1 → P2.

- **Loop per tier:** screenshot → review → fix → screenshot → review
- **Reads:** `style-tokens.json` for correct token values
- **Tools:** `ui-creator` for component changes, `frontend-design` for page-level changes
- **Each pass targets one tier only** — do not mix P0 fixes with P2 polish in the same pass

For P2 polish items specifically:
- Add loading spinners/skeletons where async operations lack feedback
- Add empty states with helpful messages where data can be absent
- Add micro-interactions (button press feedback, card hover lift, transition on route change)
- Add progress indicators for multi-step flows

```
Display:
  Polish pass — P1 tier (6 items)
  Pass 1:
    ✓ Settings spacing — replaced hardcoded padding with var(--space-4)
    ✓ Dashboard spacing — card grid gap normalized to var(--space-6)
    ✓ Integrations spacing — section margins aligned to 4px grid
    ✓ Settings consistency — form inputs now match global input style
    ✓ Onboarding consistency — button variants aligned with design system
    ✓ Team typography — heading scale corrected to var(--font-size-2xl)
  Verification: ui-review — all 6 items resolved
```

### Step 5: Final verification

Run `ui-review` + `ui-design-qa` to confirm all improvements pass.

- **Confirm:** All P0 and P1 items resolved
- **Track:** P2 items that were completed vs. deferred
- **Output:** Final quality score comparison (before vs. after)

```
Display:
  Design Polish — Complete
  Before: 38/48 criteria passing (79%)
  After:  46/48 criteria passing (96%)

  P0 resolved: 2/2 ✓
  P1 resolved: 6/6 ✓
  P2 resolved: 3/4 (1 deferred: success confirmations — tracked in backlog)

  Status: PASS — ready for release
```

## Notes

- Polish is iterative, not one-shot. Expect 2-3 passes per priority tier.
- P2 items are genuinely optional for release but compound into perceived quality. Track deferred P2 items in the backlog rather than losing them.
- The usability audit in Step 2 often surfaces issues that design review misses — friction in flows, missing feedback, cognitive load. Both steps are needed.
- If Step 1 reveals more than 3 P0 items, the UI may need fix-broken-design rather than polish — the distinction is whether the implementation matches a spec (fix) vs. whether the quality meets a bar (polish).

## Display Format

```
Design Polish — [project/scope]
  Before: [N/M] criteria passing ([%])
  After:  [N/M] criteria passing ([%])
  P0: [N/N]  P1: [N/N]  P2: [N/N completed, N deferred]
  Status: [PASS | IN PROGRESS — tier [N] remaining]
```
