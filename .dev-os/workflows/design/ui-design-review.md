# Design Review Pipeline

Whole-project visual UI audit pipeline for a live project. Discovers all reviewable routes, captures page screenshots, runs the design-check heuristic pass against each page, and produces one aggregate report prioritized by severity. Browser capture follows `profiles/general/standards/global/browser-review-policy.md`: Playwright CLI default driver, `browser-cdp` visible local target when watchable review is appropriate, Playwright-managed headed/headless fallback/CI targets, and Playwright MCP fallback automation. This is the canonical procedure behind `design-review`.

## When to Use

- Auditing an entire app or marketing site for design debt in one run
- Building a remediation list before `write-spec`
- Running a post-implementation heuristic sweep across all important routes
- Performing a design-health checkpoint before handoff or release

**Do NOT use when:** reviewing a single mock or one implementation screen. Use `design-approval-review.md` for single-design approval before handoff, and `design-check` for one-page iterative review.

## Runtime Ownership

- Deterministic artifact-path and config helpers live in `scripts/lib/design-review.sh`
- `design-check` remains the single-page heuristic evaluation surface
- `design-verify` remains the pixel-diff confirmation surface when an approved artifact exists

## Process

### Step 1 — Playwright pre-flight

Before resolving routes or URLs, check whether Playwright is available:

```bash
npx playwright --version 2>/dev/null
```

- **If available:** set `playwright_available=true`. Screenshots will be captured automatically with selected driver, selected target, auth path, backend, artifact paths, and fallback reason recorded in the report.
- **If absent:** set `playwright_available=false`. Print once:
  ```
  ⚠ Playwright not found. Screenshots must be provided manually for each page.
  Install with: npm install -D playwright && npx playwright install chromium
  Continuing in manual-screenshot mode.
  ```
  In manual-screenshot mode the command prompts for a screenshot path before each page audit.

### Step 2 — Resolve Base URL

Determine the base URL in this priority order:

1. `--url <base-url>` flag
2. `base_url` field in `.dev-os/design-review.yml` (or `--config` path)
3. Prompt: `"What is the base URL for this project? (e.g. http://localhost:3000 or https://preview.vercel.app)"`

**If the URL starts with `http://localhost`, always restart the dev server before auditing.** A stale dev server may be serving an older build.

```bash
# Kill any process on the port
lsof -ti :<port> | xargs kill -9 2>/dev/null
echo "Dev server stopped."
```

Then detect project framework and Doppler config:

- Check `.dev-os/design-review.yml` for `doppler_project` and `doppler_config`
- Otherwise check `doppler --version 2>/dev/null`
- If Doppler is available, use: `doppler run --project <project> --config <config> -- <cmd>`
- If no Doppler config is known, fall back to: `doppler run -- <cmd>`
- If Doppler is not installed, run without it

Framework detection:
- Astro project (`astro.config.*` present): `bun run dev` (preferred) or `npx astro dev`
- Next.js project (`next.config.*` present): `bun run dev` or `npm run dev`
- Other: `npm run dev`

Poll until ready (max 30s, check every 2s):

```bash
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code}" <base-url>/ | grep -q "^[23]" && break
  sleep 2
done
```

Print: `Dev server restarted at <base-url>`
If still not ready after 30s: print error and exit.

### Step 3 — Discover Routes

Discover pages using the first available source (stop at the first source that yields routes):

**Source A — Astro `src/pages/` directory**
- Detect: `src/pages/` exists and `astro.config.*` is present
- Scan `src/pages/**/*.{astro,tsx,jsx,js,md,mdx}`
- Derive URLs:
  - `src/pages/index.astro` → `/`
  - `src/pages/pricing.astro` → `/pricing`
  - `src/pages/services/index.astro` → `/services`
  - `src/pages/services/ai-seo.astro` → `/services/ai-seo`
- Exclude: `404`, `500`, files prefixed `_`, and any path containing `api/`
- For Astro blogs/docs, group to top-level and key second-level routes only

**Source B — Next.js `app/` directory**
- Scan `app/**/page.{tsx,jsx,js}`
- Derive URLs:
  - `app/page.tsx` → `/`
  - `app/dashboard/page.tsx` → `/dashboard`
  - `app/settings/profile/page.tsx` → `/settings/profile`
- Exclude: `api/`, `layout`, `loading`, `error`, `not-found`, `_app`, `_document`

**Source C — Next.js `pages/` directory (legacy)**
- Scan `pages/**/*.{tsx,jsx,js}`
- Exclude `_app`, `_document`, `api/`

**Source D — `sitemap.xml`**
- Look for `public/sitemap.xml` or `sitemap.xml`
- Parse `<loc>` entries

**Source E — Manual config**
- Read `routes:` list from `.dev-os/design-review.yml`

**Fallback**

If none of the above yield routes, use `['/']` and print:

```
⚠ No routes discovered automatically. Auditing / only.
Add routes to .dev-os/design-review.yml or run --init to create a config.
```

**Route confirmation** (skipped if `--yes`):

```
Discovered 8 routes:
  /
  /dashboard
  /settings
  /settings/profile
  ...

Proceed? (Y/n)
```

### Step 4 — Per-page visual audit

For each route, construct `<base-url><route>` and:

**4a. Print progress**

```
Auditing [N/total]: <route>
```

**4b. Capture screenshots**

Determine the run folder:

```
product/design-check/YYYY-MM-DD/
```

Use route-named screenshot files, not generic `capture-*` names.

If `playwright_available=true`:

```bash
npx playwright screenshot --full-page --viewport-size="1440,900" <url> product/design-check/YYYY-MM-DD/<route-slug>/<route-slug>-desktop.png
```

If `--full`, also capture:

```bash
npx playwright screenshot --full-page --viewport-size="768,1024" <url> product/design-check/YYYY-MM-DD/<route-slug>/<route-slug>-tablet.png
npx playwright screenshot --full-page --viewport-size="375,812"  <url> product/design-check/YYYY-MM-DD/<route-slug>/<route-slug>-mobile.png
```

If `playwright_available=false`:

```
Provide screenshot for <route> (paste file path, or press Enter to SKIP):
```

If skipped: mark page verdict as `SKIPPED` and continue.

**4c. Evaluate across six dimensions**

| Dimension | What to check |
|-----------|--------------|
| **A. Visual Hierarchy** | Clear focal point, heading size/weight levels, spacing dead zones |
| **B. Spacing & Layout** | Padding/margin uniformity, consistent grid, cramped or floating elements |
| **C. Typography** | Size/weight hierarchy, line length (45–75 chars body), text–background contrast |
| **D. Color & Contrast** | Style token compliance, WCAG-level text contrast, interactive vs static distinction |
| **E. Component Fidelity** | Intentional styling vs browser defaults, interactive states visible |
| **F. Responsive** | *(Only if `--full`)* Reflow at tablet/mobile, text overflow, tap targets ≥ 44×44px |

**4d. Assign severity**

| Severity | Criteria |
|----------|----------|
| **Critical** | Layout broken, text unreadable, element overlap/clipping, major misalignment |
| **High** | Inconsistent spacing scale across pages, heading hierarchy broken |
| **Medium** | Minor alignment drift, missing component states (hover, focus) |
| **Low** | Subtle polish opportunities |

**4e. CSS Overflow Audit**

After capturing the screenshot, fetch the rendered page HTML and inspect hidden overflow patterns:

```bash
curl -s <url> | grep -iE 'overflow\s*:\s*hidden' | head -20
```

Flag these findings:

| Pattern | Severity | What it signals |
|---------|----------|----------------|
| `overflow: hidden` on `<body>`, `<main>`, or a full-width section | **High** | Scrollable or visible content may be clipped |
| `overflow: hidden` on navigation/sticky header | **High** | Menus or tooltips may be clipped |
| `overflow: hidden` on dynamic card/list container | **Medium** | Long runtime values may be cut off |
| `overflow: hidden` with fixed `height`/`max-height` | **Medium** | Content truncation risk, especially on mobile |

**4f. Content Integrity Check**

After capture, scan for critical data anomalies:

| Pattern | What it signals |
|---------|----------------|
| `NaN`, `$NaN` | Undefined or non-numeric render value |
| `undefined`, `[object Object]` | Unresolved variable rendered |
| `$0`, `$null` | Missing price/currency |
| Empty `<h1>`, `<h2>` | Heading rendered without content |
| `Lorem ipsum`, `TODO`, `FIXME`, `coming soon` | Unfinished content shipped |

If `base_url` is localhost, explicitly note that env-driven values should still be checked against production.

**4g. Write per-page report**

Write to:

```
product/design-check/YYYY-MM-DD/<route-slug>.md
```

Per-page verdicts: `PASS` | `NEEDS WORK` | `SKIPPED`

### Step 5 — Aggregate report

After all pages are audited, write:

```
product/design-check/YYYY-MM-DD/review.md
```

Report structure:

```markdown
# Design Review — [Project Name]
**Date:** YYYY-MM-DD
**Base URL:** <base-url>
**Pages audited:** N (M skipped)
**Viewport(s):** <viewports reviewed>

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| High     | N |
| Medium   | N |
| Low      | N |

**Overall verdict:** PASS | NEEDS WORK | REVIEW REQUIRED

## Critical Findings
### [route] — [finding title]
> [description]
> **Fix:** [what to do]

## High Findings
...

## Medium Findings
...

## Low Findings
...

## Per-Page Results

| Page | Verdict | Critical | High | Medium | Low |
|------|---------|----------|------|--------|-----|
| /    | NEEDS WORK | 1 | 2 | 0 | 1 |
| /dashboard | PASS | 0 | 0 | 1 | 2 |
| ... |

## Next Step
→ Run `write-spec` to turn Critical and High findings into a fix spec.
   Suggested spec name: `design-fixes-YYYY-MM-DD`
```

**Verdict logic**
- `PASS` — no Critical or High findings across all pages
- `NEEDS WORK` — any Critical or High finding
- `REVIEW REQUIRED` — majority of pages are `SKIPPED`

After writing, print:

```
Design review complete.
Report: product/design-check/YYYY-MM-DD/review.md
```

### Step 6 — Re-verification pass

After `deliver-product-slice` or another fix flow closes findings from this report:

1. Re-capture each affected route with route-named verification screenshots:
   ```bash
   npx playwright screenshot --full-page --viewport-size="1440,900" <url> product/design-check/YYYY-MM-DD/<route-slug>/<route-slug>-verify-desktop.png
   ```
2. Visually confirm the issue is gone
3. Update the per-page report verdict from `NEEDS WORK` → `PASS` (or `PARTIAL`)
4. Append a `## Verification` section to `product/design-check/YYYY-MM-DD/review.md`

If `design-verify` has already produced `product/design-verify/<spec>/implementation/`, place verification screenshots there instead to keep pixel-comparison artifacts co-located.

## Configuration

Create `.dev-os/design-review.yml` to set project defaults:

```yaml
# .dev-os/design-review.yml
base_url: http://localhost:3000
doppler_project: my-project
doppler_config: dev
routes:
  - /
  - /dashboard
  - /settings
```

Run `design-review --init` to generate this file automatically.

## Display Format

```
Design Review — [Project Name]
  Base URL:              <base-url>
  Routes audited:        N (M skipped)
  Viewports:             [desktop | desktop+tablet+mobile]
  Critical findings:     N
  High findings:         N
  Medium findings:       N
  Low findings:          N
  ─────────────────────────────────────────────────
  Verdict: [PASS | NEEDS WORK | REVIEW REQUIRED]
  Report: product/design-check/YYYY-MM-DD/review.md
```
