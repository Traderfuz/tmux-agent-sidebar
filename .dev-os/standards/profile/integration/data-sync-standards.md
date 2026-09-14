<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/integration/data-sync-standards.md and re-run profile-sync. -->
<!-- source: profile:webapp -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/webapp/standards/integration/data-sync-standards.md and re-run profile-sync. -->
# Data Synchronization Standards

**Profile**: webapp
**Category**: integration
**Scope**: Data synchronization patterns between the webapp's Convex backend and external systems —
third-party REST APIs, incoming webhooks, and scheduled pull syncs. Does NOT cover Convex-internal
reactivity (Convex handles that natively via queries and subscriptions) or database schema migrations.

---

## Principles

1. **Source of truth is explicit** — every synced entity declares which system is authoritative for each
   field. Conflicts resolve toward the declared source of truth, never arbitrarily. Ambiguity in source
   of truth is a design defect, not a runtime decision.

2. **Idempotent operations** — sync operations MUST be safe to run multiple times. Running a sync twice
   must produce the same result as running it once. Use upserts keyed on external ID; never append-only
   inserts for synced entities.

3. **Failed syncs are queued, not lost** — any sync failure stores the original payload for retry. No
   webhook handler or scheduled pull silently discards data on failure. Data loss through dropped
   payloads is never acceptable.

---

## Rules

### R1 — Webhook-push sync pattern

Webhook handlers return 202 immediately after storing the raw payload. All processing happens
asynchronously via a Convex scheduled action. This prevents webhook provider timeouts and duplicate
delivery caused by retries.

```typescript
// OFF-STANDARD: synchronous processing in webhook handler — times out Stripe's 30s window
export const stripeWebhook = httpAction(async (ctx, request) => {
  const body = await request.json();
  await ctx.runMutation(api.users.syncFromStripe, { data: body.data.object });
  return new Response('OK', { status: 200 });
});

// ON-STANDARD: store raw payload, return 202, process asynchronously
export const stripeWebhook = httpAction(async (ctx, request) => {
  const rawBody = await request.text();
  verifyStripeSignature(rawBody, request.headers.get('stripe-signature')!);
  const payload = JSON.parse(rawBody) as StripeWebhookEvent;
  await ctx.runMutation(api.webhooks.enqueue, {
    service: 'stripe', eventId: payload.id, eventType: payload.type, payload,
  });
  return new Response(null, { status: 202 });
});

// convex/webhooks.ts — idempotent enqueue (deduplicates by eventId)
export const enqueue = mutation({
  args: { service: v.string(), eventId: v.string(), eventType: v.string(), payload: v.any() },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query('webhookQueue')
      .withIndex('by_event_id', (q) => q.eq('eventId', args.eventId))
      .first();
    if (existing) return; // already enqueued — idempotent
    await ctx.db.insert('webhookQueue', { ...args, status: 'pending', retryCount: 0 });
    await ctx.scheduler.runAfter(0, internal.webhooks.process, { eventId: args.eventId });
  },
});
```

### R2 — Scheduled pull sync with cursor

Pull syncs MUST store a checkpoint (cursor or timestamp) after each successful run. Re-runs start from
the checkpoint, not from the beginning. Full re-syncs are only permitted on explicit reset.

```typescript
// OFF-STANDARD: full re-sync on every run
async function syncAllContacts(ctx: ActionCtx) {
  // O(n) every run — hammers external API, wastes rate limit quota
  const contacts = await externalCRM.getAllContacts();
  for (const contact of contacts) {
    await ctx.runMutation(api.contacts.upsert, mapContact(contact));
  }
}

// ON-STANDARD: cursor-based incremental sync
export const syncContactsIncremental = internalAction({
  handler: async (ctx) => {
    const checkpoint = await ctx.runQuery(api.sync.getCheckpoint, {
      resource: 'crm-contacts',
    });

    const { items, nextCursor, hasMore } = await externalCRM.getContacts({
      since: checkpoint?.cursor,
      limit: 100,
    });

    for (const contact of items) {
      await ctx.runMutation(api.contacts.upsert, {
        contact: mapContactToDomain(contact),
      });
    }

    if (nextCursor) {
      await ctx.runMutation(api.sync.setCheckpoint, {
        resource: 'crm-contacts',
        cursor: nextCursor,
        syncedAt: Date.now(),
      });
    }

    // Schedule continuation if more pages remain
    if (hasMore) {
      await ctx.scheduler.runAfter(500, internal.sync.syncContactsIncremental);
    }
  },
});
```

### R3 — Conflict resolution via explicit source-of-truth declaration

Every synced resource declares a `SyncConfig` that names the authoritative system per field group.
Never silently apply last-write-wins without documenting the fields and the rationale.

```typescript
// ON-STANDARD: explicit source-of-truth declaration
// src/lib/sync/configs.ts

export interface SyncConfig {
  resource: string;
  sourceOfTruth: 'stripe' | 'convex' | 'external-crm';
  /** Fields that always follow the declared source of truth on conflict */
  authorityFields: string[];
  /** Fields owned by this application — incoming sync MUST NOT overwrite them */
  localOnlyFields: string[];
}

export const USER_SYNC_CONFIG = {
  resource: 'users',
  sourceOfTruth: 'stripe',
  // Stripe is authoritative for billing and identity fields
  authorityFields: ['email', 'name', 'stripeCustomerId', 'subscriptionStatus'],
  // User preferences are owned by the app — never synced outward or overwritten inward
  localOnlyFields: ['preferences', 'notificationSettings', 'onboardingState'],
} satisfies SyncConfig;

// Upsert respects the config — localOnlyFields are preserved from the existing record
export const upsertUser = mutation({
  args: { user: v.object({ ... }) },
  handler: async (ctx, { user }) => {
    const existing = await ctx.db
      .query('users')
      .withIndex('by_external_id', (q) => q.eq('externalId', user.externalId))
      .first();
    if (!existing) { await ctx.db.insert('users', user); return; }
    // Preserve localOnlyFields — never overwrite from external source
    const preserved = Object.fromEntries(
      USER_SYNC_CONFIG.localOnlyFields.map((f) => [f, existing[f as keyof typeof existing]])
    );
    await ctx.db.patch(existing._id, { ...user, ...preserved });
  },
});
```

### R4 — Retry queue for failed syncs

Failed sync operations MUST be recorded in a Convex retry queue with the original payload, a retry
count, and the next-attempt timestamp. After `maxRetries` attempts, the record moves to a dead-letter
table and fires an alert.

```typescript
// ON-STANDARD: Convex sync failure queue
// convex/syncQueue.ts
export const enqueueFailed = mutation({
  args: { resource: v.string(), operation: v.string(), payload: v.any(), error: v.string() },
  handler: async (ctx, args) => {
    const MAX_RETRIES = 5;
    const existing = await ctx.db
      .query('syncQueue')
      .withIndex('by_resource_operation', (q) =>
        q.eq('resource', args.resource).eq('operation', args.operation)
      )
      .first();

    const retryCount = (existing?.retryCount ?? 0) + 1;
    const nextAttemptMs = Date.now() + Math.pow(2, retryCount) * 1_000;

    if (retryCount > MAX_RETRIES) {
      await ctx.db.insert('syncDeadLetter', { ...args, retryCount, failedAt: Date.now() });
      await ctx.scheduler.runAfter(0, internal.alerts.syncMaxRetriesExceeded, {
        resource: args.resource,
      });
      if (existing) await ctx.db.delete(existing._id);
      return;
    }

    if (existing) {
      await ctx.db.patch(existing._id, { retryCount, nextAttemptMs, error: args.error });
    } else {
      await ctx.db.insert('syncQueue', { ...args, retryCount, nextAttemptMs, createdAt: Date.now() });
    }
    await ctx.scheduler.runAt(nextAttemptMs, internal.syncQueue.processNext, {
      resource: args.resource,
    });
  },
});
```

---

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Synchronous processing inside webhook handler | Webhook provider (Stripe, Clerk, etc.) has a ~30s timeout; slow processing causes timeouts, the provider retries, and duplicate processing occurs |
| Full re-sync without cursor on every scheduled run | O(n) every run; hammers external API rate limits; as data grows, the sync window exceeds the schedule interval |
| Implicit last-write-wins with no documentation | Conflicts silently corrupt billing or identity fields; no audit trail; impossible to debug data discrepancies |
| Discarding failed sync payloads on error | Data loss with no recovery path; the system silently falls out of sync with no observable signal |
| Incoming sync overwrites `localOnlyFields` | User preferences, onboarding state, and app-owned settings are clobbered by external data on every sync cycle |

---

## Deviation Guidance

MAY use last-write-wins for genuinely non-critical display fields (avatar URLs, display names, timezone
from external profile) without the full `SyncConfig`. MUST document the fields and the rationale in a
comment at the upsert call site. MUST NOT use implicit LWW for billing fields, subscription status,
authentication identifiers, or any field that affects access control.

MAY skip the retry queue for low-value analytics events where loss is acceptable. MUST document the
decision and add a log statement on failure so the drop is observable.

---

## Compliance Test

Before marking a sync integration complete, verify all five:

1. Webhook handlers store the raw payload and return 202 before any processing logic runs?
2. Pull syncs read a checkpoint before fetching and write a new checkpoint after each successful batch?
3. Every synced resource has an explicit `SyncConfig` with `sourceOfTruth` and `localOnlyFields`?
4. Failed sync operations are enqueued in Convex `syncQueue` with retry count and next-attempt
   timestamp?
5. `localOnlyFields` are explicitly preserved in all upsert mutations — never overwritten by incoming
   sync data?

---

## References

- Convex documentation — mutations, scheduled functions, and HTTP actions
- Stripe webhook best practices — acknowledge immediately, process asynchronously
- Martin Fowler, _Enterprise Integration Patterns_ — event-driven sync and idempotent receiver patterns
