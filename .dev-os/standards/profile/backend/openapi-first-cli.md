<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/backend/openapi-first-cli.md and re-run profile-sync. -->
# CLI Profile — OpenAPI-First for CLI APIs

Extends: `profiles/cli/standards/backend/api-conventions-cli.md`

## Overview

Not every CLI API needs an OpenAPI spec. This standard defines when to use OpenAPI for CLI-hosted APIs versus when an informal JSON contract suffices — and what to do when you do adopt OpenAPI.

---

## Decision Rule: When to Use OpenAPI

| Situation | Use OpenAPI? |
|---|---|
| API consumed only by the same CLI tool (internal) | No — JSON contract in code is enough |
| API consumed by multiple CLI tools in the same project | No — shared TypeScript types suffice |
| API is an MCP server (tool discovery) | No — MCP protocol defines the schema contract |
| API is exposed to external consumers or third-party tools | **Yes** |
| API surface will be versioned and maintained long-term | **Yes** |
| API will have generated clients (SDK, typed clients) | **Yes** |

**Default posture for CLI profile:** informal contract. Adopt OpenAPI only when external consumption or long-term maintenance is confirmed.

---

## Rules (when OpenAPI is adopted)

### Rule 1: OpenAPI spec MUST be the source of truth

Generate types and validation from the spec — do not write the spec after the code.

```bash
# ON-STANDARD — spec-first
openapi.yml → generate types → implement handlers
              └─ validate responses against spec in tests

# OFF-STANDARD — code-first
implement handlers → export types → write spec as documentation
```

### Rule 2: Spec file MUST live at `openapi.yml` in the project root or `api/openapi.yml`

```
project/
├── openapi.yml       # preferred location
├── api/
│   └── openapi.yml  # acceptable when api/ is the API package root
```

### Rule 3: Paths MUST use kebab-case, parameters MUST use camelCase

```yaml
# ON-STANDARD
paths:
  /tool-results/{toolId}:
    get:
      parameters:
        - name: toolId

# OFF-STANDARD
paths:
  /toolResults/{tool_id}:
```

### Rule 4: CLI APIs MUST NOT require OAuth flows in OpenAPI security schemes for local use

If the API has an auth opt-in (see `api-conventions-cli.md` Rule 3), document it as optional:

```yaml
security: []   # empty = no auth required by default
components:
  securitySchemes:
    bearerToken:
      type: http
      scheme: bearer
      description: "Optional. Enable via CLI_API_AUTH=1"
```

---

## Informal Contract (no OpenAPI)

When OpenAPI is not adopted, document the API contract in a `docs/api.md` or inline TypeScript types:

```typescript
// Sufficient for internal CLI API
interface ToolListResponse {
  ok: true
  tools: Array<{ name: string; description: string; inputSchema: object }>
}

interface ErrorResponse {
  ok: false
  error: string   // snake_case error code
  message: string
  hint?: string
}
```

This is the default — do not reach for OpenAPI prematurely.

---

## Compliance Test

- [ ] If API is internal-only: no OpenAPI spec required; JSON/TS contract documented?
- [ ] If OpenAPI adopted: spec is the source of truth (not post-hoc docs)?
- [ ] Spec file lives at `openapi.yml` or `api/openapi.yml`?
- [ ] Local auth opt-in is not a required OAuth flow in the OpenAPI security scheme?
