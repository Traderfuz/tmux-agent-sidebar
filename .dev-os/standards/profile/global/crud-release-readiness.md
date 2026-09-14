<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/crud-release-readiness.md and re-run profile-sync. -->
# CRUD Release-Readiness Standard

---

## Overview

This standard defines the required pre-release quality gates for create/read/update/delete behavior in web app routes. A route that creates, reads, updates, or deletes data is not releasable until all gates pass. The gates are binary — no partial credit.

**Standard Label:** `Release-Readiness CRUD Audit`

---

## Scope

**Covers:**
- CRUD routes in Next.js App Router (Server Actions, Route Handlers)
- Convex mutations and queries

**Does NOT cover:**
- Performance benchmarks
- A/B tests
- Analytics instrumentation
- Accessibility audits (separate standards)

---

## Principles

### 1. Gate before ship

A route with untested destructive operations is a liability, not a feature. Gates enforce this before merge, not after incident.

### 2. Idempotency for mutations

Status-change and delete mutations must be idempotent. Calling them twice must produce the same result as calling them once.

### 3. Smoke tests over unit tests

E2E CRUD smoke tests catch integration failures that unit tests miss. The release gate requires smoke tests, not just unit tests.

---

## Required Gates

A release is not ready unless all gates pass:

1. Static API contract checks
2. Typecheck and lint
3. CRUD smoke tests (E2E)
4. Idempotency checks for destructive/status mutations

---

## 1) Static API Contract Checks

Block release on:
- `api as any` in page-level data calls
- references to missing backend functions
- known bad path patterns and wrong return-shape assumptions

Recommended scan commands:

```bash
rg -n "\(api as any\)" app/app -g 'page.tsx' -g 'page.ts'
rg -n "reports\.create|integrations\.test" app/app -g 'page.tsx' -g 'page.ts'
```

---

## 2) Type + Lint Gate

Must pass with zero errors:

```bash
cd app
bunx tsc --noEmit --pretty false
bunx eslint app --ext .ts,.tsx --no-error-on-unmatched-pattern
```

---

## 3) CRUD Smoke E2E

Run route-group smoke tests for:
- Clients
- Campaigns
- Billing
- Messaging
- Settings integrations

Each suite must verify:
- create/read/update/delete happy path
- repeated destructive/status actions do not hard-fail UX
- list/detail state is consistent after mutation

---

## 4) Idempotency Policy (Required)

For `archive`, `delete`, `pause`, `resume`, or equivalent state mutations:
- repeated calls must not throw hard errors for already-in-target-state records
- return success with an explicit state flag

Example:

```ts
{ success: true, alreadyArchived: true }
```

---

## Anti-Patterns

| Anti-pattern | Consequence |
|---|---|
| Merging without smoke test | CRUD regression discovered in production |
| No idempotency check on delete | Double-delete causes 500 errors |
| Skipping typecheck gate | Type errors surface as runtime crashes |
| Manual QA substituting for automated gates | Inconsistent coverage, not scalable |

---

## Deviation Guidance

MAY skip the idempotency gate for append-only operations (logging, audit trails). MUST document the exception in the PR description.

---

## Deployment Rule

Do not deploy when any gate fails.

Required CI checks:
- `contract-scan`
- `typecheck`
- `lint`
- `e2e-crud-smoke`

---

## Pre-Deploy Checklist

- [ ] Contract scan clean (`api as any`, missing/wrong function paths)
- [ ] `tsc --noEmit` clean
- [ ] ESLint clean
- [ ] CRUD smoke tests pass for clients/campaigns/billing/messaging/settings
- [ ] Destructive/status mutations are idempotent
- [ ] Convex deploy run for backend mutation changes
- [ ] Preview verification complete
- [ ] Production deploy explicitly approved

---

## Compliance Test

Before marking a CRUD route as release-ready, verify all of the following:

- [ ] Static API contract checks pass?
- [ ] `bun run typecheck && biome check` passes with zero errors?
- [ ] CRUD smoke tests written for every new create/update/delete route?
- [ ] Idempotency verified for every status-change and delete mutation?
- [ ] No `TODO: add tests` comments in PR diff?

---

## Incident Follow-Up Rule

When a runtime CRUD defect is found in production:
1. Patch defect.
2. Add or update smoke test coverage for the defect path.
3. Update this standard if a new failure class is discovered.

---

## References

- [Playwright E2E documentation](https://playwright.dev/docs/intro) — for writing and running CRUD smoke tests
- [Convex mutation documentation](https://docs.convex.dev/functions/mutations) — idempotency patterns for Convex mutations
- [RFC 7231 — HTTP/1.1 Semantics: Idempotent methods](https://datatracker.ietf.org/doc/html/rfc7231#section-4.2.2) — canonical definition of idempotency
