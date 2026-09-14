<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/canonical-locations.md and re-run profile-sync. -->
---
title: Canonical Filesystem Locations Standard
version: 1.1.0
status: Accepted
---

# Canonical Filesystem Locations Standard

## Purpose

This standard is the single source of truth for DevOS canonical filesystem locations. Any DevOS surface that creates, resolves, stores, or documents filesystem paths MUST resolve through the documented resolver for that location category. Scripts, skills, chains, agents, docs, and generated examples MUST NOT hardcode replaceable location policy.

This standard applies the RFC 2119 normative vocabulary model: **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** carry their RFC 2119 meanings. It also applies convention-over-configuration: each location has one default, one resolver path, and explicit override points.

## Scope

This standard covers canonical DevOS filesystem location resolution. It does NOT cover non-filesystem service identifiers, network endpoints, credentials, or deployment target naming.

## Principles

1. **Resolve once, reuse everywhere:** Path-creating code MUST call the category resolver instead of reconstructing the same path manually.
2. **Environment before defaults:** Environment variables and config keys MUST be honored before fallback defaults.
3. **Nested ownership:** Generated workspaces MUST group derived state under the owning project or OS, not flatten names into ambiguous siblings.
4. **Examples are contracts:** Skill examples, chain examples, and docs MUST show canonical paths because operators copy them into real workflows.
5. **Change by resolver:** Changing a canonical location SHOULD require updating the resolver or this standard, not hunting path literals across scripts.

## Resolver Table

| Location category | Canonical pattern | Environment variable | Config key | Default value | Source of truth |
|---|---|---|---|---|---|
| Worktree locations | `<workspace-root>/<project>/<slug>` | `DEVOS_WORKSPACE_ROOT` | `.dev-os/config.yml` `worktrees.workspace_root` | `$HOME/projects/workspaces` | `worktree_canonical_path()` in `scripts/lib/worktree-manager.sh` |
| DevOS install location | `$DEVOS_DIR` | `DEVOS_DIR` | None | `$HOME/.dev-os` symlink to source | DevOS shell/runtime bootstrap; scripts MUST use `${DEVOS_DIR:-$HOME/.dev-os}` |
| OS package locations | `$OS_WORKSPACE_ROOT/<os-name>/` | `OS_WORKSPACE_ROOT` | None | `$HOME/projects/os/<os-name>/` | `OS_WORKSPACE_ROOT` in `scripts/lib/skills-sync.sh` |
| Project scan locations | `$PROJECT_SCAN_ROOT/` | `PROJECT_SCAN_ROOT` | None | `$HOME/projects/` | Portfolio/project scanning scripts that read `$PROJECT_SCAN_ROOT` |
| Portfolio registry | `~/.dev-os/portfolio.yml` | `DEVOS_DIR` for install root | None | `${DEVOS_DIR:-$HOME/.dev-os}/portfolio.yml` | Portfolio skill and registry readers |
| Runtime state | Resolver-returned path | Resolver-dependent | Resolver-dependent | Resolver-dependent | `devos_runtime_path` / `devos_runtime_existing_path` in `scripts/lib/runtime-state.sh` |
| Skills — global | `$HOME/.claude/skills/<name>/SKILL.md` | `HOME` | None | `$HOME/.claude/skills/<name>/SKILL.md` | Claude skills loader and DevOS skill sync surfaces |
| Skills — project-local | `.claude/skills/<name>/SKILL.md` | Project cwd | None | `.claude/skills/<name>/SKILL.md` | Project-local skill loader |
| Skills — OS source | `$OS_WORKSPACE_ROOT/<os>/profiles/<profile>/skills/<name>/SKILL.md` | `OS_WORKSPACE_ROOT` | None | `$HOME/projects/os/<os>/profiles/<profile>/skills/<name>/SKILL.md` | OS profile source tree and skills sync |
| Standards — profile source | `profiles/<profile>/standards/<category>/` | None | None | `$DEVOS_DIR/profiles/general/standards/<category>/` | `activate_local_profile()` in `scripts/lib/profile-distribution.sh` |
| Standards — project mirror | `.dev-os/standards/profile/<category>/` | Project cwd | None | `.dev-os/standards/profile/` | Profile standards sync (cleaned and re-copied on each sync) |
| Standards — project-owned global | `.dev-os/standards/global/` | Project cwd | None | `.dev-os/standards/global/` | Project extraction layer (preserved by profile sync) |
| Tools/scripts | `${DEVOS_TOOLS_DIR:-$HOME/.dev-os/tools}/` | `DEVOS_TOOLS_DIR` | None | `$HOME/.dev-os/tools/` | Tool installer and launcher scripts |
| Session scripts | `${DEVOS_TOOLS_DIR}/worktree-sessions/<name>.sh` | `DEVOS_TOOLS_DIR` | None | `$HOME/.dev-os/tools/worktree-sessions/<name>.sh` | Worktree session launcher scripts |

## Worktree Locations

Worktree paths MUST use the nested canonical pattern:

```text
<workspace-root>/<project>/<slug>
```

The `<workspace-root>` value MUST resolve in this order:

1. `DEVOS_WORKSPACE_ROOT`
2. `.dev-os/config.yml` key `worktrees.workspace_root`
3. `$HOME/projects/workspaces`

The source of truth is `worktree_canonical_path()` in `scripts/lib/worktree-manager.sh`. Any code that creates, checks, opens, or documents a DevOS worktree path MUST route through that function or through a wrapper that delegates to it. Integrations that create worktree-backed artifacts MUST NOT reconstruct worktree paths independently.

ON-STANDARD:

```text
<workspace-root>/myapp/variant-minimal
<workspace-root>/boxi-app-supabase/fix-auth-callback
```

OFF-STANDARD:

```text
<workspace-root>/myapp-variant-minimal
../myapp-variant-minimal
../boxi-app-supabase-fix-auth-callback
```

Flat worktree paths are off-standard because they lose the owning project boundary, collide across projects with similar slugs, and make cleanup/audit tooling infer ownership from string parsing. Sibling `../<repo>-<slug>` worktree creation is off-standard because it bypasses workspace-root policy entirely.

## DevOS Install Location

DevOS install paths MUST resolve through `$DEVOS_DIR` with fallback to `$HOME/.dev-os`:

```sh
${DEVOS_DIR:-$HOME/.dev-os}
```

Scripts MUST NOT hardcode `~/.dev-os` or `$HOME/.dev-os` directly when referring to the DevOS install root. The fallback MAY appear only as part of the resolver expression above or a shared helper that implements the same contract.

The default `$HOME/.dev-os` path is treated as an install symlink to source. Code MUST assume operators can relocate the install by setting `DEVOS_DIR`.

ON-STANDARD:

```sh
DEVOS_ROOT="${DEVOS_DIR:-$HOME/.dev-os}"
"$DEVOS_ROOT/scripts/lib/runtime-state.sh"
```

OFF-STANDARD:

```sh
~/.dev-os/scripts/lib/runtime-state.sh
$HOME/.dev-os/scripts/lib/runtime-state.sh
```

## OS Package Locations

OS package source locations MUST use this pattern:

```text
$OS_WORKSPACE_ROOT/<os-name>/
```

When `OS_WORKSPACE_ROOT` is unset, the default is:

```text
$HOME/projects/os/<os-name>/
```

The source of truth is the `OS_WORKSPACE_ROOT` handling in `scripts/lib/skills-sync.sh`. Scripts that sync skills, profiles, standards, commands, chains, or OS package artifacts MUST use `$OS_WORKSPACE_ROOT` rather than hardcoding `$HOME/projects/os`.

ON-STANDARD:

```text
$OS_WORKSPACE_ROOT/dev-os/
$OS_WORKSPACE_ROOT/marketing-os/
$OS_WORKSPACE_ROOT/creative-os/
```

OFF-STANDARD:

```text
$HOME/projects/os/dev-os/
~/projects/os/dev-os/
```

The default path MAY appear in documentation as a fallback value, but executable code SHOULD express it through the resolver variable.

## Project Locations

Project scanning MUST use:

```text
$PROJECT_SCAN_ROOT/
```

When `PROJECT_SCAN_ROOT` is unset, the default is:

```text
$HOME/projects/
```

Project-discovery code MUST NOT assume every operator keeps projects directly under `$HOME/projects` unless it is implementing the fallback. Portfolio-aware workflows SHOULD read the portfolio registry:

```text
${DEVOS_DIR:-$HOME/.dev-os}/portfolio.yml
```

Documentation MAY refer to the user-facing path `~/.dev-os/portfolio.yml`, but scripts MUST resolve it through `${DEVOS_DIR:-$HOME/.dev-os}/portfolio.yml`.

## Runtime State

Runtime state paths MUST resolve through:

```sh
devos_runtime_path
devos_runtime_existing_path
```

The source of truth is:

```text
scripts/lib/runtime-state.sh
```

Scripts MUST NOT hardcode runtime-state files such as:

```text
product/inbox.jsonl
.devos/runtime/*.json
.dev-os/runtime/*.json
```

Runtime paths are intentionally resolver-owned because state may live in project-local directories, DevOS runtime directories, recovery directories, or compatibility locations. Callers MUST ask the resolver for the right path rather than assuming layout.

ON-STANDARD:

```sh
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/runtime-state.sh"
inbox_path="$(devos_runtime_path inbox)"
state_path="$(devos_runtime_existing_path session-state)"
```

OFF-STANDARD:

```sh
inbox_path="product/inbox.jsonl"
state_path=".dev-os/runtime/session-state.json"
```

## Skills Location

Skill paths have three canonical layers:

| Layer | Pattern | Rule |
|---|---|---|
| Global | `$HOME/.claude/skills/<name>/SKILL.md` | Global installed skill visible across sessions |
| Project-local | `.claude/skills/<name>/SKILL.md` | Project override or project-specific skill |
| OS source | `$OS_WORKSPACE_ROOT/<os>/profiles/<profile>/skills/<name>/SKILL.md` | Source package skill copied/synced into installed layers |

Tools that read or write skills MUST know which layer they are operating on. Sync tooling MUST treat OS source as source-owned and installed global/project-local paths as distribution targets unless the command explicitly edits a local override.

Skill examples that mention worktree paths MUST use the canonical nested worktree pattern:

```text
<workspace-root>/<project>/<slug>
```

They MUST NOT show flat examples such as:

```text
<workspace-root>/<project>-<slug>
```

## Standards Location

Standard paths have three canonical layers:

| Layer | Pattern | Rule |
|---|---|---|
| Profile source | `profiles/<profile>/standards/<category>/*.md` | Source of truth. Sync propagates these into every project activating the profile. The `global` category holds cross-project standards. |
| Project mirror | `.dev-os/standards/profile/<category>/` | Sync-owned copy; cleaned and re-copied on each sync, user edits preserved to `.conflicts/`. This is the layer injection and standards-guide read. |
| Project-owned global | `.dev-os/standards/global/` | Project-extracted standards; preserved by profile sync and excluded from drift management. |

Standards MUST be authored in the profile source (`profiles/<profile>/standards/`); the project mirror is generated and MUST NOT be hand-edited. Scripts MUST resolve the sync through `activate_local_profile()` in `scripts/lib/profile-distribution.sh` rather than copying standards independently.

Project-local standards SHOULD extend or override source standards rather than duplicate them wholesale.

## Tools and Scripts Location

Tool and generated-script paths MUST resolve through:

```sh
${DEVOS_TOOLS_DIR:-$HOME/.dev-os/tools}/
```

Session scripts created by worktree/session tooling MUST use:

```text
${DEVOS_TOOLS_DIR}/worktree-sessions/<name>.sh
```

Code that writes tools or session launchers MUST honor `DEVOS_TOOLS_DIR`. The `$HOME/.dev-os/tools` default MAY appear only as a fallback value.

ON-STANDARD:

```sh
TOOLS_DIR="${DEVOS_TOOLS_DIR:-$HOME/.dev-os/tools}"
session_script="$TOOLS_DIR/worktree-sessions/${name}.sh"
```

OFF-STANDARD:

```sh
session_script="$HOME/.dev-os/tools/worktree-sessions/${name}.sh"
```

## Anti-patterns

| Anti-pattern | OFF-STANDARD example | Why it fails | Correct alternative |
|---|---|---|---|
| Flat worktree path | `<workspace-root>/myapp-variant-minimal` | Loses project ownership boundary and collides across projects | `<workspace-root>/myapp/variant-minimal` |
| Sibling worktree creation | `../repo-slug` or `../myapp-variant-minimal` | Bypasses workspace-root resolver and scatters generated worktrees | `worktree_canonical_path "$project" "$slug"` |
| Hardcoded DevOS install root | `~/.dev-os/scripts/foo.sh` | Ignores relocated installs and symlink policy | `${DEVOS_DIR:-$HOME/.dev-os}/scripts/foo.sh` |
| Hardcoded runtime inbox | `product/inbox.jsonl` | Ignores runtime resolver and compatibility paths | `devos_runtime_path inbox` |
| Hardcoded runtime JSON | `.dev-os/runtime/session.json` | Couples callers to one state layout | `devos_runtime_path` / `devos_runtime_existing_path` |
| Hardcoded OS source root | `$HOME/projects/os/dev-os` | Ignores custom OS workspaces | `$OS_WORKSPACE_ROOT/dev-os` with fallback resolver |
| Hardcoded project scan root | `$HOME/projects` | Misses operators using different project roots | `$PROJECT_SCAN_ROOT` with `$HOME/projects` fallback |
| Skill docs using flat worktrees | `<workspace-root>/<project>-<slug>` | Teaches off-standard path creation | `<workspace-root>/<project>/<slug>` |
| Tools bypassing `DEVOS_TOOLS_DIR` | `$HOME/.dev-os/tools/worktree-sessions/x.sh` | Breaks relocated tool stores | `${DEVOS_TOOLS_DIR:-$HOME/.dev-os/tools}/worktree-sessions/x.sh` |

## Deviation Guidance

A surface MAY deviate from this standard only when interoperating with a legacy path that already exists and cannot be moved in the same change. When deviating, the surface MUST:

1. Prefer the canonical resolver first.
2. Fall back to the legacy path only through an `existing_path` compatibility helper where available.
3. Record why the legacy fallback still exists.
4. Include a migration path that removes the fallback.

New code MUST NOT introduce new legacy path shapes.

## Compliance Test

- [ ] **CL1:** Worktree-creating code routes through `worktree_canonical_path()` or a wrapper that delegates to it.
- [ ] **CL2:** No script hardcodes `~/.dev-os` or `$HOME/.dev-os` without a `${DEVOS_DIR:-$HOME/.dev-os}` fallback or equivalent shared resolver.
- [ ] **CL3:** OS package paths use `$OS_WORKSPACE_ROOT` and document `$HOME/projects/os/<os-name>/` only as the fallback default.
- [ ] **CL4:** Runtime state paths resolve via `devos_runtime_path` or `devos_runtime_existing_path`.
- [ ] **CL5:** Skill examples use nested `<workspace-root>/<project>/<slug>` worktree paths.
- [ ] **CL6:** Skills, chains, scripts, and docs contain no sibling `../<repo>-<slug>` worktree creation examples.
- [ ] **CL7:** Project scanning code uses `$PROJECT_SCAN_ROOT` before the `$HOME/projects/` fallback.
- [ ] **CL8:** Portfolio registry access resolves through `${DEVOS_DIR:-$HOME/.dev-os}/portfolio.yml` in executable code.
- [ ] **CL9:** Tool/session script writers honor `${DEVOS_TOOLS_DIR:-$HOME/.dev-os/tools}`.
- [ ] **CL10:** Standards-layer code distinguishes global, profile, and project-local standards paths instead of treating them as interchangeable.
- [ ] **CL11:** Skill-layer code distinguishes global, project-local, and OS source skill paths instead of writing to whichever file appears first.
- [ ] **CL12:** Documentation tables include the env var, config key where applicable, default value, and source-of-truth resolver for every canonical location category they describe.
- [ ] **CL13:** New path examples keep placeholders such as `<workspace-root>` intact while changing only the canonical nesting shape.
- [ ] **CL14:** Any legacy path fallback has an explicit comment or note explaining why it exists and how it will be removed.

If any compliance check fails, fix the path usage or record a time-bounded deviation that names the resolver gap. Do not add more callsites to an off-standard path while a deviation exists.

## References

- RFC 2119 normative vocabulary — defines MUST, SHOULD, MAY, and related compliance language.
- Convention over Configuration — establishes one expected default with explicit override points.
- DevOS `scripts/lib/worktree-manager.sh` — source of truth for `worktree_canonical_path()`.
- DevOS `scripts/lib/runtime-state.sh` — source of truth for runtime state path resolution.
- DevOS `scripts/lib/profile-distribution.sh` — source of truth for standards sync via `activate_local_profile()`.
