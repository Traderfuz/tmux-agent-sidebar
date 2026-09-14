# Product Docs Sync Workflow

Reconcile and update core product narrative documents from implementation evidence.

> Public invocations should use `docs-sync --scope product`. The legacy
> `product-docs-sync` router phrase serves this workflow as a guide and explicit
> no-op wrapper, and runtime routing translates it to the product docs-sync scope.
> This document is the execution contract for the manual workflow until a
> dedicated product narrative runner exists.

## Scope

This workflow manages **product narrative docs only**:

- `product/product-overview.md` (primary output)
- `product/roadmap.md` (advisory updates — flag drift, do not overwrite)

It does NOT manage:
- README.md, CLAUDE.md, AGENTS.md — those belong to `docs-sync`
- Profile/command parity — that belongs to `docs-sync`
- Spec task checkboxes — those belong to `implement-tasks`

## When to Use

Invoke this workflow:
1. After a spec is merged (`merge-feature`) — to reflect new capabilities
2. After `ground-truth-recon` detects narrative drift — as the repair action
3. On-demand via `docs-sync --scope product`

Do not use to sync technical docs, command counts, or version strings — use `docs-sync` without product scope for that. Do not use to author new product strategy — use `plan-product`.

## Source-of-Truth Inputs

The workflow reads these inputs to build the current-state picture:

| Source | What it provides |
|--------|-----------------|
| `product/specs/feature-backlog.md` | Lifecycle state of all specs (completed, in-progress, planned) |
| `product/specs/*/tasks.md` | Task completion counts per spec |
| `product/specs/*/spec.md` | Feature descriptions and goals |
| Repository file structure | Actual implementation evidence (routes, components, scripts, tests) |
| `product/roadmap.md` | Strategic context and planned phases |
| `CLAUDE.md` | Architecture and integration descriptions |

## WIP Classification

Every claim in `product/product-overview.md` must be classified:

- **Implemented** — code exists, tests pass, feature is usable
- **Planned** — described in a spec but not yet built (cite the spec)
- **User-facing truth-risk** — a claim in docs or UI that does not match current implementation

## Process

### Step 1: Gather Evidence

Read the source-of-truth inputs listed above. Build a list of:
- Features that are implemented (evidence: merged specs with all tasks complete)
- Features that are planned (evidence: specs in backlog, tasks not complete)
- Claims that may be stale (evidence: product-overview says X but no matching implementation found)

### Step 2: Classify and Draft

For `product/product-overview.md`:
1. Group features by area (e.g., "Core Framework", "Commands", "Integrations")
2. Mark each with its classification: Implemented / Planned / Truth-risk
3. Include spec links where relevant

### Step 3: Diff and Apply

If `--dry-run`:
- Show planned changes as a diff summary
- Do not write any files

Otherwise:
- Write `product/product-overview.md` with the updated narrative
- If `product/roadmap.md` contains claims contradicted by implementation evidence, flag them in a comment block at the bottom rather than overwriting

### Step 4: Report

```
Product docs sync complete:
  product/product-overview.md — updated (N sections, M features classified)
  product/roadmap.md — [no changes / N drift flags added]
```

## Relationship to Other Systems

- **`docs-sync`** — handles README, CLAUDE.md, profile, and command parity. Not product narrative.
- **`ground-truth-recon`** — detects drift and reconciles mismatches. May recommend running `docs-sync --scope product` as the repair action, but is not the primary producer.
- **`plan-product`** — authors `mission.md`, `roadmap.md`, and `tech-stack.md` via guided interview. Those are strategic inputs, not current-state narrative.

## Display

Product docs sync summary:

```
Product docs synced
  mission.md:   [updated | current]
  roadmap.md:   [updated | current]
  tech-stack.md:[updated | current]
  Source:       [N] completed specs merged
```
