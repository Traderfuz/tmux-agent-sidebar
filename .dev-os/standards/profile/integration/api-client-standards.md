<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/integration/api-client-standards.md and re-run profile-sync. -->
<!-- source: profile:webapp -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/webapp/standards/integration/api-client-standards.md and re-run profile-sync. -->
# API Client Standards

**Profile**: webapp
**Category**: integration
**Scope**: API client design for external service integrations — third-party REST APIs, LLM providers
(OpenRouter, Anthropic, OpenAI), and webhook source clients. Does NOT cover Convex queries/mutations
(see `modular-provider.md`) or internal service communication (see `global/modular-integration.md`).

---

## Principles

1. **Domain models, not wire types** — clients translate external API responses into domain types before
   returning; callers never handle raw response shapes or SDK-specific types.

2. **Interface-first, implementation-swappable** — every API client exports a TypeScript interface and a
   factory function. Tests inject mock implementations; production code never imports a concrete class
   directly.

3. **Fail fast, retry selectively** — transient failures (429, 5xx) retry with exponential backoff and
   jitter. Permanent failures (400, 401, 403, 404) throw immediately without retry; retrying them wastes
   quota and masks bugs.

---

## Rules

### R1 — Client interface pattern

Every integration exports a typed interface from `types.ts` and a factory function from `client.ts`.
Callers import the interface, not the concrete implementation.

```typescript
// OFF-STANDARD: concrete class exposed directly
import { StripeClient } from './stripe-client';
const stripe = new StripeClient(process.env.STRIPE_KEY!);
stripe.createPaymentIntent(500, 'usd');

// ON-STANDARD: interface + factory
// src/lib/integrations/stripe/types.ts
export interface StripeClientInterface {
  createPaymentIntent(amount: number, currency: string): Promise<PaymentIntent>;
  retrieveCustomer(id: string): Promise<Customer>;
  cancelPaymentIntent(id: string): Promise<void>;
}

// src/lib/integrations/stripe/client.ts
export function createStripeClient(apiKey: string): StripeClientInterface {
  const sdk = new Stripe(apiKey, { apiVersion: '2024-06-20' });
  return {
    async createPaymentIntent(amount, currency) { ... },
    async retrieveCustomer(id) { ... },
    async cancelPaymentIntent(id) { ... },
  };
}
```

### R2 — Response mapping

Raw API or SDK response types are internal to the client module. Every exported function returns a domain
type. Map at the boundary; do not let raw types leak to callers.

```typescript
// OFF-STANDARD: leaking raw Stripe type to caller
async createPaymentIntent(): Promise<Stripe.PaymentIntent> {
  return stripe.paymentIntents.create({ amount, currency });
}

// ON-STANDARD: domain type at boundary
export interface PaymentIntent {
  id: string;
  amount: number;
  currency: string;
  status: 'pending' | 'processing' | 'succeeded' | 'failed';
}

async createPaymentIntent(amount: number, currency: string): Promise<PaymentIntent> {
  const raw = await sdk.paymentIntents.create({ amount, currency });
  return {
    id: raw.id,
    amount: raw.amount,
    currency: raw.currency,
    status: mapPaymentStatus(raw.status),
  };
}

function mapPaymentStatus(raw: Stripe.PaymentIntent.Status): PaymentIntent['status'] {
  switch (raw) {
    case 'succeeded': return 'succeeded';
    case 'canceled': return 'failed';
    case 'processing': return 'processing';
    default: return 'pending';
  }
}
```

### R3 — Retry with backoff

Transient failures MUST retry using exponential backoff with jitter. MUST NOT retry on 4xx responses
except 429 (rate limit). Maximum attempts default to 3; callers MAY override.

```typescript
// ON-STANDARD
async function withRetry<T>(
  fn: () => Promise<T>,
  options: { maxAttempts?: number; baseDelayMs?: number } = {}
): Promise<T> {
  const { maxAttempts = 3, baseDelayMs = 100 } = options;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      const isLastAttempt = attempt === maxAttempts;
      if (!isTransientError(err) || isLastAttempt) throw err;
      const jitter = Math.random() * 50;
      await sleep(Math.pow(2, attempt) * baseDelayMs + jitter);
    }
  }
  throw new Error('unreachable');
}

function isTransientError(err: unknown): boolean {
  if (err instanceof StripeError) return err.status === 429 || err.status >= 500;
  if (err instanceof NetworkError) return true;
  return false;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
```

### R4 — Authentication

API keys and tokens are loaded from environment variables or Cloudflare env bindings. Never hardcode
credentials. Token refresh logic is encapsulated inside the client factory; callers do not manage token
lifecycle.

```typescript
// OFF-STANDARD: credential in source
export function createOpenRouterClient() {
  return createClient('sk-or-live-abc123');
}

// ON-STANDARD: env binding (Cloudflare Workers)
export function createOpenRouterClient(env: Env): LLMClientInterface {
  return buildLLMClient(env.OPENROUTER_API_KEY);
}

// ON-STANDARD: env variable (Next.js server)
export function createOpenRouterClient(): LLMClientInterface {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error('OPENROUTER_API_KEY is not set');
  return buildLLMClient(key);
}
```

### R5 — Typed error classes

Each integration module exports a typed error class that extends `Error`. Error classes include the HTTP
status and a machine-readable code. Callers use `instanceof` checks, not string matching on `message`.

```typescript
// ON-STANDARD
export class StripeError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = 'StripeError';
  }

  get isRateLimit(): boolean { return this.status === 429; }
  get isUnauthorized(): boolean { return this.status === 401; }
}

// Caller
try {
  await stripeClient.createPaymentIntent(500, 'usd');
} catch (err) {
  if (err instanceof StripeError && err.isUnauthorized) {
    // rotate key
  }
  throw err;
}
```

---

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Raw API response type exported to callers | Callers become coupled to vendor response shape; any API version change breaks call sites across the codebase |
| `catch` block retries on 400 or 401 | Masks application bugs (malformed requests, stale credentials); wastes API quota with guaranteed-to-fail requests |
| API key hardcoded in client constructor call | Secret persists in source history; cannot be rotated without a code change |
| Catch-all error suppression `catch (e) {}` | Silent failures; integration appears healthy while data is silently not syncing |
| No interface, only concrete class | Tests require real API credentials or complex spy setup; swapping implementations requires call-site changes |

---

## Deviation Guidance

MAY use SDK client classes directly (e.g., `new Stripe(key)`, `new Anthropic({ apiKey })`) inside the
client module implementation — the SDK is an implementation detail of the module. MUST NOT expose SDK
types (e.g., `Stripe.PaymentIntent`, `Anthropic.Message`) outside the module boundary.

MAY reduce `maxAttempts` to 1 (no retry) for operations where duplicate execution causes side effects
(e.g., sending an email, charging a card). MUST document the reason in a comment.

---

## Compliance Test

Before marking an integration complete, verify all five:

1. Every integration has a TypeScript interface in `src/lib/integrations/<service>/types.ts`?
2. All function return types are domain types — no raw SDK or vendor types exported?
3. Retry logic only retries on status 429 and 5xx responses?
4. API keys loaded from `process.env` or Cloudflare `env` bindings — never hardcoded?
5. Integration module exports a typed error class with `status` and `code` fields?

---

## References

- AWS SDK retry strategy — exponential backoff with jitter
- Martin Fowler, _Patterns of Enterprise Application Architecture_ — Gateway pattern
- TypeScript Handbook — interface design and structural typing
