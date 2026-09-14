<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/cli-context-ordering.md and re-run profile-sync. -->
# CLI Context Ordering

**Status:** Active. **Owner:** canonical-sections.

The inner portable context is manifest-driven. `contracts/canonical-sections.yml` is the only inventory; `scripts/lib/canonical-section-registry.sh` validates it and `canonical_emit_all_portable` renders it without dynamic evaluation.

## Canonical inner order

1. project-context
2. execution-orientation
3. skill-invocation
4. orca-control
5. safety-rules
6. conventions
7. directory-structure
8. devos-context
9. compatibility-posture
10. context-artifact-commit-policy
11. notepad-discipline

The top-level `DEVOS_*` taxonomy remains owned only by `contracts/managed-blocks.yml`. Project Brief precedes CANONICAL. All writers must preserve bytes outside managed blocks and fail unchanged on invalid ownership, markers, symlinks, permissions, or unavailable manifest/generator. Runtime alignment text consumes only `execution-alignment-public/v1`; absent or unsupported capability is advisory-only and must not claim enforcement.
