<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/installable-os-dual-write.md and re-run profile-sync. -->
# Installable OS Dual-Write Standards

## Overview

The `os` workspace contains installable OS packages whose source files are copied or linked into client projects. Dogfooding or debugging an installed copy can make a fix appear complete while the canonical OS package source remains unchanged. The next reinstall then drops the fix.

This standard extends the DevOS self-dogfood dual-write rule to all installable OS packages in the workspace: durable fixes land in the OS package source, and active installed copies are updated when the current verification path depends on them.

## Scope

This standard covers dual-write handling for installable OS package artifacts in the `os` workspace. It does NOT cover ordinary application code, generated client deliverables, release publishing, or one-off project-local customizations.

## Named frameworks

- **GitOps Source of Truth:** Durable desired state must live in version-controlled OS package source.
- **Configuration Drift Management:** Installed/runtime copies must not silently diverge from their package source.
- **RFC 2119 Normative Vocabulary:** MUST/SHOULD/MAY language makes propagation expectations checkable.
- **DRY/DAMP Standards Balance:** Canonical OS source remains DRY while active installed copies stay explicit enough for dogfood verification.

## Principles

1. **Package source is durable:** Fixes intended for future installs belong in the owning OS package source.
2. **Installed copies are executable:** The current client or dogfood project may execute an installed copy before reinstall happens.
3. **Propagation must be visible:** Agents must state whether a fix was copied, synced, or intentionally left pending.
4. **Each OS owns its namespace:** Fixes must be made in the owning OS package, not in a downstream package that merely consumes its output.

## Rules

### Rule 1 — Locate the owning OS package

Before fixing an installed artifact, agents MUST identify its owning OS package and source path.

Common source roots:

| OS package | Canonical source examples | Installed/local examples |
|---|---|---|
| DevOS | `profiles/**`, `scripts/**`, `chains/**` | `.dev-os/**`, `.claude/**` |
| Marketing OS | `marketing-os/profiles/default/**`, `marketing-os/scripts/**` | `.marketing-os/**`, `marketing/**`, `.claude/skills/mos-*` |
| Creative OS | `creative-os/profiles/default/**`, `creative-os/scripts/**` | `.creative-os/**`, `creative/**`, `.claude/skills/cos-*` |
| Research OS | `research-os/profiles/default/**`, `research-os/scripts/**` | `.research-os/**`, `research/**`, `.claude/skills/ros-*` |
| Design OS | `design-os/profiles/default/**`, `design-os/scripts/**` | `.design-os/**`, `design/**`, `.claude/skills/dos-*` |
| Boxi Ops OS | `boxi-ops-os/profiles/default/**`, `boxi-ops-os/scripts/**` | `.boxi-ops-os/**`, `clients/**`, `.claude/skills/bos-*` |

### Rule 2 — Patch source and active copy when verifying locally

When the current failure is observed in an installed/local copy and the fix is intended to persist, agents MUST patch the canonical OS source. If the current verification command reads the installed/local copy, agents MUST also patch that active copy or run the OS installer/sync step before verifying.

```text
# OFF-STANDARD
Patch .claude/skills/mos-keyword-research/SKILL.md in a client project only.

# ON-STANDARD
Patch marketing-os/profiles/default/skills/mos-keyword-research/SKILL.md,
then update the client installed copy or rerun the Marketing OS installer/sync.
```

### Rule 3 — Do not cross-write downstream dependencies

Downstream OSes MUST NOT patch upstream handoff contracts in their own package just to make a local pipeline pass. The owning OS source must be fixed first, then downstream consumers updated only if their local installed copy is stale.

### Rule 4 — Prefer installer/sync when broad propagation is needed

For more than one installed artifact, agents SHOULD run the OS package's installer, updater, or sync script instead of manual copying. Manual dual-write is acceptable for one-file dogfood fixes when it is faster and clearly verified.

### Rule 5 — Document intentional one-surface fixes

Agents MAY change only source or only installed/local copy when the change is intentionally scoped that way. They MUST state the reason and the expected follow-up.

Examples:

- Source-only: preparing the next OS release; no active client verification needed.
- Local-only: temporary client customization that must not be promoted to package source.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Fix only a client-installed skill | Next OS update overwrites it | Patch owning OS source and propagate |
| Fix only package source while testing installed copy | Current verification still reads stale code | Run installer/sync or patch active copy |
| Patch downstream OS for upstream data contract bug | Hides the actual owner of the defect | Fix upstream OS source first |
| Copy files across OS packages without ownership check | Breaks namespace isolation | Identify owning OS package and source root |
| Commit unexplained source/local drift | Future agents cannot tell whether drift is intentional | Document deviation or converge copies |

## Deviation guidance

You MAY skip dual-write when the artifact is not installed from an OS package, when the change is explicitly local-only, or when a package installer/sync will immediately propagate the source change. When you do, state the skipped surface and why.

## Profile inheritance notes

Extends the DevOS maintenance posture from `self-dogfood-dual-write.md` to the multi-OS workspace. Adds OS package ownership and cross-OS namespace rules.

## Compliance test

- [ ] Did the fix touch or target an installed OS artifact in a client/dogfood project?
- [ ] Did the agent identify the owning OS package and canonical source path?
- [ ] If the fix should persist, was the OS package source updated?
- [ ] If local verification reads an installed copy, was that copy updated or resynced before verification?
- [ ] If only one surface changed, is the source-only or local-only reason stated?
- [ ] Did verification cover the surface that will execute after the change?
- [ ] Does the diff avoid unexplained cross-OS ownership drift?

If any check fails, patch or sync the missing surface before declaring the fix complete.

## References

- [OpenGitOps Principles](https://opengitops.dev/) — version-controlled desired state and convergence.
- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) — normative language for checkable requirements.
- [Configuration drift](https://en.wikipedia.org/wiki/Configuration_drift) — divergence between intended and actual system state.
