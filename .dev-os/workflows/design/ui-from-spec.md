# UI from Spec

Turn an approved wireframe, Figma spec, or Design OS handoff into working React components. Covers two entry paths — importing a Design OS handoff package or drafting from a brief via `ai-design-draft` — then builds components against the design reference and verifies the implementation matches the spec before merge. This is the primary workflow for spec-driven frontend implementation.

## When to Use

- A Figma design or Design OS handoff exists and needs to be implemented
- A wireframe or HTML mockup has been approved and needs to become React components
- After `ui-review --scope full` approves a design and `ui-design-handoff` produces the package
- When a designer hands off a spec and a developer needs to build it
- When `ai-design-draft` has produced an approved HTML preview that needs implementation

**Do NOT use when:** No design reference exists (use new-project-ui to build from scratch). Do not use when copying an existing live UI (use clone-reference-ui). Do not use when the design hasn't been approved yet — run `ui-review --scope full` first.

## Process

### Step 1: Import the design reference

Choose the entry path based on what exists:

**Path A — Design OS handoff (from Figma or design tool):**
Run `consume-design` to import the handoff package.

- **Reads:** `design/export/handoff-to-dev-os.json` (or `.dev-os/state/design-handoff.json` if already consumed)
- **Writes:** `.dev-os/state/design-handoff.json` + component map
- **Produces:** Token files, component specs, reference screenshots

**Path B — Draft from brief (no existing design):**
Run `ai-design-draft` to create the design reference.

- **Input:** Brief description of the page
- **Process:** ASCII wireframe → approval gate → HTML preview
- **Output:** `design-preview-approved.html` + `style-guide.md`
- **Gate:** Must get approval before proceeding to Step 2

```
Display:
  Design reference loaded
  Path: A (Design OS handoff)
  Source: .dev-os/state/design-handoff.json
  Components: Hero, FeatureCard, PricingTable, ContactForm
  Reference HTML: .dev-os/state/design-references/design-preview.html
  Reference screenshots: desktop-1440.png, mobile-375.png
```

### Step 2: Verify design tokens are available

Check that the design system tokens exist and match the design reference.

- **Check:** `style-tokens.json` or `tokens.css` exists with color, spacing, type, radius values
- **Check:** Token values match the reference design (colors, fonts, spacing)
- **If missing:** Run `design-system-generator` or `ui-design-system` to generate tokens from the reference

```
Display:
  Tokens verified
  Source: creative/style-system/acme/style-tokens.json
  Colors: 12 tokens | Spacing: 8 tokens | Type: 6 tokens | Radius: 4 tokens
  Match with reference: ✓ all values consistent
```

### Step 3: Build components

Run `ui-creator` (Mode 3 Companion) for individual components, or `frontend-design` for full page implementations.

- **Input:** "build this as a shadcn React component" + component spec from handoff
- **Reads:** `design-preview-approved.html` (layout reference)
- **Reads:** `style-tokens.json` (via cos-consume bridge)
- **Output:** Production React artifact with correct token usage

Build components in dependency order — shared/atomic components first, then compositions:
1. Atomic components (Button, Input, Badge, Card)
2. Composite components (FeatureCard, PricingTable)
3. Page layout (grid, sections, responsive structure)
4. Page-specific logic (forms, interactions, state)

```
Display:
  Build — 4 components
  Order: atomic → composite → layout → logic
    ✓ FeatureCard (shadcn Card + Badge + tokens)
    ✓ PricingTable (3-column grid + FeatureCard composition)
    ✓ ContactForm (shadcn Form + Input + Button + validation)
    ✓ HeroSection (layout + responsive breakpoints + CTA)
  Token compliance: all values from style-tokens.json
```

### Step 4: Verify implementation matches spec

Run `ui-design-qa --mode verify` to compare the built implementation against the design reference.

- **Capture:** Implementation screenshots at 1440px (desktop) and 375px (mobile)
- **Compare:** Implementation vs. reference screenshots + reference HTML
- **Check:** Spacing, colors, typography, interaction patterns, responsive behavior
- **Gate:** Must pass before merge — all regressions must be classified and resolved

```
Display:
  Design Verify — implementation vs. spec
  Desktop (1440px):
    ✓ Layout structure matches reference
    ✓ Colors match token values
    ✓ Typography matches type scale
    ⚠ Card shadow slightly lighter than reference (intentional — CSS shadow rendering)

  Mobile (375px):
    ✓ Responsive reflow correct
    ✓ Touch targets ≥48px
    ✓ Navigation collapses to hamburger

  Regressions: 0
  Intentional differences: 1 (documented)
  Status: PASS — ready for merge
```

If verification fails, fix the regressions and re-run. Use the design-qa workflow for detailed side-by-side comparison if needed.

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `ui-from-spec` (this) | Build from an approved design spec | Imports reference → builds → verifies against spec |
| `new-project-ui` | Greenfield — no design exists | Creates style + builds from description, no reference |
| `clone-reference-ui` | Copy an existing live UI | Captures from URL/screenshot, not from a spec |
| `design-handoff` | Produce the handoff package | Creates the spec; this workflow consumes it |
| `complete-project-design` | Full multi-page project | Orchestrates this workflow across many pages |

## Notes

- Path A (Design OS handoff) is preferred when a designer has produced the spec. Path B (ai-design-draft) is for developer-led implementation where no designer is involved.
- Always build atomic components first. If you build the page layout first and then extract components later, you'll end up with tightly-coupled components that are hard to reuse.
- The verification gate (Step 4) is the quality contract between design and implementation. Skipping it means regressions go undetected until design-qa or design-review catches them later.
- If the spec changes after implementation starts, re-run Step 1 to update the reference, then re-verify with Step 4. Do not implement against a stale reference.

## Display Format

```
UI from Spec — [page/component name]
  Entry: [Design OS handoff | ai-design-draft]
  Components: [N] built
  Tokens: [verified | generated | missing]
  Verify: [PASS | FAIL — N regressions]
  Status: [ready for merge | blocked]
```
