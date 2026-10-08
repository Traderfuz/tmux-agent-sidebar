# Design Review

This compatibility workflow delegates whole-project heuristic review to `ui-review --scope full`.

Browser capture follows `profiles/general/standards/global/browser-review-policy.md`; reports include selected driver, selected target, auth path, backend, artifact paths, and fallback reason.

## When to Use

- Audit an entire app or marketing site.
- Build a remediation list before `write-spec`.
- Do not use it for one page; use `ui-review --scope page`.
- Avoid it for approved-reference comparison; use `ui-design-qa --mode verify`.

## Delegation

1. Run `ui-review --scope full` with the project or base URL.
2. Let the replacement skill discover routes, capture each route, and write dated per-route reports and the aggregate report.
3. Use `ui-design-qa --mode verify` when an approved reference exists.

The replacement skill owns route discovery, capture, heuristic evaluation, dated per-route artifacts, and the aggregate report. Use `ui-design-qa --mode verify` for approved-reference comparison.

## Display Format

```text
Design Review Delegated
─────────────────────────────────────────────
Replacement: ui-review --scope full
```
