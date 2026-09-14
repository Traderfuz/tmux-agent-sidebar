# Design QA

Compare implemented UI against the approved design reference to catch visual regressions and implementation drift. Uses side-by-side screenshot comparison at matching viewport sizes to identify differences, then classifies each difference as intentional (responsive adaptation, content change) or regression (unintended drift from the approved design). Browser capture follows `profiles/general/standards/global/browser-review-policy.md`; reports must include selected driver, selected target, auth path, backend, artifact paths, and fallback reason.

## When to Use

- After implementing a frontend feature — before marking tasks complete
- During PR review for any change that affects visual output
- After CSS/token changes that may cause visual regressions
- Before deploying a frontend release to production
- When `design-verify` is invoked (this workflow is the backing process)
- If you only need a fast iterative pass on a live URL or screenshot, use `design-check` first; keep this workflow for the reference-based comparison step.

**Do NOT use when:** No approved design reference exists (run design-review and design-handoff first). Do not use for backend-only changes with no visual impact.

## Process

### Step 1: Load design reference

Load the approved design artifacts from the handoff:

- Reference HTML: `.dev-os/state/design-references/design-preview.html`
- Reference screenshots: `.dev-os/state/design-references/desktop-1440.png` and `mobile-375.png`
- Design handoff metadata: `.dev-os/state/design-handoff.json`

If no reference exists, abort and direct the user to run the design-handoff workflow first.

```
Display: "Loaded design reference from [date]. Components: [list]"
```

### Step 2: Capture implementation screenshots

Capture the current implementation at the same viewport sizes as the reference:

- **Desktop:** 1440 x 900
- **Mobile:** 375 x 812

Use Playwright CLI/default Playwright tooling per `browser-review-policy.md` to navigate to the same pages/routes shown in the reference and capture full-page screenshots. For local watchable review, target `browser-cdp`; for CI/PR, use Playwright-managed headed/headless and never require CDP.

```
Display: "Implementation screenshots captured at 1440px and 375px"
```

### Step 3: Compare screenshots

For each viewport size, compare reference vs implementation:

1. **Structural comparison:** Are the same elements present in the same positions?
2. **Token compliance:** Do colors, fonts, spacing match the design tokens?
3. **Responsive behavior:** Does the layout adapt correctly between desktop and mobile?
4. **State coverage:** Are hover, focus, disabled, and error states implemented?

Use visual diff (pixel comparison) if available, or manual side-by-side inspection.

```
Display: Diff summary
  Desktop: 3 differences found
  Mobile:  5 differences found
```

### Step 4: Classify differences

For each difference, classify as:

- **Intentional** — responsive adaptation, content update, or approved change
- **Regression** — unintended drift from the approved design
- **Enhancement** — improvement beyond the original design (document and get approval)

| # | Location | Description | Classification | Severity |
|---|----------|-------------|---------------|----------|
| 1 | Hero section | Headline font size 2px smaller than reference | Regression | Medium |
| 2 | Mobile nav | Hamburger menu added (not in reference) | Intentional | — |
| 3 | Footer links | Color is #666 instead of token --color-text-muted (#6b7280) | Regression | High |
| 4 | Pricing cards | Extra "Popular" badge added | Enhancement | — |

```
Display: Classified differences table with counts per category
```

### Step 5: Generate QA report

Produce a structured QA report:

- **Status:** Pass (0 regressions) / Needs fixes (regressions found)
- **Regression count:** number of unintended drifts
- **Intentional count:** number of classified acceptable differences
- **Enhancement count:** number of improvements needing approval
- **Per-difference detail:** location, description, classification, fix action

```
Display:
  Design QA Report — [date]
  Status: NEEDS FIXES (2 regressions, 1 enhancement pending approval)

  Regressions:
    1. Hero headline: font-size should be var(--font-size-3xl) — currently 46px instead of 48.83px
    2. Footer links: color should be var(--color-text-muted) — currently hardcoded #666

  Action: Fix regressions before merge. Get approval for "Popular" badge enhancement.
```

## Notes

- This workflow complements `design-verify` — that command invokes this workflow under the hood.
- Screenshot comparison is viewport-size-sensitive. Always use the exact same dimensions as the reference.
- Regressions in token usage (hardcoded values replacing tokens) are always High severity — they indicate the design system is being bypassed.
- Run this workflow again after fixing regressions to confirm all issues are resolved.

## Display Format

```
Design QA — [spec-name] — [date]
  Status: [PASS | NEEDS FIXES]
  Regressions: [N]   Intentional: [N]   Enhancements: [N]
  Blocking: [regression list | none]
  Action: [fix regressions before merge | approved — proceed]
```
