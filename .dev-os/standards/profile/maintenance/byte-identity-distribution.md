<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/byte-identity-distribution.md and re-run profile-sync. -->
# Byte-Identity Distribution Standards

## Overview

Artifacts distributed by copy to more than one repo or surface drift. The workspace has now
hit this failure class at least seven times: statusline (G-SL-D-01), MCP config (G-MCPS-005),
managed blocks (G-HC-003), worktree notation (G-WTN-001/003), generated CLI (G-P-02),
`coexistence.sh` (G-COEX-W-001, six divergent copies), and `output.sh` (six divergent copies,
discovered incidentally). Every instance was fixed one-off; the class kept recurring because
nothing forced copy-distributed artifacts to declare an identity contract at birth.

This standard makes byte-identity a design requirement for copy-distributed artifacts.

## Scope

Covers any file distributed verbatim to more than one repo, package, or install surface in
the `os` workspace (engines, shared libs, verifiers, hooks, statuslines). Does NOT cover
rendered templates (placeholder substitution makes byte comparison meaningless — keep the
shared logic in a verbatim engine and render only the thin identity layer), per-OS authored
content, or generated artifacts (capabilities, indexes).

## Named frameworks

- **GitOps Source of Truth:** one canonical, version-controlled source; copies are derived state.
- **Convergence Loop (detect → sync → verify):** drift is detected mechanically, repaired by a
  sanctioned sync path, and verified by tests after every write.

## Rules

### Rule 1 — Declare a canonical source

Every byte-identical artifact MUST name exactly one canonical source file (repo + path) in a
header comment. Copies MUST carry the same header naming the canonical source and the sync
command. Example: `scripts/lib/coexistence-engine.sh` is canonical in
`dev-os/templates/installable-os/files/`; every OS carries a verbatim copy.

### Rule 2 — Provide a checksum gate

A mechanical check MUST exist that compares every copy against the canonical source and fails
loud, naming the drifted repo + file (e.g. `scripts/sync-coexistence-engine.sh --check`).
The gate MUST be wired into at least one recurring surface (cross-OS verify flow, CI cadence,
or status signal) — an unread gate is cosmetic.

### Rule 3 — Provide exactly one sync fix-path

The ONLY sanctioned write path to a copy is the artifact's sync script. The sync MUST skip
dirty targets, verify after copy (tests when available), and revert on verification failure.
Hand-editing a copy is a contract violation even when the edit is "obviously correct".

### Rule 4 — Enumerate dependencies, not just artifacts

A byte-identical artifact MUST depend only on (a) other byte-identical artifacts, (b) a
declared per-surface identity layer (config/shim), or (c) stable system tools. A dependency on
a per-repo drifted file (e.g. a verifier sourcing per-OS `output.sh`) silently breaks
byte-identity — audit the dependency closure when declaring the artifact.

### Rule 5 — Route per-surface variation to an extension layer

Per-surface behavior lives in a declared extension point (identity vars, ext hook file) that
is additive only and MUST NOT redefine canonical functions. Tests enforce no-shadowing.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Fix a bug directly in one OS's copy | Next sync overwrites it, or copies diverge | Fix canonical source, run sync |
| Distribute by template render | Render is a fork moment; checksum impossible | Verbatim engine + rendered thin shim |
| Gate in CI only | Local migration windows drift unnoticed | Gate in local verify flow + CI |
| Declare artifact without dependency audit | Copies depend on drifted per-repo files | Rule 4 dependency closure |
| Two sync systems for one artifact | Divergent write paths race | One sync fix-path (Rule 3) |

## Registered byte-identical artifacts

| Artifact | Canonical source | Gate / sync |
|---|---|---|
| `scripts/lib/coexistence-engine.sh` | `dev-os/templates/installable-os/files/scripts/lib/coexistence-engine.sh` | `scripts/sync-coexistence-engine.sh [--check]` (workspace) |
| `scripts/verify-coexistence.sh` | `dev-os/templates/installable-os/files/scripts/verify-coexistence.sh` | same |

Candidates for promotion: `scripts/lib/output.sh` (drifted 6 ways — see scaffold audit,
spec 2026-07-03-coexistence-scaffold-upgrade).

Relationship to existing machinery: `sync-installable-os-profile.sh` +
`check-installable-os-shared-policies.sh` propagate *standards/policy documents*;
byte-identity sync scripts propagate *runtime artifacts*. Distinct scopes; do not merge.

## Deviation guidance

You MAY skip this standard for single-consumer files, generated files, or explicitly
short-lived experiments. State the skipped surface and why. A file that gains its second
consumer copy loses the exemption immediately.

## Compliance test

- [ ] Does the artifact name its canonical source + sync command in a header on every copy?
- [ ] Does a checksum gate exist and fail loud naming repo + file?
- [ ] Is the gate wired into a recurring surface (verify flow, CI, or status signal)?
- [ ] Is the sync script the only write path, with dirty-skip + verify + revert?
- [ ] Is the dependency closure free of per-repo drifted files?
- [ ] Is per-surface variation isolated to identity vars / an additive ext layer?

If any check fails, the artifact is not byte-identity distributed; register it properly before
shipping the next copy.
