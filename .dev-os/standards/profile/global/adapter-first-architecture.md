<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/adapter-first-architecture.md and re-run profile-sync. -->
# Adapter-First Default Standards

**Sibling standards (the mechanics):**
- [`extensibility.md`](./extensibility.md) — interface contracts, extension registries, contract tests
- [`provider-agnostic-architecture.md`](./provider-agnostic-architecture.md) — capability-first routing policy for external services
- [`modular-architecture.md`](./modular-architecture.md) — where code lives, feature boundaries, dependency direction
- [`modular-integration.md`](./modular-integration.md) — how modules connect at runtime, plugin registration protocol
- [`modular-provider.md`](../../../default/standards/global/modular-provider.md) — provider ports, adapters, routers, and tests for app code
- [`dual-transport-provider.md`](../../../installable-os/standards/global/dual-transport-provider.md) — multi-transport routing in installable OS skills

## Overview

The sibling standards define *how* to build a swappable boundary once you have decided to build one: contracts, registries, adapters, tests. None of them states the *default posture* — which surfaces start behind a port with adapters when a project begins, and which stay plain modules. Undecided posture produces both failure modes: vendor SDKs leaking into feature code because nobody decided, and speculative interfaces wrapping single-implementation code because somebody over-applied the pattern. This standard is that decision layer. It is deliberately thin: it names the default, defines the one test that separates wrapped from plain, and routes the mechanics to the siblings.

## Scope

This standard covers the default architecture posture for boundaries in new software: which surfaces start behind a port. It does NOT cover interface contract design once wrapped (`extensibility.md`), provider-backed integration implementation (`modular-provider.md`), routing policy and lock-in declaration for external services (`provider-agnostic-architecture.md`), transport-tier routing inside skills (`dual-transport-provider.md`), or where modules live on disk (`modular-architecture.md`).

## Named Frameworks

### Ports and Adapters (Hexagonal Architecture)
Alistair Cockburn, 2005. Ports are stable capability definitions owned by the application; adapters are swappable implementations behind them. Domain logic depends on ports, never on concrete external details.
**Applied to:** Rule 1 — the port is the default shape for any surface that qualifies.

### Rule of Three
Martin Fowler, _Refactoring_ (1999). Duplication and abstraction earn their cost on the third concrete case; abstracting before that is usually premature.
**Applied to:** Rule 2 — plain modules for single-implementation logic — and Rule 1's plausibility test: *could a reasonable second implementation exist within the product's lifetime*, not *does one exist today*.

### YAGNI
Kent Beck, _Extreme Programming Explained_ (1999). Build for the requirement in hand; speculative generality is cost paid by every future reader.
**Applied to:** Rule 2 — no interface, composition root, or mock seam beyond what real implementations justify.

### Convention over Configuration
DHH, Rails Doctrine (2004). Sensible defaults handle the common case; only unconventional behavior requires explicit specification.
**Applied to:** the headline — adapter-first IS the default for qualifying surfaces; deviations are recorded, never silent.

## Principles

1. **The default is a port for anything third-party or plausibly multi-implementation.** External services, storage engines, auth, payments, email, search, export formats, notification channels, external CLIs: capability named first, one narrow port, adapters behind it.
2. **Plain modules for everything else.** Internal logic with a single implementation and no plausible second one is not wrapped. Speculative interfaces are paid for by every reader.
3. **Every not-wrapped decision is visible.** A plain module next to a vendor SDK boundary is a recorded one-liner with a revisit trigger — not an accident somebody rediscovers during a migration.

## Rules

### Rule 1 — Third-party and plausibly multi-implementation surfaces MUST start behind a port (`MUST`)

The plausibility test: *could a reasonable second implementation exist within the product's lifetime without changing the domain model?* LLM vendors, databases, auth providers, email senders, search engines, storage backends, export formats, notification channels, external CLIs — all pass. If yes, the surface starts as: one narrow port + one adapter. The port is the only thing the application imports.

```typescript
// OFF-STANDARD — vendor SDK wired straight into feature code; posture never decided
import { Resend } from "resend";
export async function sendWelcome(to: string) {
  return new Resend(process.env.RESEND_KEY).emails.send({ to, subject: "Welcome" });
}

// ON-STANDARD — port first, one adapter, feature depends on the port only
// lib/mail/port.ts
export interface MailPort {
  send(input: { to: string; subject: string; body: string }): Promise<{ id: string }>;
}
// lib/mail/resend-adapter.ts implements MailPort
// app code: import { mail } from "@/lib/mail" — never from a vendor package
```

Contract mechanics (header block, exit-code tables, versioning, contract tests) are owned by `extensibility.md` Rules 1, 6, 7 and `modular-provider.md` Rules 1–7. This standard does not restate them.

### Rule 2 — Single-implementation internal logic MUST be a plain module (`MUST`)

When the plausibility test fails — one implementation, no realistic second, no external boundary — the correct architecture is a plain module with no interface, no composition root, and no speculative seams.

```typescript
// OFF-STANDARD — speculative abstraction: one implementation, ceremonial interface
interface DatePort { now(): Date; }
class SystemDatePort implements DatePort { now() { return new Date(); } }
const date: DatePort = new SystemDatePort();  // nobody will ever swap this

// ON-STANDARD — plain module
export function now(): Date { return new Date(); }
```

### Rule 3 — Each not-wrapped boundary MUST record its posture (`MUST`)

A plain module that sits at an external boundary (or any boundary with a named revisit trigger) carries a one-line posture note at its definition site:

```typescript
// POSTURE(plain): single implementation (Stripe), lock-in accepted; revisit trigger: second payment provider, pricing change >2x
export async function charge(amountCents: number, customerId: string) { /* Stripe SDK */ }
```

When the boundary is strategic — costly to reverse, long-lived, user-visible, central to product quality — the posture is recorded as an ADR per `provider-agnostic-architecture.md` Rule 7 and the `adr` skill.

### Rule 4 — A wrapped boundary MUST satisfy the sibling mechanics (`MUST`)

Deciding to wrap does not complete the work. A wrapped surface MUST meet: explicit interface contract (`extensibility.md` Rule 1), no-modification extension (`extensibility.md` Rule 2), contract test (`extensibility.md` Rule 7), provider normalization and router rules for third-party implementations (`modular-provider.md` Rules 1–7), and capability-first routing policy (`provider-agnostic-architecture.md` Rules 1–5). DRY applies to rules — each mechanic is defined once in its owning sibling; this standard only routes.

### Rule 5 — Project start SHOULD declare posture per boundary category (`SHOULD`)

At spec or architecture time (architecture brief, `architecture-creator` output, or the spec's product-context section), list the system's boundary categories and mark each `adapter-first` or `plain`, with the revisit trigger for plain ones. A boundary discovered mid-build without a declared posture defaults to Rule 1 when it qualifies.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Adapter-for-everything (interface around each module) | Every reader pays ceremony cost; implementations never swap | Rule 2: plain module unless plausibility test passes |
| Vendor SDK imported directly in feature code | Lock-in chosen by omission; migration becomes app-wide refactor | Rule 1: port + adapter; `modular-provider.md` Rule 2 |
| God-interface with 10+ required methods | New adapters too expensive to build; extensibility collapses | Narrow port per capability; `extensibility.md` ISP row |
| Wrapping only after three call sites are coupled | The second implementation arrives after the blast radius exists | Rule 5: declare posture at project start |
| Silent plain module next to a vendor SDK | Lock-in is invisible; future sessions re-litigate it | Rule 3: posture one-liner with revisit trigger |
| Posture note without revisit trigger | "Recorded" but unactionable; drifts into noise | One-liner must name what would change the decision |

## Deviation guidance

You MAY deviate — plain module for a qualifying third-party surface, or a wrapped interface for non-qualifying logic — when the plausibility test or a cost argument justifies it. When you do: record `# DEVIATION(adapter-first)` with the reason and revisit trigger at the boundary site. Strategic lock-in additionally requires an ADR. Deviations are scoped to one boundary; they never change this standard's defaults.

## Profile inheritance notes

This standard lives at `general` level and propagates to all profiles inheriting general (`webapp`, `devos-platform`, and their children). It defines no profile-specific overrides. Profiles adding a new swappable-primitive category MUST extend `extensibility.md` (per its inheritance notes) before implementing the first variant; this standard's default posture applies unchanged.

## Compliance test

Answer YES or NO. A single NO is a posture gap.

1. Does every third-party surface with a plausible second implementation sit behind a local port the application imports? (Y/N)
2. Is every not-wrapped boundary marked with a posture one-liner (plus ADR when strategic)? (Y/N)
3. Are single-implementation internal modules plain — no speculative interfaces or composition roots? (Y/N)
4. Does each wrapped boundary satisfy `extensibility.md` Rule 1 (contract) and Rule 7 (contract test)? (Y/N)
5. Did the spec or architecture brief declare posture per boundary category at project start? (Y/N)

Machine check (check 2): `bash "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/posture-check.sh" <boundary-code-paths>` validates that every `POSTURE(...)` marker and `# DEVIATION(adapter-first)` comment carries a revisit trigger. Zero markers is a valid state — enforcement is opt-in at boundaries.


If any check fails: treat it as an architecture-posture gap, not a code smell. Fix at the boundary; record justified deviations with `# DEVIATION(adapter-first)`.

## References

- Alistair Cockburn, [*Hexagonal Architecture*](https://alistair.cockburn.us/hexagonal-architecture/) (2005) — ports as stable capability definitions, adapters as swappable implementations
- Martin Fowler, _Refactoring_ (1999) — Rule of Three: when abstraction has earned its cost
- Kent Beck, _Extreme Programming Explained_ (1999) — YAGNI: no speculative generality
- DHH, [Rails Doctrine](https://rubyonrails.org/doctrine) (2004) — convention over configuration: the default is explicit, deviations are visible
- Sibling mechanics: `extensibility.md`, `provider-agnostic-architecture.md`, `modular-provider.md`, `dual-transport-provider.md`
