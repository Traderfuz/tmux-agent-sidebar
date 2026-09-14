# Design System Audit

Verify design token and component visual consistency across the codebase. Scans for hardcoded visual values (hex colors, px sizes, font names), measures token adoption coverage, identifies unused tokens, and flags components that are styled inconsistently across pages. Produces a token coverage score and actionable remediation list.

## When to Use

- Before a major release — verify design system integrity
- After adding new pages or components — check token adoption
- When visual inconsistency is reported ("the button looks different on the settings page")
- During quarterly design system maintenance
- After onboarding a new developer — audit their recent commits for token compliance

**Do NOT use when:** The project has no design token system yet (run `design-system` to generate one first). Do not use for functional testing (use `e2e` instead).

## Process

### Step 1: Scan for hardcoded visual values

Search the codebase for visual values that should be tokens but aren't:

- **Hex colors:** `#[0-9a-fA-F]{3,8}` in CSS, TSX, or style objects
- **RGB/HSL:** `rgb(`, `rgba(`, `hsl(`, `hsla(` in stylesheets
- **Pixel font sizes:** `font-size: \d+px` (should be rem/token)
- **Pixel spacing:** `margin|padding|gap: \d+px` not matching the 4px scale
- **Font family strings:** `font-family: "..."` outside of token definitions
- **Duration values:** `\d+ms|\d+s` outside of token definitions

Exclude: `tokens.css`, `design-system.json`, `tailwind.config.*` (these ARE the token source).

```
Display: Hardcoded value inventory
  Found 23 hardcoded values across 8 files:
    src/components/Card.tsx:12    — background: "#f5f5f5" (should use --color-bg-muted)
    src/app/pricing/page.tsx:45  — padding: "30px" (not on 4px scale)
    src/components/Footer.tsx:8   — font-family: "Inter" (should use --font-body)
    ...
```

### Step 2: Measure token adoption coverage

Calculate the percentage of visual values that reference tokens vs hardcoded:

```
Token coverage = (token references) / (token references + hardcoded values) × 100
```

- **Green (>90%):** Design system is well-adopted
- **Yellow (70-90%):** Significant hardcoded values — remediation needed
- **Red (<70%):** Design system is not being used — systematic intervention required

```
Display:
  Token Coverage: 84% (Yellow)
    Token references: 156
    Hardcoded values: 30

  Breakdown by category:
    Colors:   92% (3 hardcoded)
    Spacing:  78% (12 hardcoded)
    Typography: 88% (4 hardcoded)
    Duration:  71% (5 hardcoded)
    Other:    80% (6 hardcoded)
```

### Step 3: Identify unused tokens

Scan `tokens.css` for tokens that are defined but never referenced in any source file:

```
Display: Unused tokens
  4 tokens defined but never used:
    --color-accent-light    (defined line 23)
    --space-18              (defined line 67)
    --font-size-4xl         (defined line 41)
    --duration-slow         (defined line 89)

  Recommendation: Remove unused tokens or document why they're reserved
```

### Step 4: Check component visual consistency

For components used on multiple pages, verify they are styled identically:

1. Find all instances of shared components across route segments
2. Check that each instance uses the same token references
3. Flag instances where the same component has different styles on different pages

```
Display: Consistency check
  Button component: 12 instances across 5 pages
    ✓ 10 instances use consistent token-based styles
    ✗ 2 instances have inline style overrides:
      app/settings/page.tsx:34 — style={{ padding: "8px 12px" }} (overrides token)
      app/admin/page.tsx:67    — className="bg-blue-600" (hardcoded, not token)
```

### Step 5: Generate audit report

Produce a comprehensive audit report with:

- **Token coverage score** (percentage with color rating)
- **Hardcoded value inventory** (file, line, value, suggested token)
- **Unused token list** (token name, definition location)
- **Consistency violations** (component, page, issue)
- **Remediation priority** (high: token bypass in shared components, medium: hardcoded values, low: unused tokens)

```
Display: Audit summary
  ┌─────────────────────────────────────┐
  │ Design System Audit — 2026-03-19    │
  │ Token Coverage: 84% (Yellow)        │
  │                                     │
  │ Hardcoded values: 30 across 8 files │
  │ Unused tokens: 4                    │
  │ Consistency violations: 2           │
  │                                     │
  │ Priority fixes:                     │
  │   High:   2 (component overrides)   │
  │   Medium: 30 (hardcoded values)     │
  │   Low:    4 (unused tokens)         │
  └─────────────────────────────────────┘
```

### Step 6: Route to remediation

Based on the audit findings, route to the appropriate fix workflow:

| Finding type | Remediation |
|---|---|
| Token coverage <70% (Red) | Run `design-system` to regenerate or expand the token set, then re-audit |
| Consistency violations in shared components (High priority) | Run `fix-inner-pages` workflow — establish golden page, fix each page against it |
| Hardcoded values in page-specific files (Medium priority) | Run `fix-broken-design` per affected page — replace hardcoded values with token references |
| Unused tokens (Low priority) | Review with designer — remove if confirmed unused, or document as reserved |

```
Display:
  Remediation routing:
  Token coverage: 84% (Yellow) → targeted fixes, not full regeneration
  High (2 component overrides) → fix-inner-pages
  Medium (30 hardcoded values across 8 files) → fix-broken-design per page
  Low (4 unused tokens) → review with designer
```

## Notes

- This workflow references standards: `design-tokens.md` (token hierarchy and naming), `spacing.md` (4px scale), `typography.md` (modular scale and measure), `animation.md` (duration tiers).
- Token coverage below 70% typically indicates the design system was added after significant code was written — run `design-system` to regenerate the token set before attempting per-file fixes.
- Unused tokens may be intentionally reserved for future use — check with the designer before removing.
- Run this audit after every major feature addition to prevent token coverage from degrading incrementally.
- After remediation, re-run this audit (Step 1-5) to verify the coverage improved. Target: >90% (Green).

## Display Format

```
Design System Audit — [project]
  Token coverage: [N%] ([Green | Yellow | Red])
  Hardcoded values: [N] across [N] files
  Unused tokens: [N]
  Consistency violations: [N]
  Remediation: [routing summary]
  Status: [clean | issues found — see routing]
```

### Step 7: Write audit cadence state

After a successful audit, refresh `.dev-os/runtime/design-audit-state.json` with the latest audit date and coverage score so maintenance/status reminders stay accurate.

```bash
mkdir -p .dev-os/runtime
cat > .dev-os/runtime/design-audit-state.json <<EOF
{
  "last_audit": "$(date +%Y-%m-%d)",
  "coverage_score": <N>
}
EOF
```
