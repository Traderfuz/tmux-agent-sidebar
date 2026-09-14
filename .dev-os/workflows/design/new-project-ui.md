# New Project UI

Build a brand-aligned UI page or component from scratch when no existing assets, design system, or style tokens exist. Chains style selection, component building, and bundling into a single workflow with a verification gate before delivery. This is the default starting workflow for any greenfield frontend project.

## When to Use

- Starting a new product or feature with no existing UI
- Building a standalone page (landing page, login, dashboard) for a new project
- Prototyping a UI concept where no brand identity exists yet
- When the user says "build me a page" or "create a UI" without referencing an existing design

**Do NOT use when:** A wireframe, Figma spec, or design reference already exists (use ui-from-spec). Do not use when cloning an existing UI (use clone-reference-ui). Do not use when the project already has a design system and style tokens — skip Step 1 and use `ui-creator` directly.

## Process

### Step 1: Lock the visual style

Run `ai-style-system` to select an aesthetic archetype and generate the token foundation.

- **Input:** Product description, target audience, mood/tone (e.g., "SaaS product, tech audience, clean and modern, not corporate")
- **Output:** Archetype selected (e.g., "Soft Gradient Premium") + `style-tokens.json` written
- **Location:** `creative/style-system/{client}/style-tokens.json`

**Shortcut:** If the archetype is already known, pass it directly — `ui-creator` will look up the variant table automatically.

```
Display:
  Style — archetype selected
  Archetype: Soft Gradient Premium
  Tokens: creative/style-system/acme/style-tokens.json
  Radius: 0.75rem | Button: default | Card: shadow-md | Badge: secondary
```

### Step 2: Build the UI component or page

Run `ui-creator` to create the React artifact from a natural language description.

- **Input:** Description of the UI (e.g., "login page with email/password, Google OAuth button, forgot password link")
- **Reads:** `style-tokens.json` automatically via the cos-consume bridge — injects palette, radius, font, and spacing tokens
- **Output:** `src/` React project with `App.tsx` + `index.css` (or equivalent shadcn structure)

For multi-component pages, use `frontend-design` instead of `ui-creator` — it handles forms, dashboards, and multi-section layouts.

```
Display:
  Build — component created
  Skill: ui-creator
  Components: LoginForm, OAuthButton, ForgotPasswordLink
  Tokens injected: palette (12), radius (0.75rem), font (Inter)
  Output: src/App.tsx + src/components/ (3 files)
```

### Step 3: Quick QA check

Run `ui-review` on the built component to catch obvious issues before bundling.

- **Input:** Local dev server URL or file path
- **Output:** Severity-rated findings (P0/P1/P2)
- **Gate:** Fix any P0 issues before proceeding. P1/P2 can be tracked.

```
Display:
  QA — quick check
  Page: localhost:3000
  P0: 0 | P1: 1 (button contrast at 3.8:1) | P2: 0
  Action: Fix P1 before bundling
```

### Step 4: Bundle for sharing

Run `web-artifacts-builder` to produce a single-file HTML preview.

- **Run:** `init-artifact.sh` + `bundle-artifact.sh`
- **Output:** `bundle.html` (single file, no server needed, shareable)

```
Display:
  Bundle — complete
  Output: bundle.html (380KB)
  Open: file:///path/to/bundle.html
```

### Step 5: Verify and deliver

Run `ui-review` on the bundled output to confirm the final artifact matches the intended design.

- **Compare:** Bundled output vs. style-tokens.json (token compliance)
- **Gate:** Must pass before sharing with stakeholders or merging

```
Display:
  Verify — final check
  Token compliance: 100% (all values from style-tokens.json)
  Contrast: WCAG AA pass
  Status: PASS — ready to share
```

## Differences from Related Workflows

| Workflow | Use case | Key difference |
|----------|----------|----------------|
| `new-project-ui` (this) | Greenfield — no assets exist | Style selection + build + bundle from zero |
| `ui-from-spec` | Wireframe or Figma spec exists | Imports design reference, builds to match |
| `clone-reference-ui` | Copying an existing UI | Captures reference first, then builds |
| `stitch-concept` | Fast AI-generated mockups | Generates screens via Stitch API, not direct build |
| `complete-project-design` | Full multi-page project | Orchestrates this workflow across many pages |

## Notes

- Step 1 can be skipped if the project already has `style-tokens.json`. Pass the archetype name directly to `ui-creator`.
- For a full project with many pages, use `complete-project-design` which runs this workflow per-page inside Phase 2.
- The bundle step (Step 4) is optional for in-project development — it's primarily for sharing previews with stakeholders who don't run dev servers.
- Always run `ui-review` (Step 3) before bundling. Catching issues early avoids re-bundling.

## Display Format

```
New Project UI — [component/page name]
  Archetype: [name | existing tokens]
  Components: [N] built
  QA: P0: [N] P1: [N] P2: [N]
  Bundle: [bundle.html | skipped]
  Status: [PASS — ready | BLOCKED — P0 issues]
```
