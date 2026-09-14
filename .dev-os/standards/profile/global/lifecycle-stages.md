<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/lifecycle-stages.md and re-run profile-sync. -->
# Lifecycle Stages Standard

## Overview

DevOS projects move through a defined set of lifecycle stages, each mapped to a
**compatibility posture** that governs how aggressively code may change. The
stage is stored in the single canonical `lifecycle:` field of `.dev-os/config.yml`
and drives the compatibility-posture block rendered into `CLAUDE.md` / `AGENTS.md`
for every CLI.

This standard is the human-readable mirror of the authoritative code in
`scripts/lib/lifecycle.sh` (`_LIFECYCLE_STAGES`, `lifecycle_posture`). On any
disagreement, the code is authoritative.

## Scope

Covers the stage vocabulary, the stage→posture mapping, the canonical config
field, and how stages are read/written/transitioned. Does NOT cover deploy
routing (which deploy target a stage selects) — that is downstream/future work.

## Stage vocabulary (ordered)

```
prelaunch → alpha → beta → rc → live → deprecated → sunset
```

| Stage | Posture | Meaning |
|-------|---------|---------|
| `prelaunch` | forward-only | Default. Built but unreleased; no users. Breaking changes OK. |
| `alpha` | forward-only | Early testing, internal/invited. Breaking changes OK. |
| `beta` | forward-only | Wider testing. Breaking changes discouraged but allowed. |
| `rc` | forward-only | Release candidate; stabilizing. |
| `live` | contract-preserving | Publicly live. Preserve public contracts and behavior. |
| `deprecated` | frozen | Superseded. Security/critical fixes only; no features. |
| `sunset` | frozen | End-of-life. No changes except EOL/takedown. |

## Posture classes

- **forward-only** — prefer the best forward version; breaking changes,
  deletion over shims, no legacy compatibility layers. (prelaunch/alpha/beta/rc)
- **contract-preserving** — preserve public contracts and user-facing behavior
  unless a change is intentional and explicitly scoped; prefer migrations and
  deprecation paths. (live)
- **frozen** — security/critical/EOL changes only; no features or refactors;
  prefer documenting the successor over changing the codebase.
  (deprecated/sunset)

The posture renderer keys off the **posture class**, not the raw stage name, so
the whole forward-only band shares one rendered block.

## Canonical field

- The single source of truth is `lifecycle:` in `.dev-os/config.yml`.
- The legacy `lifecycle_stage:` field is **retired**. `config-writer` /
  `devos-init` reconcile any project still carrying it into `lifecycle:` and
  remove the legacy line (one-time migration, not a dual-write shim). On a
  value disagreement, the legacy `lifecycle_stage:` value is preferred (it was
  the one driving posture) and a WARN names both.

## Reading / writing / transitioning

- **Read:** `lifecycle_get_stage <root>` (defaults `prelaunch`).
- **Write:** `lifecycle_set_stage <root> <stage>` — rejects out-of-vocabulary
  stages (exit 2).
- **Validate:** `lifecycle_valid_stage <stage>`; `lifecycle_posture <stage>`.
- **Set via config tool:** `devos-config --lifecycle <stage>` (validated).
- **Transition to live:** `go-live` — sets `lifecycle: live` AND rewrites the
  CLAUDE.md/AGENTS.md compatibility-posture blocks. Use `go-live` (not a bare
  config edit) for the full `* → live` transition.

## Release awareness

`devos-init` Phase 12b treats stages `beta`/`rc`/`live` (among other signals) as
indicating a project that ships releases, and checks release-infra coherence
(CHANGELOG, version sync, and — for registry adapters only — a CI publish
workflow). OS-package/self-install projects need no CI publish workflow.
