# Clone Reference UI

Reproduce or adapt a UI from a live URL or screenshot. Captures the reference design's layout, color palette, typography, and component patterns, then optionally re-skins it to your own brand identity before building production components. Use when you want "something like that site" as a starting point rather than designing from zero.

## When to Use

- Reproducing a competitor's UI layout for a new project
- Adapting a reference design or inspiration site to your brand
- Rebuilding an internal tool that exists only as a live URL (no source access)
- When a stakeholder says "make it look like this" and provides a URL or screenshot
- When migrating a legacy UI to a new framework while preserving the visual design

**Do NOT use when:** A wireframe or Figma spec exists (use ui-from-spec — it's designed for spec-driven builds). Do not use when building from scratch with no reference (use new-project-ui). Do not use for generating AI mockups (use stitch-concept). Do not use to literally copy a site's code — this workflow captures visual patterns, not source code.

## Process

### Step 1: Capture the reference

Run `ui-clone` to analyze the reference UI.

- **Input:** Live URL or screenshot file path
- **Analyzes:** Layout structure, color palette, typography, component patterns, spacing system, responsive behavior
- **Output:** Reference analysis document with extracted design tokens, component inventory, and layout map

```
Display:
  Reference captured
  Source: https://example.com/dashboard
  Layout: sidebar (240px) + main content (flex)
  Colors: 6 extracted (#1a1a2e, #16213e, #0f3460, #e94560, #f5f5f5, #333)
  Typography: Inter (headings), System UI (body), 16px base
  Components: Sidebar, TopBar, MetricCard (4x), DataTable, ActionButton
  Spacing: 8px base grid (8, 16, 24, 32, 48)
  Responsive: sidebar collapses at 1024px
```

### Step 2: Decide on brand direction

Choose whether to keep the reference's visual style or re-skin to your own brand.

**Option A — Keep reference style:**
Use the extracted color palette and typography directly. Skip to Step 3.

**Option B — Re-skin to your brand:**
Run `ai-style-system` to select your archetype, then `ui-creator` will read your `style-tokens.json` instead of the reference palette.

- The layout and component structure come from the reference
- The visual style (colors, fonts, radius, shadows) comes from your brand tokens
- **Result:** Same layout, different brand identity

```
Display:
  Brand direction: B (re-skin)
  Reference layout: kept (sidebar + main, metric cards, data table)
  Style source: creative/style-system/acme/style-tokens.json
  Archetype: Soft Gradient Premium (replacing reference's Sharp Technical palette)
```

### Step 3: Build the components

Run `ui-creator` to create production React components based on the reference analysis.

- **Input:** "build this layout" + reference analysis from Step 1
- **Reads:** Your `style-tokens.json` (Option B) or extracted reference tokens (Option A)
- **Output:** shadcn React artifact with components matching the reference layout

Build in the same dependency order as the reference:
1. Layout shell (sidebar, main area, responsive structure)
2. Shared components (cards, buttons, form inputs)
3. Page-specific compositions (metric grid, data table, action bar)

```
Display:
  Build from reference
  Components: 6
    ✓ SidebarLayout.tsx (240px sidebar, collapsible at 1024px)
    ✓ TopBar.tsx (search, user avatar, notifications)
    ✓ MetricCard.tsx (icon, value, label, trend indicator)
    ✓ DataTable.tsx (sortable columns, pagination)
    ✓ ActionButton.tsx (primary/secondary variants)
    ✓ DashboardPage.tsx (composition of all components)
  Token source: style-tokens.json (brand-aligned)
```

### Step 4: Compare build against reference

Run `ui-review` to compare the built implementation against the reference.

- **Capture:** Built page at same viewport as the reference
- **Compare:** Layout structure, component placement, spacing proportions, responsive behavior
- **Note:** Colors and fonts will differ if Option B (re-skin) was chosen — that's intentional. Compare layout and structure, not exact pixel colors.

```
Display:
  Reference comparison
  Layout match: ✓ (sidebar + main, same proportions)
  Component count: 6/6 present ✓
  Spacing proportions: ✓ (same relative spacing, different absolute values)
  Responsive: ✓ (sidebar collapses at 1024px)
  
  Intentional differences (Option B re-skin):
    Colors: reference #1a1a2e → brand var(--color-bg-primary)
    Font: reference Inter → brand var(--font-heading)
    Radius: reference 0px → brand var(--radius-md)
  
  Status: PASS — layout matches reference, brand correctly applied
```

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `clone-reference-ui` (this) | Reproduce/adapt from a URL or screenshot | Captures reference first, then builds |
| `new-project-ui` | Greenfield — no reference | Builds from description, no capture step |
| `ui-from-spec` | Build from approved wireframe/Figma | Imports a design spec, not a live site |
| `stitch-concept` | Fast AI mockups | Generates concepts, doesn't capture existing UI |
| `redesign-page` | Replace an existing page design | Changes the design direction of your own page |

## Notes

- `ui-clone` captures layout patterns and visual tokens — it does not copy source code, JavaScript, or backend logic. The output is a design analysis, not a code export.
- Option B (re-skin) is the recommended path for most cases. Directly copying a competitor's visual identity creates legal and brand risks. Use the layout as inspiration but apply your own brand.
- The reference analysis from Step 1 is reusable. If you're building multiple pages that reference the same site, capture once and reference the analysis document for each page build.
- For multi-page reference captures (e.g., "build all 5 pages like that SaaS app"), use `complete-project-design` with this workflow as the per-page build step in Phase 2.

## Display Format

```
Clone Reference UI — [source URL or screenshot]
  Reference: [URL | screenshot path]
  Components captured: [N]
  Brand direction: [keep reference | re-skin to [archetype]]
  Components built: [N]
  Layout match: [PASS | FAIL — N deviations]
  Status: [PASS — ready | BLOCKED — layout mismatch]
```
