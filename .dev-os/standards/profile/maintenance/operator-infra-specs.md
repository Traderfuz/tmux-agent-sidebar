<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/operator-infra-specs.md and re-run profile-sync. -->
# Operator-Infra Specs Live in dev-os

**Rule:** Specs that describe machine-level operator infrastructure — anything whose implementation lives in `$HOME` (binaries, `~/.config/**`, `~/.claude/**`, systemd user units, dev-os internals) — belong in `~/projects/os/dev-os/product/specs/`, not in a product repo's `product/specs/`.

**Why:** The artifact has zero coupling to any product codebase. Filing it in a product repo (e.g. boxi, an Astro site, a Cloudflare worker) only happens because the operator's `cwd` was that repo when `/brainstorm` ran. Future-you searches for trace/collector/statusline specs in dev-os and doesn't find them. If the product repo is ever shared, the spec doesn't travel with it.

**How to apply:**

| Signal | Home |
|---|---|
| Spec describes binary install (`~/.local/bin/`), systemd unit, or other `$HOME`-scoped config | `dev-os` |
| Spec edits `~/.claude/settings.json`, `~/.claude/statusline.sh`, or anything under `~/.dev-os/scripts/` | `dev-os` |
| Spec is about telemetry collection, observability stack, agent runtime, hooks, MCP servers — anything OS-level | `dev-os` |
| Spec touches `app/`, `lib/`, project DB schema, project routes/components | the **product** repo |
| Spec is a cross-cutting workflow/process/standard for DevOS itself | `dev-os` (`product/specs/` or `profiles/<p>/standards/`) |

**Decision gate at brainstorm time:** before `write-spec` writes the file, ask "if I checkout this product repo on a fresh machine, does this spec apply?" If no → spec belongs in dev-os.

**Migration of existing misfiled specs:** copy spec + gap-analysis report + relevant `gap-registry.jsonl` rows to `~/projects/os/dev-os/product/`, drop them from the product repo, delete the product-repo branch if it only carried this work. Reference the move in the dev-os commit body (`originally written in <product-repo>; moved per maintenance/operator-infra-specs.md`).

**Note (forward-only):** historical operator-infra specs already merged into product repos are not retroactively moved. The convention applies to new specs from the date this standard lands.
