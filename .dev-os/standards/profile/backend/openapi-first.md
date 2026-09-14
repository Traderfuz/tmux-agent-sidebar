<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/backend/openapi-first.md and re-run profile-sync. -->
# OpenAPI-First API Standards

## Overview

An API without a machine-readable contract accumulates integration debt silently. Every consumer — a CLI tool, a frontend, a partner integration, an AI agent — must reverse-engineer the surface from code, docs, or trial and error. OpenAPI eliminates that debt by making the contract explicit, versioned, and automatically exploitable. This standard ensures every HTTP API project in this organisation maintains an OpenAPI 3.x specification that is always current, always valid, and always ready for tooling consumption.

## Scope

This standard covers OpenAPI specification authoring for HTTP API projects across all supported stacks. It does NOT cover request/response body schema design, authentication implementation, or non-HTTP protocols (GraphQL, gRPC, WebSocket, tRPC).

## Principles

1. **Contract before consumer:** The spec is the authoritative description of the API — not the README, not the code, not the Postman collection. When the code and the spec disagree, the spec wins and the code is wrong.
2. **Zero-friction CLI generation:** Every project MUST be consumable by `devos-cli-creator --spec` without manual intervention. A spec that cannot generate a CLI is incomplete.
3. **operationId is an API contract:** Operation IDs become CLI command names, SDK method names, and changelog entries. They must be stable, kebab-case, and human-meaningful — not auto-generated hashes.
4. **Tags are the grouping contract:** Tags become CLI command groups, SDK namespaces, and documentation sections. Every operation must declare its group.
5. **Spec lives in source control:** The spec file is a first-class source artifact, not a generated artifact in `.gitignore`. It is reviewed in PRs, versioned with the codebase, and blocked from merging when invalid.

## Approach: spec-first vs code-first

Both approaches are acceptable. The outcome requirement is the same: a valid, current `openapi.yml` in the repository root (or `docs/openapi.yml` for monorepos).

### Spec-first (recommended for new projects)

Write the `openapi.yml` before implementing routes. Use it to drive the implementation. The spec is the source of truth; routes are its implementation.

**When to use:** New projects, API redesigns, any project where the team controls both sides of the contract.

**Toolchain:** `redocly cli` for linting and bundling; `openapi-generator` for stub generation.

### Code-first with auto-generation (acceptable for existing projects)

Annotate routes; a framework plugin emits the spec at build/dev time. The code is the source of truth; the spec is a derived artifact — but it MUST be committed and kept current.

**When to use:** Existing projects adding OpenAPI retroactively; projects where spec-first would require a full rewrite.

**Critical constraint:** The auto-generated spec MUST be committed to source control and MUST pass CI validation. A spec that only exists at runtime is not a spec.

## Per-stack tooling

### Next.js (App Router)

**Recommended:** `ts-rest` — define contracts as TypeScript; auto-generates both server router and OpenAPI spec from a single contract file. One source of truth, no annotation drift.

```bash
npm install @ts-rest/core @ts-rest/next @ts-rest/open-api
```

Contract file (`lib/contract.ts`) becomes the spec source. Generate spec:
```typescript
import { generateOpenApi } from '@ts-rest/open-api';
import { contract } from './lib/contract';

export const openApiDocument = generateOpenApi(contract, {
  info: { title: 'My API', version: '1.0.0' },
});
```

**Alternative:** `next-openapi-gen` for annotation-based generation from existing routes.

### FastAPI (Python)

Built-in — no additional tooling required. FastAPI generates OpenAPI 3.x automatically.

```python
from fastapi import FastAPI

app = FastAPI(
    title="My API",
    version="1.0.0",
    openapi_url="/openapi.json",
)
```

Export spec to file for CI validation and source control:
```bash
python -c "import json, app; print(json.dumps(app.app.openapi()))" > openapi.json
```

Add to CI: commit the exported `openapi.json` on every build. Diff in PR shows API surface changes.

### Express / Node.js

**Recommended:** `tsoa` — TypeScript decorators on controllers emit spec + validated routes.

```bash
npm install tsoa
```

```typescript
@Route('users')
@Tags('users')
export class UsersController extends Controller {
  @Get('{id}')
  @OperationId('get-user')
  public async getUser(@Path() id: string): Promise<User> { ... }
}
```

Generate spec: `tsoa spec` → `openapi.json`. Routes: `tsoa routes`.

**Alternative:** `express-openapi-validator` for validation-first without codegen.

### Go (Gin / Chi / net/http)

**Recommended:** `swaggo/swag` — annotation-based generation.

```bash
go install github.com/swaggo/swag/cmd/swag@latest
```

```go
// @Summary Get user by ID
// @Tags users
// @Produce json
// @Param id path string true "User ID"
// @Success 200 {object} User
// @Router /users/{id} [get]
// @ID get-user
func GetUser(c *gin.Context) { ... }
```

Generate: `swag init` → `docs/swagger.json`.

### Rust (Axum / Actix-web)

**Recommended:** `utoipa` — proc-macro annotations.

```toml
[dependencies]
utoipa = { version = "4", features = ["axum_extras"] }
utoipa-swagger-ui = { version = "7", features = ["axum"] }
```

```rust
#[utoipa::path(
    get,
    path = "/users/{id}",
    tag = "users",
    operation_id = "get-user",
    responses((status = 200, body = User))
)]
async fn get_user(Path(id): Path<String>) -> impl IntoResponse { ... }
```

Generate spec: `utoipa::gen::OpenApi` derive on the app struct.

## operationId requirements

`operationId` MUST be present on every operation. It is the stable identifier used by CLI generators, SDK generators, and changelog tooling.

**Format:** `kebab-case`, `{verb}-{resource}` pattern, unique across the entire spec.

```yaml
# OFF-STANDARD
paths:
  /users/{id}:
    get:
      summary: Get user
      # no operationId — generates ugly fallback names

# OFF-STANDARD
paths:
  /users/{id}:
    get:
      operationId: getUserById_v2_FINAL   # not kebab-case, not stable

# ON-STANDARD
paths:
  /users/{id}:
    get:
      operationId: get-user
      tags: [users]
      summary: Get user by ID
```

**Naming pattern:**

| HTTP method | Resource | operationId |
|-------------|----------|-------------|
| GET collection | leads | `list-leads` |
| GET single | leads | `get-lead` |
| POST create | leads | `create-lead` |
| PUT replace | leads | `update-lead` |
| PATCH partial | leads | `patch-lead` |
| DELETE | leads | `delete-lead` |
| POST action | leads/enrich | `enrich-lead` |

## Tags requirements

Every operation MUST declare at least one tag. Tags map to CLI command groups and documentation sections.

```yaml
# OFF-STANDARD
paths:
  /leads:
    get:
      operationId: list-leads
      # no tags — all commands land in 'misc' group

# ON-STANDARD
paths:
  /leads:
    get:
      operationId: list-leads
      tags: [leads]
      summary: List leads
```

Tag names: lowercase, hyphen-separated, matching the URL resource segment. Declare all tags at the spec root:

```yaml
tags:
  - name: leads
    description: Lead management
  - name: clients
    description: Client management
```

## CI validation

Every project MUST run spec validation on every pull request. Choose one:

### Redocly CLI (recommended)

```bash
npm install -g @redocly/cli
redocly lint openapi.yml
```

GitHub Actions:
```yaml
- name: Validate OpenAPI spec
  run: npx @redocly/cli lint openapi.yml
```

Configure rules in `redocly.yaml`:
```yaml
apis:
  main:
    root: openapi.yml
rules:
  operation-operationId: error
  operation-tag-defined: error
  no-unused-components: warn
```

### Spectral (alternative)

```bash
npm install -g @stoplight/spectral-cli
spectral lint openapi.yml --ruleset @stoplight/spectral-oas
```

**Minimum required rules (both tools):**
- `operation-operationId` → **error** (not warn)
- `operation-tag-defined` → **error**
- `info-contact` → warn
- `no-unused-components` → warn

## devos-cli-creator integration

A spec passing CI validation MUST be consumable by `devos-cli-creator --spec` without flags or manual intervention:

```bash
devos-cli-creator \
  --spec ./openapi.yml \
  --name my-api \
  --lang python \
  --output ./my-api-cli
```

**Verification command** — add to Makefile or `package.json` scripts:
```bash
devos-cli-creator --spec ./openapi.yml --name smoke-test --lang python --output /tmp/smoke-test-cli --no-skill
```

Run this as a post-CI step to confirm the spec is CLI-generator-ready. Zero-commands output (empty spec, missing operationIds) is a hard failure.

**What makes a spec CLI-generator-ready:**
- `info.title` and `info.version` present
- At least one `servers` entry with a non-empty URL
- All operations have `operationId` (kebab-case)
- All operations have at least one `tags` entry
- No unresolved `$ref` paths

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Spec only exists at runtime (`/openapi.json` endpoint, not committed) | CI can't validate it; PRs don't show API surface changes; breaks offline tooling | Export spec to file and commit it |
| `operationId: getUserV2FINAL` | Not kebab-case; breaks CLI command naming; implies instability | `operationId: get-user` — stable, kebab-case |
| Operations with no `tags` | All commands land in the `misc` group; CLI is unusable | Every operation gets at least one tag matching its resource |
| Spec committed but not in CI lint | Spec drifts silently from code; only discovered when tooling fails | `redocly lint` or `spectral lint` as required CI check |
| Separate spec and implementation with no generation link | Spec drifts from code; two sources of truth | Use a framework that generates or validates the spec from code |
| `tags: [ApiV2, Users, GET]` | Verbose, inconsistent, maps to noisy CLI groups | `tags: [users]` — resource name only, lowercase, singular or plural consistently |

## Deviation guidance

**MAY** omit the spec for purely internal server-to-server APIs (no human consumers, no CLI needed, traffic stays within a private VPC). MUST document the omission in the project README with the reason.

**MAY** use a runtime-only spec (not committed) during active API design sprints. MUST commit and enable CI validation before merging to the main branch.

**MAY** split a large API into multiple spec files using `$ref` bundling (Redocly's multi-file format). MUST provide a single bundled `openapi.yml` at the repo root for tooling consumption.

## Compliance test

- [ ] Repository contains an `openapi.yml` (or `docs/openapi.yml`) committed to source control?
- [ ] Every operation in the spec has a `operationId` in kebab-case (`{verb}-{resource}` pattern)?
- [ ] Every operation has at least one `tags` entry?
- [ ] CI runs `redocly lint` or `spectral lint` with `operation-operationId: error`?
- [ ] `devos-cli-creator --spec ./openapi.yml --name test --lang python --output /tmp/test --no-skill` exits 0 and produces at least one command group?
- [ ] Framework tooling is configured to generate or validate the spec automatically (not manually maintained)?

If any check fails: either fix it or record the deviation in the project README with the reason and the date by which it will be resolved.

## References

- [OpenAPI Specification 3.x](https://spec.openapis.org/oas/v3.1.0) — the normative spec definition
- [Google AIP-122 Resource Names](https://google.aip.dev/122) — naming patterns for operationId and resource grouping
- [Redocly CLI Rules](https://redocly.com/docs/cli/rules/) — linting rule reference
- [Stoplight Spectral OAS Ruleset](https://github.com/stoplightio/spectral/blob/develop/packages/rulesets/src/oas/index.ts) — alternative CI validator
- [ts-rest documentation](https://ts-rest.com) — contract-first TypeScript approach for Next.js
- [tsoa documentation](https://tsoa-community.github.io/docs/) — decorator-based OpenAPI generation for Express
- [swaggo/swag](https://github.com/swaggo/swag) — Go annotation-based generation
- [utoipa](https://github.com/juhaku/utoipa) — Rust proc-macro OpenAPI generation
