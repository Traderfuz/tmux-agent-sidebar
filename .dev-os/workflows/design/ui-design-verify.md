# Design Verify

This compatibility workflow delegates approved-reference verification to `ui-design-qa --mode verify`.

## When to Use

- Verify a frontend implementation against an approved design artifact.
- Produce final pre-merge visual confirmation.
- Do not use it when no approved design artifact exists; use `ui-review --scope page` or `ui-review --scope full`.
- Avoid it for exploratory visual review.

## Delegation

1. Run `ui-design-qa --mode verify` with the approved artifact and the implementation.
2. Let the replacement skill find the approved artifact, capture matched viewports, compare, and write the report.
3. Follow its fallback handling when capture tooling is unavailable.

The replacement skill owns approved-artifact discovery, matched viewport capture, comparison, fallback handling, and report generation.

## Display Format

```text
Design Verify Delegated
─────────────────────────────────────────────
Replacement: ui-design-qa --mode verify
```
