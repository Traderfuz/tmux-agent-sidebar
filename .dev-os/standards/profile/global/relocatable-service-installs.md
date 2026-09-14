<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/relocatable-service-installs.md and re-run profile-sync. -->
# Relocatable Service Installs Standards

## Overview

This standard governs how service-managed, self-hosted installs (CI runners, daemons, standalone toolchains) are laid out on disk and referenced by their launch units. It exists because the 2026-08-28 boxi runner outage showed the real cost of non-relocatable layout: an `mv` broke boot, the unit retried 203/EXEC on every start, and systemd degraded until a human traced symlinks by hand.

## Scope

This standard covers on-disk layout of service-managed installs and the unit files that launch them. It does NOT cover systemd unit syntax generally or paths owned by a package manager.

## Principles

1. **Move-safety:** An install directory survives `mv` to a new parent with zero file edits.
2. **The directory is the truth:** The live install path is the single source of location; launch units are derived from it at install time, never maintained by hand afterward.
3. **Reference what you own relatively, what you don't absolutely:** Paths inside the install tree are relative; paths outside it are absolute and counted as external dependencies.

## Rules

### Internal references

- **All symlinks inside an install directory MUST use relative targets** (`MUST`)

```bash
# OFF-STANDARD (what broke the runner)
ln -sfn /home/tafadzwa/actions-runner-boxi/bin.2.336.0 bin
# After mv: dangling; systemd fails 203/EXEC every boot

# ON-STANDARD
cd /home/tafadzwa/services/actions-runner-boxi
ln -sfn bin.2.336.0 bin
ln -sfn externals.2.336.0 externals
# Survives any mv of the parent directory
```

### Unit files

- **ExecStart/WorkingDirectory MUST be generated from the live path at install time and MUST be regenerated after any move** (`MUST`). systemd requires absolute paths in `ExecStart` (systemd.exec(5)) — so the unit is the one legitimate absolute reference, and it must be derived, not hand-maintained:

```bash
# OFF-STANDARD
sudo sed -i 's|old-runner-path|newer-runner-path|' /etc/systemd/system/runner.service  # by memory, later

# ON-STANDARD — immediately after any mv of the install dir
sudo cp /etc/systemd/system/runner.service /etc/systemd/system/runner.service.bak.$(date +%s)
sudo sed -i "s|$(readlink -f "$OLD")|$PWD|g" /etc/systemd/system/runner.service
sudo systemctl daemon-reload && sudo systemctl restart runner.service
systemctl is-active runner.service   # gate: must print "active"
```

### Post-move verification

- **A move is not done until the primary binary executes and the unit reaches `active`** (`MUST`):

```bash
test -x ./bin/<primary-binary> && echo binary-ok
systemctl is-active <unit>
```

- **A retired install MUST have its unit disabled, not left enabled-and-failing** (`MUST`).

### Install location

- **Long-lived service installs SHOULD live in one canonical root** (for example `$HOME/services/<name>` or `/opt/<name>`), not loose `$HOME/<name>` directories (`SHOULD`).
- **Versioned subdirectories MAY be kept** (`bin.2.336.0`) with the version-symlink pattern above.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Absolute internal symlinks | Any `mv` dangles them; failures surface only at next boot | Relative targets inside the tree |
| Hand-editing unit paths months later | Path drift between memory and reality; easy to miss `daemon-reload` | Regenerate/repoint immediately after the move, with backup |
| Leaving an enabled unit pointing at a removed path | systemd retries every boot forever; masks real failures | `systemctl disable --now` on retirement |
| Moving an install without post-move verification | Breakage discovered at the worst time | `test -x` + `is-active` gate before declaring done |

## Deviation guidance

You MAY use absolute internal symlinks when the target genuinely lives outside the install tree (a shared cache, a site-wide runtime). When you do: record the external dependency in the install directory's README or `.service` notes so any future move re-checks it.

## Compliance test

- [ ] Does `find <install-dir> -type l -lname '/*'` return nothing (no absolute-target symlinks inside the tree)?
- [ ] Does the unit's `ExecStart` path exist on disk right now?
- [ ] Is the unit's `WorkingDirectory` the parent of the `ExecStart` binary?
- [ ] Does `test -x <install-dir>/bin/<primary-binary>` succeed?
- [ ] After any move, did `systemctl is-active <unit>` print `active` before the task was declared done?

If any check fails: fix the symlink or unit reference before finishing the move; if the install is retired instead, disable the unit and record that decision.

## References

- `$ORIGIN`-relative runpath, ld.so(8) `dt_runpath` — the dynamic linker's canonical relocatable-reference mechanism; same principle applied to symlinks.
- systemd.exec(5) — why `ExecStart` must stay absolute and therefore generated, not hand-edited.
- Arch Linux wiki: systemd service path requirements — practitioner confirmation of the absolute-path constraint.
