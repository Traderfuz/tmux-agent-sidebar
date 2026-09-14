# Redesign Page

Intentionally replace an existing UI page or section with a new design direction. Unlike fix-broken-design (which restores correct behavior) or design-polish (which improves existing quality), this workflow changes the design intent itself — new layout, new hierarchy, new interaction patterns. Includes a structured audit of what exists, a design draft with approval gate, side-by-side quality comparison, and preview deployment before production merge.

## When to Use

- Stakeholder or user feedback indicates the current design approach is wrong, not just poorly executed
- Usability testing shows fundamental UX problems that can't be fixed with polish
- The product direction has changed and the UI needs to reflect new priorities
- A page was built as a prototype and needs to be replaced with a production design
- When the gap between the current UI and the desired experience is too large for incremental fixes

**Do NOT use when:** The implementation is wrong but the design is correct (use fix-broken-design). Do not use for quality polish on a correct design (use design-polish). Do not use when multiple pages need consistency repair (use fix-inner-pages). Do not use when only the style/brand is changing but the layout stays the same (use ai-style-system to update tokens, then fix-broken-design to propagate).

## Process

### Step 1: Audit what exists

Run `ui-review` + `usability-audit` to document the current state — what works, what doesn't, and what users have complained about.

- **Input:** Current page URL + any user feedback, support tickets, or analytics data
- **Output:** Redesign brief with three lists: keep, change, remove

```
Display:
  Redesign Audit — /app/pricing

  KEEP (works well):
    - Pricing tier comparison layout (users understand the 3-column format)
    - Feature checklist per tier (high engagement in analytics)
    - FAQ section (reduces support tickets)

  CHANGE (problems identified):
    - CTA placement — below the fold, users scroll past without seeing it
    - Tier differentiation — visual hierarchy doesn't emphasize recommended plan
    - Mobile layout — tiers stack but comparison is lost
    - Social proof — no testimonials or trust indicators

  REMOVE (no longer needed):
    - Enterprise contact form — moved to separate /enterprise page
    - Changelog link — outdated, confuses users

  User complaints (from support/feedback):
    - "I can't tell which plan is right for me"
    - "The page feels overwhelming with too many features listed"
```

### Step 2: Lock the visual direction

Decide whether the brand/style is changing along with the layout.

- **Same brand direction:** Keep existing `style-tokens.json`. Skip to Step 3.
- **New brand direction:** Run `ai-style-system` to select a new archetype and generate updated tokens.
- **Output:** Confirmed style tokens for the redesign

```
Display:
  Visual direction: Keeping existing archetype (Soft Gradient Premium)
  Style tokens: creative/style-system/acme/style-tokens.json (unchanged)
  
  OR

  Visual direction: New archetype selected — Bold Modern / Sharp Technical
  Style tokens: creative/style-system/acme/style-tokens.json (updated)
```

### Step 3: Draft the new design

Run `ai-design-draft` to create the new page design with approval gate.

- **Input:** Redesign brief (keep/change/remove from Step 1) + style tokens
- **Constraints:** Must preserve items in the "keep" list. Must address items in the "change" list. Must remove items in the "remove" list.
- **Process:** ASCII wireframe → approval gate → HTML preview
- **Gate:** Must get explicit approval before building. The approval gate prevents wasted implementation effort.

```
Display:
  Design Draft — /app/pricing (redesigned)

  Wireframe:
  ┌──────────────────────────────────────────────┐
  │  Hero: "Find your plan" + CTA above fold     │
  ├──────────────────────────────────────────────┤
  │  [Basic]    [★ Pro]      [Team]              │
  │  $9/mo      $29/mo       $79/mo              │
  │  ───────    ───────      ───────             │
  │  features   features     features            │
  │  [Start]    [Start →]    [Start]             │
  ├──────────────────────────────────────────────┤
  │  Social proof bar (logos + testimonial)       │
  ├──────────────────────────────────────────────┤
  │  Comparison toggle (simple ↔ detailed)       │
  ├──────────────────────────────────────────────┤
  │  FAQ (accordion)                             │
  └──────────────────────────────────────────────┘

  Changes from current:
    + CTA moved above fold (hero section)
    + Pro tier visually emphasized (★ badge, larger card)
    + Mobile: swipeable tier cards instead of stacked list
    + Social proof section added
    + Feature comparison is togglable (simple default, detailed on demand)
    - Enterprise form removed
    - Changelog link removed

  Status: Awaiting approval — do not build until approved
```

### Step 4: Build the replacement

After approval, build the new design using `ui-creator` or `frontend-design`.

- **Input:** Approved HTML preview from Step 3 + style-tokens.json
- **Output:** New React components replacing the old page
- **Rule:** Build on a feature branch. Do not modify the production page directly.

```
Display:
  Building redesigned /app/pricing
    ✓ src/app/pricing/page.tsx — rebuilt with new layout
    ✓ src/components/PricingHero.tsx — new component (CTA above fold)
    ✓ src/components/TierCard.tsx — updated with emphasis variant
    ✓ src/components/SocialProof.tsx — new component
    ✓ src/components/FeatureComparison.tsx — new togglable comparison
    ✓ src/components/PricingFAQ.tsx — migrated from old page (kept)

  Old components removed:
    ✗ src/components/EnterpriseForm.tsx — deleted (moved to /enterprise)
    ✗ src/components/ChangelogLink.tsx — deleted

  Branch: redesign/pricing-page
```

### Step 5: Side-by-side comparison

Compare the old and new designs using design quality metrics.

- **Run `ui-design-qa` on both versions** (old production vs. new branch)
- **Compare:** Contrast scores, accessibility scores, visual hierarchy ratings
- **Verify:** New design scores equal or higher on all criteria
- **Run `ui-design-qa --mode verify`** to confirm the new implementation matches the approved preview

```
Display:
  Side-by-side comparison — /app/pricing

  Criterion           | Old design | New design | Delta
  ────────────────────┼────────────┼────────────┼──────
  Visual hierarchy    | Needs work | Pass       | +1
  Contrast            | Pass       | Pass       | =
  Consistency         | Pass       | Pass       | =
  Spacing             | Needs work | Pass       | +1
  Typography          | Pass       | Pass       | =
  Accessibility       | Needs work | Pass       | +1

  Old: 3/6 pass    New: 6/6 pass
  Implementation vs. approved preview: MATCH ✓
```

### Step 6: Ship with rollback plan

Deploy to preview first, verify, then merge to production.

- **Preview deploy:** `deploy` to preview/staging environment
- **Verify in preview:** Run `ui-review` against the preview URL
- **Merge:** Only after preview verification passes

{{include workflows/_shared/git/commit-message-format}}

{{include workflows/_shared/git/push-and-pr}}

```
Display:
  Redesign deployment:
    Preview: https://preview-abc123.vercel.app/pricing ✓
    Design check (preview): 6/6 pass ✓
    PR: #142 — redesign: pricing page with above-fold CTA and tier emphasis
    Status: Ready for production merge

  Rollback plan:
    If issues found post-merge: revert PR #142 (git revert)
    Old page is preserved in git history — zero data loss
```

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `redesign-page` (this) | Change the design direction | New layout, new hierarchy, new interactions |
| `fix-broken-design` | Fix a broken implementation | Restore correct behavior against existing spec |
| `design-polish` | Improve quality of working UI | Elevate without changing the design approach |
| `fix-inner-pages` | Fix cross-page inconsistency | Harmonize pages to a shared standard |
| `design-iteration` | Iterative design refinement | Works within the current design direction |

## Notes

- The approval gate in Step 3 is the most important part of this workflow. Building without approval wastes implementation effort if the design direction is wrong.
- Always build on a feature branch with preview deployment. Never modify production directly during a redesign.
- The "keep" list from Step 1 protects elements that are working. Redesign doesn't mean rebuild everything — it means change what needs changing while preserving what works.
- If the redesign affects shared components (nav, footer, sidebar), the blast radius extends beyond the target page. Run `ui-review --scope full` across all pages after the change to catch unintended side effects.
- Keep the old page accessible in git history. If the redesign underperforms (A/B test, user feedback), you can revert quickly.

## Display Format

```
Redesign Page — [page/route]
  Audit:     keep [N] / change [N] / remove [N]
  Direction: [same archetype | new archetype: name]
  Draft:     [pending approval | approved]
  Build:     [N components new, N updated, N removed]
  Quality:   old [N/6] → new [N/6]
  Status:    [PREVIEW DEPLOYED | MERGED | BLOCKED — approval pending]
```
