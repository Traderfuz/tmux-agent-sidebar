<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/backend/api.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/backend/api.md and re-run profile-sync. -->
# API Standards

## Overview

A REST API is a contract between the server and every client that will ever consume it. Consistent endpoint design — predictable URLs, correct HTTP method semantics, and a uniform response envelope — reduces the surface area for client-side misinterpretation, makes SDK generation reliable, and lets teams evolve services without breaking consumers. Stability and clarity in API shape are engineering discipline, not aesthetics.

## Scope

This standard covers REST endpoint naming, HTTP method selection, API versioning strategy, query parameter conventions, HTTP status code selection, and the structure of success and error response envelopes.

It does NOT cover authentication (see `auth.md`), rate limiting implementation, request body schema validation, or WebSocket/streaming API design.

## Principles

1. **Resources not actions:** URLs identify things (nouns), not operations. The HTTP method communicates what to do with the thing.
2. **URLs are stable contracts:** Once a versioned URL is published to consumers, its shape MUST NOT change without a version increment. Clients cannot be forced to update on your schedule.
3. **Method communicates intent:** GET is always safe and idempotent. PUT and PATCH are idempotent. POST is neither. Violating HTTP semantics forces clients to treat every call as a black box.

## Rules

### Resource Naming

- Use plural nouns for collection endpoints: `/users`, `/orders`, `/invoices`.
- Use kebab-case for multi-word resources: `/payment-methods`, `/line-items`.
- Nest resources only when the child is genuinely owned by the parent and has no independent existence. Limit nesting to two levels.
- Never encode verbs in URLs. The method is the verb.

```typescript
// OFF-STANDARD: verb in URL, camelCase, action suffix
GET /getUser/123
POST /createOrder
GET /user_payment_methods

// ON-STANDARD: plural noun, kebab-case, nesting where ownership is clear
GET    /users/123
POST   /orders
GET    /users/123/payment-methods
```

### HTTP Method Semantics

| Method | Semantics | Idempotent | Safe |
|--------|-----------|-----------|------|
| GET | Retrieve resource(s) | Yes | Yes |
| POST | Create a new resource | No | No |
| PUT | Replace a resource entirely | Yes | No |
| PATCH | Partially update a resource | Yes | No |
| DELETE | Remove a resource | Yes | No |

Never use GET to trigger state changes. Never use POST where PUT or PATCH is correct.

### Versioning Strategy

- Include the major version in the URL path: `/v1/users`, `/v2/orders`.
- Increment the major version only on breaking changes (removed fields, changed semantics, renamed resources).
- Additive changes (new optional fields, new endpoints) do not require a version bump.
- Maintain at least one prior major version in production for a deprecation window (minimum 90 days).

```typescript
// OFF-STANDARD: no versioning, breaking changes silently deployed
GET /users/123

// ON-STANDARD: versioned path
GET /v1/users/123
GET /v2/users/123   // new shape, old shape still served at /v1
```

### Query Parameters

- Use query parameters for filtering, sorting, pagination, and search. Never create separate endpoints for these.
- Pagination: `?page=2&per_page=25` or `?cursor=<token>&limit=25` (cursor preferred for large datasets).
- Filtering: `?status=active&role=admin` (flat, not nested query strings).
- Sorting: `?sort=created_at&order=desc`.

```typescript
// OFF-STANDARD: filter logic baked into separate endpoints
GET /users/active
GET /users/admins

// ON-STANDARD: composable query params
GET /v1/users?status=active&role=admin&sort=created_at&order=desc&page=1&per_page=25
```

### HTTP Status Codes

Always return a status code whose meaning matches the actual outcome. Never return 200 with an error body.

| Situation | Code |
|-----------|------|
| Successful GET, PATCH, PUT | 200 |
| Successful POST (resource created) | 201 |
| Successful DELETE or async-accepted | 204 / 202 |
| Validation error, malformed request | 400 |
| Missing or invalid credentials | 401 |
| Valid credentials but insufficient permissions | 403 |
| Resource not found | 404 |
| Method not allowed for this resource | 405 |
| Conflict (e.g. duplicate unique field) | 409 |
| Unprocessable entity (semantic validation) | 422 |
| Server error | 500 |

### Response Envelope

Success responses return the resource or a collection directly. Error responses MUST follow a consistent envelope so clients can parse errors generically.

```typescript
// OFF-STANDARD: inconsistent, no machine-readable error code
// HTTP 200
{ "success": false, "msg": "not found" }

// ON-STANDARD: success — return the resource directly
// HTTP 200
{
  "id": "usr_01HX",
  "email": "alice@example.com",
  "created_at": "2025-01-15T08:00:00Z"
}

// ON-STANDARD: error — RFC 7807 Problem Details envelope
// HTTP 422
{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Validation Error",
  "status": 422,
  "detail": "The 'email' field must be a valid email address.",
  "instance": "/v1/users",
  "errors": [
    { "field": "email", "code": "invalid_format", "message": "Not a valid email." }
  ]
}
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `POST /getUser` | Verb in URL; GET semantics via POST hides intent from proxies and caches | `GET /v1/users/{id}` |
| `GET /users?action=delete` | Safe method triggering state change; breaks caches and crawlers | `DELETE /v1/users/{id}` |
| `HTTP 200` with `{ "error": "not found" }` | Clients cannot use status codes for routing; defeats HTTP | `HTTP 404` with RFC 7807 body |
| `/userList`, `/getAllOrders` | Mixed conventions break client code generation and documentation | `/v1/users`, `/v1/orders` |
| `/users/123/address/country/city` | Deep nesting creates fragile coupling; country is not a resource | `/v1/users/123/address?include=country,city` |
| No versioning on first release | Adding versioning later requires all clients to update simultaneously | Start at `/v1/` from day one |

## Deviation guidance

- **MAY** use `POST` for complex search operations where the filter payload exceeds URL length limits, provided the endpoint name makes this explicit (e.g., `/v1/orders/search`) and the operation is documented as non-mutating.
- **MAY** omit the versioning prefix for purely internal APIs that have a single known consumer within the same deploy boundary — document this explicitly.
- **MUST NOT** return different envelope shapes for different endpoints within the same API version. Inconsistent envelopes break generic error handling in clients.
- **MUST NOT** break a published versioned URL without incrementing the major version, regardless of how minor the change appears.

## Compliance test

- [ ] All collection endpoints use plural nouns and kebab-case (no verbs, no camelCase in the path).
- [ ] Every endpoint has a major version prefix (`/v1/`, `/v2/`).
- [ ] No GET endpoint triggers a state change; POST/PUT/PATCH/DELETE are used for mutations.
- [ ] All error responses use the RFC 7807 envelope with `type`, `title`, `status`, and `detail` fields.
- [ ] HTTP status codes match the actual outcome — no 200 responses with error bodies.

## References

- [Google AIP-122: Resource names](https://aip.dev/122) — canonical naming rules for resource-oriented APIs, including plural nouns and kebab-case
- [RFC 7231: HTTP/1.1 Semantics](https://datatracker.ietf.org/doc/html/rfc7231) — definitive reference for HTTP method semantics and status code meanings
- [RFC 7807: Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807) — the error envelope format used in the Rules section above
- [Google AIP-158: Pagination](https://aip.dev/158) — cursor and page-based pagination conventions
