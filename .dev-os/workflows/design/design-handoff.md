# Design Handoff

Structured handoff from design decisions to implementation-ready artifacts. Captures tokens, layout, interactions, and component specs into a machine-readable package for implementation workflows (`ui-from-spec`, `ui-creator`). Prevents the "designer said blue but developer built teal" class of defects by making every design decision explicit and traceable.

> **Note:** This workflow produces a local handoff artifact (`.dev-os/state/design-handoff.json`) for use by implementation workflows. `consume-design` consumes a different artifact — the Design OS cross-OS export (`design/export/handoff-to-dev-os.json`). These are complementary: use `consume-design` for external Design OS handoffs, use this workflow for internal design-to-dev handoffs.

## When to Use

- After completing a design iteration cycle (`ui-design-iteration`)
- After approving a design draft from superdesign or ai-design-draft
- After manual design decisions are finalized (Figma, whiteboard, verbal)
- Before starting implementation of any frontend feature
- When a design review passes and the design is approved for build

**Do NOT use when:** The design is still in exploration (use variant-exploration workflow instead) or when making code-only changes with no design impact.

## Process

### Step 0: Verify design review was completed [G-001]

Before proceeding, check for a completed design review artifact:

```
Look for: product/design-check/<spec>/design-conditions.md or product/design-check/<spec>-review.md
  with status APPROVED or APPROVED WITH CONDITIONS
```

- **Found with APPROVED or APPROVED WITH CONDITIONS** → proceed to Step 1.
- **Found with REJECTED** → abort. Return to `ui-design-iteration` to fix the failures, then re-run design-review before handoff.
- **Not found** → abort and direct the user:

```
✗ No completed design review found for this spec.
  Run ui-review --scope full first to evaluate the design quality.
  The handoff gate requires an APPROVED or APPROVED WITH CONDITIONS result.
```

**Exception:** If this is a direct `ai-design-draft` → handoff path where a standalone HTML approval was the review, the approval is implicit. Proceed if the user confirms the design was reviewed and approved.

### Step 1: Capture design decisions

Collect all design decisions into a structured inventory. For each decision, record:

- **Tokens**: colors, fonts, spacing, radii, shadows, durations used
- **Layout**: grid structure, breakpoints, content flow, responsive behavior
- **Interactions**: hover states, focus states, transitions, animations, loading states
- **Content**: real copy (not lorem ipsum), image dimensions, icon set

```
Display: Markdown checklist showing each decision category with items found
```

### Step 2: Generate design-system artifacts

From the captured decisions, produce or update:

1. `tokens.css` — CSS custom properties for all visual values (per design-tokens standard)
2. `tailwind.config.ts` or `@theme` block — Tailwind integration for token values
3. `design-system.json` — machine-readable token file (W3C format if applicable)

Verify: every value in the design traces to a token. No hardcoded hex, px, or font names remain unaccounted.

```
Display: File list with token counts — e.g., "tokens.css: 42 tokens (12 color, 8 spacing, 6 type, 4 radius, 4 shadow, 4 duration, 4 font)"
```

### Step 3: Create component specs

For each new or modified component, document:

- **Props interface** (TypeScript types with descriptions)
- **States** (default, hover, focus, active, disabled, loading, error, empty)
- **Variants** (size, color, style variations)
- **Responsive behavior** (what changes at each breakpoint)
- **Accessibility** (ARIA roles, keyboard interactions, focus management)

```
Display: Component spec table — Name | Props | States | Variants | A11y
```

### Step 4: Produce reference artifacts

Generate visual references that developers compare against during implementation:

1. **Desktop screenshot** at 1440px width
2. **Mobile screenshot** at 375px width
3. **Reference HTML** (`design-preview.html`) — a static HTML file showing the approved design

The reference HTML is the source of truth for pixel-level verification via `ui-design-qa --mode verify`.

**Naming convention [G-013]:** The file produced here is a *draft reference* named `design-preview.html`. After the Step 5 checklist passes, rename or copy it to `design-preview-approved.html` at one of these canonical locations to enable `ui-design-qa --mode verify`:

1. `product/specs/<spec-name>/design/design-preview-approved.html` ← preferred
2. `product/design/<spec-name>/design-preview-approved.html`
3. `.dev-os/state/design-preview-approved.html` ← fallback (consumed by `consume-design`)

The `-approved` suffix is the gate signal. `ui-design-qa --mode verify` will not run without it.

```
Display: "Reference artifacts saved to .dev-os/state/design-references/"
```

### Step 5: Validate handoff completeness

Run the handoff checklist — all items must pass before handoff is complete:

- [ ] design-review has been completed — status is APPROVED or APPROVED WITH CONDITIONS [G-008]
- [ ] Every color in the design maps to a token in `tokens.css`
- [ ] Every font size maps to the type scale (per typography standard)
- [ ] Every spacing value is a multiple of the 4px base unit (per spacing standard)
- [ ] Every animation has a defined duration tier and easing (per animation standard)
- [ ] Component specs include all states (not just the happy path)
- [ ] Reference screenshots exist for desktop (1440px) and mobile (375px)
- [ ] `design-handoff.json` is written to `.dev-os/state/`
- [ ] `design-preview.html` has been copied to `design-preview-approved.html` at one of the three canonical locations (see Step 4 naming convention) [G-013]

```
Display: Checklist with PASS/FAIL per item and overall status
```

### Step 6: Write handoff artifact

Write the complete handoff package to `.dev-os/state/design-handoff.json`:

```json
{
  "version": "1.0",
  "date": "2026-03-19",
  "tokens_file": "tokens.css",
  "reference_html": ".dev-os/state/design-references/design-preview.html",
  "screenshots": {
    "desktop": ".dev-os/state/design-references/desktop-1440.png",
    "mobile": ".dev-os/state/design-references/mobile-375.png"
  },
  "components": ["Hero", "FeatureCard", "PricingTable", "ContactForm"],
  "checklist_status": "all_pass"
}
```

This file is consumed by implementation workflows (`ui-from-spec`, `ui-creator`) as the local design reference. For cross-OS handoffs from Design OS, see `consume-design` which reads a separate export format.

## Notes

- The handoff is a one-way gate: design decisions are locked after handoff. Changes require a new design iteration cycle, not ad-hoc modifications during implementation.
- Reference HTML does not need to be functional — it is a visual reference only. No JavaScript, no API calls, no routing.
- Component specs should use the project's actual TypeScript types, not pseudocode.

## Display Format

```
Design Handoff Package — [spec-name]
  Tokens:     [N design tokens exported]
  Components: [N component specs]
  Status:     ready for consume-design
```
