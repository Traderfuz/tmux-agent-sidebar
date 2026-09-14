<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/product/product-doc-ownership.md and re-run profile-sync. -->
# Product Document Ownership

Canonical roles, producers, and refresh contracts for core product narrative documents.

## Ownership Table

| Document | Role | Producer Command | Refresh Contract |
|----------|------|-----------------|------------------|
| `product/mission.md` | Product identity and enduring direction | `plan-product` | Manual — updated via plan-product interview |
| `product/roadmap.md` | Strategic roadmap — major phases and milestone sequencing | `plan-product` | Manual — updated via plan-product interview |
| `product/tech-stack.md` | Technology choices, platforms, and runtime decisions | `plan-product` | Manual — updated via plan-product interview |
| `product/product-overview.md` | Current-state product narrative — what exists now vs what is planned | `docs-sync --scope product` | Tracked by context-refresh; updated via docs-sync product scope |
| `product/specs/project-roadmap.md` | Execution board — active and queued specs with sequencing | `orchestrate` | Generated on orchestrate runs |
| `product/specs/feature-backlog.md` | Status index — lifecycle state, task counts, merge position | update-backlog workflow (auto-invoked by write-spec, create-tasks, implement-tasks, merge-feature) | Auto-updated after each lifecycle transition |
| `product/specs/<spec>/planning/architecture.md` | Approved per-spec architecture blueprint — C4/Mermaid diagrams + structural decisions | `architecture-creator` via the shape-spec architecture gate | Generated on shaping when the spec is architecturally significant; gated approve/revise/skip; consumed by `create-tasks` |

## Authority Split

These three artifacts serve distinct purposes and must not be conflated:

- **`product/roadmap.md`** = strategic direction (human-authored, stable)
- **`product/specs/project-roadmap.md`** = execution board (generated, changes with each orchestrate run)
- **`product/specs/feature-backlog.md`** = status index (auto-updated, changes with each spec lifecycle event)

When reading "the roadmap," operators should consult `product/roadmap.md` for strategic context and `product/specs/project-roadmap.md` for execution state.

## WIP Classification

`product/product-overview.md` must distinguish between:

- **Implemented** — features and flows that exist in code today
- **Planned** — features described in specs but not yet built
- **User-facing truth-risk** — claims in docs or UI that do not match current implementation

This vocabulary is shared with the `ground-truth-recon` skill.

## Scaffolding

`product_ensure_structure()` in `scripts/lib/product-workspace.sh` scaffolds all four product-root docs:
- `product/mission.md`
- `product/roadmap.md`
- `product/tech-stack.md`
- `product/product-overview.md`

## Relationship to Other Systems

- **`docs-sync`** handles README, CLAUDE.md, profiles, and command parity — not product narrative docs
- **`ground-truth-recon`** detects drift and reconciles mismatches — it may recommend `docs-sync --scope product` but is not the primary producer
- **`docs-sync --scope product`** is the dedicated workflow for updating `product/product-overview.md` from implementation evidence
