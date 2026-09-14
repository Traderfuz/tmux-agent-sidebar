<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/backend/queries.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/backend/queries.md and re-run profile-sync. -->
# Query Standards

## Overview

The way a query is written determines not only whether it returns correct results, but whether it is safe, how long it takes, and how the database behaves under concurrent load. A poorly formed query that works correctly in development can cause a production outage at scale — through full table scans, N+1 loops, lock contention, or SQL injection vulnerabilities. Query discipline is a correctness and security concern first, and a performance concern second.

## Scope

This standard covers query construction safety (parameterization), column selection, N+1 prevention through eager loading, transaction usage for multi-step writes, query timeouts, and caching strategy for expensive reads.

It does NOT cover schema design or index creation (see `models.md`), connection pool configuration, or infrastructure-level read replica routing (see `deployment.md`).

## Principles

1. **Parameterization is non-negotiable:** User-supplied or externally-sourced values MUST NEVER be interpolated into query strings. This is not a performance guideline — it is a security invariant.
2. **Select what you need:** Fetching columns you do not use wastes network bandwidth, increases serialization cost, and prevents index-only scans. `SELECT *` is a code smell in production paths.
3. **Related changes travel together:** Any sequence of writes that must succeed or fail as a unit must be wrapped in a database transaction. Partial writes are a class of silent data corruption.

## Rules

### Always Use Parameterized Queries

User-supplied input, URL parameters, session data, or any value not hardcoded in the source file MUST be passed as a query parameter — never interpolated into a string.

```typescript
// OFF-STANDARD: string interpolation — SQL injection vulnerability
async function getUserByEmail(email: string) {
  const result = await db.query(
    `SELECT * FROM users WHERE email = '${email}'`  // NEVER DO THIS
  );
  return result.rows[0];
}

// ON-STANDARD: parameterized query — database handles escaping
async function getUserByEmail(email: string) {
  const result = await db.query(
    'SELECT id, email, display_name FROM users WHERE email = $1',
    [email]
  );
  return result.rows[0];
}

// ON-STANDARD: ORM query builder (parameterized automatically)
async function getUserByEmail(email: string) {
  return db
    .selectFrom('users')
    .select(['id', 'email', 'display_name'])
    .where('email', '=', email)
    .executeTakeFirst();
}
```

This rule applies to all values: IDs from URL params, filter values from query strings, user-submitted data, values from external APIs, and values read from other database rows.

### Avoid SELECT *

Explicit column selection is required in all production query paths. `SELECT *` is acceptable only in ad-hoc debugging or exploratory scripts, never in application code.

```typescript
// OFF-STANDARD: fetches all columns including blobs, JSON fields, and future additions
const user = await db
  .selectFrom('users')
  .selectAll()
  .where('id', '=', userId)
  .executeTakeFirst();

// ON-STANDARD: fetch only what the calling code will use
const user = await db
  .selectFrom('users')
  .select(['id', 'email', 'display_name', 'avatar_url'])
  .where('id', '=', userId)
  .executeTakeFirst();
```

Rationale: adding a large JSONB or TEXT column to a frequently-queried table causes a regression in all existing `SELECT *` queries. Explicit selection is also required for index-only scans to function.

### Eager Loading to Prevent N+1 Queries

Never load a list and then query for related data inside a loop. Fetch related data in the same query or in a single follow-up query for all IDs.

```typescript
// OFF-STANDARD: N+1 — one query per order to fetch line items
async function getOrdersWithItems(userId: string) {
  const orders = await db
    .selectFrom('orders')
    .select(['id', 'status', 'created_at'])
    .where('user_id', '=', userId)
    .execute();

  // This fires one query PER ORDER — 100 orders = 101 queries
  for (const order of orders) {
    order.items = await db
      .selectFrom('order_items')
      .select(['id', 'product_id', 'quantity', 'unit_price_cents'])
      .where('order_id', '=', order.id)
      .execute();
  }
  return orders;
}

// ON-STANDARD: fetch all items in one query and join in application memory
async function getOrdersWithItems(userId: string) {
  const orders = await db
    .selectFrom('orders')
    .select(['id', 'status', 'created_at'])
    .where('user_id', '=', userId)
    .execute();

  if (orders.length === 0) return orders;

  const orderIds = orders.map((o) => o.id);
  const items = await db
    .selectFrom('order_items')
    .select(['id', 'order_id', 'product_id', 'quantity', 'unit_price_cents'])
    .where('order_id', 'in', orderIds)   // single query for all IDs
    .execute();

  const itemsByOrderId = Map.groupBy(items, (item) => item.order_id);
  return orders.map((order) => ({
    ...order,
    items: itemsByOrderId.get(order.id) ?? [],
  }));
}
```

Alternatively, use a JOIN when the relationship is simple and the result set is bounded:

```typescript
// ON-STANDARD: join for simple 1:few relationships
const ordersWithItems = await db
  .selectFrom('orders')
  .innerJoin('order_items', 'order_items.order_id', 'orders.id')
  .select([
    'orders.id',
    'orders.status',
    'order_items.product_id',
    'order_items.quantity',
  ])
  .where('orders.user_id', '=', userId)
  .execute();
```

### Transactions for Multi-Step Writes

Any sequence of writes where partial completion would leave the database in an invalid state MUST be wrapped in a transaction.

```typescript
// OFF-STANDARD: two writes without a transaction — partial failure corrupts state
async function transferFunds(fromId: string, toId: string, cents: number) {
  await db
    .updateTable('accounts')
    .set({ balance_cents: sql`balance_cents - ${cents}` })
    .where('id', '=', fromId)
    .execute();

  // If this fails, the debit happened but the credit did not
  await db
    .updateTable('accounts')
    .set({ balance_cents: sql`balance_cents + ${cents}` })
    .where('id', '=', toId)
    .execute();
}

// ON-STANDARD: both writes inside a transaction — atomic success or failure
async function transferFunds(fromId: string, toId: string, cents: number) {
  await db.transaction().execute(async (trx) => {
    await trx
      .updateTable('accounts')
      .set({ balance_cents: sql`balance_cents - ${cents}` })
      .where('id', '=', fromId)
      .execute();

    await trx
      .updateTable('accounts')
      .set({ balance_cents: sql`balance_cents + ${cents}` })
      .where('id', '=', toId)
      .execute();
  });
}
```

Use transactions for: multi-table inserts, insert-then-update sequences, conditional writes that depend on a prior read, and any operation where failure halfway through would create orphaned or inconsistent records.

### Query Timeouts

All queries that run in a request/response path MUST have a timeout. Without timeouts, a slow query holds a connection pool slot and cascades into application-level starvation.

```typescript
// OFF-STANDARD: no timeout — one slow query blocks the connection pool
const results = await db
  .selectFrom('analytics_events')
  .select(['id', 'event_type', 'payload'])
  .where('user_id', '=', userId)
  .execute();

// ON-STANDARD: explicit statement timeout (PostgreSQL)
const results = await db.transaction().execute(async (trx) => {
  await sql`SET LOCAL statement_timeout = '5000'`.execute(trx);  // 5 seconds
  return trx
    .selectFrom('analytics_events')
    .select(['id', 'event_type', 'payload'])
    .where('user_id', '=', userId)
    .execute();
});

// ON-STANDARD: timeout at the ORM/driver level (Prisma example)
const results = await prisma.analyticsEvent.findMany({
  where: { userId },
  select: { id: true, eventType: true },
  // Prisma: timeout via query engine config or $queryRawUnsafe with SET LOCAL
});
```

Default timeout budgets by query type:
- Transactional read (single row by PK/index): 1–2 seconds
- Transactional write: 3–5 seconds
- Reporting / aggregation query: 30 seconds (run in background, not request path)

### Caching Strategy for Expensive Reads

Queries that are expensive, read-heavy, and tolerant of slight staleness MUST use a caching layer rather than hitting the database on every request.

```typescript
// OFF-STANDARD: expensive aggregation on every request
async function getDashboardMetrics(orgId: string) {
  return db
    .selectFrom('events')
    .select([
      db.fn.count('id').as('total_events'),
      db.fn.sum('revenue_cents').as('total_revenue'),
    ])
    .where('org_id', '=', orgId)
    .executeTakeFirst();
}

// ON-STANDARD: cache with explicit TTL and cache-aside pattern
const METRICS_TTL_SECONDS = 60;

async function getDashboardMetrics(orgId: string) {
  const cacheKey = `metrics:org:${orgId}`;
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  const metrics = await db
    .selectFrom('events')
    .select([
      db.fn.count('id').as('total_events'),
      db.fn.sum('revenue_cents').as('total_revenue'),
    ])
    .where('org_id', '=', orgId)
    .executeTakeFirst();

  await redis.setex(cacheKey, METRICS_TTL_SECONDS, JSON.stringify(metrics));
  return metrics;
}
```

Document the TTL and staleness tolerance at the call site. Never cache data where staleness would affect correctness (e.g., balance checks, permission lookups in security-critical paths).

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| String interpolation of user input into SQL | SQL injection — allows arbitrary query execution by an attacker | Parameterized queries or ORM query builder |
| `SELECT *` in application code | Fetches unused columns; prevents index-only scans; silently grows with schema changes | Explicit column list matching what the code actually uses |
| Querying in a loop (N+1) | 100 parent rows = 101 queries; exponential degradation under load | Fetch all child rows by parent IDs in one query, join in memory or use SQL JOIN |
| Multi-step writes without a transaction | Partial failures create orphaned or inconsistent records silently | Wrap the sequence in a database transaction |
| Queries without timeouts in request paths | One slow query holds a connection pool slot; cascades into service-wide starvation | Set `statement_timeout` per query or per transaction |
| Caching security-critical data (balances, permissions) | Stale cache returns wrong authorization decisions | Never cache data whose staleness affects correctness |
| Raw SQL with concatenated values in an ORM project | Bypasses ORM's parameterization; reintroduces injection risk | Use the ORM's parameterized raw query interface (`$queryRaw` with tagged template, `sql` tagged literal) |

## Deviation guidance

- **MAY** use `SELECT *` in migration scripts and one-off administrative scripts where the schema is fixed and injection is not a concern.
- **MAY** skip a transaction for a single-table, single-row write — a single statement is implicitly atomic in all major databases.
- **MAY** accept N+1 for prototyping and non-production paths, but MUST add a comment marking it as a known issue to fix before shipping.
- **MUST NOT** disable parameterization for any query path that accepts input from outside the application binary (HTTP requests, queue messages, webhooks, file uploads).
- **MUST NOT** use query-level caching for permission checks, authentication data, or financial balances where stale data changes the correctness of a security decision.

## Compliance test

- [ ] No query in application code concatenates or interpolates externally-sourced values into a SQL string — all values are passed as parameters.
- [ ] No production query path uses `SELECT *` or `selectAll()` — all queries list explicit columns.
- [ ] No list-then-loop pattern exists where an inner query runs inside a loop over query results — all related data is fetched in a single follow-up query or JOIN.
- [ ] All multi-step write sequences (two or more writes that must succeed together) are wrapped in an explicit database transaction.
- [ ] All queries in request/response paths have a configured statement timeout.

## References

- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) — canonical reference for parameterization requirements and injection prevention patterns
- [Use The Index, Luke — Markus Winand](https://use-the-index-luke.com/) — practical, database-agnostic guide to index-aware query design; covers why `SELECT *` prevents index-only scans and how WHERE clause ordering affects index use
- [Martin Fowler: Patterns of Enterprise Application Architecture — Unit of Work](https://martinfowler.com/eaaCatalog/unitOfWork.html) — foundational pattern behind transaction grouping for related writes
- [PostgreSQL: Statement Timeout](https://www.postgresql.org/docs/current/runtime-config-client.html#GUC-STATEMENT-TIMEOUT) — official documentation for per-session and per-transaction statement timeouts
