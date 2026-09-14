# Contract-Drift Audit Workflow

## When to Use

Run this workflow after merges, spec completions, or any significant upstream change to detect artifacts that are likely stale — before the staleness causes downstream failures.

Do not use this workflow as a substitute for `ownership-audit` — contract-drift-audit detects probable staleness by mtime comparison; ownership-audit validates entries against their declared verify commands.

## Purpose

Detect derivative artifacts that likely encode older behavior after upstream changes. Generalizes the stale-doc/stale-test problem into a reusable drift detector.

## Scope

This workflow inspects changed files since a baseline revision, classifies them into domains (docs, commands, workflows, scripts, runtime, specs), and maps those domains to expected derivative artifacts via the ownership manifest.

Artifacts that should have been updated but were not touched are reported as "likely stale derivatives."

## Behavior

1. Resolve baseline revision (merge-base, `HEAD~1`, or explicit `--since`)
2. Collect changed files since baseline
3. Classify changed files into domains
4. Map domains to expected derivative artifacts from `product/artifact-ownership.yml`
5. Report derivatives not touched in the same changeset
6. Detect new readers of state files without ownership coverage

## Output Classes

| Class | Description |
|-------|-------------|
| Definite defect | New reader of unowned state file — ownership gap |
| Likely stale derivative | Expected derivative not updated after upstream change |
| Follow-up suggestion | Informational — may or may not need action |

## Report Output

`product/runtime/reports/contract-drift-audit-latest.md`

## v1 Scope Limits

- Heuristic-based, not fully semantic
- Supports `docs` and `reports` scopes reliably
- `tests`, `snapshots`, `fixtures` scopes are present but may produce false positives
- Domain classification uses path-prefix matching

## Integration

- Reads the ownership manifest (`product/artifact-ownership.yml`)
- Does not modify or refresh any artifacts
- Reports only — leaves remediation to the user or other commands
