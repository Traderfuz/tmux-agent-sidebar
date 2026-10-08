# Design Check

This compatibility workflow delegates single-page heuristic review to `ui-review --scope page`.

## When to Use

- Review one page or screenshot quickly.
- Run a heuristic visual pass during implementation.
- Do not use it to compare against an approved mockup; use `ui-design-qa --mode verify`.
- Avoid it for whole-project audits; use `ui-review --scope full`.

## Delegation

1. Run `ui-review --scope page` with the page URL or screenshot.
2. Follow the replacement skill's target, capture, context, heuristic, and report procedure.
3. For approved-reference comparison, run `ui-design-qa --mode verify` instead.

Use the replacement skill's target, capture, context, heuristic, and report procedure. For approved-reference comparison, use `ui-design-qa --mode verify`.

## Display Format

```text
Design Check Delegated
─────────────────────────────────────────────
Replacement: ui-review --scope page
```
