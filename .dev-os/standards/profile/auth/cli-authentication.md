<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/auth/cli-authentication.md and re-run profile-sync. -->
# CLI Authentication Standards

**Related Standards:**
- [Error Handling](../../../../default/standards/global/error-handling.md) - Error handling patterns for auth failures
- [Tech Stack](../tech-stack.md) - Runtime and framework choices
- [Modular Provider](../modular-provider.md) - Provider pattern for auth backends

## Overview

CLI applications that authenticate users against a web backend should use a **browser redirect flow with PKCE** (Proof Key for Code Exchange). This pattern delegates identity management to the web application's existing auth provider (Clerk, Auth.js, Supabase Auth, etc.) and issues opaque session tokens for CLI use.

Direct password entry, long-lived API keys, or embedded OAuth client secrets in CLI binaries are not acceptable.

---

## Architecture

```
CLI                          Web App                     Backend
 │                              │                           │
 ├─ Generate PKCE pair ─────────┤                           │
 ├─ Generate state (CSRF) ──────┤                           │
 ├─ Start localhost server ──────┤                           │
 ├─ Open browser ───────────────►│                           │
 │                              ├─ Authenticate user ──────►│
 │                              │  (Clerk/Auth.js/etc.)     │
 │                              ├─ Generate auth code ─────►│
 │                              │  (with code_challenge)    │
 │  ◄──── Redirect to localhost ┤                           │
 │        ?code={code}&state={state}                        │
 ├─ Validate state ──────────────┤                           │
 ├─ Exchange code + verifier ───────────────────────────────►│
 │                              │          Verify PKCE      │
 │  ◄───────────────────────────────── Return session token │
 ├─ Save token to config ───────┤                           │
 │                              │                           │
 ├─ Subsequent requests ────────────────────────────────────►│
 │  (Authorization: Bearer {token})     Validate session    │
```

---

## PKCE Implementation

### Code Verifier

Generate a cryptographically random code verifier. Minimum 43 characters, recommended 128 characters.

```typescript
import crypto from "node:crypto";

function generateCodeVerifier(): string {
  return crypto.randomBytes(64).toString("hex"); // 128-char hex
}
```

### Code Challenge

Use the S256 method (SHA-256 hash, base64url-encoded). Never use the `plain` method.

```typescript
function generateCodeChallenge(codeVerifier: string): string {
  return crypto
    .createHash("sha256")
    .update(codeVerifier)
    .digest("base64url");
}
```

### State Parameter

Generate a random state parameter for CSRF protection. Validate it on callback.

```typescript
function generateState(): string {
  return crypto.randomBytes(32).toString("hex"); // 64-char hex
}
```

---

## Local Auth Server

The CLI starts a temporary HTTP server on `127.0.0.1` to receive the browser callback.

### Requirements

| Requirement | Detail |
|-------------|--------|
| **Bind address** | `127.0.0.1` only (never `0.0.0.0`) |
| **Port** | OS-assigned random port (port 0) |
| **Lifetime** | Single request, then shutdown |
| **Timeout** | 5 minutes max, auto-close on expiry |
| **Protocol** | HTTP is acceptable on localhost |
| **Endpoint** | Single callback path (e.g., `/cb`) |

### State Validation

Always validate the `state` parameter on callback. Reject with a clear error if it doesn't match:

```typescript
if (query.state !== expectedState) {
  res.writeHead(400);
  res.end("State mismatch - possible CSRF attack");
  reject(new Error("CSRF: state parameter mismatch"));
  return;
}
```

### Response Pages

Return user-friendly HTML pages for both success and error states. The user sees these in their browser:

- **Success:** "Authentication successful! You can close this tab."
- **Error:** "Authentication failed. Please try again." with the error reason.

---

## Session Token Design

### Token Generation (Backend)

| Property | Requirement |
|----------|-------------|
| **Format** | Opaque random hex (no encoded data) |
| **Length** | Minimum 128 characters |
| **Source** | `crypto.randomBytes(64).toString("hex")` |
| **Storage** | Hash with SHA-256 before persisting to database |
| **Expiry** | 30 days, refreshed on active use |

Never use JWTs as CLI session tokens. Opaque tokens allow immediate server-side revocation without waiting for expiry.

### Token Storage (CLI)

Store session tokens in the CLI config file with appropriate filesystem permissions:

```typescript
// Config location: ~/.flowstate/config.json (or ~/.config/{app}/config.json)
interface CliConfig {
  deploymentUrl: string;
  accessToken: string;  // Opaque session token
  userId: string;
  email?: string;
}
```

The config file should have `600` permissions (owner read/write only).

### Token Lifecycle

```
pending ──► active ──► expired
                │
                └──► revoked
```

- **pending:** Auth code generated, waiting for PKCE exchange
- **active:** Session token issued, in use
- **expired:** TTL exceeded (30 days without refresh)
- **revoked:** User manually revoked via `auth logout` or `auth revoke`

---

## Backend Session Schema

```typescript
cliAuthSessions: defineTable({
  userId: v.id("users"),
  authCode: v.string(),
  codeChallenge: v.string(),
  sessionToken: v.optional(v.string()),   // SHA-256 hash, set on exchange
  status: v.union(
    v.literal("pending"),
    v.literal("active"),
    v.literal("revoked"),
    v.literal("expired"),
  ),
  deviceName: v.optional(v.string()),
  lastUsedAt: v.optional(v.string()),     // ISO 8601
  expiresAt: v.string(),                   // ISO 8601
  createdAt: v.string(),                   // ISO 8601
})
  .index("by_authCode", ["authCode"])
  .index("by_userId", ["userId"])
  .index("by_sessionToken", ["sessionToken"])
  .index("by_status", ["status"])
```

### Required Backend Functions

| Function | Purpose | Auth Required |
|----------|---------|---------------|
| `generateCliSession` | Create pending session with auth code | Web auth (Clerk/etc.) |
| `exchangeCliSession` | Exchange auth code + verifier for token | None (PKCE proves identity) |
| `validateCliSession` | Check if session token is valid | None (token is the credential) |
| `refreshCliSession` | Extend session expiry | None (token is the credential) |
| `revokeCliSession` | Revoke a specific session | Web auth |
| `revokeByToken` | Revoke session by token (for logout) | None (token is the credential) |
| `revokeAllCliSessions` | Revoke all sessions for user | Web auth |
| `listCliSessions` | List active sessions | Web auth |

### PKCE Exchange Verification

The exchange function must verify the PKCE proof:

```typescript
async function exchangeCliSession(authCode: string, codeVerifier: string) {
  const session = await findByAuthCode(authCode);

  // 1. Validate session exists and is pending
  if (!session || session.status !== "pending") {
    throw new Error("Invalid or expired auth code");
  }

  // 2. Validate auth code not expired (5-minute window)
  if (Date.now() > new Date(session.expiresAt).getTime()) {
    throw new Error("Auth code expired");
  }

  // 3. Verify PKCE: SHA-256(codeVerifier) must match stored codeChallenge
  const computedChallenge = crypto
    .createHash("sha256")
    .update(codeVerifier)
    .digest("base64url");

  if (computedChallenge !== session.codeChallenge) {
    throw new Error("PKCE verification failed");
  }

  // 4. Generate opaque session token
  const sessionToken = crypto.randomBytes(64).toString("hex");

  // 5. Store hashed token, mark session active
  await updateSession(session._id, {
    sessionToken: hashToken(sessionToken),
    status: "active",
    expiresAt: thirtyDaysFromNow(),
  });

  return { sessionToken, userId: session.userId };
}
```

---

## CLI Auth Commands

Every CLI with authentication must implement these subcommands:

### Required Commands

| Command | Purpose | Notes |
|---------|---------|-------|
| `auth login` | Authenticate via browser redirect | Primary flow |
| `auth login --token <t>` | Authenticate with existing token | CI/CD flow |
| `auth logout` | Revoke session, clear local config | Best-effort server revocation |
| `auth status` | Show current auth state and user info | Include session expiry |

### Recommended Commands

| Command | Purpose |
|---------|---------|
| `auth sessions` | List all active sessions across devices |
| `auth revoke [id]` | Revoke a specific session |
| `auth revoke --all` | Revoke all sessions |
| `auth token` | Generate short-lived token for CI/CD |

### UX Patterns

**Login:**
```
$ myapp auth login
Opening browser for authentication...
If the browser doesn't open, visit:
  https://myapp.example.com/cli-auth?port=54321&state=abc...

Waiting for authentication... ✓
Logged in as user@example.com
Credentials saved to ~/.config/myapp/config.json
Session expires: 2026-03-14
```

**Status:**
```
$ myapp auth status
Authenticated
  Name: Jane Doe
  Email: jane@example.com
  Status: Active
  Device: janes-laptop
  Session: Active (expires in 28 days)
```

**Not authenticated:**
```
$ myapp auth status
Not authenticated
Run: myapp auth login
```

---

## Deployment URL Resilience

The CLI must handle deployment URL changes gracefully. Backend URLs change during migrations, and users should not need to manually update config files.

### Priority Order

```typescript
const deploymentUrl = process.env.DEPLOYMENT_URL || config.deploymentUrl;
```

1. **Environment variable** (`DEPLOYMENT_URL` / `CONVEX_DEPLOYMENT`) always wins
2. **Persisted config** value used as fallback
3. **Hardcoded default** only applies on first config creation

### Refresh on Login

Every successful login should persist the current deployment URL:

```typescript
saveConfig({
  deploymentUrl: process.env.DEPLOYMENT_URL || config.deploymentUrl,
  accessToken: result.sessionToken,
  userId: result.userId,
});
```

### Missing URL Error

Provide a clear error when no deployment URL is available:

```typescript
if (!deploymentUrl) {
  throw new Error(
    "No deployment URL configured.\n" +
    "Set DEPLOYMENT_URL env var or run: myapp auth login"
  );
}
```

---

## Web-Side Auth Page

The web application needs a dedicated page (e.g., `/cli-auth`) that:

1. Accepts query parameters: `port`, `state`, `code_challenge`
2. Requires user authentication (redirect to login if needed, preserving params)
3. Calls the backend to generate an auth code (passing `code_challenge`)
4. Redirects to `http://localhost:{port}/cb?code={authCode}&state={state}`

### Parameter Preservation

When redirecting unauthenticated users to login, preserve the CLI auth parameters so the flow resumes after login:

```typescript
// Redirect to login with return URL
const returnUrl = `/cli-auth?port=${port}&state=${state}&code_challenge=${challenge}`;
router.push(`/login?redirect=${encodeURIComponent(returnUrl)}`);
```

---

## CI/CD Token Flow

For non-interactive environments, support direct token authentication:

```bash
# Generate token via web UI or authenticated CLI
$ myapp auth token
Token: abc123...
Save this token and protect it securely

# Use in CI/CD
$ MYAPP_TOKEN=abc123... myapp task list
# or
$ myapp auth login --token abc123...
```

### CI/CD Token Properties

| Property | Requirement |
|----------|-------------|
| **Expiry** | Short-lived (1 hour recommended) |
| **Usage** | One-time use, marked after first auth |
| **Storage** | SHA-256 hashed in database |
| **Generation** | Only by authenticated users |

---

## Security Checklist

- [ ] PKCE with S256 method (never `plain`)
- [ ] State parameter for CSRF protection
- [ ] Auth code expires in 5 minutes
- [ ] Session tokens are opaque (not JWTs)
- [ ] Tokens hashed with SHA-256 before database storage
- [ ] Localhost server binds to `127.0.0.1` only
- [ ] Localhost server shuts down after single callback
- [ ] Auth server has 5-minute timeout
- [ ] Session expiry of 30 days with active refresh
- [ ] Device name captured for audit trail
- [ ] Logout revokes server-side session (best-effort)
- [ ] Environment variable overrides persisted deployment URL
- [ ] CI/CD tokens are short-lived and one-time use
- [ ] No secrets embedded in CLI binary or source code
- [ ] Config file permissions restricted to owner (`600`)

---

## Anti-Patterns

| Anti-Pattern | Why | Instead |
|-------------|-----|---------|
| Embed OAuth client secret in CLI | Secrets in distributed binaries are public | Use PKCE (public client) |
| Store passwords locally | Insecure, bad UX | Browser redirect to existing auth |
| Use JWTs as session tokens | Cannot revoke before expiry | Opaque tokens with server-side validation |
| Long-lived API keys | Large compromise window | 30-day sessions with refresh |
| `plain` PKCE method | No protection against code interception | Always use S256 |
| Bind auth server to `0.0.0.0` | Exposes callback to network | Bind to `127.0.0.1` only |
| Hardcode deployment URLs | Breaks on migration | Env var override + config refresh |
| Skip state validation | CSRF vulnerability | Always validate state on callback |
