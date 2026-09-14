<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/prod-test-safety.md and re-run profile-sync. -->
# Production Test Safety Standards

## Overview

A smoke test against production is the only test that can corrupt real customer
data, bill a real account, or send a real email to a real person. The general
teardown discipline is necessary but not sufficient here: production runs need a
dedicated identity surface, a bounded blast radius, dry-run-before-destroy on
every sweep, and same-run self-clean — so a prod check verifies the live system
without leaving residue or touching anything real.

## Scope

This standard covers any test that executes against a **production** backend —
smoke tests, synthetic monitors, post-deploy verification, dogfood runs. It does
NOT cover tests against local/staging/ephemeral backends (see
`test-data-lifecycle.md`), nor production *data migrations* (those are an
operational change gated by `live-client-action-gate.md`, not a test).

## Principles

1. **Synthetic, never real:** Production checks act only on dedicated synthetic
   identities and resources, never on real customer records.
2. **Self-cleaning within the run:** A prod check removes everything it created
   before it exits — residue in production is an incident, not a TODO.
3. **Dry-run before destroy:** Any deletion against production is previewed
   (counts + sample) and confirmed before it executes.
4. **Bounded blast radius:** A prod check can only touch a small, capped set it
   owns; it can never issue an unbounded delete or a whole-table sweep.

## Rules

### Use a dedicated synthetic identity surface (`MUST`)

Production checks operate only through reserved synthetic accounts/domains
(e.g. `*@boxi-smoke.dev`, `e2e-<runId>@…`), provisioned for testing and excluded
from analytics, billing, and customer comms. A prod check MUST NOT read, mutate,
or assert against a real customer record.

```ts
// OFF-STANDARD — smoke test signs up against a real-looking domain in prod
await signup({ email: 'jane@gmail.com', plan: 'pro' }) // bills a real plan path

// ON-STANDARD — reserved synthetic identity, tagged, manifest-recorded
const runId = getTestRunId()
const user = await signup({ email: `e2e-${runId}@boxi-smoke.dev`, plan: 'test' })
recordTestRunRecord({ model: 'user', id: user.id, source: 'prod-smoke', cleanup: 'delete', tags: ['synthetic'] })
```

### Self-clean within the same run (`MUST`)

A prod check tears down its artifacts before it exits, in a guaranteed
`finally`/`afterAll` — it does not defer cleanup to a separate scheduled job.
The general manifest+teardown lifecycle applies, with the stricter requirement
that teardown completes **in-run**. A separate `db:cleanup:prod` sweep exists
only to remediate pre-standard residue, never as the primary path.

### Dry-run before any destructive prod operation (`MUST`)

Every deletion against production runs in preview first: print the count and a
sample of what would be deleted, require an explicit confirm (flag or env), and
only then delete. Default posture is dry-run; destruction is opt-in.

```bash
# ON-STANDARD — dry-run is the default; destroy requires an explicit flag
db:cleanup:prod:dry   # prints "would delete 7 leads, 2 users (sample: …)"
db:cleanup:prod       # only after reviewing the dry-run output
```

### Cap the blast radius (`MUST`)

A prod check declares an upper bound on the artifacts it may create and delete
(e.g. ≤ N records per run). Teardown deletes by recorded id from the manifest —
never `deleteMany({})`, never a delete keyed only by a broad pattern. A sweep
that finds more than the declared cap MUST stop and surface, not proceed.

```ts
// OFF-STANDARD — unbounded; a bad WHERE wipes real data
await prisma.lead.deleteMany({ where: { name: { contains: 'Smoke' } } })

// ON-STANDARD — delete exactly the recorded ids, capped
const ids = readTestRunRecords().filter(r => r.model === 'lead').map(r => r.id)
if (ids.length > MAX_PER_RUN) throw new Error(`blast radius ${ids.length} > cap ${MAX_PER_RUN}`)
await prisma.lead.deleteMany({ where: { id: { in: ids } } })
```

### Gate destructive prod actions behind explicit authorization (`MUST`)

Destructive operations against production run only under explicit, scoped
credentials (e.g. `doppler run --config prd`) and an interactive or
flag-gated confirmation — never silently from an automated path without a
recorded decision. Composes with `live-client-action-gate.md`.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Smoke test uses real-looking customer data in prod | Pollutes analytics/billing; indistinguishable from real | Reserved synthetic identity surface |
| Cleanup deferred to a nightly cron | Residue lives in prod for hours/days; can be incident | Self-clean in the same run's teardown |
| `deleteMany` keyed by name/email pattern in prod | One bad pattern deletes real customer rows | Delete recorded ids from the manifest, capped |
| Destructive sweep with no dry-run | No chance to catch an over-broad match before it runs | Dry-run default; destroy is an explicit opt-in |
| Unbounded prod cleanup | A wrong WHERE has unlimited blast radius | Declared per-run cap; stop-and-surface if exceeded |

## Deviation guidance

You MAY run a one-time historical-residue sweep that matches by pattern (the
`db:cleanup:prod` remediation path) when cleaning data created *before* this
standard existed. When you do: it MUST run dry-run first, MUST be reviewed by a
human against the dry-run output, and MUST be removed (or reduced to the manifest
path) once the historical set is cleared — it is not a standing mechanism.

## Profile inheritance notes

Standalone testing standard for the `general` profile; inherited by all child
profiles. Strengthens `test-data-lifecycle.md` for the production target and
composes with `live-client-action-gate.md` (authorization for live mutations).

## Compliance test

- [ ] Do all production checks act only on a reserved synthetic identity surface (no real customer records read or mutated)?
- [ ] Does every prod check tear down its created artifacts in-run (guaranteed `finally`/`afterAll`), not via a deferred job?
- [ ] Does every destructive prod operation run dry-run-first with an explicit confirm before deleting?
- [ ] Is every prod deletion keyed to recorded manifest ids (never `deleteMany({})` or a broad pattern)?
- [ ] Is there a declared per-run blast-radius cap that stops-and-surfaces when exceeded?
- [ ] Are destructive prod actions gated behind explicit scoped credentials + confirmation?

If any check fails: route the check onto the synthetic identity surface, move teardown in-run, and replace any pattern sweep with capped, manifest-keyed deletion behind a dry-run gate.

## References

- Charity Majors / Cindy Sridharan — **Testing in Production (TiP)**: production checks run as synthetic, isolated, bounded traffic that never touches real users.
- Site Reliability Engineering (Beyer et al., Google, 2016) — **synthetic monitoring** / black-box probes using dedicated synthetic accounts; **blast radius** containment.
- Gerard Meszaros, *xUnit Test Patterns* — **Automated Teardown** applied with an in-run completion requirement for the production target.
- `live-client-action-gate.md` — authorization gate this standard composes with for destructive live operations.
