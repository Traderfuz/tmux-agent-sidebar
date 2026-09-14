<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/runtime-file-taxonomy.md and re-run profile-sync. -->
# Runtime File Taxonomy — Three-Tier Definition

## Overview

DevOS writes runtime state to disk in many shapes — session logs, agent-telemetry
spans, generated skills-index YAMLs, committed health reports. Without a taxonomy,
files accumulate in the wrong tier: ephemeral telemetry bloats git history,
generated context rots in a planning directory, and readers cannot tell which
runtime files are authoritative. This standard defines the **three tiers** every
runtime file belongs to, so writers, reviewers, and cleanup tooling share one map.

This is the standard that `product/runtime/README.md` and the runtime-cull
maintenance step reference. It is a **file-placement** standard — distinct from
[`runtime-standards.md`](./runtime-standards.md), which governs *language/runtime
selection* (Node, Python, Bun versions).

## Scope

This standard covers **where runtime-generated and runtime-adjacent files must
live** in a DevOS project and whether they are committed. It does NOT cover
source code layout (`docs/`, `scripts/`), product planning artifacts
(`product/specs/`, `product/plans/`), or standards/profile authoring — those have
their own placement rules.

## The Three Tiers

| Tier | Location | Committed? | Lifetime | Examples |
|------|----------|-----------|----------|----------|
| **Tier 1 — Ephemeral** | `runtime/` (gitignored) + external runtime root | ❌ never | single session / short TTL | agent-telemetry spans, scratch review HTML, debug-attempts, orphan session snapshots |
| **Tier 2 — Committed project runtime state** | `product/runtime/` | ✅ yes | session-scoped, shared via git | `state.yml`, `daily-log.jsonl`, `learnings-log.jsonl`, `reports/`, committed `review-previews/` |
| **Tier 3 — Generated context** | `docs/context/` | ✅ yes (regenerated) | regenerable from source | `*-skills-index.yaml`, `DEVOS_SKILLS_INDEX.json`, `codebase-map.md`, `DEVOS_CONTEXT_BUNDLE.md` |

### Tier 1 — Ephemeral runtime state

Files that describe a single session or have a short useful life. They must be
**gitignored** and must never be committed. They live under the gitignored
`runtime/` directory or, when the runtime root is externalized (see
`scripts/lib/runtime-state.sh`), under the per-project external runtime root.

- `agent-telemetry/` JSONL spans — high-volume (1/day), only useful for the
  session that produced them
- working/scratch review HTML (`runtime/reviews/`) — superseded once a preview is
  promoted to Tier 2
- transient orchestration scratch (debug-attempts, rollback-state)

**Maintenance:** the weekly/maintenance pass culls Tier 1 files older than a TTL
(default 30 days). Tier 1 is the only tier eligible for automatic culling.

### Tier 2 — Committed project runtime state

Files that need to **survive across sessions and be shared via git** so other
agents, `daily-review`, and `project-status` can read the project's current
operational state. These live under `product/runtime/` and ARE committed.

- `state.yml` — cadence/session state
- `daily-log.jsonl`, `health-daily-log.jsonl` — daily activity
- `learnings-log.jsonl` — human-curated advisor learnings
- `reports/` — committed audit and health reports
- `review-previews/` — review HTML promoted for shared review sessions

**Test:** a Tier 2 file answers the question *"what is the project's current
state that the next session must see?"* If the answer is *"only this session
cared about it"*, it is Tier 1.

### Tier 3 — Generated context

Files that are **regenerable from source** and exist to inject context into
sessions. These live under `docs/context/` and are committed (so context
injection is deterministic), but they are never hand-edited — a generator owns
each one.

- `*-skills-index.yaml` (per-OS skills indexes)
- `DEVOS_SKILLS_INDEX.json`, `DEVOS_CHAINS_INDEX.json`, `DEVOS_WORKFLOWS_INDEX.md`
- `codebase-map.md`, `DEVOS_CONTEXT_BUNDLE.md`, `DEVOS_CAPABILITIES_INDEX.md`

**Test:** a Tier 3 file has a named generator (a script or skill). If no
generator owns it, it is either Tier 2 (hand-curated state) or misplaced.

## Principles

1. **Tier determines commit policy, not the reverse.** Decide a file's lifetime
   first; the tier then dictates location and `.gitignore` status. Committing a
   Tier 1 file is the most common violation.

2. **Generated ≠ curated.** A regenerable file is Tier 3 and belongs in
   `docs/context/`; a hand-curated operational file is Tier 2 and belongs in
   `product/runtime/`. Mixing them makes cleanup unsafe (culling a curated file)
   and context stale (failing to regenerate a generated one).

3. **Ephemeral volume must not enter git.** Agent-telemetry and scratch review
   HTML are high-churn; committing them bloats history and triggers dirty-tree
   guards. Tier 1 is gitignored by construction.

4. **One canonical path per tier.** Do not fork a tier across multiple roots
   without an explicit external-runtime-root config. Readers and tooling assume
   the single canonical location.

## Rules

### R1 — Tier 1 files MUST be gitignored
Any file whose useful life is a single session or that is regenerated at high
frequency MUST live under `runtime/` (or the external runtime root) and MUST
appear in `.gitignore`. (`MUST`, RFC 2119)

```
# OFF-STANDARD — telemetry committed, bloating history
product/runtime/agent-telemetry/spans-2026-06-25.jsonl   # tracked

# ON-STANDARD — gitignored, ephemeral
runtime/agent-telemetry/spans-2026-06-25.jsonl           # .gitignore: runtime/agent-telemetry/
```

### R2 — Tier 2 files MUST be committed and hand-curated
Operational state that the next session must see MUST live under
`product/runtime/` and MUST be committed. It MUST NOT be machine-regenerated
wholesale (a generator overwriting `learnings-log.jsonl` destroys human
curation). (`MUST`)

### R3 — Tier 3 files MUST have a named generator and live in docs/context/
Generated context MUST live under `docs/context/`, MUST be committed, and MUST
be owned by a named generator (script or skill). Hand-editing a Tier 3 file is a
violation — the next regeneration silently reverts the edit. (`MUST`)

### R4 — A file MUST NOT span tiers
A single file is in exactly one tier. If a directory mixes tiers, split it
(e.g. `product/runtime/agent-telemetry/` is wrong — telemetry is Tier 1 and
belongs under gitignored `runtime/agent-telemetry/`). (`MUST`)

### R5 — Cleanup tooling MAY only cull Tier 1
Automatic culling (maintenance passes, TTL sweeps) MAY delete Tier 1 files only.
Tier 2 and Tier 3 files require explicit operator action or regeneration
respectively. (`MUST`)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Committing `agent-telemetry/` spans | Bloats git history, triggers dirty-tree guards | Tier 1 → gitignore `runtime/agent-telemetry/` |
| Hand-editing a `*-skills-index.yaml` | Next regeneration reverts the edit | Tier 3 → edit the source the generator reads, regenerate |
| Placing generated context in `product/runtime/` | Readers can't tell curated from generated; cleanup unsafe | Tier 3 → `docs/context/` |
| Machine-overwriting `learnings-log.jsonl` | Destroys human curation | Tier 2 → append-only, human-curated |
| Forking a tier across roots without config | Readers/tooling miss the second copy | One canonical path; use external-runtime-root config if needed |

## Compliance Test

- [ ] Is every `agent-telemetry/` location gitignored (R1)?
- [ ] Are operational state files under `product/runtime/` committed and not machine-regenerated wholesale (R2)?
- [ ] Does every file in `docs/context/` have a named generator (R3)?
- [ ] Does any directory mix tiers (R4)? If yes, split it.
- [ ] Does any automatic cleanup touch Tier 2 or Tier 3 (R5)? If yes, restrict it to Tier 1.

If any check fails: move the offending file to its correct tier, update the
relevant generator/writer path, and add/fix the `.gitignore` entry.

## References

- `product/runtime/README.md` — Tier 2 directory guide (links here)
- [`runtime-standards.md`](./runtime-standards.md) — language/runtime *selection*
  (sibling standard, different concern)
- `scripts/lib/runtime-state.sh` — external runtime-root resolution
- Spec: `product/specs/2026-06-25-runtime-taxonomy-gap-convergence/spec.md`
