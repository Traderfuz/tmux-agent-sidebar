<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/architecture/canonical-tool-prefixes.md and re-run profile-sync. -->
# Canonical Tool Naming Prefixes Standard

## Overview

DevOS and its installable OS packages share one flat skill/command namespace across multiple AI CLIs. Without a canonical prefix convention, two problems appear immediately: a tool name collides with a CLI built-in (so the CLI shadows it), or a reader cannot tell which OS package owns a tool. This standard fixes both by defining the reserved prefixes — `bx-`, `devos-`, `cos-`, `dos-`, `ros-`, `mos-` (plus `bos-`, `km-`) — what each one means, and the single-source-of-truth files that must agree before any prefix is used.

A prefix here is not decoration. It is the namespace that the ownership resolver, the collision auditor, and the cross-OS gap router all read to decide who owns a surface.

## Scope

This standard covers the canonical name prefixes for DevOS skills and OS-package commands, what each prefix means, and the registries that must stay in sync. It does NOT cover skill file structure (see `skills-system.md`), skill composition archetypes (see `skill-composition.md`), or command output contracts (see `agent-native-cli.md`).

## Principles

1. **Namespace before name:** A tool's prefix declares ownership; the rest of the name describes the job.
2. **Single source of truth:** Prefix → owner is defined once, in registries, and consumed everywhere — never re-hardcoded per skill.
3. **Collision avoidance is mandatory, not aesthetic:** A bare name that shadows a CLI built-in is a defect because the user can never invoke it.
4. **Reserved means reserved:** A prefix maps to exactly one owner; reuse for a different owner is forbidden.
5. **Register before use:** A new prefix exists in the registries before the first tool that carries it.

## Canonical prefix registry

| Prefix | Owner | Kind | Meaning |
|---|---|---|---|
| `bx-` | DevOS (framework-owned, cross-OS) | skill family | The builder/creator suite — authoring tools that generate other artifacts (`bx-skill-creator`, `bx-standards-creator`, `bx-command-creator`, `bx-workflow-creator`, `bx-pipeline-creator`, `bx-runbook-creator`, `bx-agent-creator`, `bx-chain-manager`, …). Resolves to `dev-os` ownership. |
| `devos-` | DevOS framework platform | skill / command | Platform tools and any bare name namespaced to dodge a CLI built-in collision (`devos-init`, `devos-verify`, `devos-doctor`, `devos-agent`, `devos-clear`, …). |
| `cos-` | creative-os | skill prefix | Creative OS tools (`cos-image-gen`, …). |
| `dos-` | design-os | command prefix | Design OS tools. |
| `ros-` | research-os | command + skill prefix | Research OS tools. |
| `mos-` | marketing-os | command prefix | Marketing OS tools. |
| `bos-` | boxi-ops-os | skill / command | Boxi Ops OS tools (reserved). |
| `km-` | km-os | skill / command | Knowledge-management OS tools (reserved). |

The user-facing six are `bx-`, `devos-`, `cos-`, `dos-`, `ros-`, `mos-`; `bos-` and `km-` are reserved for completeness so they are never reassigned.

## Single source of truth

Three files MUST agree. Changing one without the others is the primary drift defect this standard prevents:

| File | Role |
|---|---|
| `.dev-os/reserved-prefixes.yml` (`owned_prefixes`) | Declares which prefixes are namespaced and therefore exempt from the bare-name collision rule. |
| `scripts/lib/os-ownership-resolver.sh` (`_OS_OWNERSHIP_PREFIX_MAP`) | Maps each OS-package prefix to its `os-id` for ownership/routing resolution. |
| `os-registry.yml` at repo root (`skill_prefix` / `command_prefix`) | Records each **installed** OS package and the prefix it ships. Tracks installed packages only — a reserved-but-uninstalled prefix is absent until its package ships. |

`bx-` and `devos-` appear in `owned_prefixes` but not in `_OS_OWNERSHIP_PREFIX_MAP`, because they are framework-owned (they resolve to `dev-os`, not to a separate OS package). Every OS-package prefix (`cos-`, `dos-`, `ros-`, `mos-`, `bos-`, `km-`) MUST appear in both `reserved-prefixes.yml` and `os-ownership-resolver.sh`. A prefix whose OS package is **installed** MUST additionally appear in `os-registry.yml`. Because `os-registry.yml` tracks installed packages only, a reserved-but-uninstalled prefix (e.g. `km-` for the not-yet-shipped km-os) is correct to be absent from `os-registry.yml` until its package ships.

## Rules

### R1 — name shape

- Every skill/command name **MUST** be lowercase kebab-case: `<prefix>-<descriptive-slug>`. (`MUST`)
- The slug **SHOULD** be a verb-or-noun phrase describing the one job, per `skill-composition.md`. (`SHOULD`)

```text
# OFF-STANDARD
cosImageGen          # camelCase, no hyphen after prefix
COS_image_gen        # uppercase + underscore
creative-image-gen   # owner spelled out instead of reserved prefix

# ON-STANDARD
cos-image-gen
ros-deep-research
bx-standards-creator
```

### R2 — OS-package tools carry their prefix

- A tool that belongs to an installable OS package **MUST** carry that package's reserved prefix. (`MUST`)
- A tool **MUST NOT** carry a prefix it does not belong to. (`MUST NOT`)

### R3 — framework families

- Cross-OS authoring/builder tools **MUST** use `bx-`. (`MUST`)
- DevOS platform tools **MUST** use `devos-` (or remain bare when no collision exists — see R4). (`MUST`)

### R4 — bare-name collision rule

- A bare (unprefixed) DevOS skill name **MUST NOT** equal any command in `.dev-os/reserved-prefixes.yml` `builtin_blocklist` (the union across all CLIs). (`MUST NOT`)
- A colliding bare name **MUST** be namespaced `devos-` (`clear` → `devos-clear`, `verify` → `devos-verify`, `review` → `devos-code-review`). (`MUST`)
- Owned-prefix tools are exempt — they already carry a namespace. (`MAY` remain as-is)

```text
# OFF-STANDARD — bare name shadows a CLI built-in, user can never reach it
verify          # collides with claude-code + codex builtins

# ON-STANDARD
devos-verify
```

### R5 — registry synchronization

- Adding or changing a prefix **MUST** update all applicable SSOT files in the same change: `reserved-prefixes.yml` `owned_prefixes` and `os-ownership-resolver.sh` `_OS_OWNERSHIP_PREFIX_MAP` (OS packages only). When the OS package is **installed**, also update `os-registry.yml` (`skill_prefix` / `command_prefix`); it tracks installed packages only, so a reserved-but-uninstalled prefix is registered in the first two files and added to `os-registry.yml` on install. (`MUST`)
- A prefix **MUST NOT** be used by any tool before it is registered. (`MUST NOT`)

### R6 — uniqueness

- A reserved prefix **MUST** map to exactly one owner. (`MUST`)
- A new OS package **MUST NOT** reuse an existing prefix or introduce an ad-hoc prefix outside the registry. (`MUST NOT`)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Bare name colliding with a CLI built-in | The CLI shadows it; the skill is unreachable | Namespace it `devos-` |
| Spelling the owner out (`creative-image-gen`) | Resolver/router key on the reserved prefix, not free text | Use `cos-image-gen` |
| Adding a prefix to one registry only | Ownership resolver and collision auditor disagree → mis-routed gaps | Update all three SSOT files together |
| Reusing a reserved prefix for a new owner | Two owners claim one namespace; routing becomes ambiguous | Register a new, unused prefix |
| Inventing an ad-hoc prefix per project | Unowned namespace escapes routing and audits | Register the prefix first, then use it |
| `bx-` tool placed in an OS-package registry map | `bx-`/`devos-` are framework-owned, not OS packages | Keep `bx-`/`devos-` in `owned_prefixes` only; resolve to `dev-os` |

## Deviation Guidance

You **MAY** leave a DevOS skill name bare (no `devos-` prefix) when its bare name does not appear in any CLI's `builtin_blocklist` and it is not an OS-package tool. When you do, you **MUST** keep the name in `DEVOS_SKILLS_INDEX` and re-run `scripts/skill-collision-audit.sh` after any blocklist bump so a future CLI built-in does not silently shadow it.

You **MAY** reserve a prefix ahead of building its tools (as `bos-` and `km-` are reserved). When you do, you **MUST** register it in the SSOT files with its intended owner so it is never reassigned.

A prefix used without a registry entry, or a registry entry changed in only one of the three files, is a defect — not a deviation.

## Profile inheritance notes

This standard lives in the base `general` profile and is standalone (no parent override). Child profiles inherit it unchanged; OS packages extend the registry, not this document.

## Named Framework Backing

- **RFC 2119 normative vocabulary** (IETF) — MUST / SHOULD / MAY / MUST NOT authority levels make each prefix rule checkable.
- **Namespacing / collision-avoidance** — the same discipline as language package namespaces and reverse-DNS identifiers: a prefix carves a private region out of a shared global name space.
- **Single Source of Truth (SSOT)** — each fact (prefix → owner) has one authoritative representation; the three registries are kept in lockstep rather than duplicated by memory.
- **Convention over Configuration** (Rails Doctrine, DHH) — the prefix is the convention that encodes ownership, so individual tools need no per-tool ownership configuration.
- **POSIX / Unix command-naming conventions** — lowercase, hyphen-separated, short command names that compose cleanly across shells and CLIs.

## Compliance Test

- [ ] Is every new tool name lowercase kebab-case in the form `<prefix>-<slug>`?
- [ ] Does every OS-package tool carry its package's reserved prefix (`cos-`, `dos-`, `ros-`, `mos-`, `bos-`, `km-`)?
- [ ] Do cross-OS builder tools use `bx-` and platform tools use `devos-`?
- [ ] Is every bare DevOS skill name absent from `.dev-os/reserved-prefixes.yml` `builtin_blocklist`?
- [ ] Is each colliding bare name namespaced `devos-`?
- [ ] Does each OS-package prefix appear in all three SSOT files (`reserved-prefixes.yml`, `os-ownership-resolver.sh`, `os-registry.yml`)?
- [ ] Does each reserved prefix map to exactly one owner?
- [ ] Was any new prefix registered before its first tool shipped?

If any check fails: rename the tool, namespace the collider, or synchronize the registries before merging.

## References

- `.dev-os/reserved-prefixes.yml` — `owned_prefixes` + per-CLI `builtin_blocklist` (SSOT for collision avoidance).
- `scripts/lib/os-ownership-resolver.sh` — `_OS_OWNERSHIP_PREFIX_MAP` (SSOT for prefix → OS-id).
- `os-registry.yml` — installed OS packages and their `skill_prefix` / `command_prefix`.
- `product/specs/2026-05-29-skill-prefix-collision-namespacing/spec.md` — origin spec for the collision-namespacing rule.
- `architecture/skill-composition.md` — skill archetypes and the one-deliverable slug rule.
- [RFC 2119 — Key words for requirement levels](https://datatracker.ietf.org/doc/html/rfc2119) — normative MUST/SHOULD/MAY vocabulary.
- [Convention over Configuration — Rails Doctrine](https://rubyonrails.org/doctrine) — conventions encode decisions so configuration is not repeated.
