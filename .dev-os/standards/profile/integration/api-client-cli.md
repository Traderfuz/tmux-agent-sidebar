<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/integration/api-client-cli.md and re-run profile-sync. -->
# CLI Profile — API Client Standards

## Overview

CLI tools frequently call external APIs: model providers, data services, SaaS platforms, or the tool's own daemon. Terminal context imposes different constraints than browser context: no OAuth redirect flows, no cookie jar, no browser storage, and the user expects the tool to fail clearly rather than open a browser window. This standard defines how CLI-profile projects wire external API integrations.

---

## Principles

1. **Credentials come from the environment, not interactive prompts by default.** A CLI tool running in CI or scripted mode cannot prompt for credentials. `env var` → `config file` → `interactive prompt` is the resolution order.
2. **Fail loud with actionable output.** A failed API call should tell the user exactly what went wrong and what to do next — not silently retry or swallow the error.
3. **No browser-mediated auth flows in the API client layer.** OAuth redirects, device-code flows, and browser login belong in a dedicated `auth login` command — not embedded in every API call.

---

## Rules

### Rule 1: Credentials MUST resolve in this order

```
1. Explicit flag (--api-key, --token)
2. Environment variable (TOOLNAME_API_KEY, OPENAI_API_KEY, etc.)
3. Config file (~/.config/tool-name/credentials or .env.local)
4. Interactive prompt (only in interactive TTY, never in CI)
```

```typescript
// ON-STANDARD
function resolveApiKey(): string {
  if (flags.apiKey) return flags.apiKey
  if (process.env.TOOLNAME_API_KEY) return process.env.TOOLNAME_API_KEY
  const stored = readCredentialsFile()
  if (stored?.apiKey) return stored.apiKey
  if (process.stdin.isTTY) return promptUser("Enter API key: ")
  throw new Error("No API key found. Set TOOLNAME_API_KEY or run: tool-name auth login")
}

// OFF-STANDARD — always prompts, breaks CI
const key = await prompt("Enter your API key:")
```

### Rule 2: API errors MUST surface with error code + hint on stderr

```typescript
// ON-STANDARD
try {
  const result = await apiClient.call(params)
} catch (err) {
  if (err.status === 401) {
    console.error("✗ error: authentication failed (401)")
    console.error("  hint: run 'tool-name auth login' to refresh credentials")
    process.exit(1)
  }
  if (err.status === 429) {
    console.error(`✗ error: rate limit exceeded — retry after ${err.retryAfter}s`)
    process.exit(1)
  }
  console.error(`✗ error: API call failed: ${err.message}`)
  if (flags.debug) console.error(err.stack)
  process.exit(1)
}

// OFF-STANDARD — raw throw, no user guidance
const result = await apiClient.call(params)  // throws unhandled
```

### Rule 3: Timeouts MUST be explicit

Never rely on the HTTP client's default timeout (often unlimited). Set timeouts per call type:

| Call type | Recommended timeout |
|---|---|
| Auth / token exchange | 10s |
| Simple CRUD | 30s |
| LLM inference (streaming) | 120s |
| File upload / batch | 300s |

```typescript
// ON-STANDARD
const response = await fetch(url, {
  signal: AbortSignal.timeout(30_000),  // 30s
  headers: { Authorization: `Bearer ${apiKey}` }
})
```

### Rule 4: Retry logic MUST be explicit and bounded

```typescript
// ON-STANDARD — explicit, bounded, with jitter
async function callWithRetry(fn: () => Promise<Response>, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn()
    } catch (err) {
      if (attempt === maxRetries || !isRetryable(err)) throw err
      const delay = Math.min(1000 * 2 ** attempt + Math.random() * 100, 10_000)
      await sleep(delay)
    }
  }
}

// OFF-STANDARD — unbounded retry loop
while (true) { try { return await fn() } catch { await sleep(1000) } }
```

Retryable: network errors, 429, 503. Non-retryable: 400, 401, 403, 404, 422.

### Rule 5: Auth flows MUST be isolated in a dedicated command

A `tool-name auth login` command (or `tool-name auth <provider>`) owns the interactive auth flow — device code, browser OAuth, API key entry. API client code calls `resolveCredentials()` and never starts an auth flow mid-command.

```bash
# ON-STANDARD — clear separation
tool-name auth login          # interactive, opens browser if needed
tool-name fetch-data          # reads stored credentials, never prompts

# OFF-STANDARD — prompts mid-command
tool-name fetch-data          # "You're not logged in. Opening browser..."
```

### Rule 6: Output format MUST respect `--json` and piping context

API responses surfaced to the user follow `terminal-ui.md` Rule 1: human-readable by default, `--json` for machine-readable. Raw API JSON must NOT be passed through directly.

```typescript
// ON-STANDARD — shape the output
const data = await fetchUser(id)
if (flags.json) {
  console.log(JSON.stringify({ id: data.id, name: data.name, email: data.email }))
} else {
  console.log(`User: ${data.name} (${data.email})`)
}

// OFF-STANDARD — raw API passthrough (includes internal fields, pagination cursors, etc.)
console.log(JSON.stringify(await fetchUser(id)))
```

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Prompting for credentials in every command | Breaks CI / scripted use | Credential resolution order: flag → env → file → prompt |
| Swallowing API errors silently | User doesn't know what failed | Always surface error code + hint on stderr |
| No timeout on API calls | Hangs indefinitely in slow/broken network | Set explicit timeouts per call type |
| Unbounded retry loop | Can hang for hours | Bound retries (max 3–5), exponential backoff with jitter |
| Auth flow embedded in API client | Every command opens browser | Isolate auth in `auth login` command |
| Raw API JSON passthrough | Leaks internal fields, pagination noise | Shape the output before surfacing |

---

## Compliance Test

- [ ] Credentials resolve: flag → env → config file → prompt (TTY only)?
- [ ] API errors surface with error code + hint on stderr?
- [ ] All HTTP calls have explicit timeouts?
- [ ] Retry logic is bounded with exponential backoff?
- [ ] Auth flow is isolated in a dedicated `auth` command (not embedded)?
- [ ] Output respects `--json` flag and doesn't pass through raw API responses?
