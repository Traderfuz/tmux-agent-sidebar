<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/coding-style.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/coding-style.md and re-run profile-sync. -->
# Coding Style Standards

## Overview

Coding style is not a formatting preference sheet. It is the set of readability and maintainability constraints that make code review faster, refactors safer, and cross-language collaboration cheaper. A strong coding style standard keeps teams from arguing about taste in the diff and instead anchors decisions in clarity, consistency, and change safety.

## Scope

This standard covers naming, function shape, control flow, abstraction boundaries, and local code readability across the default profile. It does NOT cover formatter-specific whitespace rules, language-specific compiler settings, or validation and error-handling policy covered by adjacent standards.

## Principles

1. **Clarity over cleverness:** Prefer the version a competent teammate can understand in one reading over the version that is shorter or more novel.
2. **One level of abstraction at a time:** Keep functions and modules focused so readers are not forced to jump constantly between orchestration, parsing, storage, and presentation concerns.
3. **Consistency beats local optimization:** Once a codebase has an established pattern, the cost of a custom variation is usually higher than the gain from the variation.
4. **Names carry the first layer of documentation:** The best comment is often a better symbol name or a smaller function.

## Framework Basis

This standard combines four named frameworks:

- **ISO Scope Pattern:** keeps this document focused on code readability and structure rather than adjacent standards domains.
- **RFC 2119 Normative Vocabulary:** MUST/SHOULD/MAY language makes review decisions checkable.
- **Google/Airbnb Style Guide Hierarchy:** principles first, rules second, edge cases last.
- **Convention over Configuration:** prefer the established local pattern unless a deviation is justified explicitly.

## Rules

### Rule 1: Names MUST describe role and intent

Names must communicate what a thing is for, not just what type it happens to hold.

**OFF-STANDARD**

```typescript
const data = await fetchUser();
const tmp = normalize(data);

function handle(items: Item[]) {
  // ...
}
```

**ON-STANDARD**

```typescript
const rawUser = await fetchUser();
const normalizedUser = normalizeUser(rawUser);

function processOrderItems(items: Item[]) {
  // ...
}
```

Rules:

- Avoid generic names like `data`, `value`, `thing`, `tmp`, `misc`, `helper` unless the scope is genuinely tiny.
- Include units or meaning when relevant: `timeoutMs`, `retryCount`, `priceCents`, `userById`.
- Abbreviations are acceptable only when they are industry-standard and obvious to the team (`id`, `url`, `html`, `sql`).

### Rule 2: Functions MUST stay at one level of abstraction

A function should either orchestrate steps or implement one step in detail. It should not do both.

**OFF-STANDARD**

```typescript
async function createInvoice(order: Order) {
  if (!order.customerEmail) throw new Error("Missing email");

  const tax = order.subtotal * 0.15;
  const total = order.subtotal + tax;
  const html = `<h1>Invoice</h1><p>Total: ${total}</p>`;

  await db.invoices.insert({ orderId: order.id, total });
  await mailer.send({ to: order.customerEmail, subject: "Invoice", html });
}
```

**ON-STANDARD**

```typescript
async function createInvoice(order: Order) {
  assertInvoiceable(order);

  const invoice = buildInvoice(order);
  await saveInvoice(invoice);
  await sendInvoiceEmail(invoice);
}
```

If a reader needs to understand persistence details, pricing math, and rendering details inside one function, the function is too broad.

### Rule 3: Control flow SHOULD prefer guard clauses over deep nesting

Handle invalid or terminating cases early so the main path stays readable.

**OFF-STANDARD**

```python
def send_receipt(order):
    if order:
        if order.email:
            if order.status == "paid":
                return mailer.send(order.email)
    return None
```

**ON-STANDARD**

```python
def send_receipt(order):
    if not order:
        return None
    if not order.email:
        return None
    if order.status != "paid":
        return None
    return mailer.send(order.email)
```

Nested branching is acceptable when the nesting itself represents the domain structure, but not when it merely hides the happy path.

### Rule 4: Repetition SHOULD trigger extraction only after the pattern is real

Do not abstract after one use. Extract once the repetition is meaningful and stable.

**OFF-STANDARD**

```typescript
function runUserOperation<T>(fn: () => Promise<T>) {
  return fn();
}
```

**ON-STANDARD**

```typescript
async function createUser(input: CreateUserInput) {
  validateCreateUserInput(input);
  return db.users.insert(input);
}
```

```typescript
async function updateUser(input: UpdateUserInput) {
  validateUpdateUserInput(input);
  return db.users.update(input.id, input);
}
```

Extract the shared path only after the duplication reveals a durable common contract.

### Rule 5: Modules MUST expose a coherent responsibility

A file or module should be organized around one reason to change.

**OFF-STANDARD**

```typescript
// user-utils.ts
export function validateUser() {}
export async function saveUser() {}
export function renderUserCard() {}
export function trackUserAnalytics() {}
```

**ON-STANDARD**

```typescript
// user-validation.ts
export function validateUser() {}

// user-repository.ts
export async function saveUser() {}

// UserCard.tsx
export function UserCard() {}
```

Small files are not the goal by themselves; coherent files are.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Generic names like `data`, `helper`, `processThing` in broad scopes | Forces the reader to infer meaning from implementation details | Name by role, entity, and intent |
| Functions that validate, transform, persist, and render in one body | Mixes abstraction levels and raises change risk | Split orchestration from detailed steps |
| Deep nesting of conditionals | Hides the happy path and complicates reasoning | Use guard clauses for early exits |
| Premature helper extraction after one duplication | Creates abstractions with no stable contract | Wait for a real repeated pattern |
| Utility dumping grounds (`utils.ts`, `helpers.ts`) | Becomes a junk drawer with no ownership boundary | Organize by domain or responsibility |

## Deviation Guidance

- Teams MAY keep a small amount of local duplication when extracting an abstraction would obscure the intent more than the duplication costs.
- Teams MAY use a broader module when the platform requires colocation, such as framework route files or worker entrypoints, provided internal helper functions preserve readable structure.
- Teams MUST NOT introduce abbreviations that are specific to one developer or one ticket.
- Teams MUST NOT hide complex logic behind generic names like `handle`, `process`, or `run` when a more specific name is available.

## Related Standards

- `type-checking.md` for type safety policy
- `validation.md` for boundary validation rules
- `commenting.md` for when code needs explanation beyond naming
- `modular-integration.md` for module boundary design

## Compliance Test

- [ ] Do names communicate role and intent without needing adjacent comments?
- [ ] Does each function stay at one level of abstraction rather than mixing orchestration and detailed implementation?
- [ ] Is the happy path readable without navigating deep nested branches?
- [ ] Are abstractions extracted only after a real repeated pattern exists?
- [ ] Does each module expose a coherent responsibility rather than acting as a general dumping ground?
