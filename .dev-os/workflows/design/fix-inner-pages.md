# Fix Inner Pages

Repair visual inconsistency across multiple inner pages that have drifted from each other or from the design system. Establishes a "golden" reference page, audits token adoption across all routes, then fixes each page individually and verifies cross-page consistency. Designed for the scenario where the landing page looks good but inner pages (dashboard, settings, profile, etc.) are each slightly different.

## When to Use

- Multiple pages look visually inconsistent with each other (different spacing, font sizes, card styles)
- Inner pages were built by different developers or at different times and never harmonized
- After a design system update, some pages were migrated but others were missed
- When a design review flags cross-page consistency as a failure
- When `ui-review --scope full` reports different scores per page with consistency violations

**Do NOT use when:** Only one page is broken (use fix-broken-design). Do not use when the design system itself doesn't exist yet (run `ui-design-system` first). Do not use when the visual direction needs to change (use redesign-page).

## Process

### Step 1: Audit all pages at once

Run `ui-review --scope full` to auto-discover all routes and produce per-page scores with a cross-page consistency rating.

- **Input:** App URL (local dev server or deployed)
- **Auto-discovers:** All routes via sitemap, route config, or page directory scan
- **Output:** Per-page score + cross-page consistency score

```
Display:
  Design Review — all routes
  Pages discovered: 6

  Page                  | Hierarchy | Contrast | Consistency | Spacing | Typography | A11y
  ──────────────────────┼───────────┼──────────┼─────────────┼─────────┼────────────┼──────
  /app/dashboard        | Pass      | Pass     | Pass        | Pass    | Pass       | Pass
  /app/settings         | Pass      | Pass     | Fail        | Fail    | Needs work | Pass
  /app/profile          | Pass      | Pass     | Needs work  | Pass    | Pass       | Pass
  /app/billing          | Fail      | Pass     | Fail        | Fail    | Fail       | Needs work
  /app/team             | Pass      | Pass     | Fail        | Needs work | Pass    | Pass
  /app/integrations     | Pass      | Pass     | Needs work  | Pass    | Pass       | Pass

  Cross-page consistency: 58% (Red — systematic intervention needed)
  Shared nav consistent: Yes
  Shared footer consistent: Yes
  Card component variants: 3 different styles detected (should be 1)
  Button variants: 2 different styles detected (should be 1 per variant)
```

### Step 2: Identify the golden page

Select the page that most closely matches the intended design as the reference standard.

- **Criteria:** Highest design review score, most token-compliant, most representative of the intended style
- **If no page is fully correct:** Run `ai-design-draft` to create the canonical layout as an HTML reference
- **Output:** Golden page identified + list of what makes it the reference

```
Display:
  Golden page: /app/dashboard (6/6 criteria pass)
  Reference characteristics:
    - Card style: shadow-md, rounded-lg, padding var(--space-6)
    - Heading scale: h1=3xl, h2=2xl, h3=xl
    - Grid gap: var(--space-6) between cards
    - Button style: primary variant for CTAs, outline for secondary
    - Spacing pattern: section gap var(--space-12), element gap var(--space-4)
```

### Step 3: Audit design token adoption

Run `ui-design-system-audit` to measure token coverage across all pages and identify hardcoded values.

- **Input:** Full codebase scan (CSS, TSX, style objects)
- **Output:** Token coverage %, per-file list of hardcoded values, suggested token replacements

```
Display:
  Token Coverage: 72% (Yellow)
  
  Files with hardcoded values:
    src/app/settings/page.tsx    — 8 hardcoded values (worst offender)
    src/app/billing/page.tsx     — 6 hardcoded values
    src/app/team/page.tsx        — 4 hardcoded values
    src/components/SettingsCard.tsx — 3 hardcoded values
    src/components/BillingTable.tsx — 2 hardcoded values

  Top hardcoded patterns:
    padding: "20px"  (appears 5x, should be var(--space-5))
    color: "#6b7280" (appears 3x, should be var(--color-text-muted))
    font-size: "14px" (appears 4x, should be var(--font-size-sm))
    border-radius: "8px" (appears 3x, should be var(--radius-md))
```

### Step 4: Fix pages one at a time

For each non-golden page, run a fix cycle: capture → diagnose → fix → verify.

- **Order:** Fix the worst-scoring page first (most impact per fix)
- **Per page:**
  a. `ui-review` — capture current issues for this specific page
  b. `ui-creator` or `frontend-design` — fix the page, using the golden page as layout reference + `style-tokens.json` for correct values
  c. `ui-design-qa --mode verify` — confirm the page now matches the golden page's standards

```
Display:
  Fixing page 1/5: /app/billing (worst score: 3/6)
    a. Design check: 9 issues found (1 P0, 3 P1, 5 P2)
    b. Fixing:
       ✓ Replaced 6 hardcoded values with design tokens
       ✓ Rebuilt card layout to match dashboard card style
       ✓ Fixed heading scale (was h1=2xl, now h1=3xl matching golden)
       ✓ Added missing focus states on billing form inputs
       ✓ Aligned grid gap to var(--space-6)
    c. Design verify: PASS (6/6 criteria)

  Fixing page 2/5: /app/settings (score: 4/6)
    ...

  Progress: 3/5 pages fixed
```

### Step 5: Cross-page consistency check

Re-run `ui-review --scope full` across all pages to verify consistency has improved.

- **Target:** All pages share consistent navigation, spacing, typography, component styling, and tokens
- **Output:** Updated cross-page consistency score (target: >90%)
- **Gate:** Cross-page consistency must be Green (>90%) before merge

```
Display:
  Design Review — re-run after fixes
  Cross-page consistency: 58% → 94% (Green)

  All pages now share:
    ✓ Card style: shadow-md, rounded-lg, var(--space-6) padding
    ✓ Heading scale: 3xl / 2xl / xl
    ✓ Grid gap: var(--space-6)
    ✓ Button variants: consistent primary/outline usage
    ✓ Token coverage: 72% → 96%

  Remaining variance (acceptable):
    /app/billing — extra "overdue" badge variant (intentional)
    /app/team — avatar stack component (unique to this page)

  Status: PASS — cross-page consistency restored
```

## Notes

- The "golden page" concept prevents the common failure mode of fixing each page in isolation and ending up with 6 different interpretations of "correct."
- Token adoption audit (Step 3) often reveals that the consistency problem is systemic — developers used hardcoded values because they didn't know the token existed or the token wasn't documented. Consider updating design system docs after this workflow.
- Fix pages in worst-first order. Each fix improves the overall consistency score, which makes the remaining pages' deviations more visible.
- If cross-page consistency is below 50% in Step 1, the design system may need regeneration. Run `ui-design-system` before proceeding with page fixes.

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `fix-inner-pages` (this) | Multiple pages inconsistent with each other | Cross-page audit + golden reference + per-page fix |
| `fix-broken-design` | Single page broken vs. spec | Single-page diagnosis and fix |
| `design-system-audit` | Token adoption scan | Read-only audit — doesn't fix, just reports |
| `design-polish` | Improve quality of working UI | Quality elevation, not consistency repair |

## Display Format

```
Fix Inner Pages — [project]
  Pages scanned:   [N]
  Pages fixed:     [N/N]
  Consistency:     [before%] → [after%]
  Token coverage:  [before%] → [after%]
  Status: [PASS — consistent | IN PROGRESS — N pages remaining]
```
