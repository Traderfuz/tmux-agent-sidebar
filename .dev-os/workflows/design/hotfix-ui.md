# Hotfix UI

Emergency fix for a visually broken production page. Optimized for speed and minimal blast radius — diagnose fast, fix only what's broken, verify the fix doesn't regress other pages, and ship independently from feature work. This is the design equivalent of a code hotfix: smallest possible change to restore correct visual behavior.

## When to Use

- A production page is visually broken after a recent deploy
- A CSS or dependency update caused visible regressions
- A user or stakeholder reports a visual defect that needs immediate resolution
- The dev server shows a layout break that blocks a demo or review

**Do NOT use when:** The issue is cosmetic polish, not a break (use design-polish). Do not use when multiple pages need systematic repair (use fix-inner-pages). Do not use when the design direction needs to change (use redesign-page). Do not use for backend-only bugs with no visual impact.

## Process

### Step 1: Screenshot the problem

Run `ui-review` against the production URL to capture the exact visual state and identify broken elements.

- **Input:** Production URL or staging URL where the bug is visible
- **Capture at:** The viewport size where the issue is reported (default: desktop 1440px + mobile 375px)
- **Output:** Specific broken elements with severity ratings

```
Display:
  Design Check — https://app.example.com/dashboard
  Findings: 3 issues
    P0: Main content area — entire layout collapsed to single column (was 3-column grid)
    P0: Hero section — background image missing, showing white void
    P1: Sidebar nav — z-index conflict, rendered behind main content
```

### Step 2: Isolate the cause

Run `systematic-debugging` or `diagnose-first` to identify the root cause without guessing.

Check these common visual break causes in order:

1. **Recent deploy diff** — what changed in the last deploy? (`git diff HEAD~1 -- "*.css" "*.tsx" "*.ts"`)
2. **CSS specificity conflict** — did a new class override an existing one?
3. **Missing or changed tokens** — was a CSS variable removed or renamed?
4. **Responsive breakpoint change** — did a media query threshold shift?
5. **Z-index stacking issue** — did a new element create a stacking context?
6. **Overflow / container issue** — did a parent container change its sizing?
7. **Font / asset loading failure** — is an external resource failing to load?
8. **Dependency update** — did a package update change default styles?

```
Display:
  Root cause isolation:
  ✓ Recent deploy diff: tailwind.config.ts changed — screens.lg moved from 1024px to 1280px
  → Grid switches from 3-col to 1-col at 1024-1280px range
  → Background image class uses lg: prefix, now doesn't apply at 1024px

  Fix: Restore screens.lg to 1024px in tailwind.config.ts
  Blast radius: 1 file, 1 line change
```

### Step 3: Minimal targeted fix

Edit only the specific file(s) that cause the regression. Do not refactor, do not improve, do not clean up.

- **Rule:** Fix only what's broken. The smallest change that restores correct behavior.
- **Do not:** Add comments, refactor surrounding code, update dependencies, or improve adjacent components
- **Do not:** Change files unrelated to the visual break

```
Display:
  Fix applied:
    tailwind.config.ts:14 — screens.lg: "1024px" (restored from "1280px")
  
  Files changed: 1
  Lines changed: 1
```

### Step 4: Visual regression check

Run `ui-design-qa --mode verify` to confirm the fix resolves the issue AND doesn't break other pages.

- **Check the broken page:** Does it render correctly now?
- **Check 2-3 other pages:** Do they still render correctly? (regression scan)
- **Compare:** Fixed page vs. last known good state (before the breaking deploy)

```
Display:
  Design Verify — post-hotfix
  Fixed page (/dashboard):
    ✓ 3-column grid restored at 1024px
    ✓ Background image visible
    ✓ Sidebar z-index correct

  Regression scan (3 other pages):
    ✓ /settings — no visual change (expected)
    ✓ /billing — no visual change (expected)
    ✓ /profile — no visual change (expected)

  Status: PASS — safe to deploy
```

If the fix introduces new regressions, the change was too broad. Revert and re-diagnose with a narrower scope.

### Step 5: Ship the hotfix

Commit and deploy independently from any in-progress feature work.

{{include workflows/_shared/git/commit-message-format}}

- **Branch:** `hotfix/fix-[brief-description]` (or commit directly to main if your workflow allows)
- **Commit message:** `fix(ui): [what was broken and why]`
- **Deploy:** Ship the hotfix independently — do not bundle with feature PRs

```
Display:
  Hotfix shipped:
    Branch: hotfix/fix-dashboard-grid-breakpoint
    Commit: fix(ui): restore lg breakpoint to 1024px — grid collapsed at 1024-1280px
    Deploy: production ✓
    Time from report to fix: ~15 min
```

## Notes

- Speed matters for hotfixes, but accuracy matters more. A wrong hotfix that creates new regressions is worse than a slow correct fix.
- Always check the recent deploy diff first (Step 2, check #1). Most visual breaks trace to a recent change.
- The regression scan in Step 4 is non-negotiable. A hotfix that fixes one page and breaks three others is a net negative.
- If the root cause is unclear after 15 minutes of debugging, escalate — roll back the breaking deploy while continuing to diagnose.
- Keep the hotfix commit separate from all other work. This makes rollback trivial if the fix is wrong.

## Display Format

```
Hotfix UI — [page/route]
  Issue:     [brief description]
  Cause:     [root cause in one line]
  Fix:       [N files, N lines changed]
  Regression: [N pages checked, N clean]
  Status:    [DEPLOYED | BLOCKED — regression detected]
```
