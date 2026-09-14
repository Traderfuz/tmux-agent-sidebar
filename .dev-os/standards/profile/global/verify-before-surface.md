<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/verify-before-surface.md and re-run profile-sync. -->
# Verify Before Surface

## Purpose

Backlog surfaces (gap registry, inbox captures, open specs) decay if they are not periodically reconciled with source-of-truth. Without verification, items resolved in code remain "open" in storage forever, accumulating as actionable backlog noise that the user must clean by hand.

This standard governs every code path that **surfaces a backlog item to the user as actionable** — `triage_scan_*`, `daily-start` Signals, `orchestrate` recommendations, `health` checks, `weekly-review` panels, `project-status` dashboards.

## Scope

**Applies to:** any function that reads a JSONL/JSON store, filters by status field, and prints results that the user is expected to act on.

**Does not apply to:** raw debug dumps (`logs`, `trace`), historical reports (gap analysis report files), inert metadata reads (config inspection).

## The Rule

Before a backlog item is included in user-facing output, the surfacing function MUST attempt source-of-truth verification.

**Three permitted outcomes per item:**

| Outcome | Meaning | Action |
|---|---|---|
| `still_open` | Verified — issue still exists in code | Surface as actionable |
| `resolved_in_code` | Strong signal item was resolved (closing commit, marker file, source state shows fix) | Auto-flip status in store; do NOT surface |
| `indeterminate` | No strong signal either way | Surface as actionable, optionally tagged for manual review |

**Conservative bias:** `indeterminate` is the default when no strong signal exists. Auto-flip ONLY on strong evidence — never on weak heuristics.

## Strong-signal definitions

A signal is "strong" if it would be obvious to a human reviewer that the item is resolved.

| Item kind | Strong signal |
|---|---|
| Gap registry entry | Closing commit (within `DEVOS_VBS_LOOKBACK_DAYS`, default 14) whose subject contains the `gap_id` AND a fix verb (close/fix/resolve/complete/done/land/ship). OR: `gap_id` appears in a recent CHANGELOG.md entry. |
| Inbox capture | ≥2 distinctive title keywords appear in a recent commit subject/body AND that commit contains a fix verb. |
| Spec | All tasks in `tasks.md` are `[x]` AND the spec dir's last-modified is within 7 days. OR: every unchecked task has an explicit task id and recent closing commits mention every remaining id with a fix/close/complete verb. |

Weak signals (do NOT auto-flip on these alone):
- Mere mention of an ID without a fix verb
- A single keyword match
- Age alone (a stale capture is not the same as a resolved one)

## Implementation contract

Surfacing functions integrate with the canonical helper at `scripts/lib/verify-before-surface.sh`:

```bash
source scripts/lib/verify-before-surface.sh
# returns: still_open | resolved_in_code | indeterminate
result=$(vbs_verify_gap "G-XXX-01")
[[ "$result" == "resolved_in_code" ]] && vbs_autoflip_resolved gap "G-XXX-01"

# Specs are verified before being shown as active implementation work.
spec_result=$(vbs_verify_spec "product/specs/my-spec")
[[ "$spec_result" == "resolved_in_code" ]] && skip_surface=true
```

Functions accept a `--verify` / `--no-verify` flag. Default is `--verify` when called from `daily-start`, `triage`, `health`. Default is `--no-verify` when called from raw debug paths.

A `verify_mode` env override is allowed:
- `TRIAGE_VERIFY_GAPS=0` disables verification on the gap scan
- `CAPTURE_VERIFY_AGING=0` disables verification on the capture-aging scan

## Why conservative bias matters

A false "resolved" auto-flip removes a real bug from the user's awareness — silent drop. A false "still open" surface costs only one verification cycle. The cost ratio is asymmetric: we accept N extra surfaces to prevent one silent drop.

## Manager-layer obligation

`health` and `triage` MUST surface a "registry-drift" health metric — count of `open` gaps that verification suggests are resolved. Drift that grows without remediation is a designer-layer signal that the verification helper needs improvement OR the system is producing untracked closing commits.

## Designer-layer obligation

`weekly-review` MUST include a "registry & inbox health" panel that runs verification and reports drift. When drift > 0, the panel recommends `gap-analysis --converge --fix --continue`. The state file `product/runtime/state.yml` tracks `last_registry_recheck_at` so `daily-start` can nudge when stale > 7 days.

## What this standard does not do

- It does not replace `gap-analysis --converge --fix` as the explicit user-invoked redesign mechanism. It complements it by preventing storage drift between converge runs.
- It does not auto-write captures or auto-create gaps. Surface drift is detected and reported; closure of OUTSTANDING work remains a designer decision.

## The test

A new "scan and surface" function passes this standard if:
1. It accepts `--verify` and respects the env override
2. It calls `vbs_verify_*` before counting/printing
3. It auto-flips `resolved_in_code` items via `vbs_autoflip_resolved`
4. It does NOT auto-flip on `indeterminate`
5. It surfaces `still_open` and `indeterminate` to the user

## References

- `scripts/lib/verify-before-surface.sh` — canonical helper
- `scripts/lib/checks/registry-drift.sh` — manager-layer health probe
- `product/gap-analysis/2026-04-27-auto-map-and-surface-verify-multi-angle-dalio.md` — origin gap report
- `product/specs/2026-04-27-verify-before-surface/spec.md` — implementation spec
