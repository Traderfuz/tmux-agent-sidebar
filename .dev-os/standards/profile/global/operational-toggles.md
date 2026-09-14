<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/operational-toggles.md and re-run profile-sync. -->
# Operational Toggles Standard

**Area:** global
**Added:** 2026-06-28
**Source:** spec 2026-06-27-devos-operational-toggles

---

## Overview

DevOS has many operational surfaces (tracing, hooks, cron, MCP guards, review gates, browser
CDP, agent dispatch) whose on/off controls historically scattered across environment
variables, rc-file edits, runtime sentinels, and raw scripts. Operators could not reliably
answer "is this on?", "what will pause?", "is this safe?", or "how do I restore it?". This
standard defines the **single reusable contract every operational-toggle skill MUST follow**
so toggles are inspectable, reversible, audited, and safe by construction.

## Scope

Governs any skill that enables/disables a DevOS operational surface. It does NOT govern
process lifecycle skills that already expose `start|stop|status` (`dev-server`,
`memory-watcher`), CI toggling (`ci-toggle`), or destructive process termination.

---

## Rules

### R1 — The `status | on | off` verb contract (MUST)

Every toggle skill MUST expose `status`, `on`, and `off` as its minimum UX. It MAY add named
modes (`full-off`, `turns-off`, `--scope <s>`) but MUST NOT rename the three base verbs.

### R2 — `status` reports state AND source-of-state (MUST)

`status` MUST report each managed scope's effective state and the **source of that state**, one of:
`default | env | runtime-sentinel | project-local | global | config`. It MUST surface TTL expiry and
expired-disabled states where TTL applies, and MUST flag a scope whose effective source is `env` while
a conflicting lower-precedence value exists as **`env-masked`**.

### R3 — Source-of-state precedence (MUST)

Effective state resolves by this precedence, highest first:

```
env > runtime-sentinel > project-local > global > config > default
```

The shared resolver `toggles_resolve_state <root> <subsystem> <scope>` (in
`scripts/lib/toggles.sh`) is the single source of truth — toggle skills and hook bodies MUST
call it rather than re-implementing precedence.

### R4 — Restore-command echo + reversibility (MUST)

Every state-changing action (`on`/`off`/modes) MUST be reversible and MUST print, after the
change: (a) what changed, (b) what remains disabled, (c) the **exact command to restore** the
prior state. When an `env` override masks the change, it MUST warn and print the `unset`
command for the masking variable.

### R5 — Dangerous-action guardrail (MUST)

Any action that disables a blocking safety gate or reduces observability (e.g. `secret-scan`,
`pre-push`, trace `full-off`, `all`) MUST require `--reason "<text>"` plus a time bound —
either `--ttl <dur>` or `--until-manual` — MUST print a warning naming the disabled gate, and
MUST emit an audit event. No silent safety bypass is ever permitted.

### R6 — State owner (MUST)

Persistent project toggle state lives in `.dev-os/runtime/toggles.yml`; persistent all-project
overrides live in `~/.dev-os/runtime/global-toggles.yml` and are selected explicitly with `--global`.
Environment variables remain as escape hatches; `status` MUST report when an env override is effective.
Skills MUST read/write state only through `scripts/lib/toggles.sh` — never by editing hook files or rc
files directly (rc-block / systemd ownership stays with the wrapped scripts).

### R7 — Audit stream is primary; review-event is for dangerous actions only (MUST)

State changes MUST append a structured line to the dedicated runtime audit stream
`<runtime-root>/toggles-audit.jsonl` (resolved via `scripts/lib/runtime-state.sh`) as the
**primary** audit path. A `review-event@v1` MUST be emitted **only** for human-review-worthy
dangerous actions, so the `devos-review` queue is not polluted by routine toggles. Audit fires
on state-*changing* commands and on lazy TTL-expiry auto-restore — never on `status`.

### R8 — Lazy TTL expiry is auditable both ways (MUST)

Because expiry is resolved lazily (no daemon), the first `toggles_resolve_state` read after a
disable's `expires_at` MUST resolve to the restored state, emit a **one-time** auto-restore
audit line, and clear the expired entry. Subsequent reads MUST NOT re-emit. An auto-restore
is as auditable as the original disable.

### R9 — Hook-file integrity (MUST)

A toggle skill MUST NOT edit installed hook scripts. State lives in `toggles.yml`; hooks gate
their body on `toggles_resolve_state` at invocation time. A subsequent `repair-hooks` run MUST
NOT erase toggle state.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Renaming the base verbs (`enable`/`disable`) | Breaks operator muscle memory and cross-toggle consistency | Keep `status`/`on`/`off`; add modes alongside |
| Disabling a safety gate with no TTL | Bypass silently outlives its window | Require `--reason` + (`--ttl`/`--until-manual`) (R5) |
| Re-implementing precedence per skill | Drift; env-mask bugs; cross-CLI divergence | Call `toggles_resolve_state` (R3) |
| Routine toggles emitting `review-event@v1` | Pollutes the review queue | Primary audit is `toggles-audit.jsonl`; review-event for dangerous only (R7) |
| Editing hook files to pause a hook | `repair-hooks` clobbers it; not reversible cleanly | Gate hook body on `toggles_resolve_state` (R9) |
| No restore command shown | Operator re-discovers restore each time | Echo the exact restore command (R4) |

---

## Deferred toggle candidates (MUST reuse this standard)

The following surfaces are deferred to follow-up specs. Each new toggle **must reuse** this
standard (R1–R9) — it must not invent its own contract:

- `hooks-toggle` (scoped hook enable/disable)
- `cron-toggle`
- `auto-maintenance-toggle`
- `mcp-guard-toggle`
- `review-gate-toggle` / `lavish-toggle`
- `browser-cdp-toggle`
- `agent-dispatch-toggle`

---

## Compliance test

Answer yes/no. A standards-compliant toggle skill requires all MUST answers YES.

- [ ] **[MUST]** Exposes `status`, `on`, `off` without renaming them (R1)?
- [ ] **[MUST]** `status` reports state + source-of-state, including `env-masked` (R2)?
- [ ] **[MUST]** Resolves state via `toggles_resolve_state` (precedence env > runtime-sentinel > project-local > config > default) (R3)?
- [ ] **[MUST]** Every state change echoes the exact restore command (R4)?
- [ ] **[MUST]** Dangerous actions require `--reason` + (`--ttl` | `--until-manual`) and warn (R5)?
- [ ] **[MUST]** Persistent state lives in `.dev-os/runtime/toggles.yml` via `scripts/lib/toggles.sh` (R6)?
- [ ] **[MUST]** State changes audit to `toggles-audit.jsonl`; `review-event@v1` only for dangerous actions (R7)?
- [ ] **[MUST]** Lazy TTL expiry emits a one-time auto-restore audit (R8)?
- [ ] **[MUST]** Never edits hook files; state survives `repair-hooks` (R9)?

**Scoring:** all MUST YES → Compliant. Any MUST NO → Non-compliant; fix before shipping the toggle.

---

## References

- `scripts/lib/toggles.sh` — the shared resolver/state/audit lib (single source of truth)
- `scripts/lib/runtime-state.sh` — resolves the runtime root for `toggles-audit.jsonl`
- `scripts/lib/review-emit.sh` — `review-event@v1` emission for dangerous actions
- spec `2026-06-27-devos-operational-toggles` — origin + first slices (`trace-toggle`)
