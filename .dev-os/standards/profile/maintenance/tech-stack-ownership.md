<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/tech-stack-ownership.md and re-run profile-sync. -->
# Tech Stack Ownership

Canonical ownership contract for every DevOS `tech-stack` artifact.

## Ownership Matrix

| Artifact | Primary writer | Purpose | Read by |
|----------|----------------|---------|---------|
| `product/tech-stack.md` | `plan-product` | Strategic product technology decisions | Product planning workflows, humans |
| `.dev-os/config.yml` `tech_stack` | `start` | Machine-readable bootstrap metadata for framework/tool detection | `bundle-injection.sh`, canonical project context, start diagnostics |
| `.dev-os/standards/global/tech-stack.md` | `extract-standards` | Observed codebase truth extracted from the repository | Humans, standards review, AGENTS/CLAUDE standards injection |
| `.dev-os/standards/profile/tech-stack.md` | profile activation (`activate_local_profile`) | Recommended conventions from the active DevOS profile | Humans, standards review, AGENTS/CLAUDE standards injection |

## Single-Writer Rule

Each `tech-stack` path has exactly one primary writer.

- Product strategy docs are not updated by standards extraction or profile sync.
- Config metadata is not updated by standards extraction.
- Extracted standards are not overwritten by profile sync.
- Profile-synced standards are not treated as extracted project truth.

## Read/Write Split

| Surface | Writes | Reads |
|---------|--------|-------|
| `start` | `.dev-os/config.yml` `tech_stack`, `.dev-os/standards/profile/*` (via profile activation) | repo files, profile config |
| `extract-standards` | `.dev-os/standards/global/*` | repo files |
| `extract-standards --from-profile` | `.dev-os/standards/profile/*` (via profile activation) | active profile from `.dev-os/config.yml`, profile chain |
| `plan-product` | `product/tech-stack.md` | product interview input, codebase inference |
| `bundle-injection.sh` | none | `.dev-os/config.yml`, `.dev-os/standards/global/*`, `.dev-os/standards/profile/*` |

## Interpretation Guidance

- Treat `product/tech-stack.md` as strategy.
- Treat `.dev-os/config.yml` `tech_stack` as bootstrap metadata.
- Treat `.dev-os/standards/global/tech-stack.md` as observed current state.
- Treat `.dev-os/standards/profile/tech-stack.md` as recommended conventions from the chosen DevOS profile.

If both extracted and profile `tech-stack` standards exist, that is expected. They serve different purposes and must coexist without clobbering each other.

## Compliance test

- [ ] Does `product/tech-stack.md` exist and contain a date header within the last 90 days?
- [ ] Does every package in `package.json` (or `pyproject.toml`) dependencies have a corresponding entry in `product/tech-stack.md` or `.dev-os/config.yml` `tech_stack`?
- [ ] Does `command grep "tech_stack" .dev-os/config.yml` return a non-empty result (bootstrap metadata present)?

If any check fails: update `product/tech-stack.md` with the missing framework entry and date it. Undocumented dependencies are invisible to gap-analysis and will be re-flagged as gaps.
