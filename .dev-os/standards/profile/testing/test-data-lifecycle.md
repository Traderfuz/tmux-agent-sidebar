<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/testing/test-data-lifecycle.md and re-run profile-sync. -->
# Test Data Lifecycle Standards

## Overview

A test that writes to a shared or persistent backend incurs a debt the moment it
creates a row: that record must be removed, or it accumulates as drift the team
later has to guess at and sweep. This standard makes test-created data
*ephemeral by construction* — every record is tagged at creation, recorded to a
run-scoped manifest, and torn down in the same run that made it — so cleanup is
deterministic deletion of a known set, never pattern-matching against data that
"looks like" a test.

## Scope

This standard covers the lifecycle of every artifact a test creates in a shared
or persistent backend — database rows, auth users, storage objects, queued jobs,
external-API records. It does NOT cover unit tests that touch no external state,
test-runner configuration, or the implementation of the cleanup tooling itself
(those belong in `e2e-testing.md` and the project's `scripts/`).

## Principles

1. **Leave no trace:** A test run ends with the backend in the state it started —
   every artifact a run creates, that run deletes. (Meszaros, *Fresh Fixture*.)
2. **Tag at creation, not at cleanup:** Test data is identified by an explicit
   marker written when the record is created, never inferred later from how it
   looks. Pattern-guessing always lags the data it chases.
3. **Teardown is guaranteed, not best-effort:** Cleanup runs even when the test
   fails, throws, or times out. A teardown that only runs on the happy path is
   not a teardown.
4. **Cleanup deletes a known set:** Teardown reads the run manifest and deletes
   exactly what was recorded — not a heuristic sweep across the whole table.

## Rules

### Tag every created record (`MUST`)

Every record a test writes carries a run-scoped marker — a `seedKey`/`testRunId`
field, or equivalent tag in `metadata` — set at creation. The marker identifies
*which run* created the record so teardown can target it precisely.

```ts
// OFF-STANDARD — untagged; only identifiable by a brittle email pattern later
await prisma.lead.create({ data: { email: 'e2e-foo@example.com', name: 'E2E Foo' } })

// ON-STANDARD — tagged at creation + recorded to the run manifest
const runId = getTestRunId() // TEST_RUN_ID env, or `manual-<ts>` fallback
const lead = await prisma.lead.create({
  data: { email: `e2e-${runId}@boxi-smoke.dev`, name: 'E2E Foo', seedKey: `test:${runId}` },
})
recordTestRunRecord({ model: 'lead', id: lead.id, source: 'smoke', cleanup: 'delete', tags: ['e2e'] })
```

### Record to a run-scoped manifest (`MUST`)

Each created artifact is appended to a per-run manifest keyed by `runId`
(e.g. `product/runtime/test-run-manifests/<runId>.jsonl`). The manifest is the
single source of truth for teardown — it names the model, id, and cleanup verb
for every artifact.

### Tear down in a guaranteed-finally block (`MUST`)

Teardown runs in `afterAll`/`afterEach` or a `try/finally` so it executes on
failure, throw, and timeout. It reads the run manifest and deletes exactly those
records.

```ts
// OFF-STANDARD — cleanup only reached when the test passes
test('smoke', async () => {
  const lead = await createLead()
  await assertDashboardShows(lead)   // throws here → lead leaks forever
  await prisma.lead.delete({ where: { id: lead.id } })
})

// ON-STANDARD — teardown always runs, deletes the recorded set
afterAll(async () => {
  for (const r of readTestRunRecords()) {
    if (r.cleanup === 'delete') await prisma[r.model].deleteMany({ where: { id: r.id } })
  }
})
```

### Clean side effects beyond rows (`MUST`)

The same lifecycle applies to non-row artifacts a test creates: auth users,
storage objects, queued/scheduled jobs, and records pushed to external APIs.
Each is tagged and recorded so teardown removes it. An auth user created and
never deleted is the same leak as an orphaned row.

### Pattern-match sweeps are a fallback, not the mechanism (`SHOULD NOT`)

A heuristic cleanup (delete rows whose email matches `e2e-*`, or a hardcoded list
of historical UUIDs) is a one-time remediation for data created *before* this
standard — not the ongoing cleanup path. New tests MUST NOT rely on a sweep to
remove what they create. A growing `HISTORICAL_TEST_*_IDS` list is a signal the
manifest+teardown path is being bypassed.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Cleanup at the end of the test body | Skipped on failure/throw/timeout → leak | `afterAll`/`finally` reading the manifest |
| Identify test data by email/name pattern | Lags reality; misses renamed/edge records; risks deleting real data | Tag with `seedKey`/`testRunId` at creation |
| Hardcoded list of orphaned test UUIDs | Manual, unbounded, always stale | Run-scoped manifest + deterministic teardown |
| Tearing down rows but not auth users / storage | Non-row artifacts leak silently | Record every artifact type in the manifest |
| Shared mutable fixture reused across runs | Cross-run contamination; "leave no trace" violated | Fresh per-run fixture, torn down each run |

## Deviation guidance

You MAY skip per-record teardown when the test runs against a **disposable,
per-run backend** (ephemeral container, transaction rolled back at test end, or a
database dropped after the run) — because the whole environment is the teardown.
When you do: the disposal MUST be guaranteed (the container/transaction is torn
down in a `finally`/`afterAll`), and you MUST state in the test file that
isolation is provided by environment disposal rather than per-record cleanup.

## Profile inheritance notes

Standalone testing standard for the `general` profile; inherited by all child
profiles (webapp, cli, etc.). Composes with `live-client-action-gate.md` (gating
mutations against live data) and the stricter `prod-test-safety.md` (when the
target backend is production).

Scope boundary: this standard owns **ephemeral** run-scoped test data — created and
torn down inside a single run. Persistent **committed** fixtures (checked-in JSON
manifests, seeds, golden files, recorded provider payloads) are owned by
`committed-fixture-freshness.md`, which covers version stamps, named producers, and
CI-enforced staleness detection. A fixture that survives the run is out of scope here.

## Compliance test

- [ ] Does every test that writes to a shared backend tag each created record with a run-scoped marker at creation?
- [ ] Is every created artifact appended to a per-run manifest before the test asserts anything?
- [ ] Does teardown run in `afterAll`/`afterEach`/`finally` (i.e. on failure, throw, and timeout — not only on pass)?
- [ ] Does teardown delete the recorded set from the manifest rather than pattern-matching the table?
- [ ] Are non-row artifacts (auth users, storage objects, queued jobs, external records) recorded and torn down too?
- [ ] Is there zero reliance on a hardcoded historical-test-id list or `e2e-*` email sweep for new tests?

If any check fails: add the tag + manifest record at creation and move cleanup into a guaranteed teardown that reads the manifest. If isolation is by environment disposal, record that deviation in the test file.

## References

- Gerard Meszaros, *xUnit Test Patterns* (2007) — **Automated Teardown**, **Fresh Fixture**, **Transient Fixture**, **Persistent Fresh Fixture**: the canonical patterns for leaving the system as the test found it.
- *Software Engineering at Google* (Winters et al., 2020), ch. "Testing Overview" — **hermetic tests**: a test that brings up and tears down its own state, independent of other runs.
- xUnit Test Patterns — **Erratic Test / Interacting Tests** smell: the failure mode that uncleaned shared data produces.
