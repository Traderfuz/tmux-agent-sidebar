# Design Iteration

Improve a design through a structured screenshot → review → fix → screenshot loop. Unlike fix-broken-design (which fixes regressions against a spec), this workflow is used when the design itself needs iterative refinement — the implementation is correct but the design direction, layout, or visual quality should be improved.

## When to Use

- A page is working but the design needs refinement — proportions, spacing, visual hierarchy
- Design review returned "Approved with conditions" and the conditions require iteration on the design itself, not a bug fix
- Exploring multiple design directions before committing to one (use with `variant-exploration` for side-by-side comparison)
- When a stakeholder asks "can we make this feel more polished?" — not a bug, a quality improvement

**Do NOT use when:** The implementation has visual regressions against the spec (use `fix-broken-design`). Do not use when the design direction is fundamentally wrong (use `redesign-page`). Do not use when the issue is token coverage (use `design-system-audit`).

## Process

### Step 1: Capture baseline

Run `design-check` on the page to establish the current state before any changes.

- **Input:** Dev server URL and target page route
- **Capture at:** 1440px desktop and 375px mobile
- **Output:** Baseline screenshot + issue inventory

```
Display:
  Design Check — /app/dashboard (baseline)
  Score: 4/6 criteria passing

  Issues found:
    P1: Visual hierarchy — secondary actions equal weight to primary
    P1: Spacing — stat cards at 12px gap (should be 16px on 4px scale)
    P2: Typography — heading 24px instead of var(--font-size-2xl)
    P2: Color — border #e0e0e0 instead of var(--color-border)
```

### Step 2: Identify improvement targets

Review the design-check output and identify 2-4 specific improvements for this iteration. Limit scope — one iteration should not attempt to fix everything.

- **Priority:** Tackle P1 issues before P2
- **Limit:** 2-4 changes per iteration (more changes = harder to verify cause-and-effect)
- **Document:** Write down the exact changes planned before touching code

```
Display:
  Iteration 1 plan:
  1. Fix visual hierarchy — demote secondary actions to ghost/outline style
  2. Fix stat card gap — 12px → 16px (var(--space-4))
  3. Fix heading font size — hardcoded 24px → var(--font-size-2xl)
```

### Step 3: Implement improvements

Apply the planned changes. Prefer token references over hardcoded values.

- **Scope:** Only the changes listed in Step 2
- **Standard:** All visual values must reference design tokens (use `design-system-audit` first if token coverage is <80%)
- **Do not:** Fix unrelated issues discovered during implementation — add them to a next-iteration list

### Step 4: Screenshot and compare

Run `design-verify` to compare the updated design against the baseline.

- **Input:** Same page route and viewport sizes as Step 1
- **Compare:** Before screenshot (baseline) vs. after screenshot
- **Gate:** Each planned change should be visually confirmed in the diff

```
Display:
  Design Verify — /app/dashboard (iteration 1)
  Changes detected: 3 of 3 planned

  ✓ Visual hierarchy — secondary actions now ghost style (confirmed)
  ✓ Spacing — stat card gap 12px → 16px (confirmed)
  ✓ Typography — heading var(--font-size-2xl) applied (confirmed)

  New issues introduced: 0
  Regression scan: no shared component changes
```

**If new issues appeared:** Add them to the next-iteration list; do not fix inline unless they are P0 blockers.

**If planned changes are not visible:** Investigate before proceeding — the change may not have applied (cache, SSR, wrong selector).

### Step 5: Assess quality and decide

After verifying the iteration, assess the current state:

- **Meets target:** If the design-check score improved to the target threshold → done
- **More iteration needed:** If P1 issues remain → return to Step 2 with a new 2-4 item plan
- **Convergence:** Stop after 3 iterations without improvement — escalate to `redesign-page` if the design is not converging

```
Display:
  After iteration 1:
  Score: 5/6 criteria passing (was 4/6)
  Remaining P1: 0
  Remaining P2: 1 (color border)

  → One more iteration to close P2 issue, then done
```

## Output Format

After each iteration, display a summary block:

```
Design Iteration — /app/dashboard
Iteration: N
Changes applied: N of N planned
Score: X/6 → Y/6
Remaining P1: N | Remaining P2: N
Status: [Done | Continue to iteration N+1 | Escalate to redesign-page]
```

## Iteration Tracking

Track iterations to detect convergence failure:

| Iteration | Changes made | Score before | Score after | New issues |
|-----------|-------------|-------------|-------------|------------|
| 1 | Hierarchy, spacing, typography | 4/6 | 5/6 | 0 |
| 2 | Color border token | 5/6 | 6/6 | 0 |

**Convergence signal:** 6/6 criteria passing, or 2 consecutive iterations with no score improvement.

**Escalation:** If 3 iterations produce no improvement, the design direction itself needs rethinking — use `redesign-page` instead.

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `design-iteration` (this) | Iterative quality improvement | Changes the design; tracks iterations to convergence |
| `fix-broken-design` | Fix regressions against a spec | Implementation is wrong; spec is the target |
| `design-polish` | End-of-sprint polish pass | Full-app polish across all pages; uses usability audit |
| `redesign-page` | Replace design direction | Changes the design intent, not just quality |
| `variant-exploration` | Compare multiple directions | Side-by-side options before committing |

## Notes

- Keep iterations small (2-4 changes) — larger changes make it impossible to verify what improved what.
- Design iteration and `variant-exploration` are complementary: use `variant-exploration` to choose a direction, then use `design-iteration` to refine it.
- After completing design iteration, if the page is a shared component page (e.g., a design system showcase), run `fix-inner-pages` to propagate the improvements to all pages using those components.
