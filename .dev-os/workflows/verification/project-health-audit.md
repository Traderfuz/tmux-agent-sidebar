# Project Health Audit Workflow

Use the canonical owner-root runner to produce a durable, profile-aware health
audit. The runner is breadth-oriented maintenance verification; use `e2e` for
deep user-journey coverage.

Browser review follows `browser-review-policy.md`. Every report records the selected driver, selected target, auth path, backend, artifact paths, and fallback/degraded reason.

## When to Use

Use this workflow for broad project-health evidence before release, after a
significant change, or during scheduled maintenance. Do not use it as a
substitute for deep user-journey E2E coverage or a targeted single-failure
diagnosis.

```bash
AUDIT="${DEVOS_DIR:-$HOME/.dev-os}/scripts/devos-project-health-audit.sh"
"$AUDIT" --workspace <project-root> [options]
```

The runner resolves the workspace/app target before mutation, writes one
run-scoped evidence directory, records context and phase receipts, and commits
shared history/latest projections through the state helper. It does not modify
application source or configuration.

The canonical state ownership table, target-root rules, phase/status vocabulary,
receipt identities, resume checks, context tiers, cleanup, publication, and
failure semantics are in
[references/execution-contract.md](../../../../.claude/skills/project-health-audit/references/execution-contract.md).
All summaries and CI output validate against
[`contracts/project-health-audit-summary.schema.json`](../../../../contracts/project-health-audit-summary.schema.json).

## Runner options

These are runner options, not skill-level orchestration controls:

- `--url <base-url>` — runtime target.
- `--static-only` — static analysis only.
- `--runtime-only` — runtime validation only; requires `--url`.
- `--fix` — generate run-local fix artifacts; never edit application source.
- `--severity <critical,high,medium,low>` and `--scope <components,forms,navigation,handlers,routes>` — filters.
- `--app <path-or-name>` — select an app target in a monorepo.
- `--ci` — exactly one schema-v1 JSON summary on stdout; diagnostics use stderr.
- `--dry-run` — fill forms but skip final submission during runtime validation.
- `--resume <run-id>` — reuse a compatible interrupted run checkpoint.
- `--max-routes <n>` and `--max-controls-per-route <n>` — runtime caps.
- `--prep-script <path>` — auth/fixture preparation script.
- `--profile <name>` — override detected profile.
- `--headed` — show the runtime browser.
- `--workspace <path>` — workspace (default: current directory).
- `--start-server`, `--stop-server`, `--keep-server`, `--server-port <port>`, `--server-command <cmd>` — dev-server lifecycle.

With neither `--url` nor `--start-server`, the runner selects static-only.
`--runtime-only` requires `--url`; `--static-only` and `--runtime-only` are
mutually exclusive. Registry-routed skill controls `--fix`, `--converge`, and
`--dalio` own remediation and review; do not pass the latter two to the runner.

## Durable output

Each run writes to:

```text
<workspace>/product/health-audit/<run-id>/
```

For an app target, `<run-id>` is below its deterministic
`targets/<target-key>/` root. Run-scoped entries include:

- `static-analysis/` — static detector JSON files.
- `runtime-validation/` — runtime JSON files, screenshots, and prep output.
- `fix-tasks/` — generated fix specs/tasks when runner `--fix` is selected.
- `summary.json` — schema-v1 machine score projection.
- `summary.md` — human score projection.
- `run-metadata.json` — immutable invocation metadata and context evidence.
- `checkpoint.json` — phase ledger and invocation/phase attempts.
- `receipts.jsonl` — idempotent transition receipts.

Shared `generations/<revision>/`, `history/`, and `latest` are published through
the target's atomic `.current` pointer. Same-target publication is lock-bound;
different target roots are independent.

## Phase and resume contract

The phase plan always retains these stable IDs, recording inapplicable phases as
`skipped`:

```text
static-analysis → runtime-validation → health-score → fix-generation → publish
```

Checkpoint phase statuses are `pending`, `running`, `succeeded`, `failed`, and
`skipped`. Compatible resume increments the one-based invocation attempt,
skips successful phases/routes, and retries only pending or failed work. Resume
fails closed before mutation for missing/malformed checkpoints, target or option
changes, phase-plan/plan-digest changes, material-input changes, and an already
successful terminal run.

## Ownership and remediation

Do not duplicate the ownership table here; use the canonical execution
reference linked above. The runner owns source reads, profile detection,
run-scoped evidence, checkpoints, scoring, cleanup of resources it started, and
shared publication through the helper. A server already running before the
invocation is not stopped. `--keep-server` retains a server started by the run.
Cleanup is recorded separately from primary execution and settles before
publication.

Skill-level `--fix` may auto-apply only `direct_fix_allowed`. Findings classified
as `spec_required` route through `write-spec` and `create-tasks`. `manual`
findings remain operator work. The only valid finding taxonomy is exactly those
three values.

## Output Format

Human stdout has exactly four top-level sections, in order: `Header`, `Content`,
`FILES SAVED`, and `WHAT'S NEXT`. Progress and diagnostics are stderr-only. A
human result includes the score, grade, findings, evidence path, classified
findings, status, and exactly one `→ Next:` action.

In `--ci`, stdout is exactly one `project-health-audit-summary/v1` JSON object,
including pre-summary failures. It has no headings, progress, warnings, or
shell traces; diagnostics remain on stderr. Existing summary field types remain
compatible. Normal CI exits are 1 for critical findings, 2 for score below 70
with high findings, and 0 otherwise; setup/state failures retain classified
non-zero exits.

## Verification gate

After running the audit:

1. Inspect `summary.json`, `summary.md`, checkpoint status, context evidence,
   receipts, and the published generation; do not treat `done` alone as proof.
2. Review findings by `optimize` binding-constraint impact, then severity.
3. Address `critical` findings before deployment; route `spec_required` and
   `manual` findings to their owning paths.
4. Use `--resume` only when the compatibility checks accept the checkpoint.
