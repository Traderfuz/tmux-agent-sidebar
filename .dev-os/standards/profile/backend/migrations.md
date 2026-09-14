<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/backend/migrations.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/backend/migrations.md and re-run profile-sync. -->
# Migration Standards

## Overview

A database migration is not a one-time script — it is a permanent, executable record of every deliberate change to a schema. When migrations are versioned, reversible, and immutable after deployment, the history of a database becomes as auditable as the history of source code. This discipline is the difference between a schema you can reason about and one that can only be understood by examining a live production instance.

## Scope

This standard covers database schema migrations (DDL changes: tables, columns, indexes, constraints) and data migrations (DML changes that accompany schema changes). It covers naming conventions, rollback requirements, zero-downtime patterns, and the separation of schema from data.

It does NOT cover seed data (test fixtures, reference data inserts), model/ORM definitions (see `models.md`), or query patterns (see `queries.md`).

## Principles

1. **Reversibility by default:** Every migration MUST have a working rollback. If a migration cannot be reversed, that is an exceptional condition that must be explicitly documented and approved — not the default.
2. **One logical change per migration:** A migration that adds a column and backfills data and creates an index is three migrations. Atomicity of purpose, not just atomicity of execution.
3. **Migrations are immutable after deployment:** Once a migration has run in any shared environment (staging, production), it MUST NOT be modified. Fix forward with a new migration.

## Rules

### Always Implement Down/Rollback

Every migration file must implement both `up` and `down` directions. The `down` must restore the schema to its exact prior state.

```sql
-- OFF-STANDARD: no rollback, no going back if the deploy is bad
-- migration: 20250115_add_status_to_orders.sql
ALTER TABLE orders ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'pending';
-- (no down migration)

-- ON-STANDARD: explicit up and down
-- migration: 20250115_add_status_to_orders.up.sql
ALTER TABLE orders ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'pending';

-- migration: 20250115_add_status_to_orders.down.sql
ALTER TABLE orders DROP COLUMN status;
```

```typescript
// ON-STANDARD: ORM migration with both directions (Drizzle/Knex style)
export async function up(db: Kysely<Database>): Promise<void> {
  await db.schema
    .alterTable('orders')
    .addColumn('status', 'varchar(50)', (col) => col.notNull().defaultTo('pending'))
    .execute();
}

export async function down(db: Kysely<Database>): Promise<void> {
  await db.schema
    .alterTable('orders')
    .dropColumn('status')
    .execute();
}
```

### Keep Migrations Atomic

Each migration file must represent one logical schema change. Do not bundle unrelated changes.

```sql
-- OFF-STANDARD: three unrelated changes in one migration
ALTER TABLE users ADD COLUMN avatar_url TEXT;
CREATE TABLE audit_logs (id BIGSERIAL PRIMARY KEY, event TEXT NOT NULL);
ALTER TABLE orders ADD COLUMN shipped_at TIMESTAMPTZ;

-- ON-STANDARD: three separate, independently reversible migrations
-- migration 001: add avatar to users
ALTER TABLE users ADD COLUMN avatar_url TEXT;

-- migration 002: create audit_logs table
CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  event TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- migration 003: add shipped_at to orders
ALTER TABLE orders ADD COLUMN shipped_at TIMESTAMPTZ;
```

### Zero-Downtime Patterns (Expand-Contract)

For systems that must stay live during deploys, apply the expand-contract pattern: add before you remove, make nullable before you make required.

**Expand phase** (deploy while old code still runs):
- Add new columns as nullable or with a default.
- Add new tables.
- Create new indexes (use `CONCURRENTLY` in PostgreSQL).

**Contract phase** (deploy after all code is updated and old paths are gone):
- Remove old columns.
- Remove old tables.
- Drop obsolete indexes.

```sql
-- OFF-STANDARD: rename column in one migration (breaks running app instances)
ALTER TABLE users RENAME COLUMN full_name TO display_name;

-- ON-STANDARD: expand first, contract later
-- Phase 1 migration (expand): add new column, copy data
ALTER TABLE users ADD COLUMN display_name TEXT;
UPDATE users SET display_name = full_name;

-- Phase 2 migration (contract): after all code uses display_name
ALTER TABLE users DROP COLUMN full_name;
```

### Never Modify Deployed Migrations

Once a migration file has been applied in any shared environment, it is immutable. If a migration was wrong, create a new corrective migration.

```
-- OFF-STANDARD: editing an already-applied migration file to fix a typo
-- This causes the migration tool's checksum verification to fail and
-- creates an inconsistent state between environments.

-- ON-STANDARD: leave the original migration intact, add a new one
-- migration 20250115_add_status_to_orders.sql  (DO NOT TOUCH)
-- migration 20250116_fix_status_default_value.sql  (new file)
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'new';
```

### Concurrent Index Creation on Large Tables

Creating an index with `CREATE INDEX` takes a full table lock. On large tables in production, use the non-blocking form.

```sql
-- OFF-STANDARD: blocks all writes while index builds (can take minutes on large tables)
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- ON-STANDARD: non-blocking (PostgreSQL CONCURRENTLY)
-- Note: cannot run inside a transaction block
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);
```

For ORMs or migration tools that wrap statements in transactions, run concurrent index creation in a separate migration that explicitly disables the transaction wrapper.

### Separate Schema Migrations from Data Migrations

Schema migrations (DDL) and data migrations (DML backfills) have different risk profiles and rollback behaviors. Keep them in separate migration files.

```
-- OFF-STANDARD: schema and data in one migration
ALTER TABLE users ADD COLUMN tier TEXT NOT NULL DEFAULT 'free';
UPDATE users SET tier = 'pro' WHERE stripe_subscription_id IS NOT NULL;

-- ON-STANDARD: schema first, data in a separate migration
-- migration 001 (schema):
ALTER TABLE users ADD COLUMN tier TEXT NOT NULL DEFAULT 'free';

-- migration 002 (data backfill — separate file, separate transaction):
UPDATE users SET tier = 'pro' WHERE stripe_subscription_id IS NOT NULL;
```

### Naming Conventions

Migration filenames must be sortable and self-describing:

```
{timestamp}_{verb}_{subject}.{direction}.sql

20250115120000_add_status_to_orders.up.sql
20250115120000_add_status_to_orders.down.sql
20250116090000_create_audit_logs_table.up.sql
20250117140000_backfill_user_tier.up.sql
```

Use Unix timestamps or ISO-format timestamps as the prefix. Never use sequential integers alone — they collide across branches.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Migration with no `down` | Cannot recover from a bad deploy; forces manual intervention | Always implement the reverse DDL |
| Modifying a committed migration file | Breaks checksum validation; creates divergence between environments | Create a new corrective migration |
| Bundling unrelated schema changes | One failure rolls back unrelated successful changes; harder to bisect problems | One logical change per migration file |
| `RENAME COLUMN` in a single migration on a live system | Running app instances still reference the old column name | Expand (add new column) → migrate data → contract (drop old column) |
| `CREATE INDEX` without `CONCURRENTLY` on a large table | Full table write lock; causes downtime or query pile-up | `CREATE INDEX CONCURRENTLY` in a separate migration outside a transaction |
| `UPDATE` millions of rows in a single migration transaction | Holds locks for the full duration; bloats WAL/undo log | Batch the update in application code or a separate batched migration |

## Deviation guidance

- **MAY** omit the `down` migration for migrations that create entirely new tables with no existing data dependency, provided the table drop is safe and documented.
- **MAY** combine schema and data in one migration for new tables being populated before first use (no live traffic to coordinate around).
- **MUST NOT** modify a migration file after it has been applied in staging or production, regardless of how trivial the change appears.
- **MUST NOT** run a schema migration and its dependent data migration as a single database transaction on large datasets — split them and batch the data migration.

## Compliance test

- [ ] Every migration file has a corresponding rollback migration (or the absence is explicitly documented with justification).
- [ ] No existing migration file has been modified after it was committed to the main branch.
- [ ] Each migration file contains one logical schema change — no bundling of unrelated DDL statements.
- [ ] Index creation on tables with more than 10,000 rows uses `CONCURRENTLY` (PostgreSQL) or the equivalent non-locking form for the target database.
- [ ] Data backfill migrations are in separate files from the schema changes that precede them.

## References

- [Evolutionary Database Design — Fowler & Sadalage](https://martinfowler.com/articles/evodb.html) — foundational treatment of migrations as executable history and the principle that the database schema is code
- [Expand-Contract pattern — Fowler](https://martinfowler.com/bliki/ParallelChange.html) — the additive-first, remove-later pattern for zero-downtime schema evolution
- [PostgreSQL: Building Indexes Concurrently](https://www.postgresql.org/docs/current/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY) — official documentation for non-locking index creation
