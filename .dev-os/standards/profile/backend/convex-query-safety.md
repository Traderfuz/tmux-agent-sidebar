<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/backend/convex-query-safety.md and re-run profile-sync. -->
<!-- source: profile:webapp -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/webapp/standards/backend/convex-query-safety.md and re-run profile-sync. -->
# Standard: Convex Query Safety

**Category:** backend  
**Applies to:** Any project using Convex as a backend (flowstate profile + webapp profile)  
**Priority:** Critical — violations cause runaway function-call billing

---

## The Problem

Convex `useQuery` creates a real-time subscription. Every time the **args object changes** (by value, not reference), Convex tears down the old subscription and creates a new one. Each new subscription = 1 function call charged against your quota.

In a React component that re-renders frequently (real-time data, state updates, timers), a single unstable arg can generate millions of function calls per month.

**The May 2026 incident:** `focus.listRecentSessions` reached 1.3M calls in 20 days because `Date.now()` was computed inline in the component body and passed as `sinceMs`. Every render → new timestamp → new subscription.

---

## Rules

### Rule 1: Never pass volatile values directly to `useQuery`

❌ **Forbidden:**
```tsx
const recentSessions = useQuery(api.focus.listRecentSessions, {
  sinceMs: Date.now() - 48 * 60 * 60 * 1000,  // new value every render
});
```

✅ **Required:**
```tsx
const sinceMs = useMemo(() => Date.now() - 48 * 60 * 60 * 1000, []);
const recentSessions = useQuery(api.focus.listRecentSessions, { sinceMs });
```

**Volatile values include:**
- `Date.now()` — changes every millisecond
- `new Date()` — new object reference every call
- `Math.random()` — never stable
- `crypto.randomUUID()` — never stable
- Inline array literals: `{ ids: [a, b, c] }` where the array is reconstructed each render
- Inline object literals whose values come from unstable sources

**Stable values (safe to use directly):**
- String or number literals: `{ date: "2026-05-20" }`, `{ limit: 10 }`
- State variables: `{ page }` where `page` is from `useState`
- Values from other stable `useQuery` results
- `useMemo` results with correct deps

### Rule 2: Stabilize with `useMemo` when args depend on time or external state

Any arg that varies by time must be frozen to the appropriate granularity for the query's purpose:

```tsx
// Daily granularity — recompute only when day changes
const today = useMemo(() => new Date().toLocaleDateString("en-CA"), []);

// Per-mount freeze — acceptable when sub-hour precision doesn't matter
const fortyEightHoursAgo = useMemo(() => Date.now() - 48 * 60 * 60 * 1000, []);

// Hourly granularity — recompute once per hour
const hourBucket = useMemo(
  () => Math.floor(Date.now() / (60 * 60 * 1000)),
  // Re-run this memo when hour changes by wrapping in a state that updates hourly
);
```

### Rule 3: Use object args with `useMemo` when the object contains non-primitive values

```tsx
// ❌ New object reference every render (even if values are stable)
const data = useQuery(api.work.listAllWork, {
  typeFilter: filter === "all" ? undefined : filter,
  page,
});

// ✅ Stable reference via useMemo
const queryArgs = useMemo(
  () => ({ typeFilter: filter === "all" ? undefined : filter, page }),
  [filter, page],
);
const data = useQuery(api.work.listAllWork, queryArgs);
```

**Exception:** Primitive-only objects are compared by value in Convex, not reference. `{ date: "2026-05-20" }` is safe without `useMemo` because the string value is stable across renders (same day).

### Rule 4: Gate queries behind `isAuthenticated` to prevent unauthenticated calls

```tsx
// ✅ Pattern: skip when not authenticated
const data = useQuery(api.foo.bar, isConvexAuthenticated ? { userId } : "skip");
```

Never subscribe a user-scoped query before authentication is confirmed.

### Rule 5: Audit cron frequency against actual need

Every cron is function calls × `1/interval × seconds-per-month`. Budget before adding:

| Interval | Calls/month |
|----------|-------------|
| 1 minute | 43,200 |
| 5 minutes | 8,640 |
| 1 hour | 720 |
| 1 day | 30 |

**Free tier limit:** 1M function calls/month total.
**Rule:** No cron faster than 5 minutes without explicit budget justification in a comment.

If push notifications need per-minute accuracy, use a 5-minute cron + `isReminderDue` with a 5-minute window (see `convex/lib/push.ts`).

### Rule 6: Use indexes for queries inside crons — never full table scans

Queries inside cron-triggered actions run at cron frequency × user count. A full `.collect()` scan on a large table at 1-minute cadence will cause both excessive function calls AND database bandwidth overages.

```ts
// ❌ Full scan — O(all_users) every minute
const prefs = await ctx.db
  .query("userPreferences")
  .filter((q) => q.eq(q.field("notificationsEnabled"), true))
  .collect();

// ✅ Index lookup — O(enabled_users) only
const prefs = await ctx.db
  .query("userPreferences")
  .withIndex("by_notifications_enabled", (q) => q.eq("notificationsEnabled", true))
  .collect();
```

---

## Pre-commit Guard

`scripts/check-convex-patterns.sh` runs on every commit via lefthook. It catches:
- `Date.now()` or `new Date()` on the same line as `useQuery(`
- `Math.random()` in `useQuery` args
- Inline object literals in `useQuery` (warning — manual review required)

The script exits non-zero for hard violations and blocks the commit.

---

## Budget Alerting (Required Setup)

Configure Convex usage alerts before deploying to production:

1. Go to Convex Dashboard → Project Settings → Usage Alerts
2. Set alert at **70% of free tier** (700K function calls/month)
3. Set alert at **90% of free tier** (900K function calls/month)
4. Route alerts to Slack or email

Without alerting, usage breaches are discovered reactively (after service interruption).

---

## Code Review Checklist (for every PR touching Convex queries)

- [ ] Every `useQuery` call: are args primitive literals, state vars, or `useMemo` results?
- [ ] No `Date.now()`, `new Date()`, `Math.random()` in query args
- [ ] New crons: is the interval ≥ 5 minutes? Is there a budget comment?
- [ ] New cron-called queries: do they use indexes, not `.filter()`?
- [ ] Auth guard: queries skip when `isConvexAuthenticated = false`?

---

## Incident Post-Mortem Reference

**Incident:** May 2026 — `focus.listRecentSessions` 1.3M calls, Convex free tier exceeded.  
**Root cause:** `Date.now()` inline in `useQuery` arg in `TodayView.tsx`.  
**Fix:** `useMemo(() => Date.now() - 48 * 60 * 60 * 1000, [])`.  
**Detection lag:** ~20 days (entire month before noticed via billing alert).  
**System redesign:** This standard + pre-commit guard + budget alerting setup.
