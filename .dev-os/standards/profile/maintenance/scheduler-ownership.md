<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/scheduler-ownership.md and re-run profile-sync. -->
# Scheduler Ownership & Namespace Routing

## Overview

DevOS ecosystems accumulate multiple scheduler surfaces — `devos-scheduler`,
`bos-scheduler`, future spoke-OS schedulers (`mos`/`ros`/`cos`/`dos`), and
runtime platform crons (Vercel/Cloudflare/Convex/boxi-app/Postiz) — that all land
recurring jobs in one shared Hermes cron listing. Without a canonical routing
rule, jobs get filed under whatever scheduler was nearest: client reports land
under `devos:`, DevOS maintenance lands under `bos:`, and app-runtime crons get
promoted to OS jobs. Each misfile mutates state the wrong OS should never touch
and makes `hermes cron list --all` unreadable.

**Rule:** Every recurring/scheduled job is owned by the OS whose **output** it
owns, and the namespace prefix (`devos:` / `bos:` / `mos:` / `ros:` / `cos:` /
`dos:` / runtime) is the enforcement boundary. Route a job by its output owner,
never by which `cwd` happened to be active when it was authored.

This is the canonical, always-loaded distillation. Projects do not re-derive the
routing; they extend it with a project-local job catalog (see
[Project extension](#project-extension)).

## Scope

This standard covers which scheduler owns which recurring job, the namespace
enforcement boundary, and the safety defaults every registration must satisfy. It
does NOT cover the registration command shapes for a specific project's jobs
(those live in a project's registration runbook), the internals of the scheduler
helper libraries, or non-recurring one-shot task dispatch.

## Routing decision tree

Answer top-to-bottom; first match wins:

1. Job checks or regenerates DevOS artifacts, runtime state, context, gap registry, hooks, MCP, or standards → **`devos:`**.
2. Job acts on client/prospect/account delivery state, reports, health, onboarding, offboarding, QBR, or service gates → **`bos:`**.
3. Job owns marketing copy/campaign/content calendar → **`mos:`** (when Marketing OS scheduler exists).
4. Job refreshes external research/intelligence feeds → **`ros:`** (when Research OS scheduler exists).
5. Job produces/reviews creative assets → **`cos:`** (when Creative OS scheduler exists).
6. Job validates design system, visual QA, or design drift → **`dos:`** (when Design OS scheduler exists).
7. Job retries webhooks, processes queues, sends campaign messages, publishes posts, or cleans runtime DB data → **runtime platform scheduler**, not an OS scheduler.

## Ownership matrix

| OS / Scheduler | Namespace | Owns | Must not own |
|---|---|---|---|
| DevOS / `devos-scheduler` | `devos:` | platform maintenance: context refresh, DevOS doctor, runtime diagnostics, gap registry recheck, weekly/monthly Dalio reviews, artifact/contract drift, full maintenance | client delivery, public-contact sends, social posts, campaign execution, app-runtime jobs |
| Boxi Ops OS / `bos-scheduler` | `bos:` | agency operations: client health, portfolio health, client reporting, ops review, QBR prep, onboarding/offboarding reminders, service delivery checks | DevOS context refresh, spoke-OS jobs, raw app-runtime crons |
| Marketing OS / future `mos-scheduler` | `mos:` | marketing campaigns, content calendars, copy refreshes, campaign performance review, brand-voice audits | agency client health, DevOS maintenance, creative asset generation jobs |
| Research OS / future `ros-scheduler` | `ros:` | competitor/news/research refreshes, source monitoring, market intelligence updates | client delivery execution, public sends, DevOS health |
| Creative OS / future `cos-scheduler` | `cos:` | asset generation/review queues, brand asset refresh, creative campaign production cadence | scheduling posts, client health, DevOS maintenance |
| Design OS / future `dos-scheduler` | `dos:` | design QA cadence, visual regression review, design-system drift | runtime deploy crons, client reports, DevOS context |
| Runtime platform scheduler | platform-specific | product/app tasks: nightly ingest checks, cleanup jobs, webhook retries, queue workers, DB maintenance | cross-OS agent workflows or DevOS/Boxi operator jobs |

**Boundary invariants:**
- `devos-scheduler` is for DevOS platform maintenance **only** — it must never mutate client/account/service state.
- `bos-scheduler` is for agency/client operations and **must not** register spoke-OS (`mos:`/`ros:`/`cos:`/`dos:`) jobs.
- Boxi Ops OS is the hub and may *recommend* spoke-OS schedules; each spoke OS *registers* its own namespace when its scheduler helper exists.

## Quick reference — "which OS schedules this?"

| Recurring work | Owner |
|---|---|
| DevOS context refresh / doctor / drift / gap recheck / Dalio reviews | `devos:` |
| Client health, portfolio health, client reports, ops review, QBR | `bos:` |
| Marketing campaigns / content calendar / brand-voice audit | `mos:` (future) |
| Competitor / news / source-monitoring refresh | `ros:` (future) |
| Creative asset generation / review cadence | `cos:` (future) |
| Design QA / token / visual-regression drift | `dos:` (future) |
| Worker cron health, app queue workers, webhook retries, campaign sends, social publish, DB cleanup | runtime platform |

## "Wrong scheduler" anti-patterns

| Anti-pattern | Why it is wrong | Correct owner |
|---|---|---|
| Client report cron under `devos:` | DevOS must not mutate client/service state | `bos:` |
| `bos-scheduler` registers `mos:campaign-*` | hub registering a spoke namespace | Marketing OS `mos:` |
| DevOS `context-refresh` under `bos:` | platform maintenance mislabeled as agency ops | `devos:` |
| boxi-app `process-email-campaigns` campaign send | bypasses runtime send/compliance path when moved into OS cron | boxi-app `process-email-campaigns` cron (hourly) |
| Social publish as autonomous OS job | skips brand/public-contact gate | Postiz scheduler + gate |
| Global job named without workdir/project | ambiguous owner in `hermes cron list` | add `--workdir` / project-slug name |

## Safety defaults

Every OS scheduler registration must:
- Default to **paused** unless `--active` is explicitly requested.
- Include `--workdir` (project) / vault scoping where applicable.
- Use namespaced job names only (`<os>:<project-slug>:<job>` for project-scoped jobs).
- Degrade to a no-op if Hermes is absent.
- Avoid public-contact sends unless the owning OS has a brand/compliance gate.
- Emit resume instructions on registration.

## Review checklist before activating any scheduled job

- [ ] Namespace prefix matches the owning OS per the matrix.
- [ ] Job is registered paused; activation is a separate deliberate step.
- [ ] `--workdir` set (or intentionally global) and visible in `hermes cron list --all`.
- [ ] Name follows `<os>:<project-slug>:<job>` for project-scoped jobs.
- [ ] No client/service-state mutation under `devos:`.
- [ ] No spoke namespace registered by `bos-scheduler`.
- [ ] Public-contact/campaign/social jobs pass the owning OS brand/compliance gate.
- [ ] Not a runtime job that belongs in Vercel/Cloudflare/Convex/boxi-app/Postiz.

## Project extension

This standard owns the routing rule; a project owns its concrete job catalog. A
project that schedules recurring work SHOULD:

- Keep the routing rule by inheritance — do not copy this file's decision tree,
  matrix, or anti-patterns into a project-local standard. Per
  `profile-standards-inheritance.md`, a project-local scheduler standard is valid
  only as a **thin extension** (`Extends:` this standard) that adds the delta:
  the project's actual `<os>:<project-slug>:<job>` catalog and a pointer to the
  project's registration runbook.
- Record concrete registration commands (with paste-ready arguments) in a
  project registration runbook, marked plan-only until reviewed.
- Treat the always-loaded routing directive (`.dev-os/project-memory.json`) as a
  pointer to this standard, not a place to re-state the matrix.

## Compliance Test

A project/operator is compliant with this standard when:

1. **Routing is answerable cold.** A reader can answer all eight canonical routing
   questions — DevOS maintenance, client health, client reports, marketing
   campaigns, research refreshes, creative assets, design QA, runtime app crons —
   from this file alone, without opening a project spec.
2. **Every scheduled job carries an owning namespace prefix** from the matrix; no
   bare/un-prefixed OS job exists in `hermes cron list --all`.
3. **No cross-boundary jobs exist:** no client/service-state mutation under
   `devos:`, no spoke namespace (`mos:`/`ros:`/`cos:`/`dos:`) registered by
   `bos-scheduler`, no app-runtime cron promoted to an OS scheduler job.
4. **Project-scoped jobs are disambiguated** by `<os>:<project-slug>:<job>` name
   and/or `--workdir`, so ownership is unambiguous in the global cron listing.
5. **Registrations default to paused** and emit resume instructions; activation is
   a separate, reviewed step.
6. **No project-local standard duplicates this file's routing content** — a
   project scheduler standard, if present, is a thin extension carrying only the
   project job catalog.

If any check fails, the offending job is misrouted — re-route it by output owner
using the decision tree above.

## Related Standards

- `integration/integration-documentation.md` — scheduler is a named integration
  surface; a registered job is production-ready only when another operator can
  answer what owns it, how it is configured/verified, and how it is disabled
  safely. This standard supplies the ownership half of that contract.
- `profile-standards-inheritance.md` — governs the thin-extension contract
  projects use to add a job catalog without duplicating this routing rule.
- `artifact-ownership.md` — companion ownership/freshness contract for generated
  artifacts.
