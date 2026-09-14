# Complete Project Design

End-to-end design pipeline for a full project — from brand identity through page building, quality verification, and deployment. Chains the foundation, build, QA, and ship phases into a single sequenced workflow with explicit gates between phases. Use when building or overhauling the entire UI for a product, not just one page.

## When to Use

- Starting a new product and need to build the full UI from scratch
- Overhauling an existing product's entire visual layer
- Re-platforming a product (e.g., migrating from one framework to another and rebuilding all UI)
- A client engagement where the deliverable is a complete designed and built frontend
- After a major brand refresh where all pages need to reflect the new identity

**Do NOT use when:** Only one page needs work (use the specific workflow: fix-broken-design, design-polish, redesign-page). Do not use for incremental feature additions to an existing product (use the "New project UI from scratch" or "UI from wireframe/Figma" workflow for the new page). Do not use when the backend/API is the focus and UI is minimal (overkill).

## Process

### Phase 1: Foundation (brand + tokens + assets)

#### Step 1: Lock the visual style

Run `ai-style-system` to select an aesthetic archetype and generate the token foundation.

- **Input:** Product description, target audience, mood/tone
- **Output:** Archetype selected + `style-tokens.json` written
- **Location:** `creative/style-system/{client}/style-tokens.json`

```
Display:
  Foundation — Style
  Archetype: Soft Gradient Premium
  Tokens written: creative/style-system/acme/style-tokens.json
  Production injection: creative/style-system/acme/production-injection.txt
```

#### Step 2: Generate the design system

Run `design-system-generator` or `ui-design-system` to produce the token files that components consume.

- **Input:** `style-tokens.json`
- **Output:** `tokens.css`, `tailwind.config.ts`, `design-system.json`

```
Display:
  Foundation — Design System
  Generated: tokens.css (42 tokens), tailwind.config.ts, design-system.json
  Categories: 12 color, 8 spacing, 6 type, 4 radius, 4 shadow, 4 duration, 4 font
```

#### Step 3: Generate brand assets

Run icon and image generation in parallel with Step 2. Always append the `production_injection` string.

- **Icons:** `replicate: generate_svg_recraft` — UI icons matching the brand
- **Hero images:** `nano-banana: generate_image` — section graphics
- **Logo:** `nano-banana: generate_logo_variations` — dark/light/icon variants

```
Display:
  Foundation — Assets
  Icons: 12 SVGs generated (nav, actions, status indicators)
  Hero: 3 section images generated
  Logo: 4 variants (full-dark, full-light, icon-dark, icon-light)
```

#### Step 4: Foundation gate

Verify all foundation artifacts exist before proceeding to build.

- **Check:** `style-tokens.json` exists and has all required fields
- **Check:** `tokens.css` has color, spacing, type, radius, shadow, duration categories
- **Check:** `archetype.txt` is set in `product/design-system/`
- **Check:** Icon SVGs and logo variants are present
- **Gate:** Do not proceed to Phase 2 until all checks pass

```
Display:
  Foundation Gate — PASS
  ✓ style-tokens.json (complete)
  ✓ tokens.css (42 tokens across 7 categories)
  ✓ archetype.txt → "Soft Gradient Premium"
  ✓ Icons: 12 SVGs
  ✓ Logo: 4 variants
  → Proceeding to Phase 2: Build
```

---

### Phase 2: Build (pages + components)

#### Step 5: Plan the page inventory

List all pages/routes the app needs. Prioritize by importance — build the core feature page first.

- **Input:** Product spec, sitemap, or user story map
- **Output:** Ordered page list with priority and description

```
Display:
  Page Inventory — 8 pages planned
  Priority | Page              | Description
  ─────────┼───────────────────┼──────────────────────────
  P1       | /app/dashboard    | Core feature — metric cards, data table
  P1       | /app/onboarding   | First-run experience — 3-step wizard
  P2       | /app/settings     | User preferences and account management
  P2       | /app/billing      | Plan selection and payment
  P3       | /app/profile      | User profile and avatar
  P3       | /app/team         | Team management and invites
  P3       | /app/integrations | Third-party connections
  P4       | /app/help         | FAQ and support contact
```

#### Step 6: Build each page (repeat per page)

For each page in priority order:

**a. Draft the design**
Run `ai-design-draft` with the page description + style-tokens.json.
- ASCII wireframe → approval gate → HTML preview
- **Gate:** Get explicit approval before building. Do not skip this.

**b. Build the page**
Run `ui-creator` (single components) or `frontend-design` (full page features).
- Input: approved HTML preview + style-tokens.json
- Output: React components for the page

**c. Quick QA**
Run `ui-review` on the built page.
- Catch P0 issues immediately before moving to the next page
- P1/P2 issues are tracked for Phase 3

```
Display:
  Build — Page 1/8: /app/dashboard
  a. Draft: approved ✓
  b. Build: 4 components (MetricCard, DataTable, FilterBar, DashboardLayout)
  c. QA: 0 P0, 1 P1 (card shadow missing), 2 P2 (tracked for Phase 3)
  
  Build — Page 2/8: /app/onboarding
  a. Draft: approved ✓
  b. Build: 3 components (StepIndicator, OnboardingForm, WelcomeScreen)
  c. QA: 0 P0, 0 P1, 1 P2 (tracked)
  
  Progress: 2/8 pages built
```

#### Step 7: Extract shared components

After 2-3 pages are built, identify and extract repeated patterns into shared components.

- **Candidates:** Navigation, Footer, Card, Button variants, Form inputs, Modal, Toast
- **Extract:** Create standalone components that all pages import
- **Verify:** Existing pages still render correctly after extraction

```
Display:
  Shared Components — extracted 6
  ✓ Navigation (used by 8/8 pages)
  ✓ Footer (used by 8/8 pages)
  ✓ Card (used by 5/8 pages)
  ✓ FormInput (used by 4/8 pages)
  ✓ Modal (used by 3/8 pages)
  ✓ Toast (used by 6/8 pages)
```

#### Step 8: Bundle previews for stakeholder review

Run `web-artifacts-builder` to create shareable HTML previews of key pages.

```
Display:
  Bundles — 3 previews created
  bundle-dashboard.html (420KB)
  bundle-onboarding.html (310KB)
  bundle-billing.html (380KB)
  → Share with stakeholders for feedback before Phase 3
```

---

### Phase 3: QA and fix (review + diagnose + repair)

#### Step 9: Full design review

Run `ui-review --scope full` across all pages.

- **Auto-discovers:** All routes
- **Scores:** Each page against 6 design criteria
- **Output:** Per-page scores + cross-page consistency percentage

```
Display:
  Design Review — all 8 pages
  /app/dashboard:    6/6 pass
  /app/onboarding:   5/6 (spacing: needs work)
  /app/settings:     4/6 (consistency: fail, spacing: needs work)
  /app/billing:      5/6 (typography: needs work)
  /app/profile:      6/6 pass
  /app/team:         5/6 (consistency: needs work)
  /app/integrations: 6/6 pass
  /app/help:         6/6 pass

  Cross-page consistency: 82% (Yellow)
```

#### Step 10: Usability audit

Run `usability-audit` on primary user journeys.

- **Journeys:** Onboarding, core task, settings change, billing update
- **Output:** Friction points with severity

#### Step 11: Design system audit

Run `ui-design-system-audit` for token coverage.

- **Output:** Coverage %, hardcoded values per file, unused tokens

#### Step 12: Fix using the right diagnostic workflow

Route each finding to the correct fix workflow:

| Finding type | Workflow |
|---|---|
| Single page has regressions vs. spec | fix-broken-design |
| Multiple pages visually inconsistent | fix-inner-pages |
| Shared component broken across all pages | fix-inner-pages (golden page + per-page fix) |
| Pages work but quality is low | design-polish |
| Design direction is wrong for a page | redesign-page |
| Accessibility failures (contrast, focus, ARIA) | design-qa + targeted fix per finding |
| Token coverage below 70% | design-system-audit first, then fix-inner-pages |
| Production broke after deploy | hotfix-ui (minimal fix, ship fast) |

#### Step 13: Re-verify

Re-run `ui-review --scope full` after all fixes. Loop Steps 12-13 until:
- All pages score green on all 6 criteria
- Cross-page consistency >90%

#### Step 14: Final accessibility pass

Run `ui-design-qa` for contrast, keyboard nav, focus states, ARIA labels.

```
Display:
  Phase 3 Complete
  Before: 4/8 pages fully passing, consistency 82%
  After:  8/8 pages fully passing, consistency 96%
  Token coverage: 78% → 97%
  Accessibility: all WCAG AA criteria met
  → Proceeding to Phase 4: Ship
```

---

### Phase 4: Ship (deploy + monitor)

#### Step 15: Pre-deployment checks

Run `verify` to confirm build health.

- **Check:** TypeScript compiles, no broken imports, build succeeds
- **Check:** Design review status is green for all pages

#### Step 16: Preview deploy

Run `deploy` to preview/staging environment.

- Run `ui-review` against the preview URL
- Test on real devices if possible

#### Step 17: Production deploy

Run `deploy` to production after preview passes.

{{include workflows/_shared/git/commit-message-format}}

#### Step 18: Post-deploy verification

Run `ui-review` against the production URL.

- Catch deployment-specific issues (CDN, fonts, images)
- If issues found: use hotfix-ui workflow for fast resolution

```
Display:
  Ship Complete
  Preview: verified ✓
  Production: deployed ✓
  Post-deploy check: all pages rendering correctly ✓
  
  Project summary:
    Pages built: 8
    Components: 24 (6 shared, 18 page-specific)
    Design system: 42 tokens, 97% adoption
    Quality: 8/8 pages green, 96% cross-page consistency
```

## Notes

- Phase gates are mandatory. Do not skip the foundation gate (Step 4) or the QA re-verification (Step 13). Skipping gates leads to compounding problems.
- Build pages in priority order, not alphabetical or random order. The first page establishes patterns that all subsequent pages follow.
- Extract shared components early (after 2-3 pages). Waiting until all pages are built makes extraction harder because each page will have its own variant of shared elements.
- Phase 3 is where most time is spent. Building pages is fast; making them consistent and polished takes iteration. Plan for 2-3 QA loops.
- The page inventory (Step 5) may change during the project. New pages get added to the bottom of the priority list, not inserted into the middle of the build queue.

## Display Format

```
Complete Project Design — [project]
  Phase:      [1 Foundation | 2 Build | 3 QA | 4 Ship]
  Foundation: [pending | complete]
  Pages:      [N/N built] ([N/N passing QA])
  Consistency: [N%]
  Token coverage: [N%]
  Status:     [IN PROGRESS — Phase N | SHIPPED]
```
