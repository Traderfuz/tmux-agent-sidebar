<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/backend/models.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/backend/models.md and re-run profile-sync. -->
# Model Standards

## Overview

The model layer is where the domain's data shape is defined and its invariants are enforced. An application that validates only in code — without corresponding database constraints — is one deployment bug away from corrupt data. Models that use the database's own constraint system (NOT NULL, UNIQUE, foreign keys) ensure correctness regardless of which code path writes a row, including migrations, admin scripts, and direct database access.

## Scope

This standard covers data model definitions, field naming and typing, required constraints, relationship definitions, index requirements, and timestamp conventions.

It does NOT cover query patterns (see `queries.md`) or migration scripts for applying model changes (see `migrations.md`).

## Principles

1. **Constraints at the database level:** Invariants that must always hold — required fields, uniqueness, referential integrity — are expressed as database constraints, not only as application-layer validation.
2. **Timestamps on everything:** Every table that represents a mutable entity carries `created_at` and `updated_at`. These are non-optional; absence makes debugging and auditing significantly harder.
3. **Naming follows domain language:** Model and field names use the terminology the business uses, not technical abbreviations or generic names. A shared vocabulary between code and conversation (ubiquitous language) is load-bearing infrastructure.

## Rules

### Model and Table Naming

- Model/class names use PascalCase singular nouns: `User`, `OrderLine`, `PaymentMethod`.
- Table names use snake_case plural nouns: `users`, `order_lines`, `payment_methods`.
- Junction/join tables use both entity names in alphabetical order: `role_users`, `tag_posts`.
- Never abbreviate: `usr`, `acct`, `cfg` make code searches unreliable and violate the ubiquitous language principle.

```typescript
// OFF-STANDARD: abbreviated, wrong case, generic name
// Table: usr_acct | Class: UserAcct
class UserAcct {
  id: number;
  nm: string;      // What is "nm"?
  ts: Date;        // "ts" could be any timestamp
}

// ON-STANDARD: singular class, plural table, domain vocabulary
// Table: users
class User {
  id: string;
  display_name: string;
  email: string;
  created_at: Date;
  updated_at: Date;
}
```

### Required Timestamps

Every table representing a mutable entity MUST include both timestamps. Read-only lookup/reference tables are the only exception.

```typescript
// OFF-STANDARD: no timestamps — no audit trail, debugging is guesswork
// Drizzle schema definition
export const orders = pgTable('orders', {
  id: serial('id').primaryKey(),
  total_cents: integer('total_cents').notNull(),
  status: text('status').notNull(),
});

// ON-STANDARD: timestamps on every mutable table
export const orders = pgTable('orders', {
  id: serial('id').primaryKey(),
  total_cents: integer('total_cents').notNull(),
  status: text('status').notNull().default('pending'),
  created_at: timestamp('created_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
  updated_at: timestamp('updated_at', { withTimezone: true })
    .notNull()
    .defaultNow(),
});
```

Use `TIMESTAMPTZ` (timestamp with time zone) in PostgreSQL. Never `TIMESTAMP WITHOUT TIME ZONE` on a system with any geographic distribution.

### NOT NULL Constraints on Required Fields

If a field is required for the entity to be meaningful, it must carry a `NOT NULL` constraint at the database level. Application-layer checks alone are insufficient — they are bypassed by migrations, scripts, and future code paths.

```typescript
// OFF-STANDARD: nullable fields that the application treats as required
export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: text('email'),          // nullable — any script can omit it
  display_name: text('display_name'),  // nullable — corrupts display logic
});

// ON-STANDARD: NOT NULL for all required fields
export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: text('email').notNull().unique(),
  display_name: text('display_name').notNull(),
  avatar_url: text('avatar_url'),   // nullable: genuinely optional field
  created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
```

### Foreign Key Constraints

Every foreign key column MUST have a database-level foreign key constraint. Relying only on application code to maintain referential integrity creates orphaned records.

```typescript
// OFF-STANDARD: no FK constraint — orphaned rows accumulate silently
export const orders = pgTable('orders', {
  id: serial('id').primaryKey(),
  user_id: integer('user_id'),   // no FK constraint
});

// ON-STANDARD: FK constraint with explicit cascade behavior
export const orders = pgTable('orders', {
  id: serial('id').primaryKey(),
  user_id: integer('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updated_at: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
```

Cascade behavior must be explicit and deliberate:

| Behavior | When to use |
|----------|------------|
| `CASCADE` | Child rows have no meaning without the parent (e.g., `order_lines` without an `order`) |
| `SET NULL` | Child rows can exist without the parent but should lose the reference (e.g., `posts` when an author is soft-deleted) |
| `RESTRICT` / `NO ACTION` | Parent must not be deleted while children exist — requires application-level handling |

### Index on FK Columns

Every foreign key column must be indexed. Without an index, any query joining or filtering on the FK performs a full table scan.

```typescript
// OFF-STANDARD: FK with no index
export const orders = pgTable('orders', {
  id: serial('id').primaryKey(),
  user_id: integer('user_id').notNull().references(() => users.id),
});

// ON-STANDARD: index declared alongside the FK
export const orders = pgTable(
  'orders',
  {
    id: serial('id').primaryKey(),
    user_id: integer('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
    created_at: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updated_at: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => ({
    userIdIdx: index('orders_user_id_idx').on(table.user_id),
  })
);
```

Also index columns that appear frequently in WHERE clauses or ORDER BY in known query patterns.

### Relationship Definitions

Relationships must be defined in both directions when the ORM supports it, with explicit names that reflect the domain.

```typescript
// OFF-STANDARD: implicit, unnamed relationship
// (Prisma style)
model Order {
  id     Int    @id @default(autoincrement())
  items  OrderItem[]
}

// ON-STANDARD: explicit naming, clear ownership
model Order {
  id          Int         @id @default(autoincrement())
  userId      Int
  user        User        @relation("UserOrders", fields: [userId], references: [id], onDelete: Cascade)
  lineItems   OrderItem[] @relation("OrderLineItems")
  createdAt   DateTime    @default(now())
  updatedAt   DateTime    @updatedAt
}

model OrderItem {
  id        Int   @id @default(autoincrement())
  orderId   Int
  order     Order @relation("OrderLineItems", fields: [orderId], references: [id], onDelete: Cascade)
  @@index([orderId])
}
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Nullable required fields (no `NOT NULL`) | Scripts, migrations, and future code paths bypass app-level validation; corrupt rows accumulate | Add `NOT NULL` constraint at the database level |
| FK column without FK constraint | Orphaned child rows silently accumulate; joins return wrong results | Declare the foreign key constraint with explicit cascade behavior |
| FK column without index | Full table scan on every join or filter on that column | Add an index alongside every FK declaration |
| Generic field names (`data`, `info`, `value`, `meta`) | Fields are not self-documenting; violates ubiquitous language; slows onboarding | Use domain-specific names (`shipping_address_json`, `stripe_metadata`) |
| `TIMESTAMP` without timezone | Silent data corruption across timezone boundaries | Always use `TIMESTAMPTZ` / `timestamp with time zone` |
| No `updated_at` | Cannot determine when a row last changed; makes cache invalidation and debugging guesswork | Add `updated_at` with an auto-update trigger or ORM hook |
| Abbreviating model/field names | Breaks codebase search; violates shared vocabulary; `usr_acct_cfg` is not a domain concept | Use full words: `user_account_configuration` |

## Deviation guidance

- **MAY** omit `updated_at` on append-only tables (e.g., event logs, audit trails) where rows are never modified after insert.
- **MAY** use a single `metadata JSONB` field for genuinely dynamic, schema-less attributes — but the column must be named clearly and its allowed shape must be documented in a code comment.
- **MUST NOT** use the database as a key-value store by storing serialized JSON in `TEXT` columns for structured data that has a known, stable shape.
- **MUST NOT** omit foreign key constraints in favor of "we validate this in the application" — this argument does not survive the first migration script.

## Compliance test

- [ ] Every model/table uses a singular PascalCase class name and plural snake_case table name.
- [ ] Every mutable table has `created_at TIMESTAMPTZ NOT NULL` and `updated_at TIMESTAMPTZ NOT NULL`.
- [ ] All required fields carry `NOT NULL` at the database level, not only in application validation.
- [ ] Every foreign key column has a declared FK constraint with an explicit `onDelete` behavior.
- [ ] Every foreign key column has a corresponding database index.

## References

- [Domain-Driven Design — Eric Evans](https://www.domainlanguage.com/ddd/) — ubiquitous language principle: model names come from the business domain, not from technical convenience
- [Database Normalization — Third Normal Form (3NF)](https://en.wikipedia.org/wiki/Third_normal_form) — foundational principle for eliminating data anomalies through proper field decomposition
- [PostgreSQL: Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html) — official reference for NOT NULL, UNIQUE, CHECK, and FOREIGN KEY constraints
- [Prisma Data Modeling](https://www.prisma.io/docs/concepts/components/prisma-schema/data-model) — concrete ORM example of relationship and constraint declaration patterns
