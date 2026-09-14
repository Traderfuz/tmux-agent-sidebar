<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/ephemeral-storage-lifecycle.md and re-run profile-sync. -->
# Ephemeral Storage Lifecycle

**Owner:** DevOS core · **Applies to:** DevOS, installable OS packages, DevOS-managed projects
**Spec:** `product/specs/2026-08-28-temporary-workspace-teardown/spec.md`

## Why

DevOS processes once exhausted all 1,048,576 `/tmp` inodes while 8 GiB of byte
capacity remained free. Cause: every producer invented its own temporary-folder
cleanup, and failure/interruption paths leaked. Rule: storage lifecycle is a
governed contract, not local command plumbing.

## The five storage classes

Classify data BEFORE writing cleanup code. The class decides the owner.

| # | Class | Examples | Lifecycle owner | Required behavior |
|---|---|---|---|---|
| 1 | Ephemeral workspace | test fixtures, extraction dirs, upload/PDF staging | the creating command or job | deleted on EVERY exit path: success, failure, handled interruption |
| 2 | Diagnostic retention | a failed run's workspace kept for inspection | the retention requestor | explicit opt-in only; path/reason/expiry printed; bounded TTL (≤72h); swept automatically |
| 3 | Cache | compiler/download caches | a cache manager | bounded size/age eviction; NEVER deleted by per-run teardown |
| 4 | Derived artifact | `dist/`, `.next/`, coverage output | the build system | reproducible; removed only by an explicit clean command |
| 5 | Dependency install | `node_modules/`, Python virtualenvs | the package manager | NOT temporary data; the ephemeral-workspace contract MUST NEVER delete it |

## Rules (MUST)

1. Every ephemeral workspace has exactly one owner — the process that created it.
2. Cleanup runs on success, failure, and handled `INT`/`TERM`/`HUP`.
3. Ownership is marked at creation, before work starts.
4. Deletion is fail-closed: only the exact created path, inside the chosen temp
   root, with a valid ownership marker, never across symlinks, never `/` or the
   temp root itself.
5. Retention is explicit (named API or `--keep-temp` style flag), states a
   reason, and carries a TTL no greater than 72 hours. Unbounded retention is
   invalid.
6. Expired retained workspaces are swept at deterministic lifecycle entry
   points (new workspace creation, session start). Host cleanup (`systemd-tmpfiles`)
   is a backstop, never the primary owner.
7. The creating process's exit status and caller trap state survive cleanup.
8. Projects inherit this classification through their DevOS profile; projects
   that create ephemeral data in non-shell runtimes use a language-appropriate
   scoped adapter with the same semantics.
9. A conformance audit rejects unmanaged ephemeral-directory creation in
   governed sources; exceptions must be narrow, classified, owned, justified,
   and review-dated.

## Anti-patterns (MUST NOT)

- Treat `node_modules/`, virtualenvs, or caches as "temp" and delete them.
- Keep a failed run's workspace "just in case" (retention is opt-in, bounded).
- Rely on host cleanup to be the primary teardown mechanism.
- Recursive-delete an arbitrary caller-supplied path.
- Copy this standard's text into child profiles — inherit it.

## Verification

Producers governed by this standard demonstrate: zero owned workspaces remain
after success, failure, and interruption cases under a dedicated `TMPDIR`;
retained entries expire; the audit reports no unresolved producers.
