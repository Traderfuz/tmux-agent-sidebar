# Ownership Audit Workflow

## When to Use

Run this workflow when you want to validate that all declared artifacts in `product/artifact-ownership.yml` are current, exist on disk, and pass their verify commands.

Do not use this workflow to discover unowned artifacts — it only audits declared entries. For unowned artifact discovery, run the filesystem scan described in the Artifact Ownership standard.

## Purpose

Validate the artifact ownership model by reading `product/artifact-ownership.yml` and checking every entry for completeness, existence, staleness, reader-only state defects, and explicit coverage of canonical derived artifacts.

## Scope

This workflow audits the ownership manifest itself and the artifacts it declares. It does not author or refresh artifacts — that is the responsibility of individual owners.

## Behavior

### Default mode

1. Parse `product/artifact-ownership.yml`
2. Validate required fields for every entry
3. Check artifact existence on disk
4. Compare artifact mtime against upstream sources (stale_policy: upstream_newer)
5. Detect reader-only runtime state files (known state surface without manifest owner)
6. Confirm canonical outputs are represented in the manifest:
   - `docs/context/DEVOS_CONTEXT_BUNDLE.md`
   - `docs/context/DEVOS_CAPABILITIES_INDEX.md`
   - `docs/context/DEVOS_CAPABILITIES_INDEX.json`
   - `docs/context/DEVOS_SKILLS_INDEX.json`
   - `docs/context/DEVOS_CHAINS_INDEX.json`
   - `docs/context/DEVOS_PUBLIC_SURFACE.md`
   - `.dev-os/runtime/context-refresh-state.json`
   - `product/runtime/context-refresh-state.json`
   - `PROJECT_INDEX.md`
   - `PROJECT_INDEX.json`
7. Emit structured markdown report

### Strict mode (`--strict`)

Same as default, but exits non-zero when any Critical or High severity defect is found. Suitable for pre-deployment gates.

### Scoped mode (`--scope <path-or-class>`)

Limits the audit to artifacts matching the given path prefix or artifact class.

## Report Output

Reports are written to:

`product/runtime/reports/ownership-audit-latest.md`

## Severity Model

| Severity | Condition |
|----------|-----------|
| Critical | Reader-only state artifact, missing owner for required artifact, missing required manifest field, missing canonical derived artifact coverage |
| High | Stale generated artifact with newer upstream, missing artifact on disk |
| Medium | Refresh/verify command unresolved |
| Low | Metadata header absent but ownership otherwise intact |

## Integration

- Does not replace `docs-sync`, `docs-sync --scope product`, `ground-truth-recon`, or `context-refresh`
- Respects the "repair first, refresh last" rule from ground-truth-recon
- Treats the skill/chain registry surface, public surface inventory, and project index as governed artifacts rather than incidental outputs
- May recommend refresh actions but does not execute them

## Display Format

```
Ownership Audit — product/artifact-ownership.yml
  Entries checked: [N]
  CURRENT:  [N]
  STALE:    [N]  ← [list paths]
  MISSING:  [N]  ← [list paths]
  Status: [PASS | FAIL]
```
