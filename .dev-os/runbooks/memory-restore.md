# Runbook: Restore pre-reinstall memory

| Field | Value |
|-------|-------|
| Service | DevOS local memory store |
| Runbook type | Backup restore / rollback |
| Severity | P2 (memory unavailable or incomplete) |
| Owner team | Developer operating the memory host |
| Last reviewed | 2026-09-30 |
| Automation status | Manual |

## Backup location

On `codebox`, the inspected backup is on `/run/media/tafadzwa/ced037ac-1ce8-4e45-90fc-2920a9d34dc9/archive/old-ubuntu-2026-09/ai-history/.memory/local/`.
Copy `mem.db`, `mem.db-wal`, and `mem.db-shm` together. Do not open the originals: SQLite may update the shared-memory file.

## Restore

```bash
ssh tafadzwa@codebox
src=/run/media/tafadzwa/ced037ac-1ce8-4e45-90fc-2920a9d34dc9/archive/old-ubuntu-2026-09/ai-history/.memory/local
copy=$(mktemp -d)
cp "$src/mem.db" "$src/mem.db-wal" "$src/mem.db-shm" "$copy/"
(cd "$copy" && sha256sum mem.db mem.db-wal mem.db-shm | tee sha256.before)
devos-memory-mcp restore --from "$copy/mem.db" --dry-run
```

Review the JSON plan. Confirm inserted + skipped equals source rows and that quarantine counts are expected. Then apply:

```bash
devos-memory-mcp restore --from "$copy/mem.db"
(cd "$copy" && sha256sum -c sha256.before)
devos-memory-mcp status --warm
# If embeddings remain pending or need refresh:
devos-memory-mcp regenerate-embeddings
```

Keep the snapshot path from the apply report. Restore does not modify the copied source; verify its three hashes after the run as shown above.

## Rollback

Use the snapshot path printed by restore:

```bash
devos-memory-mcp restore --rollback <snapshot-path>
```

The command verifies a matching restore report when available, replaces the live database atomically, removes stale WAL/SHM files, and prints before/after counts and digests. Confirm the output before resuming memory-backed work.
