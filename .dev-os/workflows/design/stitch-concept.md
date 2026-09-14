# Stitch Concept

Rapidly generate UI screen concepts using the Google Stitch API without manual wireframing. Produces AI-generated screen mockups from text prompts, iterates on them conversationally, exports a design spec, and hands off to `ui-creator` for production implementation. Best for fast concept exploration when you know what you want but don't want to draw it.

## When to Use

- Need UI mockups fast — exploring layouts, screen concepts, or page variations
- The user says "show me what a dashboard could look like" or "generate a screen for..."
- Comparing multiple screen concepts before committing to a direction
- When manual wireframing would slow down the ideation phase
- Before running `ui-creator` — use Stitch to nail the layout first, then build

**Do NOT use when:** Building production components (use `ui-creator` directly). Do not use when a Figma spec already exists (use ui-from-spec). Do not use when cloning an existing UI (use clone-reference-ui). Do not use for icon or graphic generation (use icon-and-graphic-generation).

## Process

### Step 1: Create a Stitch project

Run `stitch: stitch_create_project` to set up the workspace.

- **Input:** Project name + description
- **Output:** Stitch project ID and workspace URL

```
Display:
  Stitch project created
  Name: acme-dashboard-concept
  Project ID: stitch_abc123
```

### Step 2: Generate screens from prompts

Run `stitch: stitch_generate_screen` for each screen concept needed.

- **Input:** Natural language description of the screen (e.g., "dashboard with sidebar nav, metric cards at top, data table below, dark theme")
- **Output:** Screen with HTML preview + image preview
- **Generate multiple:** Create 2-3 variations if exploring different layouts

```
Display:
  Screen generated: dashboard-v1
  Description: "dashboard with sidebar nav, metric cards, data table"
  Preview: HTML + image available
  
  Screen generated: dashboard-v2
  Description: "dashboard with top nav, full-width metric banner, card grid"
  Preview: HTML + image available
```

### Step 3: Iterate on screens

Run `stitch: stitch_edit_screen` to refine concepts conversationally.

- **Input:** Edit instructions referencing the existing screen (e.g., "make the sidebar collapsible, add a dark mode toggle, change the metric cards to show sparkline charts")
- **Output:** Updated screen with changes applied
- **Loop:** Iterate until the screen matches the intended design

```
Display:
  Screen edited: dashboard-v1 (iteration 2)
  Changes: collapsible sidebar, dark mode toggle added, sparkline charts in metric cards
  Preview: updated HTML + image
```

### Step 4: Export design spec

Run `stitch: stitch_export_design_md` to produce a structured design document.

- **Output:** `DESIGN.md` with component map, layout description, interaction notes
- **Contains:** Screen descriptions, component inventory, responsive behavior notes

```
Display:
  Design spec exported
  File: DESIGN.md
  Components: 6 identified (Sidebar, MetricCard, DataTable, TopNav, DarkModeToggle, SparklineChart)
  Layout: sidebar + main content area, responsive collapse at 768px
```

### Step 5: Hand off to ui-creator

Run `ui-creator` to build production React components from the design spec.

- **Input:** `DESIGN.md` as the layout reference
- **Reads:** `style-tokens.json` (if available) for brand-aligned token injection
- **Output:** Production shadcn React artifact

```
Display:
  Build from Stitch spec
  Reference: DESIGN.md (6 components)
  Tokens: style-tokens.json injected
  Output: src/ React project
    ✓ Sidebar.tsx (collapsible, dark mode aware)
    ✓ MetricCard.tsx (with sparkline chart)
    ✓ DataTable.tsx (sortable, paginated)
    ✓ TopNav.tsx (with dark mode toggle)
    ✓ DashboardLayout.tsx (sidebar + main grid)
```

### Step 6: Verify the build

Run `ui-review` to confirm the built components match the Stitch concept.

- **Compare:** Built components vs. Stitch screen preview
- **Check:** Layout structure, component presence, responsive behavior
- **Gate:** Major deviations from the concept should be flagged and fixed

```
Display:
  Design Check — Stitch concept vs. build
  Layout match: ✓
  Components present: 6/6 ✓
  Responsive behavior: ✓ (sidebar collapses at 768px)
  Status: PASS — build matches concept
```

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `stitch-concept` (this) | Fast AI-generated screen concepts | Uses Stitch API for rapid screen generation |
| `new-project-ui` | Build from description directly | No mockup step — goes straight to code |
| `ui-from-spec` | Build from approved wireframe/Figma | Imports an existing spec, doesn't generate one |
| `clone-reference-ui` | Copy an existing UI | Captures a real UI, doesn't generate from prompt |
| `variant-exploration` | Parallel design exploration | Uses git worktrees for code variants, not AI screen gen |

## Notes

- Stitch-generated screens are concepts, not production code. Always hand off to `ui-creator` (Step 5) for the production build.
- Generate 2-3 screen variations in Step 2 before iterating. It's faster to pick the best starting point than to iterate a suboptimal concept into shape.
- The `DESIGN.md` export (Step 4) is the handoff artifact. It bridges Stitch's AI-generated concepts with `ui-creator`'s component building.
- If `style-tokens.json` exists, Step 5 will produce brand-aligned components. If it doesn't, the build will use `ui-creator`'s defaults — run `ai-style-system` first if brand alignment matters.
- Stitch works best for page-level layouts (dashboards, settings pages, landing pages). For individual component design (a single button, a card variant), use `ui-creator` directly.

## Display Format

```
Stitch Concept — [project/screen name]
  Screens generated: [N]
  Iterations: [N]
  Spec exported: [DESIGN.md | pending]
  Build: [N components from spec]
  Status: [CONCEPT ONLY | BUILT | VERIFIED]
```
