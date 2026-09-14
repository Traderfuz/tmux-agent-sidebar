<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/cross-cli-fix-propagation.md and re-run profile-sync. -->
# Cross-CLI Fix Propagation Standard

## Overview

A fix applied to one CLI integration is not complete until it has been audited and applied across every CLI in that feature's `applies_to` set. DevOS supports multiple CLI targets — Claude Code, Codex, Pi, Kimi, Gemini, OpenCode, and others — through a shared registry (`hook-registry.yml`, `integrations/`) that declares which targets each primitive touches. When a bug or behavioral drift exists in one target, the same root cause almost always exists in the others because they share implementation logic. Fixing one and deferring the rest creates silent drift that compounds across sessions.

This standard was formalized from the 2026-06-17 SIGTTIN incident: `session-start-health-gate.sh` was initially identified as the suspension cause for Pi. Systematic audit revealed 6 additional hooks with the identical unguarded `read` pattern — all registered for codex and pi via `applies_to`. The fix was incomplete until all 7 hooks were addressed in the same session.

## Scope

This standard covers the required audit, propagation, and verification of bug fixes, behavioral changes, and structural improvements across all CLIs listed in the `applies_to` arrays of `hook-registry.yml` and equivalent per-integration registries.

It applies to **all DevOS-compatible OS packages**: dev-os, marketing-os, creative-os, research-os, design-os, km-os, boxi-ops-os, and any OS added in the future. A hook or script that runs across CLIs in one OS must be audited and fixed across CLIs in every OS that ships the same primitive. Cross-OS propagation follows the same blast-radius logic as cross-CLI propagation: the `applies_to` array is the authoritative set, not the OS where the symptom was reported.

It does NOT cover intentional per-CLI feature divergence (e.g., a hook that is only meaningful for Claude Code's session model and explicitly absent from `applies_to` for other CLIs), CLI-specific extension authoring, or initial feature design decisions.

## Principles

1. **The `applies_to` array is the blast radius.** Before closing any fix, read the registry entry for every artifact touched. Every CLI in `applies_to` is in scope for the same audit.
2. **Root causes replicate across targets.** When CLIs share source hooks or library logic, a bug in the shared surface reproduces on every target that runs it. Never assume a bug is CLI-specific without checking the registry.
3. **A fix is a transaction, not a patch.** All CLIs in `applies_to` are fixed in the same commit. Staged deferral ("I'll get to codex later") is not a valid state — it is an open gap.
4. **Stale CLI surfaces are technical debt.** An unfixed CLI surface diverges silently. The longer it runs unfixed, the harder it is to verify whether it was intentional drift or missed propagation.
5. **Install regenerates; scripts propagate.** Changes to hook scripts are live immediately (via the `~/.dev-os` symlink). Changes to which hooks fire require `install.sh` to regenerate the CLI-specific config files (`hooks.json`, `hooks.yaml`).

## Rules

### Rule 1: Identify the `applies_to` set before implementing a fix

Before writing any change to a shared hook, script, or library function, read the registry:

```bash
# Find all hooks that apply to codex or pi
grep -A5 "name: my-hook.sh" ~/.dev-os/scripts/sync/hook-registry.yml | grep "applies_to"
# Or: scan for the unguarded pattern across all hooks that apply to a given CLI
grep -rn "my-bug-pattern" ~/.dev-os/scripts/hooks/*.sh \
  | while read -r match; do
      hook=$(basename "${match%%:*}")
      grep -A10 "name: $hook" ~/.dev-os/scripts/sync/hook-registry.yml | grep "applies_to"
    done
```

**OFF-STANDARD:** Fix the specific hook that was reported and move on.  
**ON-STANDARD:** Grep for the same pattern across all hooks. Check `applies_to` for each match. Fix all of them.

### Rule 2: Audit all matches, not just the reported one

When a bug pattern is found in one hook, run a full scan for the same pattern across all hooks registered for the affected CLI before writing any fix:

```bash
# Example: find all unguarded top-level stdin reads in hooks registered for pi
grep -rn "^IFS= read\|^read -r -t.*stdin" ~/.dev-os/scripts/hooks/*.sh

# Then cross-reference against the registry to confirm applies_to
python3 -c "
import re, pathlib
registry = pathlib.Path('~/.dev-os/scripts/sync/hook-registry.yml').expanduser().read_text()
# ... emit applies_to for each matched hook name
"
```

### Rule 3: Apply the fix to all affected CLIs in the same session

All CLIs in the `applies_to` set for every affected hook receive the fix before the session ends. The commit message names the full set:

```
# OFF-STANDARD commit message
fix(hooks): guard health gate stdin read for pi

# ON-STANDARD commit message
fix(hooks): guard stdin reads against SIGTTIN on codex/pi

Hooks touched: session-start-health-gate (pi+codex),
session-end-crash-marker-cleanup (pi+codex),
session-start-mcp-guard, session-start-mcp-drift-guard,
session-start-crash-detect, session-start-orphan-scan,
session-start-staleness-check, session-start-orca-detect (codex)
```

### Rule 4: Run install.sh when config files (not just scripts) change

Editing a hook script: live immediately, no install needed (symlink path).  
Changing which hooks fire (adding, removing, renaming entries in `hook-registry.yml`): run `install.sh --clients all` to regenerate `~/.codex/hooks.json`, `~/.pi/agent/hook/hooks.yaml`, and `~/.claude/settings.json`.

```bash
# After any registry change
bash ~/.dev-os/scripts/install.sh --clients all
```

### Rule 5: Stale-hook pruning is mandatory on install

`install.sh` MUST run the stale-hook prune pass for each target before re-registration. Hook entries that are no longer in the registry must be removed, not left to accumulate. Confirm the prune log shows "none found" or explicitly lists what was removed.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Fix the reported hook only | The same pattern exists in sibling hooks. The bug recurs on the next session for the other CLIs. | Grep for the pattern; check `applies_to` for every match; fix all in the same session. |
| "I'll fix codex later" deferred commit | Creates an explicit open gap that will be forgotten. There is no "later" gate. | One fix, all CLIs, one commit. |
| Assuming a bug is Claude-only | Hook scripts run on every CLI in `applies_to`. A read-from-TTY bug doesn't care which CLI triggered the session. | Check `applies_to` first. |
| Checking `applies_to` after writing the fix | You may have scoped the fix incorrectly. The registry is the blast radius, not the symptom. | Read `applies_to` before writing a single line of fix code. |
| Running `install.sh` for only one CLI | `--cli claude` updates `settings.json` but leaves `hooks.json` and `hooks.yaml` stale. | Use `--clients all` or verify each target explicitly. |

## Deviation guidance

A fix MAY be applied to a subset of CLIs when: the `applies_to` array for the affected hook explicitly excludes the other CLIs, AND the exclusion is intentional and documented in the registry. When this is the case: the commit message MUST state which CLIs were excluded and why. Do NOT omit CLIs from `applies_to` as a workaround to avoid propagating a fix.

## Compliance test

- [ ] Before implementing the fix: was the `applies_to` set for every affected artifact read from the registry?
- [ ] Was a grep-scan run for the bug pattern across all hooks, not just the reported one?
- [ ] Every CLI in every affected `applies_to` array was audited for the same root cause?
- [ ] The fix was applied to all affected CLIs in the same session and committed together?
- [ ] `install.sh --clients all` was run if any registry entry (not just script content) changed?
- [ ] The stale-hook prune log was reviewed for each CLI target?
- [ ] The commit message names the full set of hooks and CLIs touched?

If any check fails: the fix is incomplete. Extend the current session to close the remaining CLIs before committing.

## References

- [Fowler — Shotgun Surgery (Refactoring)](https://refactoring.guru/smells/shotgun-surgery) — the anti-pattern this standard reverses: a single logical change that must be made in many places. Here: identify all the places first, then make the change atomically.
- [IETF RFC 1958 — Architectural Principles of the Internet](https://datatracker.ietf.org/doc/html/rfc1958) — interoperability requires testing across all implementations, not just the reference one.
- `scripts/sync/hook-registry.yml` — canonical `applies_to` registry. The authority for which CLIs own a hook.
- `scripts/lib/hook-settings-prune.py` — stale-hook prune implementation for Claude Code settings.json.
- `scripts/lib/integrations/codex.sh` — codex integration with stale-hook logging.
- `scripts/lib/hook-registry-multi-cli.sh` — pi integration with stale-hook logging.
