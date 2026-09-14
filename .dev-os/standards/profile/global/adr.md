<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/adr.md and re-run profile-sync. -->
# Architecture Decision Record (ADR) Standard

## Purpose

Architectural and tooling decisions decay in value the moment the reasoning behind them is lost. A codebase without ADRs forces every future contributor — human or AI — to reverse-engineer intent from code, leading to repeated debates, undocumented reversals, and inconsistent implementations.

This standard defines the canonical format, lifecycle, storage location, and trigger conditions for ADRs in all DevOS-governed projects. It governs what Claude writes when creating or updating an ADR, and what Claude checks when reviewing proposed changes that affect existing decisions.

## Scope

This standard covers: ADR format and required sections, status lifecycle, naming and storage, trigger conditions (when to write one), amendment process, and what counts as an architectural decision.

It does NOT cover: general documentation (covered by `docs-architect`), spec authoring (covered by `write-spec`), or product-level technical choices recorded in `product/tech-stack.md` — those are inventories, not decision records.

---

## What Counts as an Architectural Decision

Write an ADR when a decision meets **two or more** of these criteria:

1. **Costly to reverse** — undoing the decision requires significant rework (database engine, auth provider, monorepo vs polyrepo, ORM selection)
2. **Affects multiple parts of the system** — the choice constrains or shapes how other components are built
3. **Has viable alternatives** — at least two reasonable options existed and one was consciously rejected
4. **Future contributors will ask "why"** — the rationale is non-obvious from the code alone

**Threshold examples:**

| Decision | Write ADR? | Reason |
|---|---|---|
| Chose Supabase over PlanetScale | Yes | Costly to reverse, affects auth + DB + storage |
| Chose tRPC over REST | Yes | Affects all API endpoints, has clear alternatives |
| Chose `zod` for validation | Yes | Used everywhere, alternatives existed |
| Added a utility function | No | Trivially reversible, no alternatives considered |
| Chose `date-fns` over `luxon` | Yes | Used throughout, alternatives existed |
| Named a variable `userId` | No | Not architectural |
| Chose Next.js App Router over Pages Router | Yes | Affects entire project structure |
| Added a `README.md` | No | Not a decision with alternatives |

**When in doubt:** If a future contributor could reasonably ask "why did we do it this way?" and the answer isn't obvious from the code, write the ADR.

---

## Storage Location

ADRs live in the project's `docs/adr/` directory:

```
docs/
  adr/
    README.md          # index of all ADRs with one-line summaries
    0001-use-supabase-over-planetscale.md
    0002-trpc-for-api-layer.md
    0003-zod-for-runtime-validation.md
```

**Naming convention:** `NNNN-short-slug-in-kebab-case.md`
- `NNNN` — zero-padded sequential number (0001, 0002, ...)
- slug — lowercase, hyphen-separated, describes the decision (not the outcome): `use-supabase-over-planetscale`, not `chose-database`
- Number assignment is append-only — never renumber existing ADRs

**If `docs/adr/` does not exist:** Create it along with a `README.md` index when writing the first ADR.

---

## ADR Format

Every ADR MUST contain these sections in this order:

```markdown
# ADR-NNNN: [Title — describes the decision in plain language]

**Date:** YYYY-MM-DD
**Status:** [Proposed | Accepted | Deprecated | Superseded by ADR-NNNN]
**Deciders:** [who made or approved this decision]

## Context

[2–4 sentences. What is the problem or constraint that required a decision?
What is the system state or requirement that made the status quo insufficient?
Do NOT describe the decision here — only the situation that required one.]

## Decision

[1–3 sentences. What was decided? State the decision clearly and directly.
Start with "We will..." or "We chose..."]

## Alternatives Considered

[For each alternative rejected, one entry:]

### [Alternative name]
- **Summary:** [what it is in one sentence]
- **Why rejected:** [the specific reason it lost to the chosen option]

[Minimum 1 rejected alternative. If no alternatives were considered, reconsider
whether this is an architectural decision or just a preference.]

## Consequences

### Positive
- [What gets better or easier as a result of this decision]

### Negative / Trade-offs
- [What gets harder, more constrained, or requires future work]
- [Known limitations of the chosen option]

## Compliance

[Optional but recommended for decisions that constrain future code]

Rules that follow from this decision:
- [Specific coding rule or constraint enforced by this decision]
- [e.g., "All API endpoints MUST use tRPC procedures. Direct `fetch` to internal APIs is not permitted."]
```

### Required vs optional sections

| Section | Required? |
|---|---|
| Title, Date, Status, Deciders | MUST |
| Context | MUST |
| Decision | MUST |
| Alternatives Considered (min 1) | MUST |
| Consequences (both sub-sections) | MUST |
| Compliance rules | SHOULD (if decision constrains future code) |

---

## Status Lifecycle

```
Proposed → Accepted → Deprecated
                    ↘ Superseded by ADR-NNNN
```

| Status | Meaning |
|---|---|
| `Proposed` | Written but not yet approved — under review |
| `Accepted` | Decision is in effect and governs current implementation |
| `Deprecated` | Decision no longer applies (feature removed, approach abandoned) — not replaced |
| `Superseded by ADR-NNNN` | A newer decision replaces this one — link to the superseding ADR |

**Rules:**
- Never delete an ADR — set status to `Deprecated` or `Superseded`
- When superseding, update the old ADR's status AND add a note in the new ADR referencing the old one
- `Proposed` ADRs SHOULD be resolved (Accepted or rejected) before implementation begins on the affected component

---

## When to Write an ADR

| Trigger | Action |
|---|---|
| `write-spec` phase produces a decision meeting the threshold above | Create ADR alongside `spec.md` |
| `architect-review` surfaces a significant technical choice | Create ADR before or during implementation |
| A third-party library or service is selected for first use in the project | Create ADR |
| A prior ADR is being revisited or reversed | Create superseding ADR; update old ADR status |
| Code review reveals a decision was made without documentation | Backfill ADR post-hoc |
| `create-tasks` produces tasks that lock in an approach | Check whether an ADR is needed before tasks start |

**Integration with the planning pipeline:** During `write-spec`, if the spec introduces a new technology, integration, or structural choice meeting the ADR threshold, note it in the spec under a `## Decisions` section. The ADR is written during `create-tasks` or before the first implementation task that depends on the decision.

---

## Amendment Process

**Minor amendments** (clarifications, typo fixes, adding consequences discovered after implementation):
- Edit the existing ADR directly
- Add an `## Amendment` section at the bottom with date and what changed
- Status does not change

**Major reversals** (the decision is being undone or replaced):
- Write a new ADR (gets a new number)
- Set the old ADR status to `Superseded by ADR-NNNN`
- Add a line in the old ADR's `## Decision` section: `> Superseded by [ADR-NNNN](./NNNN-slug.md) on YYYY-MM-DD`
- Never edit the old ADR's original `## Decision` content — preserve the original reasoning

---

## `docs/adr/README.md` Index Format

Maintain a running index of all ADRs:

```markdown
# Architecture Decision Records

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-0001](./0001-use-supabase-over-planetscale.md) | Use Supabase over PlanetScale | Accepted | 2026-01-15 |
| [ADR-0002](./0002-trpc-for-api-layer.md) | Use tRPC for API layer | Accepted | 2026-01-18 |
| [ADR-0003](./0003-zod-for-runtime-validation.md) | Use Zod for runtime validation | Accepted | 2026-01-20 |
```

Update the index every time an ADR is created or its status changes.

---

## Anti-patterns

| Anti-pattern | Problem | Correct approach |
|---|---|---|
| ADR with no alternatives considered | Looks like documentation of preference, not a decision | Always record at least one rejected alternative with a specific reason |
| Vague context ("We needed a database") | Future reader can't assess whether the context still applies | Be specific: what requirement, constraint, or failure drove the decision? |
| Decision and context merged ("We chose Supabase because we needed a database") | Can't tell when the decision applies or doesn't | Separate context (the problem) from decision (the solution) |
| Deleting superseded ADRs | Loses the history of why the current approach was chosen | Set status to Superseded, keep the file |
| ADR for every library added | ADR overhead without value for low-stakes decisions | Apply the two-criteria threshold — trivially reversible decisions don't need ADRs |
| ADR written after implementation is complete | Still valuable, but loses the "proposed" phase | Write ADR when the decision is being made, not after it's encoded in the codebase |

---

## Compliance Test

Answer YES or NO before merging any PR that introduces a new architectural choice:

1. Does the decision meet two or more of the four threshold criteria (costly to reverse, multi-component impact, viable alternatives existed, future "why" question)? If yes → ADR required. (Y/N)
2. Is the ADR stored in `docs/adr/NNNN-slug.md` with the correct naming convention? (Y/N)
3. Does the ADR contain all required sections (Context, Decision, Alternatives with at least one rejected option, Consequences)? (Y/N)
4. Is the `docs/adr/README.md` index updated with the new entry? (Y/N)
5. If this supersedes a previous decision, is the old ADR's status updated to `Superseded by ADR-NNNN`? (Y/N)

---

## Example ADR

```markdown
# ADR-0001: Use Supabase as the Primary Backend Platform

**Date:** 2026-01-15
**Status:** Accepted
**Deciders:** @Traderfuz

## Context

The project requires authentication, a relational database, file storage, and real-time
subscriptions. Managing these independently (separate auth provider, database host, storage
service) adds significant infrastructure complexity for a pre-launch product. A managed
platform that integrates all four reduces operational overhead at the cost of vendor lock-in.

## Decision

We will use Supabase as the primary backend platform, providing PostgreSQL, Auth, Storage,
and Realtime through a single managed service.

## Alternatives Considered

### PlanetScale + Clerk + Cloudflare R2
- **Summary:** Best-in-class individual services for database, auth, and storage
- **Why rejected:** Three separate services, three billing relationships, three sets of SDK
  integrations. Operational complexity not justified at current scale.

### Firebase
- **Summary:** Google's BaaS with Firestore, Auth, and Storage
- **Why rejected:** Firestore's document model requires denormalization patterns that conflict
  with the relational data model in the spec. PostgreSQL is strongly preferred.

## Consequences

### Positive
- Single SDK, single billing relationship, single dashboard
- PostgreSQL gives full relational power (joins, transactions, row-level security)
- Row Level Security enforces data isolation at the database level, not application level
- Supabase local development stack enables offline-first development

### Negative / Trade-offs
- Vendor lock-in: migrating away from Supabase Auth requires reworking session handling
- Supabase Storage is less feature-rich than dedicated CDN solutions (no image transforms)
- Self-hosting is possible but complex; we are dependent on Supabase's managed infrastructure

## Compliance

Rules that follow from this decision:
- All database access MUST go through the Supabase client (`@supabase/supabase-js`) — no raw
  `pg` connections in application code
- Authentication MUST use Supabase Auth — no parallel auth system
- File uploads MUST use Supabase Storage — no direct S3 or R2 integration
```
