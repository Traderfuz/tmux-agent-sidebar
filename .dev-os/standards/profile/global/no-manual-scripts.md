<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/no-manual-scripts.md and re-run profile-sync. -->
# No Manual Scripts

## Overview

Operators invoke skills, not scripts. Every user-facing `.sh` script in an installable OS package or DevOS itself must have a corresponding skill entry that routes to it. The skill is the interface; the script is the implementation. An operator should never have to remember or type a script path to access a capability.

## Scope

This standard covers user-facing shell scripts in installable OS packages (`scripts/*.sh`) and DevOS core (`~/.dev-os/scripts/*.sh`). It does NOT cover internal library scripts (`scripts/lib/*.sh`), test helpers (`tests/`), build/CI scripts, hooks, or registry generators that run as part of automated pipelines.

## Principles

1. **Skills are the public surface:** A skill's `SKILL.md` is the operator-facing contract. Scripts are implementation details behind that contract. Operators discover capabilities through skill descriptions and trigger phrases, not by browsing `scripts/` directories.
2. **Zero path memorization:** If an operator must remember `bash scripts/client-workspace-scaffold.sh --slug acme --boxi-root ~/agency` to use a capability, the capability is not discoverable. A skill entry like `bos-start-here` WORKSPACE intent absorbs that path and presents a confirmation-gated invocation.
3. **Scripts serve skills, not the reverse:** A script that has no skill routing it is either an internal helper (belongs in `scripts/lib/`) or a missing skill entry. There is no third category for "user-facing script without a skill."

## Rules

### Rule 1 - Every user-facing script MUST have a skill entry

A script in `scripts/*.sh` that an operator would invoke directly must be routable through at least one skill in `profiles/*/skills/`. The skill may invoke the script itself (orchestrator pattern) or instruct the operator to run it with pre-filled arguments (plan-only pattern).

```
# OFF-STANDARD - operator must know and type the script path
bash scripts/client-workspace-scaffold.sh --slug acme-plumbing --boxi-root ~/projects/agency

# ON-STANDARD - skill absorbs the script path; operator says "create the client workspace"
# bos-start-here WORKSPACE intent runs the scaffold with confirmation gating
```

### Rule 2 - Internal scripts MUST live in `scripts/lib/`

Scripts that are sourced by other scripts, called by hooks, or run as part of automated pipelines are internal. They belong in `scripts/lib/`, not `scripts/`. The `scripts/` root is the user-facing surface; `scripts/lib/` is the internal surface.

```
# OFF-STANDARD - helper script at user-facing level
scripts/config-read.sh        # sourced by other scripts, never invoked by operator

# ON-STANDARD - helper script in lib/
scripts/lib/config-read.sh    # clearly internal
```

### Rule 3 - Skill entries MUST include trigger phrases that match the script's purpose

The skill's `description:` frontmatter must contain trigger phrases an operator would naturally use when they need the script's capability. If the operator would say "scaffold the client workspace," that phrase must appear in the routing skill's description.

### Rule 4 - Maintenance and verification scripts route through orchestrator skills

Scripts like `verify-all.sh`, `repair-orphans.sh`, and `update-all-projects.sh` route through ops-category skills (`bos-doctor`, `bos-ops-review`, or the entry-point orchestrator). The orchestrator decides when to invoke them, not the operator.

### Rule 5 - New scripts require a skill routing plan before merge

When adding a new user-facing script, the PR or spec must name which skill will route to it. "Add skill entry later" is a deferred gap, not a plan. The script and its skill entry ship together or the script ships as `scripts/lib/` (internal).

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Documenting script paths in README for operator use | Operator must find, read, and remember the path | Create a skill entry; README references the skill name |
| User-facing script in `scripts/` with no skill | Capability is invisible to skill discovery | Add skill entry or move to `scripts/lib/` if internal |
| Skill that says "run `bash scripts/foo.sh`" in output | Operator still types a path | Skill invokes the script itself or uses plan-only with pre-filled command |
| "We'll add the skill entry in a later PR" | The script ships undiscoverable; the skill entry never arrives | Ship together or defer the script |

## Deviation guidance

You MAY leave a script at `scripts/` without a skill entry when ALL of these hold: (1) the script is used exclusively by CI/CD or automated hooks, (2) no operator would ever invoke it interactively, and (3) the script's header comment documents why it has no skill entry. When you deviate, record the reason in the script's header and in the OS's gap registry if one exists.

## Classification guide

| Script location | Category | Skill entry required? |
|---|---|---|
| `scripts/*.sh` (operator would invoke) | User-facing | Yes - route through a skill |
| `scripts/*.sh` (CI/hook/pipeline only) | Automation | No - document in header |
| `scripts/lib/*.sh` | Internal helper | No - sourced, never invoked directly |
| `tests/*.sh`, `tests/bats/*.bats` | Test infrastructure | No |
| `scripts/hooks/*.sh` | Hook handler | No - invoked by hook system |

## Compliance test

- [ ] Every `scripts/*.sh` file that an operator would invoke has at least one skill in `profiles/*/skills/` that routes to it?
- [ ] No skill output asks the operator to type a raw `bash scripts/...` path without pre-filling the arguments?
- [ ] Internal-only scripts live in `scripts/lib/`, not `scripts/`?
- [ ] New script PRs name the routing skill before merge?
- [ ] Scripts with no skill entry have a header comment documenting why (CI-only, hook-only, etc.)?

If any check fails: add the skill entry, move the script to `scripts/lib/`, or document the deviation in the script header.

## References

- Convention over Configuration (Rails Doctrine, DHH 2004) - sensible defaults handle common cases; the skill is the default interface, the script path is the unconventional alternative
- Facade Pattern (GoF, Gamma et al. 1994) - the skill provides a simplified interface to the script's underlying complexity
- ADR-0004 (Boxi Ops OS) - client workspace topology already exemplifies this: `client-workspace-scaffold.sh` is invoked through the `bos-start-here` WORKSPACE orchestrator, never typed directly
