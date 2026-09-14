<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/backend/api-conventions.md and re-run profile-sync. -->
<!-- source: profile:webapp -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/webapp/standards/backend/api-conventions.md and re-run profile-sync. -->
# API Conventions Standards

Extends: [../../../default/standards/backend/api.md](../../../default/standards/backend/api.md)

## Overview

This document extends the default API standards with webapp-specific rules for Next.js 16+ App Router Route Handlers, Convex function typing, and Zod boundary validation. It covers the structural contracts that every Route Handler must satisfy — named HTTP method exports, a shared `ApiResponse<T>` envelope, and mandatory Zod validation at each writable boundary. Convex internal-tool functions must carry generated `Doc<>` and `Id<>` types throughout; `any` is never an acceptable document shape.

## Scope

**Covers:**
- Next.js Route Handler file structure and export conventions
- `ApiResponse<T>` shared response envelope definition and usage
- Convex query, mutation, and action typing with generated types
- Zod schema placement rules for Route Handlers

**Does NOT cover:**
- REST principles, HTTP verb semantics, status code mapping (see default/standards/backend/api.md)
- Database query and mutation patterns (see `queries.md`)
- Clerk session verification, middleware placement, and protected routes (see Clerk docs)
- Pagination, filtering, and sorting conventions (see default)

## Principles

1. **Validate at the boundary:** Every Route Handler that accepts a request body MUST parse and validate with Zod before any service call or database write. A handler that skips this step is incomplete, not merely imperfect.
2. **Typed responses end-to-end:** Route Handlers return `NextResponse<ApiResponse<T>>`. Convex functions are typed via the generated `Doc<>` and `Id<>` types. Using `any` for response shapes or Convex document fields is a violation.
3. **Named exports, never default:** Next.js App Router Route Handlers MUST use named HTTP method exports (`GET`, `POST`, `PATCH`, `DELETE`). A default export is not recognised by the App Router and silently breaks routing.
4. **Fail loudly at the edge:** Return structured `ApiResponse` error shapes (with `error` and optional `details`) at the earliest failure point. Never let a raw thrown error propagate to the client.

## Rules

### Next.js Route Handler structure

MUST export named HTTP method functions (`GET`, `POST`, `PATCH`, `DELETE`). Never use a default export. Each exported function MUST be typed with `NextRequest` as the parameter and return `Promise<NextResponse>`.

**OFF-STANDARD:**
```ts
// src/app/api/users/route.ts — BAD
export default async function handler(req: any, res: any) {
  res.json({ users: [] })
}
```

**ON-STANDARD:**
```ts
// src/app/api/users/route.ts — GOOD
import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { createUser } from '@/services/users'
import type { ApiResponse } from '@/types/api'

const CreateUserSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
})

export async function POST(
  request: NextRequest
): Promise<NextResponse<ApiResponse<{ id: string }>>> {
  const body = await request.json()
  const parsed = CreateUserSchema.safeParse(body)

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Validation failed', details: parsed.error.flatten() },
      { status: 400 }
    )
  }

  const user = await createUser(parsed.data)
  return NextResponse.json({ data: { id: user.id } }, { status: 201 })
}
```

### Shared response envelope

MUST use `ApiResponse<T>` for all Route Handler responses. Define it once in `src/types/api.ts` and import it everywhere. Never inline ad-hoc response shapes.

**Definition (`src/types/api.ts`):**
```ts
export interface ApiResponse<T = undefined> {
  data?: T
  error?: string
  details?: unknown
}
```

**Usage in a GET handler:**
```ts
// src/app/api/users/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server'
import type { ApiResponse } from '@/types/api'
import type { User } from '@/types/models'

export async function GET(
  _request: NextRequest,
  { params }: { params: { id: string } }
): Promise<NextResponse<ApiResponse<User>>> {
  const user = await getUserById(params.id)

  if (!user) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 })
  }

  return NextResponse.json({ data: user })
}
```

**Usage in an error response:**
```ts
return NextResponse.json(
  { error: 'Unauthorised' } satisfies ApiResponse,
  { status: 401 }
)
```

### Convex function typing

MUST type Convex queries and mutations using the generated `Doc<>` and `Id<>` types from `convex/_generated/dataModel`. MUST NOT use `any` for Convex document shapes or argument validators. Every argument accepted by a mutation or query MUST be declared with a `v.*` validator.

**OFF-STANDARD:**
```ts
// convex/users.ts — BAD
export const getUser = query(async ({ db }, { userId }: { userId: any }) => {
  return await db.get(userId)
})
```

**ON-STANDARD:**
```ts
// convex/users.ts — GOOD
import { query, mutation } from './_generated/server'
import { v } from 'convex/values'
import type { Doc, Id } from './_generated/dataModel'

export const getUser = query({
  args: { userId: v.id('users') },
  handler: async (ctx, { userId }): Promise<Doc<'users'> | null> => {
    return await ctx.db.get(userId)
  },
})

export const updateUserName = mutation({
  args: {
    userId: v.id('users'),
    name: v.string(),
  },
  handler: async (ctx, { userId, name }): Promise<Id<'users'>> => {
    await ctx.db.patch(userId, { name })
    return userId
  },
})
```

### Zod schema placement

MUST define Zod schemas in the same file as the Route Handler that uses them. Only extract a schema to a shared location (e.g., `src/lib/schemas/`) when it is consumed by three or more handlers. Avoid a global schemas barrel file that accumulates every schema regardless of usage.

**Correct placement (single-handler schema):**
```
src/app/api/
  users/
    route.ts          ← CreateUserSchema defined here, used only here
  projects/
    route.ts          ← CreateProjectSchema defined here, used only here
  invitations/
    route.ts          ← InviteSchema defined here, used only here
```

**Correct placement (shared schema, 3+ consumers):**
```
src/lib/schemas/
  email.ts            ← EmailSchema used by /users, /invitations, /waitlist
```

## Anti-patterns

| Anti-pattern | Why it is wrong | Correct approach |
|---|---|---|
| `export default async function handler` in a Route Handler file | Default exports are ignored by the Next.js App Router; routes silently return 404 | Export named HTTP method functions: `export async function POST` |
| Accepting a POST/PATCH body without Zod validation | Unvalidated input reaches services and the database; type safety breaks at runtime | Call `Schema.safeParse(body)` and return 400 on failure before any service call |
| Using `any` for Convex document types or argument validators | Defeats TypeScript's safety guarantees; Convex-generated types become unreliable | Use `Doc<'table'>`, `Id<'table'>`, and `v.*` validators throughout |
| Returning inline error strings (`{ message: 'oops' }`) instead of `ApiResponse` | Inconsistent response shapes break client-side error handling and type inference | Always return `{ error: string, details?: unknown }` using the `ApiResponse<T>` envelope |
| Defining the same Zod schema in multiple Route Handler files | Schema drift: identical fields diverge silently over time | Extract to `src/lib/schemas/` only when consumed by 3+ handlers; otherwise keep co-located |

## Deviation guidance

MAY skip Zod body validation on `GET` handlers that read exclusively from path params or search params (no request body). In that case, MUST still type path params explicitly using destructured `params` with a typed interface — never cast to `any`.

```ts
// Acceptable GET with typed params, no Zod body validation needed
export async function GET(
  _request: NextRequest,
  { params }: { params: { id: string } }
): Promise<NextResponse<ApiResponse<Project>>> {
  // params.id is typed as string from the route segment
}
```

MAY use Convex `action` (instead of `query`/`mutation`) when a Convex function must call a third-party API. Actions are not subject to the same transactional guarantees — document this explicitly with a comment in the source file.

## Profile inheritance notes

- **Extends:** `default/standards/backend/api.md`
- **Adds:** Next.js Route Handler named-export contract, `ApiResponse<T>` envelope definition and usage, Convex `Doc<>`/`Id<>`/`v.*` typing patterns, Zod boundary validation rule, schema co-location rule
- **Not overriding:** REST resource naming, HTTP method semantics, status code mapping, RFC 7807 error format, API versioning strategy (all remain in the default standard)

## Compliance test

- [ ] Every Route Handler file exports only named HTTP method functions — no default export present
- [ ] Every POST and PATCH handler calls `Schema.safeParse(body)` and returns a 400 response before reaching any service or database call
- [ ] Every Convex query and mutation declares argument validators using `v.*` and returns a type of `Doc<'table'>` or a primitive — no `any`
- [ ] All Route Handler responses use the `ApiResponse<T>` envelope from `src/types/api.ts`
- [ ] Zod schemas are defined in the handler file unless shared across three or more handlers, in which case they live under `src/lib/schemas/`

## References

- [default/standards/backend/api.md](../../../default/standards/backend/api.md)
- [Next.js Route Handlers — official docs](https://nextjs.org/docs/app/building-your-application/routing/route-handlers)
- [Zod — safeParse and error formatting](https://zod.dev/?id=safeparse)
- [Convex TypeScript — Doc and Id types](https://docs.convex.dev/database/types)
- [Convex argument validators — v.*](https://docs.convex.dev/functions/args-validation)
