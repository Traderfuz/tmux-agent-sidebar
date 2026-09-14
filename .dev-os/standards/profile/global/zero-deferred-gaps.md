<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/zero-deferred-gaps.md and re-run profile-sync. -->
---
id: zero-deferred-gaps
category: global
version: 2.0.0
created: 2026-06-03
status: active
extends: ../../../default/standards/global/gap-closure-posture.md
---

# Zero Deferred Gaps

Extends: [../../../default/standards/global/gap-closure-posture.md](../../../default/standards/global/gap-closure-posture.md)

## Overview

This general-profile extension makes blast-radius enforcement mechanical. A gap that affects the current feature or slice blocks that work; an unrelated gap is routed through the parent’s canonical capture and immutable receipt without blocking unrelated features or repositories.

## Scope

This standard covers affected-feature enforcement for gaps in the general profile. It does NOT cover gap detection methodology, severity scoring, or the parent’s canonical field and capture semantics.

## Principles

1. **Block only what is affected:** Enforcement follows the declared feature or slice boundary, not a repo-wide zero count.
2. **No agent escape hatch:** Agents cannot skip, defer, task-away, self-waive, or self-authorize a gap inside the active boundary.
3. **Engineered-both routing:** Out-of-radius work has one mutable capture plus one immutable registry receipt.
4. **Reopen means block again:** A stale or reopened finding is evaluated against the current blast radius before shipping.

## Named frameworks

- **RFC 2119 / RFC 8174:** uppercase normative vocabulary makes blocking and waiver conditions binary.
- **ISO 31000:** blast radius is the risk context; closure, routing, or an authorized waiver is risk treatment.
- **DRY:** the parent’s one-capture rule prevents mutable state from being copied into the registry.
- **Audit Log pattern (Fowler):** the terminal receipt preserves what was routed without becoming mutable work state.

## Rules

### Affected-feature gate

- Every gap MUST carry a mechanically resolvable affected feature, slice, or repository scope before disposition.
- A gap is **in-radius** when its affected scope intersects files, routes, contracts, tests, or artifacts changed by the current feature or slice.
- An in-radius gap MUST block that feature’s verification, merge, or release until `status: closed` OR a valid operator waiver.
- An agent MUST NOT skip, defer, task-away, downgrade, self-waive, or self-authorize an in-radius gap.
- An out-of-radius gap MUST NOT block an unrelated feature or repository solely because it remains open.
- Status semantics and forbidden statuses are inherited from the parent; this extension adds the radius gate and does not create a second state machine.

### Engineered-both out-of-radius route

- For an out-of-radius finding, the agent MUST create exactly one canonical capture for all mutable backlog state, using the parent standard’s `classification` enum.
- The agent MUST write and verify the capture under one stable routing/idempotency key, then append and verify the immutable registry receipt under that same key.
- The agent MUST NOT claim `status: routed` until both writes verify. If either fails, it MUST preserve or recover the successful side and report routing failure without fabricating success.
- The receipt MUST contain `gap_id`, `classification`, `status: routed`, `capture_id`, scope evidence, and integrity evidence; it MUST NOT copy the capture's mutable work status, title, priority, due date, or notes.
- Later work-state changes MUST update the capture only. The registry remains unchanged except for an append-only terminal event.
- A capture referenced by the receipt MUST be retained in a terminal state or by a verifiable tombstone; permanent deletion invalidates the route.

### Operator-only expiring waivers

- Only an operator may authorize a waiver for an in-radius gap.
- A waiver is a nested authorization object, not a status or classification, and is valid only with explicit operator authorization, reason, named owner, risk statement, and either an expiry timestamp or an objectively testable closing condition.
- An expired waiver, or a waiver whose closing condition is satisfied and invalidates the exception, MUST block the affected feature again without rewriting status.
- Manual or external findings remain `status: open` with `blocked_by`; they become gate-exempt only while the nested waiver is valid.

### Examples from this repository

```json
// OFF-STANDARD — G-SCHED-003 is skipped even though it touches this slice
{"gap_id":"G-SCHED-003","affected_scope":"scheduler","status":"skipped","skip_reason":"not in spec"}
// ON-STANDARD — intersecting scope blocks until evidence or valid operator waiver
{"gap_id":"G-SCHED-003","affected_scope":"scheduler","classification":"direct_fix_allowed","status":"closed","closed_by":"tests/scheduler.bats"}
```

```json
// OFF-STANDARD — G-CLISF-005 was closed, then reopened without re-blocking
{"gap_id":"G-CLISF-005","status":"reopened","previous_status":"closed","gate":"non-blocking"}
// ON-STANDARD — reopening re-evaluates the current slice boundary
{"gap_id":"G-CLISF-005","classification":"spec_required","status":"open","gate":"blocking","reopen_reason":"stale evidence"}
```

```json
// OFF-STANDARD — an out-of-radius backlog-shaped gap blocks every repository
{"gap_id":"G-MCPS-007","status":"open","repo_gate":"all"}
// ON-STANDARD — engineered-both route isolates unrelated work
{"gap_id":"G-MCPS-007","classification":"spec_required","status":"routed","capture_id":"cap_01J...","scope":"mcp","integrity":{"capture_sha256":"...","routing_key":"rk_..."}}
```

```json
// OFF-STANDARD — G-CRHT-003 is waived by the agent without a contract
{"gap_id":"G-CRHT-003","classification":"manual","waived_by":"agent","status":"waived"}
// ON-STANDARD — external/manual remains open and carries operator waiver
{"gap_id":"G-CRHT-003","classification":"manual","status":"open","blocked_by":"vendor-console","waiver":{"authorized_by":"operator","reason":"vendor console unavailable","owner":"Ops","risk":"manual verification pending","expires":"2026-09-02T00:00:00Z"}}
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Repo-wide zero-open gate | Unrelated work is blocked by unrelated risk | Gate only intersecting feature or slice scope |
| Spec omission as permission | Specs cannot erase discovered risk | Require closure or operator waiver in-radius |
| Agent waiver | No independent risk acceptance | Operator-only contract with expiry or objective condition |
| Reopen without re-gate | Stale evidence lets a defect ship | Recompute radius and block again |
| Mirrored backlog receipt | Two mutable state owners drift | Capture owns work; registry stores terminal evidence |

## Deviation guidance

There is no agent deviation path. An operator MAY authorize only the expiring waiver contract above. For a genuine external/manual exception, retain the canonical active registry record with `status: open` and `blocked_by` when it is in-radius; create a capture plus receipt only when it is out-of-radius. Record the risk and owner, and ensure the affected feature remains blocked until the waiver is valid.

## Profile inheritance notes

Extends the parent lifecycle-routing standard. Adds mechanical feature/slice intersection gating, unrelated-work isolation, reopen re-gating, and operator-only expiring waivers. Narrows the parent’s incidental-routing rule for out-of-radius findings by requiring the engineered-both terminal receipt. It does not restate the parent’s classification enum, capture ownership, or deletion rule.

## Compliance test

- [ ] Does every gap have a mechanically resolvable affected feature, slice, or repository scope?
- [ ] Does every in-radius gap have a blocking gate until `status: closed` OR a valid operator waiver?
- [ ] Can an unrelated feature or repository proceed without being blocked by an out-of-radius gap?
- [ ] Does every out-of-radius route use one stable routing key and verify capture write before receipt append?
- [ ] Is `status: routed` claimed only after both capture and receipt writes verify?
- [ ] Does a failed write preserve or recover the successful side and report routing failure without fabricated success?
- [ ] Does every waiver contain operator authorization, reason, owner, risk statement, and expiry or objective closing condition?
- [ ] Does every reopened gap trigger a fresh radius evaluation and blocking gate when it intersects the current slice?

If any check fails: block the affected feature, repair the route, or obtain a valid operator waiver; never self-waive or edit the registry into compliance.

## References

- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) and [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174) — binary normative vocabulary
- [ISO 31000 overview](https://www.iso.org/iso-31000-risk-management.html) — context and risk treatment
- [DRY principle](https://martinfowler.com/ieeeSoftware/repetition.pdf) — one mutable owner
- [Audit Log pattern](https://martinfowler.com/eaaDev/AuditLog.html) — immutable terminal evidence
- [Parent standard](../../../default/standards/global/gap-closure-posture.md) — canonical classification and capture routing
