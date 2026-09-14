<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/runtime-state-paths.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/runtime-state-paths.md and re-run profile-sync. -->
# Runtime State Path Resolution

## Overview

DevOS separates mutable runtime state from the git-tracked source tree. Live data — capture inboxes, gap registries, circuit breakers, session state — lives **outside the repo** in a per-project directory under `$XDG_STATE_HOME/dev-os/projects/<project-id>/` (defaults to `~/.local/state/dev-os/projects/<project-id>/`). This prevents inbox records, telemetry, and ephemeral state from polluting commits and avoids data loss when branches switch.

## Scope

This standard covers how scripts, skills, and agents resolve paths to mutable runtime data. It does NOT cover the runtime-state library implementation itself (`scripts/lib/runtime-state.sh`) or the migration procedure (`scripts/lib/migrate-runtime-to-external.sh`).

---

## Principles

1. **External store is canonical.** The paths returned by `devos_runtime_path`, `devos_runtime_existing_path`, and `devos_runtime_write_path` resolve mutable data into one external source of truth. The repo-local path (`<repo>/product/inbox.jsonl`, `<repo>/.dev-os/runtime/*.json`) is a legacy fallback — never the primary.

2. **Read existing; preserve history on write.** Reads MUST use `devos_runtime_existing_path`. New files without legacy history use `devos_runtime_path`. Append-only files that may have legacy history MUST use `devos_runtime_write_path`, which atomically seeds a missing external file from the legacy file before returning the write target.

3. **Always resolve, never hardcode.** A repository-local literal is allowed only inside an explicit fallback branch when the relevant helper is unavailable or cannot resolve a non-empty path.

4. **Report true divergence; never merge it implicitly.** If external and repository-local copies both exist, select external as authoritative and report divergence without merging, copying, deleting, or rewriting either file. If only the legacy file exists, `devos_runtime_write_path` may publish its complete contents externally before the first append; that one-way seed is not divergent-state reconciliation.

---

## Rules

### R1 — Resolve reads and writes separately (`MUST`)

Use the existing-path helper for reads, the runtime-path helper for new files without legacy history, and the migration-aware write helper for append-only files whose fallback history must be preserved:

```bash
local read_path write_path
if declare -f devos_runtime_existing_path >/dev/null 2>&1 &&
    read_path="$(devos_runtime_existing_path "$project_root" "product/inbox.jsonl")" &&
    [[ -n "$read_path" ]]; then
    :
else
    read_path="$project_root/product/inbox.jsonl"
fi

if declare -f devos_runtime_path >/dev/null 2>&1 &&
    write_path="$(devos_runtime_path "$project_root" "product/inbox.jsonl")" &&
    [[ -n "$write_path" ]]; then
    :
else
    write_path="$project_root/product/inbox.jsonl"
fi
```

```bash
if declare -f devos_runtime_write_path >/dev/null 2>&1 &&
    registry_write_path="$(devos_runtime_write_path "$project_root" "product/gap-analysis/gap-registry.jsonl")" &&
    [[ -n "$registry_write_path" ]]; then
    :
else
    registry_write_path="$project_root/product/gap-analysis/gap-registry.jsonl"
fi
```

Fallback is permitted only when the relevant helper is unavailable or cannot resolve a path. The absence of the external file or its parent directory is not a fallback condition; writers create the parent directory.

```bash
# WRONG — hardcoded primary path
local inbox="$project_root/product/inbox.jsonl"

# WRONG — writes through the existing-path reader helper
inbox="$(devos_runtime_existing_path "$project_root" "product/inbox.jsonl")"
printf '%s\n' "$row" >> "$inbox"
```

### R2 — Skills reference logical paths and resolver semantics (`MUST`)

Skill files that mention mutable runtime data MUST state that reads resolve with `devos_runtime_existing_path`, ordinary creates resolve with `devos_runtime_path`, append-only legacy-backed writes resolve with `devos_runtime_write_path`, and repository-local literals are fallback-only.

### R3 — Divergence is observable and non-destructive (`MUST`)

If an external mutable file and its repository-local counterpart both exist, select the external file as authoritative and emit a divergence signal. Do not silently merge, copy, delete, or rewrite either copy. Use the dedicated migration workflow when reconciliation is intentional. This does not prohibit `devos_runtime_write_path` from atomically seeding an absent external file from the sole existing legacy copy.

### R4 — External store path structure (`SHOULD`)

The external store mirrors the repo-relative path structure:
- `<runtime-root>/product/inbox.jsonl`
- `<runtime-root>/product/gap-analysis/gap-registry.jsonl`
- `<runtime-root>/.dev-os/runtime/*.json`

Where `<runtime-root>` = `$XDG_STATE_HOME/dev-os/projects/<project-id>/` (default: `~/.local/state/dev-os/projects/<project-id>/`).

---

## Key runtime files

| Logical path | Read resolver | Write resolver | Owner |
|---|---|---|---|
| `product/inbox.jsonl` | `devos_runtime_existing_path` | `devos_runtime_path` | `capture.sh` |
| `product/gap-analysis/gap-registry.jsonl` | `devos_runtime_existing_path` | `devos_runtime_write_path` | `gap-analysis` |
| `.dev-os/runtime/context-refresh-state.json` | `devos_runtime_existing_path` | `devos_runtime_path` | context-refresh |
| `.dev-os/runtime/toggles.yml` | `devos_runtime_existing_path` | `devos_runtime_path` | toggles.sh |
| `product/runtime/learnings-log.jsonl` | `devos_runtime_existing_path` | `devos_runtime_path` | learnings-capture.sh |

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `local inbox="$workspace/product/inbox.jsonl"` | Bypasses external store; data stranded in repo | Resolve via `devos_runtime_path` with fallback |
| Appending to a legacy-backed registry via `devos_runtime_path` | Creates a partial external file that shadows repository-local history | Resolve via `devos_runtime_write_path` |
| `tail product/inbox.jsonl` in a skill | Reads stale/empty repo-local file | `capture --show <id>` or resolve path first |
| `command find product/ -name 'inbox.jsonl.bak*'` only | Misses .bak files at external store | Probe BOTH external AND repo-local locations |
| Assuming `product/inbox.jsonl` is in the git tree | It should NOT be — canonical is external | Resolve via runtime-state.sh |

---

## Compliance test

- [ ] **[MUST]** Do readers use `devos_runtime_existing_path`, ordinary creators use `devos_runtime_path`, and legacy-backed appenders use `devos_runtime_write_path`?
- [ ] **[MUST]** Are repository-local literals confined to explicit branches used only when the relevant helper is unavailable or cannot resolve a path?
- [ ] **[MUST]** When external and local copies coexist, is external selected and divergence reported without merging?
- [ ] **[MUST]** Do skill files describe external-authoritative read/write resolution?

---

## References

- `scripts/lib/runtime-state.sh` — canonical path resolver implementation
- `scripts/lib/migrate-runtime-to-external.sh` — migration script for moving repo-local data to external store
- `scripts/lib/capture.sh` — primary consumer of inbox resolution
