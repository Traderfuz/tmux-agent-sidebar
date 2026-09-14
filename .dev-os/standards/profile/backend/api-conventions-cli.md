<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/backend/api-conventions-cli.md and re-run profile-sync. -->
# CLI Profile — API Conventions

Extends: `profiles/default/standards/global/tech-stack.md`

## Overview

CLI tools increasingly expose API surfaces: daemon processes, local servers, MCP tool servers, and agent backends. These differ from webapp APIs in one critical way — **the primary consumer is another program, not a browser session**. This standard defines the API shape, error format, and local-first posture for APIs built by CLI-profile projects.

For MCP-specific conventions (tool discovery, SSE transport, JSON-RPC), also read `profiles/cloudflare-workers/standards/global/tech-stack.md` and the MCP protocol spec.

---

## Principles

1. **Local-first by default.** A CLI API should work offline, run without a remote database, and avoid requiring auth setup for local development.
2. **Program-to-program contract.** Responses must be machine-parseable. Human-friendly formatting belongs in the CLI layer on top, not in the API.
3. **Fail loud, fail fast.** A CLI API running in the same process tree as the user's shell has no graceful degradation requirement — return a clear error immediately rather than retrying silently.

---

## Rules

### Rule 1: All API responses MUST be JSON

No HTML error pages. No plain-text bodies. Every endpoint — including errors — returns `Content-Type: application/json`.

```typescript
// ON-STANDARD
{ "ok": true, "data": { ... } }
{ "ok": false, "error": "config_missing", "message": "No .dev-os/config.yml found", "hint": "Run devos init" }

// OFF-STANDARD
"Error: config not found"   // plain text
<html>500 Internal Server</html>  // HTML
```

### Rule 2: Error responses MUST include `error`, `message`, and `hint`

| Field | Type | Required | Description |
|---|---|---|---|
| `ok` | boolean | Yes | Always `false` for errors |
| `error` | string | Yes | Machine-readable error code (snake_case) |
| `message` | string | Yes | Human-readable explanation |
| `hint` | string | No | Actionable next step |
| `details` | object | No | Structured context (file path, line number, etc.) |

```typescript
// ON-STANDARD
{
  "ok": false,
  "error": "spec_not_found",
  "message": "No spec found at product/specs/2026-06-23-foo/spec.md",
  "hint": "Run devos write-spec to create it",
  "details": { "path": "product/specs/2026-06-23-foo/spec.md" }
}
```

### Rule 3: Local CLI APIs MUST default to no auth

A tool server running on `localhost` for the current user does not need token auth by default. Auth is opt-in, documented explicitly, and gated behind an env var or flag — never silently required.

```typescript
// ON-STANDARD — auth opt-in
const authRequired = process.env.CLI_API_AUTH === "1"
if (authRequired) verifyBearerToken(req)

// OFF-STANDARD — always requires auth setup
if (!verifyBearerToken(req)) return 401  // breaks local dev without setup
```

Exception: MCP servers exposed over the network or in multi-user environments MUST use OAuth 2.1 bearer tokens per the `cloudflare-workers` profile conventions.

### Rule 4: HTTP status codes MUST map to semantic meaning

| Status | Use when |
|---|---|
| 200 | Success |
| 400 | Client error — bad input, invalid params |
| 404 | Resource not found |
| 409 | Conflict — duplicate, already exists |
| 422 | Unprocessable — valid format, invalid content |
| 500 | Server error — unexpected failure |

Do not return 200 with `"ok": false` for client errors. Use the correct 4xx status.

### Rule 5: CLI APIs SHOULD listen on localhost only

A CLI daemon or tool server MUST bind to `127.0.0.1` (not `0.0.0.0`) unless network exposure is explicitly intended and documented.

```typescript
// ON-STANDARD
server.listen(port, "127.0.0.1")

// OFF-STANDARD — exposes to network by default
server.listen(port)  // defaults to 0.0.0.0
```

### Rule 6: Port selection MUST avoid common conflicts

Use ports in the range `3100–3199` for CLI tool servers (reserved range for local dev tooling). Document the port in `README.md` and allow override via `--port` flag or `CLI_PORT` env var.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Plain-text error responses | Downstream tools can't parse them | Always return JSON |
| Missing `error` code field | Programmatic error handling requires a stable identifier | Include `error: "snake_case_code"` |
| Silently requiring auth for local server | Breaks local dev without setup | Default no-auth; opt-in via env var |
| Binding to 0.0.0.0 by default | Exposes tool server to network | Bind to 127.0.0.1 |
| Hardcoded port | Conflicts with other tools | Allow `--port` / `CLI_PORT` override |

---

## Related Standards

- `profiles/cloudflare-workers/standards/global/tech-stack.md` — MCP protocol, OAuth 2.1, Workers-hosted APIs
- `profiles/cli/standards/global/tech-stack.md` Rule 5 — when to graduate to a different profile
- `profiles/webapp/standards/backend/api-conventions.md` — webapp API conventions (reference when graduating)

## Compliance Test

- [ ] All API responses are JSON with `Content-Type: application/json`?
- [ ] Error responses include `ok: false`, `error` (snake_case), and `message`?
- [ ] Local server defaults to no auth (opt-in only)?
- [ ] Server binds to `127.0.0.1` unless network exposure is documented?
- [ ] Port is configurable via flag or env var?
