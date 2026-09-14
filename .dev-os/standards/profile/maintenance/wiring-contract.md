<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/wiring-contract.md and re-run profile-sync. -->
# Wiring Contract for Gate Artifacts

**Status:** canonical
**Applies to:** any spec that ships a new gate, validator, hook-invoked function, or pre-commit / pre-push check.
**Source:** Layer 2 Dalio pass surfaced the recurring "wiring aftershock" class — mechanisms shipped correctly but not integrated into the blocking hook chain, install.sh, or the profile propagation. Gaps G-DO-25, G-DO-26, G-DO-27, G-DO-29 were all single instances of the same unstated contract.

## The rule

A spec that introduces a gate artifact is not shippable until the spec includes a `wired_in` checklist, and the checklist is satisfied before the feature is marked done.

**Gate artifact** = any of: validator function, pre-commit / pre-push / post-commit script, `*_check()` function, a script installed by `scripts/install.sh`, or any standalone check that blocks a developer action.

## Required checklist

Every qualifying spec must include this block verbatim:

```markdown
## wired_in (gate integration)

- [ ] Invoked by a blocking hook chain — NOT `|| true`; exits non-zero on failure
- [ ] Propagated to profile hooks (profiles/default/hooks/pre-commit.sh and equivalents)
- [ ] Installed by scripts/install.sh for fresh installs (see install_git_pre_commit_hook pattern)
- [ ] Documented in the relevant command or SKILL.md
- [ ] At least one test (BATS or equivalent) proves the gate fires and blocks

Evidence: <file:line for each box>
```

Every box must be checked or justified inline before the spec's last task is checked.

## Exemptions

- **Read-only signals** (e.g., `gap_velocity_summary`) are not gates — checklist does not apply.
- **Deferred gates** (shipped behind a feature flag or opt-in env var) may leave the "Invoked by a blocking hook chain" box unchecked with a `deferred: <trigger>` note. The other four boxes still apply.
- **Project-local-only gates** (in `.claude/hooks/` but not `profiles/`) may skip "Propagated to profile hooks" with an inline `project-local-only` note.

## Why this exists

Without the checklist, gate artifacts routinely ship in one pass and are discovered un-wired in the next — decay trajectory "24 → 4 → 2 → 0 → 2" in the 2026-04-23 dev-os convergence summary is the canonical example. The Designer-layer fix is not more manual attention; it is a written contract the spec template enforces.

## Enforcement

- `bx-skill-creator` emits the checklist for any spec that names a validator/check/hook.
- `write-spec` includes the checklist in its template for any spec whose scope covers a gate artifact.
- `bx-command-creator` references this standard when a new command ships a gate.

## Compliance test

- [ ] For any spec merged in the last release that names a gate artifact: does its spec file contain a `## wired_in` block?
- [ ] Does `command grep -rL "wired_in" product/specs/*/spec.md 2>/dev/null | xargs -I{} command grep -l "pre-commit\|hook\|validator\|_check" {} 2>/dev/null` return zero files (no qualifying specs without the block)?
- [ ] Does the gate artifact identified in the spec exist at the path listed in the Evidence line?
- [ ] Does the pre-commit hook chain invoke it non-optionally (no `|| true` guard)?

If any check fails: the spec is not shippable. Add the `wired_in` block and satisfy all five boxes before marking done.
