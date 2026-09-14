<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/error-handling.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/error-handling.md and re-run profile-sync. -->
# Error Handling Standards

## Overview

Error handling governs how a system detects, propagates, reports, and recovers from failures. Poorly handled errors cause silent data corruption, confusing user experiences, and debugging sessions that consume hours of engineering time. Consistent error handling is the foundation of observable, trustworthy systems — it is not an afterthought.

## Scope

This standard covers error propagation across call stacks, error classification hierarchies, user-facing error messages, retry and backoff logic, and logging discipline at failure boundaries. It does NOT cover authentication or authorisation error responses (see `auth.md`) or the selection of HTTP status codes for API surfaces (see `api.md`).

## Principles

1. **Fail fast and explicitly:** Surface errors at the earliest possible point rather than allowing invalid state to propagate silently through the system.
2. **Errors are first-class values:** Treat error conditions as expected program states that must be typed, structured, and handled — not as exceptional interruptions to be swallowed.
3. **User messages are not technical details:** The message shown to a user must be actionable and safe; the message recorded in logs must be complete and precise. These are never the same string.

## Rules

### Error type hierarchy

Define a layered error taxonomy rather than relying on untyped strings or generic base errors.

OFF-STANDARD — generic error with no type information:
```typescript
throw new Error("Something went wrong");
```

ON-STANDARD — typed, structured error with context:
```typescript
class ValidationError extends AppError {
  constructor(field: string, message: string) {
    super({ code: "VALIDATION_ERROR", field, message, retryable: false });
  }
}

class ExternalServiceError extends AppError {
  constructor(service: string, cause: unknown) {
    super({ code: "EXTERNAL_SERVICE_ERROR", service, cause, retryable: true });
  }
}
```

OFF-STANDARD (Python) — bare exception with no context:
```python
except Exception:
    pass
```

ON-STANDARD (Python) — typed catch with structured logging:
```python
except httpx.TimeoutException as exc:
    logger.error("payment_service_timeout", service="stripe", attempt=attempt, exc_info=exc)
    raise ExternalServiceError(service="stripe", cause=exc) from exc
```

Error types must indicate at minimum: whether the error is retryable, which system layer owns it, and what context is needed to diagnose it.

### Boundary handling

Errors must be caught and translated at system boundaries — the edge of a module, service, or process. Inside a boundary, errors propagate as typed values. At the boundary, they are converted to the appropriate output format (HTTP response, log entry, user message).

- Avoid bare `try/catch` blocks that swallow errors without logging or re-raising.
- Do not catch errors that you cannot meaningfully handle — let them propagate to the nearest competent boundary.
- Re-raise with added context rather than wrapping silently.

OFF-STANDARD:
```typescript
try {
  await processPayment(order);
} catch {
  // ignore
}
```

ON-STANDARD:
```typescript
try {
  await processPayment(order);
} catch (err) {
  logger.error("payment_failed", { orderId: order.id, cause: err });
  throw new PaymentError("Payment processing failed", { cause: err, orderId: order.id });
}
```

### Retry with exponential backoff

Transient failures in external service calls must use exponential backoff with jitter. Retrying at a fixed interval under load amplifies the problem.

- Only retry errors explicitly classified as `retryable: true`.
- Apply a maximum retry limit (typically 3–5 attempts).
- Add jitter (randomised delay component) to prevent retry storms.
- Log each retry attempt with attempt number and delay used.

OFF-STANDARD:
```typescript
for (let i = 0; i < 3; i++) {
  await callExternalApi();
  await sleep(1000); // fixed interval
}
```

ON-STANDARD:
```typescript
const result = await retry(callExternalApi, {
  attempts: 4,
  backoff: "exponential",
  baseDelayMs: 200,
  jitter: true,
  retryIf: (err) => err instanceof ExternalServiceError && err.retryable,
  onRetry: (attempt, delay) =>
    logger.warn("retry_attempt", { fn: "callExternalApi", attempt, delayMs: delay }),
});
```

### Resource cleanup

Resources acquired during a request or operation — file handles, database connections, locks, temporary files — must be released even when errors occur.

- Use `finally` blocks, `using` declarations, context managers, or equivalent RAII patterns.
- Never rely on garbage collection alone for external resources.
- Test cleanup paths explicitly: simulate failure mid-operation and verify resources are released.

OFF-STANDARD (Python — connection leaked on error):
```python
conn = db.connect()
result = conn.execute(query)  # raises — conn never closed
conn.close()
```

ON-STANDARD (Python — guaranteed cleanup):
```python
with db.connect() as conn:
    result = conn.execute(query)
```

### Logging discipline

Log at the boundary where the error is handled, not at every intermediate function that re-raises.

- **DEBUG**: internal state, function entry/exit in verbose mode.
- **INFO**: normal business events (order placed, user registered).
- **WARN**: degraded but recoverable state (cache miss, retry attempt).
- **ERROR**: a request or operation failed; requires investigation.
- **FATAL**: the process cannot continue; requires immediate action.

Log entries must include: timestamp, error code, relevant entity IDs (user ID, request ID, resource ID), and the full stack trace for ERROR and FATAL levels. Never log passwords, tokens, PII, or raw request bodies containing sensitive fields.

### User-facing error messages

Messages shown to users must be:
- Written in plain language with no stack traces, SQL fragments, or internal identifiers.
- Actionable where possible: tell the user what they can do next.
- Consistent in tone and format across the product.

Technical details belong exclusively in structured logs, not in API error responses or UI messages.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Swallowed exceptions (`catch {}` with no action) | Errors disappear silently; the system proceeds in invalid state | Log, then re-raise or return a typed error value |
| Generic error message to user: "An error occurred" | User cannot self-serve; support cost rises | Provide a safe, specific message and a reference code for support |
| Logging sensitive data in error messages | Creates a compliance and security liability | Sanitise before logging; log reference IDs, not raw values |
| Retrying non-retryable errors | Wastes time and may worsen the failure (e.g., duplicate writes) | Check `retryable` flag before any retry loop |
| Catching at every function level | Creates noise; makes root cause harder to trace | Catch only at boundaries where you can meaningfully handle |
| Using error string matching (`if err.message.includes(...)`) | Breaks on any message change; untestable | Use typed error classes or error codes |

## Deviation guidance

- Teams MAY use a third-party retry library (e.g., `p-retry`, `tenacity`) in place of a hand-rolled backoff loop, provided the library is pinned and its behaviour is covered by tests.
- Teams MAY define domain-specific error taxonomies that extend the base hierarchy without replacing it.
- Teams MUST NOT disable error logging for any ERROR or FATAL level event, including during testing, unless the log is redirected to a test-specific sink.
- Teams MUST NOT surface raw exception messages or stack traces in production API responses or UI elements.

## Compliance test

- [ ] Does every `catch` block either re-raise, return a typed error, or log before discarding?
- [ ] Are all user-visible error messages free of stack traces, internal IDs, and technical jargon?
- [ ] Does every external service call that can fail transiently have retry logic with backoff and a retry limit?
- [ ] Are resources (connections, file handles, locks) released in a `finally`/`using`/`with` block that runs even on error?
- [ ] Do log entries for ERROR-level events include: timestamp, error code, relevant entity IDs, and full stack trace?

## References

- [Google SRE Book — Error Budgets and Reliability](https://sre.google/sre-book/embracing-risk/) — the relationship between error rates, error budgets, and reliability targets that motivates structured error handling at scale
- [RFC 7807 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc7807) — standardised format for machine-readable error responses at HTTP boundaries
- [OWASP Error Handling Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html) — security considerations for what must not appear in error responses

## Rule: Monitoring Must Accompany Graceful Degradation

When a component is designed to degrade gracefully (returns 0, emits a warning, continues without the missing dep), a health-check mechanism **must** be paired with it. Graceful degradation without monitoring is silent failure at scale.

**Required pairing:**

| Degradation pattern | Required monitoring |
|--------------------|--------------------|
| `command -v X || { warn; return 0; }` | Health check that tests `command -v X` and surfaces result in `health` |
| `[[ -f $path ]] || { warn "disabled"; return 0; }` | Path-existence check callable from install verify or `devos_*_check()` |
| Circuit breaker (N failures → skip) | Circuit state file written at `~/.claude/state/circuit-breaker/<component>.json`; readable by health surface |
| `timeout Ns <cmd> \|\| { warn; skip; }` | Timeout recorded in timing JSONL; health check uses same timeout threshold |

**Anti-pattern:**
```bash
# BAD: graceful degradation with no monitoring
if [[ ! -f "$memory_server" ]]; then
    echo "memory disabled" >&2
    return 0  # silent from this point — no way to know it's off
fi
```

**Correct pattern:**
```bash
# GOOD: graceful degradation + health check
if [[ ! -f "$memory_server" ]]; then
    echo "[integration] WARNING: memory MCP not found — injection disabled" >&2
    echo "[integration] Run: devos health or re-run install.sh to diagnose" >&2
    _devos_memory_write_circuit_breaker 1  # records state for health surface
    return 0
fi
```

**Root cause note:** This rule was added after `2026-04-26-memory-system-integration` gap analysis found that the memory MCP server had been silently absent for 67 days across all Codex/Gemini/OpenCode/Kilo sessions. Graceful degradation was correctly implemented; monitoring alongside it was not. See ADR `2026-04-26-dual-memory-system-decision.md`.
