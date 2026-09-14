<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/scan-fix-converge.md and re-run profile-sync. -->
# Scan / Fix / Converge Execution Standard

## Overview

Audit, status, and remediation skills find problems. The question this standard answers
is **what a skill does with what it finds** — and how the operator controls how
aggressive that is. Today each audit skill invents its own flags and fix behavior, so
`--fix` means different things in different skills. This standard makes one execution
contract every remediation-capable skill follows, grounded in established CLI convention
(ruff, eslint, terraform, kubectl — see
`product/research/scan-fix-converge-and-next-step-affordance-conventions-2026-06-26.md`).

It is the execution-mode companion to `ranked-list-output.md` (which governs how findings
are *ordered and displayed*). This one governs how they are *acted on*.

## Scope

Applies to any skill that detects issues and can remediate them — the audit family
(`audit-deps`, `audit-docs`, `context-surface-audit`, `docs-coverage-audit`,
`ownership-audit`, `project-health-audit`, `site-audit`, `ux-audit`, `usability-audit`,
`project-artifacts-audit`, `contract-drift-audit`, etc.) and any future scan-and-fix
skill. Read-only skills that never remediate (pure status/report) follow only the
default-read-only rule (R1) and the exit-code rule (R5).

## The three fix tiers (finding classification)

Every remediable finding is classified into exactly one tier (this is the auto-fixable
ladder from ruff/eslint):

| Tier | Meaning | Applied by |
|------|---------|------------|
| **Automatic (safe)** | Mechanical, reversible, no human judgment (e.g. sync a count, fix a dead path) | `--fix` |
| **Suggested (unsafe)** | Auto-fixable but could change meaning or overwrite human-authored content (e.g. rewrite stale prose) | `--fix --unsafe` |
| **Manual (spec-required)** | New authored work or a design decision (e.g. a missing doc/feature) | `--converge` only (or routed) |

`Automatic` = the existing `direct_fix_allowed` class. `Manual` = the existing
`spec_required` class. `Suggested` is the middle tier this standard adds.

## Rules

### R1 — Default is read-only (no flags = report only)
With no flags, the skill scans and emits an optimize-ordered report (per
`ranked-list-output`) and **writes nothing**. This is `terraform plan` / `ruff check` /
`eslint` default behavior. For every finding, print the exact command the operator would
run to remediate it (route-only).

### R2 — `--dry-run` previews the fixes `--fix` would make
`--dry-run` shows the concrete diff/changes that `--fix` (or `--fix --unsafe`) would
apply, and writes nothing. Mirrors `eslint --fix-dry-run` / `kubectl --dry-run=client`.

### R3 — `--fix` applies Automatic (safe) fixes; routes the rest
`--fix` applies every **Automatic** fix inline, in optimize-order, top-down, with no
per-item prompting. **Suggested** findings are skipped with a one-line note
(`N suggested fix(es) need --unsafe`). **Manual** findings are **routed**: the skill
prints the exact `write-spec --spec <slug>` command — it does NOT write the spec itself.
`--fix` never spawns specs or implementation work on its own.

### R4 — `--fix --unsafe` also applies Suggested fixes
Adds the **Suggested** tier to what `--fix` applies. **Manual** findings are still only
routed (printed command), never auto-written. Mirrors `ruff --unsafe-fixes`.

### R5 — `--converge` runs the full canonical pipeline until stable
`--converge` is the autonomous mode: it applies Automatic + Suggested fixes AND closes
**Manual** findings by delegating to the canonical DevOS process via
`gap-analysis --dalio --converge --fix` — `shape-spec → write-spec → gap-analysis →
reviews → create-tasks → implement-tasks → verify` — looping until 0 new findings or the
max-pass limit. This is the only mode that writes and builds specs automatically.
`--converge` implies `--fix --unsafe` for the auto-fixable tiers.

### R6 — Exit codes: 0 / 1 / 2
- `0` — clean: no findings, or all findings remediated this run
- `1` — findings remain (including Manual findings that were only routed, not closed)
- `2` — error: bad flags, missing inputs, internal failure

Provide `--exit-zero` to force `0` for chain steps that should not gate on findings.
(Convention: ruff/eslint identical 0/1/2.)

### R7 — Mode is explicit; never escalate silently
A skill MUST NOT auto-promote `--fix` to `--converge`. Mutation scope is exactly the flag
the operator passed. The default-safe, opt-in-to-more ladder is the safety contract.

## Compliance test

- [ ] No flags → report only, writes nothing, prints remediation commands (R1)?
- [ ] `--dry-run` previews without writing (R2)?
- [ ] `--fix` applies Automatic only, skips Suggested with a note, routes Manual with the
      `write-spec` command (R3)?
- [ ] `--fix --unsafe` also applies Suggested; still routes Manual (R4)?
- [ ] `--converge` delegates to `gap-analysis --dalio --converge --fix` and closes Manual
      via the canonical pipeline, looping to stable (R5)?
- [ ] Exit codes 0/1/2 with `--exit-zero` available (R6)?
- [ ] No silent escalation of mutation scope (R7)?

## Deviation guidance

- Read-only skills (pure status/report, no remediation) implement only R1 + R6.
- A skill MAY omit `--dry-run` only if it has no Automatic/Suggested tier (everything it
  finds is Manual) — state the omission.
- The default fix-tier of a finding is the skill's call, but it MUST be one of the three
  named tiers; do not invent a fourth.

## Review note

The default invocation operators reach for (likely `--converge`) is under evaluation.
Revisit ~1 week after adoption: if `--converge` is the near-universal choice, consider
making it the default and adding a `--report-only` for the current bare behavior. Tracked
via capture.
