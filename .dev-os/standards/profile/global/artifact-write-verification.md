<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/artifact-write-verification.md and re-run profile-sync. -->
# Artifact Write Verification

## Overview

A process that writes a durable artifact must prove it wrote what it claims before it
reports success. Reporting success on the basis of "I ran without throwing" is the
single most expensive failure class in this codebase: it destroys correct data, replaces
true artifacts with false ones, and leaves no diagnostic for the operator to notice.
This standard governs the moment a write path decides to say "✓".

It exists because of four defects found in one session, all with the same shape —
a success marker emitted over a broken postcondition.

## Scope

This standard covers success reporting for any process that writes, regenerates, or
mutates a durable artifact. It does NOT cover diagnostic warning handling (see
`no-silent-warnings.md`), completion-status reporting by readers (see
`verify-status-against-artifact.md`), or backlog surfacing reconciliation (see
`verify-before-surface.md`).

Boundary on content: structural invariants are in scope — emptiness, parseability,
enumerated counts, path portability, presence of a written record. Editorial and
semantic judgment is out of scope — whether prose is accurate, well-written, or
conceptually correct. The test is mechanical checkability: if a script can decide it
without judgment, this standard governs it.

## Principles

1. **The writer owns the postcondition:** Per Design by Contract, a supplier that
   returns successfully guarantees its postcondition holds. A writer that cannot assert
   its artifact exists and is well-formed has no standing to report success.
2. **Exit 0 is not evidence:** Absence of a thrown error proves the process did not
   crash. It proves nothing about the artifact. Read the artifact back.
3. **Degenerate output is worse than stale output:** A stale artifact misleads about
   recency. An empty or contradicted artifact is read as ground truth and is actively
   false. Prefer keeping the old artifact over writing a degenerate one.
4. **Silence is a defect, not tidiness:** A destructive write path that prints nothing
   gives the operator no surface on which to notice loss.

## Rules

### Write-path postconditions

- **Read-back required:** Before printing any success marker, re-read the artifact
  from its canonical path and assert it exists. (`MUST`)
- **Assert one content invariant:** The read-back MUST check at least one property
  beyond existence — non-zero length, parseable syntax, or presence of the specific
  record just written. File existence alone is not verification. (`MUST`)
- **Failed postcondition exits non-zero:** A violated postcondition is a bug, not a
  warning. Exit non-zero and name the artifact and the failed invariant. (`MUST`)

```bash
# OFF-STANDARD — success printed with no read-back
_capture_patch_fields "$inbox_path" "$target_id" "$fields_json" "$reason" || return $?
echo "[capture] ✓ updated ${target_id}"

# ON-STANDARD — postcondition asserted before the marker
_capture_patch_fields "$inbox_path" "$target_id" "$fields_json" "$reason" || return $?
if ! _capture_record_json "$inbox_path" "$target_id" >/dev/null 2>&1; then
    echo "[capture] ✗ POSTCONDITION FAILED: ${target_id} absent from ${inbox_path} after patch" >&2
    return 1
fi
echo "[capture] ✓ updated ${target_id}"
```

### Mutation semantics

- **Patch means patch:** An operation that declares it updates a field MUST NOT remove
  the record. Setting a terminal status is a field change, never a deletion. (`MUST`)
- **Retention over pruning:** Records with terminal status (`resolved`, `closed`,
  `done`) MUST remain readable by their canonical accessor. Terminal status is a
  display filter, not a delete trigger. (`MUST`)
- **Prove the delta, not the run:** A mutation reports the field it changed and the
  record it changed it on, so the operator can spot an unintended scope. (`SHOULD`)

### Generated indexes and derived artifacts

- **Count reconciliation:** When a generated artifact asserts a count or enumerates a
  set, that count MUST be reconciled against the on-disk source before the write is
  accepted. An index claiming zero skills while 48 skill directories exist is a failed
  postcondition. (`MUST`)
- **Non-empty gate:** A regeneration MUST NOT replace a non-empty artifact with an
  empty one without an explicit, logged justification. (`MUST`)
- **Shrink gate:** A regeneration that reduces an artifact by more than 50% MUST
  surface the delta and require confirmation before replacing the original. (`SHOULD`)
- **Portable paths only:** Committed generated artifacts MUST contain repo-relative
  paths. Absolute machine paths (`/home/<user>/...`) are a failed postcondition. (`MUST`)

```bash
# OFF-STANDARD — state file reports pass without validating output
printf 'status: pass\ndecision_reason: %s\nfailures: none\n' "$reason" > "$state"

# ON-STANDARD — validate before claiming pass
_skills_on_disk=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
_skills_in_index=$(python3 -c "import json;print(len(json.load(open('$INDEX'))['skills']))")
if [ "$_skills_in_index" -eq 0 ] && [ "$_skills_on_disk" -gt 0 ]; then
    printf 'status: fail\nreason: index claims 0 skills, %s on disk\n' "$_skills_on_disk" > "$state"
    echo "[context-refresh] ✗ REFUSING to write contradicted index" >&2
    exit 1
fi
```

### Concurrent and atomic writes

- **Serialize full-file read-modify-write:** Any process that reads a whole file,
  modifies it in memory, then rewrites it MUST hold an exclusive advisory lock
  (`flock`) for the full cycle, or perform an optimistic version check on write. A
  lock file that exists but is never acquired provides no protection. (`MUST`)
- **Write-sync-rename:** Durable writes SHOULD use the POSIX atomic pattern — write to
  a temp file in the same directory, `fsync`, then `rename` over the target — so a
  crash leaves either the complete old file or the complete new one. (`SHOULD`)
- **Never fan out concurrent mutations to one ledger:** Two mutating operations against
  the same file MUST be sequenced, never issued in parallel. (`MUST`)

### Required-dependency resolution

- **Absent gate helper fails loud:** When a process declares a gate blocking and its
  helper is missing, it MUST exit non-zero. Treating a missing enforcement mechanism as
  a satisfied gate converts a blocking control into a silent no-op. (`MUST`)

### Agent-authored artifacts

- **A write tool's success report is not evidence:** When an agent writes a durable
  artifact under `product/specs/**`, `product/gap-analysis/**`, or `docs/**`, it MUST
  assert the artifact exists and satisfies one content invariant before reporting
  success or letting any downstream step consume it. (`MUST`)
- **Assert before consume:** A step that reads an artifact another step claims to have
  written MUST gate on that artifact (`aawv_assert_before_consume`), not on the
  upstream success report. (`MUST`)
- **No artifact reference without the artifact:** A spec or planning artifact MUST NOT
  reference a sibling artifact in its own spec directory that does not exist on disk.
  (`MUST`)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `echo "✓ updated $id"` with no read-back | Reports success over a deleted record | Re-read the record; exit non-zero if absent |
| Terminal status triggers row removal | Destroys audit history; accessor 404s | Keep the row; filter at display time |
| Two mutating calls issued in parallel on one JSONL | Lost update — later writer clobbers earlier | Sequence them, or `flock` the full cycle |
| `status: pass` written without validating output | Masks empty and contradicted artifacts | Reconcile counts before writing `pass` |
| Regeneration writes a 0-line index | Read as ground truth; actively false | Non-empty gate; keep prior artifact, exit non-zero |
| Absolute paths in generated committed files | Breaks on every other machine | Emit repo-relative paths |
| Missing gate helper treated as gate satisfied | Blocking control becomes a no-op | Exit non-zero and name the missing helper |
| Destructive path prints nothing at all | Operator has no surface to notice loss | Report the delta on every mutation |
| Write tool reported success, so the artifact landed | Silent false-success leaves downstream work building on nothing | Assert existence plus one invariant after the write |

## Deviation guidance

You MAY skip read-back verification when the write target is an append-only telemetry
or log stream where loss of a single line is tolerable and no reader treats it as
authoritative. When you do, you MUST annotate the write path with the reason and
confirm no gate, index, or status surface consumes it.

You MAY write a shrinking artifact without confirmation in a non-interactive run when a
recorded source deletion explains the shrink. When you do, you MUST log the source
delta alongside the new size.

## Profile inheritance notes

Standalone within `global`. Sibling — not child — of
`verify-status-against-artifact.md`: that standard binds **readers** to prefer the
artifact over the marker; this one binds **writers** not to emit a marker they have not
verified. Together they close the loop. Adds the write-side postcondition obligation
that `no-silent-warnings.md` (diagnostic handling) and `verify-before-surface.md`
(surfacing reconciliation) leave uncovered.

## Compliance test

Enforcement (dev-os spec `2026-08-13-artifact-write-verification-enforcement`):
`bash scripts/lib/artifact-write-verification-check.sh [repo_root]` walks
`product/standards/write-path-inventory.yml` and reports per-path PASS/FAIL/DRIFT.
The pre-commit gate `scripts/hooks/pre-commit-artifact-write-verification.sh`
blocks staged success markers lacking read-back in inventory-listed files
(bypass: `DEVOS_AWVF_BYPASS=1`, logged). Session-start health surfaces a
YELLOW when any record fails.

Agent-authored half: `scripts/lib/agent-artifact-write-verify.sh` provides
`aawv_verify_artifact` and `aawv_assert_before_consume`, and the pre-commit gate
`scripts/hooks/pre-commit-agent-artifact-verification.sh` blocks an empty staged
artifact under `product/specs/**`, `product/gap-analysis/**`, or `docs/**`, and a
staged spec artifact referencing a sibling artifact that does not exist
(bypass: `DEVOS_AAWV_BYPASS=1`, logged). Forward-only: it evaluates staged paths,
so pre-existing dangling references are fixed as their files are next touched.

- [ ] Does every success marker in the write path fire only after re-reading the written artifact?
- [ ] Does that read-back assert at least one invariant beyond file existence?
- [ ] Does a violated postcondition exit non-zero rather than warn or continue?
- [ ] Does an operation that claims to patch a record leave that record retrievable by its canonical accessor?
- [ ] When a generated artifact asserts a count, is that count reconciled against the on-disk source before the write is accepted?
- [ ] Are committed generated artifacts free of absolute machine-specific paths?
- [ ] Does every full-file read-modify-write hold an exclusive lock or perform a version check?
- [ ] Does a process whose blocking gate helper is missing exit non-zero?
- [ ] Does an agent-authored artifact write assert existence plus one invariant before success is reported?
- [ ] Does a step that consumes another step's artifact gate on the artifact rather than the upstream success report?
- [ ] Is every sibling artifact referenced by a spec or planning artifact present on disk?

If any check fails: fix the write path, or record the deviation with its justification
in the write path itself per Deviation guidance.

## References

- [Design by Contract](https://en.wikipedia.org/wiki/Design_by_contract) — postconditions are supplier obligations; a violated postcondition is a bug, not a warning
- [Fail-fast systems](https://en.wikipedia.org/wiki/Fail-fast_system) — halt at the boundary rather than continue in a corrupted state; explicit aversion to silent failure
- [Eiffel: Design by Contract and Assertions](https://www.eiffel.org/doc/solutions/Design_by_Contract_and_Assertions) — postcondition checks catch flawed logic before results propagate
- POSIX write-sync-rename and the Lost Update problem — atomic rename gives crash safety; only advisory locking or optimistic version checks prevent concurrent clobber
- `pipeline-guardian` skill (internal) — already names the semantic-failure class this standard makes enforceable: exits 0 but output is empty, malformed, or contains placeholders
