# Fix Broken Design

Diagnose and fix a broken or low-quality UI through a structured capture → root-cause → fix → verify cycle. Uses gap analysis to identify what drifted from the spec, then applies targeted fixes against the design tokens rather than ad-hoc patches. Every fix is verified with a before/after screenshot comparison before merge.

## When to Use

- A deployed or in-development page has visual defects (wrong colors, broken layout, misaligned elements)
- QA or a design review flagged specific regressions
- A component renders differently than the approved design spec
- After a CSS refactor or dependency upgrade breaks visual output
- When `ui-review` returns severity-rated findings that need systematic resolution

**Do NOT use when:** The design itself needs to change (use design-iteration or redesign-page workflow instead). Do not use when the page has no approved design reference — run design-review and design-handoff first to establish the baseline.

## Process

### Step 1: Capture current state

Run `ui-review` against the broken page to get a severity-rated inventory of issues.

- **Input:** Live URL, local dev server URL, or screenshot path
- **Capture at:** Desktop (1440 x 900) and Mobile (375 x 812)
- **Output:** Severity-rated findings list (P0 critical, P1 major, P2 minor)

```
Display:
  Design Check — /app/dashboard
  Viewport: 1440x900
  Findings: 7 issues
    P0: Hero section — background color #333 instead of token --color-bg-primary
    P0: CTA button — border-radius 0px, spec requires var(--radius-md)
    P1: Card grid — uneven gap (24px left, 32px right), should be var(--space-6)
    P1: Navigation — active state missing, no visual indicator on current page
    P2: Footer — font-size 14px hardcoded, should be var(--font-size-sm)
    P2: Mobile nav — hamburger icon misaligned 4px right
    P2: Section heading — line-height 1.1, spec requires var(--leading-tight)
```

### Step 2: Identify root causes

Run `gap-analysis --mode ui` to compare the current implementation against the design intent.

- **Input:** Findings from Step 1 + design reference (design-preview-approved.html or design-handoff.json)
- **Compare:** Implementation vs. approved spec on 4 axes:
  1. **Token compliance** — hardcoded values vs. design tokens
  2. **Layout structure** — grid, flex, positioning mismatches
  3. **Responsive behavior** — breakpoint handling, overflow, scaling
  4. **State coverage** — missing hover, focus, disabled, error states

- **Output:** Categorized gap list with root cause per finding

```
Display:
  Gap Analysis — UI Mode
  Reference: product/specs/dashboard/design/design-preview-approved.html

  Token gaps (3):
    Hero bg:      hardcoded #333 → should be var(--color-bg-primary)
    CTA radius:   hardcoded 0px → should be var(--radius-md)
    Footer font:  hardcoded 14px → should be var(--font-size-sm)

  Layout gaps (2):
    Card grid:    inconsistent gap — CSS calc() error in grid-template
    Mobile nav:   icon alignment — missing margin-left: auto

  State gaps (1):
    Nav active:   no .active class applied — router integration missing

  Root cause summary:
    4 of 7 issues are token bypass (hardcoded values replacing tokens)
    2 are layout bugs (CSS logic errors)
    1 is a missing feature (active state not wired)
```

### Step 3: Fix targeted issues

Apply fixes using `ui-creator` (for component rebuilds) or `frontend-design` (for multi-component page fixes). Work through the gap list by priority tier.

- **Input:** Gap list from Step 2 + existing component source code
- **Reads:** `creative/style-system/{client}/style-tokens.json` or `tokens.css` for correct values
- **Fix order:** P0 first → P1 → P2
- **Rule:** Fix only what the gap list identifies. Do not refactor surrounding code.

For each fix:
1. Read the source file containing the broken component
2. Replace hardcoded values with the correct token references
3. Fix layout logic (CSS grid/flex issues) based on the gap analysis
4. Wire missing state handlers (active, hover, focus)

```
Display:
  Fixing 7 issues across 4 files:
    ✓ src/components/Hero.tsx — replaced #333 with var(--color-bg-primary)
    ✓ src/components/CTAButton.tsx — replaced 0px with var(--radius-md)
    ✓ src/components/CardGrid.tsx — fixed grid-template gap calculation
    ✓ src/components/Nav.tsx — added active state class from router
    ✓ src/components/Footer.tsx — replaced 14px with var(--font-size-sm)
    ✓ src/components/MobileNav.tsx — fixed icon alignment margin
    ✓ src/components/SectionHeading.tsx — replaced 1.1 with var(--leading-tight)
```

### Step 4: Verify the fix

Run `ui-design-qa --mode verify` to compare before/after screenshots against the approved spec.

- **Input:** Fixed pages at same viewport sizes (1440px, 375px)
- **Compare:** Before screenshots (from Step 1) vs. after screenshots vs. approved spec
- **Gate:** All P0 and P1 issues must be resolved. P2 issues should be resolved but are non-blocking.

**Regression scan (mandatory):** If the fix touched shared components (Nav, Footer, Card, Button, Form inputs), check 2-3 other pages that use the same components to verify no regressions. This prevents the common failure where fixing a Card on the dashboard breaks the same Card on the settings page.

```
Display:
  Design Verify — /app/dashboard
  Before: 7 issues (2 P0, 2 P1, 3 P2)
  After:  0 issues remaining

  P0 resolved: 2/2 ✓
  P1 resolved: 2/2 ✓
  P2 resolved: 3/3 ✓

  Token coverage: 84% → 97%

  Regression scan (shared components changed: Card, Nav):
    ✓ /app/settings — no visual change
    ✓ /app/billing — no visual change
    ✓ /app/profile — no visual change

  Status: PASS — ready for merge
```

If verification fails, return to Step 3 and fix the remaining issues. If the regression scan finds issues on other pages, escalate to fix-inner-pages instead of fixing each page individually. Do not merge until at least P0 and P1 are clear and the regression scan is clean.

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `fix-broken-design` (this) | Fix a broken implementation | Diagnose → fix → verify against existing spec |
| `design-iteration` | Improve a design through iterative refinement | Changes the design itself, not the implementation |
| `design-qa` | Compare implementation against reference | Read-only — reports diffs but doesn't fix them |
| `design-system-audit` | Audit token adoption across the codebase | Broad token scan, not page-specific fixes |
| `redesign-page` | Replace a page with a new design direction | Changes the design intent, not just the implementation |

## Notes

- Token bypass (hardcoded values replacing design tokens) is the most common root cause of design drift. The gap analysis in Step 2 specifically targets this.
- Always fix from tokens outward — replace hardcoded values with token references first, then fix layout logic, then wire missing states.
- If more than 50% of findings are token bypasses, consider running `ui-design-system-audit` as a follow-up to catch similar issues on other pages.
- Keep the fix commit separate from any unrelated code changes.

## Display Format

```
Fix Broken Design — [page/route]
  Findings:  [N] (P0: [N]  P1: [N]  P2: [N])
  Root cause: [token bypass | layout bug | missing state | mixed]
  Fixed:     [N/N]
  Status:    [PASS — ready for merge | BLOCKED — N issues remain]
```
