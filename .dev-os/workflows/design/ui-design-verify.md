# Design Verify

Reference-based implementation verification flow for `design-verify`. This workflow owns approved-artifact discovery, matched viewport capture, optional diff scoring, and report generation.

## When to Use

- Verify a frontend implementation against an approved design artifact
- Produce final pre-merge visual confirmation
- Capture implementation parity evidence at matching viewports

**Do NOT use when:** no approved artifact exists or only a manual heuristic page review is needed.

## Process

### Step 1 — Resolve the approved artifact
Search in the canonical priority order and warn when only a draft reference exists.

### Step 2 — Resolve implementation target
Confirm the live URL and stop if it is missing.

### Step 3 — Capture matched viewports
Capture approved and implementation screenshots at desktop, tablet, and mobile viewports.

### Step 4 — Compare
Use automatic diff scoring when available; otherwise write manual-review-required output.

### Step 5 — Write report
Write the design-verify report under `product/design-verify/<spec>/report.md`.

## Display Format

```text
Design Verify Complete
─────────────────────────────────────────────
Spec: <spec>
Reference: <artifact>
URL: <url>
Result: <PASS | FAIL | MANUAL REVIEW REQUIRED>
Report: product/design-verify/<spec>/report.md
```
