# Docs Full Maintenance Pipeline

Deterministic pipeline that runs the complete documentation quality loop: discover and create missing docs, repair structural drift, verify content accuracy against the code, then a final audit and summary. Use when you want documentation that is not just present and structurally correct, but provably accurate against the implementation.

## When to Use

- Before a release or milestone, to guarantee every shipped feature has an accurate guide
- After a run of features that touched schemas, flags, or behavior (where prose can silently drift)
- When asked to "fully maintain the docs", "audit and fix the docs", or "make sure the docs are accurate"
- Periodically as a scheduled documentation-debt sweep

- Anti-trigger: if you only need structural drift repair (paths/counts/versions), use `docs-full-sync` instead — it is lighter and does not run coverage discovery or content verification.

## Why this order

Each leg answers a different question and depends on the previous one being settled:

1. **docs-coverage-audit** — *which* docs should exist? Discovers the expected surface from specs/subsystems/OS outputs and creates missing docs via `user-facing-docs`. (Inventory must be complete before anything validates it.)
2. **docs-sync** — do the **paths/counts/versions/names** in those docs match the filesystem? Repairs structural drift.
3. **docs-verify** — does the **described behavior** match the code? Extracts claims and classifies VERIFIED / DRIFTED / UNVERIFIABLE — catching semantic drift that passes path/count/timestamp checks.
4. **audit-docs** — final reader-facing doc audit gate.

Order rationale: coverage decides what should exist and creates it; sync fixes structure in what exists; verify confirms content accuracy; audit is the final gate.

## Process

1. `work-intake-preflight --auto` — claim/scope the work.
2. `worktrees` + `worktree-sessions` — isolate in a worktree.
3. `docs-coverage-audit` — inventory; create missing docs (routes to `user-facing-docs`).
4. `docs-sync` — repair structural drift (paths, counts, versions, names).
5. `docs-verify` — content-accuracy pass (claim-vs-code; DRIFTED findings fixed or routed back to `docs-sync`).
6. `audit-docs` — final documentation audit.
7. `commit --all` — commit the maintenance batch.
8. `summarize` — summarize all documentation work completed.

## Dependency Graph

```
work-intake-preflight --auto
  -> worktrees -> worktree-sessions
  -> docs-coverage-audit   (create missing)
  -> docs-sync             (structural drift)
  -> docs-verify           (content accuracy)
  -> audit-docs            (final gate)
  -> commit --all
  -> summarize
```

## Resume Points

| Completed step | Resume at |
|----------------|-----------|
| coverage-audit complete | docs-sync |
| docs-sync complete | docs-verify |
| docs-verify complete | audit-docs |
| audit-docs complete | commit |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| docs-coverage-audit | No specs/subsystems | Continue with whatever surfaces exist; warn |
| docs-sync | WRONG discrepancies | Apply corrections; re-run before verify |
| docs-verify | DRIFTED claims | Fix factual claims inline or route to docs-sync; leave UNVERIFIABLE for human review |
| audit-docs | Audit findings | Resolve before commit |

## Display Format

```
Docs Full Maintenance Pipeline
  Coverage:   N created, M waived ✓
  Structural: synced ✓
  Content:    VERIFIED a / DRIFTED b (fixed) / UNVERIFIABLE c ✓
  Audit:      passed ✓
  Status: complete
```
