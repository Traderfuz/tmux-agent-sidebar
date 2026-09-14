# Comprehensive Project Audit Workflow

Run a full project audit that combines routing, UI/UX, security, documentation, and cleanup reviews into one structured pass.

If the audited project includes frontend/UI surfaces, route the UI/UX phase through the `frontend-design` contract first so the audit and any fixes are evaluated against explicit design intent.

## When to Use

Use this workflow when:

- onboarding a legacy project,
- preparing for a milestone release,
- doing post-MVP hardening,
- or when `review --comprehensive` is requested.


Do not run this workflow as a quick sanity check — it is a full multi-pass audit. For a targeted spec check, use `verify --spec` instead.

## Input

- Project name or scope from user prompt.
- Optional target path if not repository root.

## Output Artifacts

Create these files in project root unless user specifies otherwise:

- `PLAN.md`
- `UIUX_PLAN.md`
- `UIUX_AUDIT.md`
- `DOCUMENTATION-UPDATE-SUMMARY.md`
- `CHANGELOG.md` (if missing)
- `learnings.md` updates

## Phase Map (DevOS Integration)

### Phase 1: Route and Navigation Audit

1. Inventory routes/pages/layouts/middleware.
2. Identify route conflicts, broken links, and link-type misuse.
3. Fix critical route issues first.

Use alongside:

- `profiles/general/workflows/architecture/architect-review.md`

### Phase 2: UI/UX Review

1. Audit empty states, forms, loading states, responsiveness, accessibility.
2. Prioritize findings with P0/P1/P2 labels.
3. Implement highest-priority improvements.

Use alongside:

- `profiles/general/workflows/optimization/process-optimizer-review.md`
- `e2e` — for comprehensive user journey testing with browser automation, DB validation, and responsive checks (replaces manual UI/UX browser walkthrough)
- `frontend-design` — required before frontend/UI fixes or design-led visual adjustments

### Phase 3: Component Hardening

1. Review nav/header/forms/modals/loading patterns.
2. Add missing UI primitives required for UX consistency.
3. Validate keyboard and screen-reader behavior.

### Phase 4: Documentation Audit and Sync

1. Update README/CHANGELOG/BACKLOG/LEARNINGS and project plans.
2. Remove obsolete docs and conflicting files.
3. Ensure docs match code and current URLs.

Use alongside:

- `profiles/general/workflows/verification/doc-scan.md`

### Phase 5: Security and Cleanup

1. Scan for credentials, secrets, insecure configs.
2. Remove duplicate/unused artifacts.
3. Re-run security checks after cleanup.

Use alongside:

- `profiles/general/workflows/security/red-team-review.md`

## Verification Gate

Before final handoff, verify:

- build passes,
- typecheck passes,
- lint passes,
- critical routes resolve,
- docs are consistent.

## Report Format

Summarize with:

- findings by severity,
- fixes applied,
- residual risks,
- recommended next actions.

## Notes

- Prefer fixing P0 routing/security issues before broad UX polish.
- This is a warnings-first workflow: do not make destructive deletions without explicit user direction.
