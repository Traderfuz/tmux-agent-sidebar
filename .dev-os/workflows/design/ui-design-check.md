# Design Check

Single-page heuristic design review flow for `design-check`. This workflow owns the ordered procedure for resolving the target, capturing screenshots when needed, loading design context, evaluating the review dimensions, and writing the design-check report.

## When to Use

- Review one page or screenshot quickly
- Run a heuristic visual pass during implementation
- Check one page before broader design verification

**Do NOT use when:** a whole-project audit or approved-artifact verification is required.

## Process

### Step 1 — Resolve target
Choose one of:
- live URL
- existing screenshot path

### Step 2 — Capture if needed
If URL mode is used, capture screenshots with Playwright when available. If capture is unavailable, fall back to manual screenshot collection.

### Step 3 — Load design context
Look for design brief, approved artifact, style tokens, or local design files.

### Step 4 — Run heuristic review
Evaluate:
- visual hierarchy
- spacing & layout
- typography
- color & contrast
- component fidelity
- responsive integrity when `--full` is enabled

### Step 5 — Write report
Write the design-check markdown report with verdict, findings, and priority fixes.

## Display Format

```text
Design Check Complete
─────────────────────────────────────────────
Target: <url | screenshot>
Context: <found | not found>
Viewports: <desktop | desktop+tablet+mobile>
Verdict: <PASS | NEEDS WORK | REVIEW REQUIRED>
Report: product/design-check/<spec>-YYYY-MM-DD.md
```
