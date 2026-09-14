<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/free-tier-keepalive.md and re-run profile-sync. -->
# Free-Tier Keep-Alive Standards

## Overview

Many managed services with free tiers auto-pause or delete databases after N days of inactivity. Low-traffic projects lose data and availability the first time idle-deletion fires — often silently, with no warning beyond an email. This standard names the pattern, lists affected services, and defines the required implementation for projects that depend on a free-tier service.

## Scope

This standard covers keep-alive cron patterns for free-tier managed services with documented idle-deletion or pause policies. It does NOT cover provider selection (choosing Upstash vs. Redis Cloud), cost optimization (when to upgrade to a paid tier), or general cron authoring (see each platform's cron docs).

## Principles

1. **Heartbeat over hope:** Services with idle-deletion policies require an explicit heartbeat. Assuming "normal traffic will keep it warm" fails the first week traffic dips.
2. **Shorter than the window:** The cron interval MUST be strictly less than the provider's documented idle window, with enough margin to survive a missed run.
3. **Non-growing writes:** Keep-alive payloads MUST use TTL or overwrite a fixed key/row. A keep-alive that creates unbounded data is a leak.
4. **Authenticated, not public:** Cron endpoints MUST require bearer auth. A public keep-alive route is a free abuse vector.

## Rules

### When the standard applies

- **MUST** add a keep-alive cron when the project uses any service in the Affected Services table below AND the project does not have guaranteed steady traffic keeping the service warm.
- **MUST NOT** add a keep-alive cron for paid-tier services, self-hosted services, or high-traffic projects. Unnecessary crons add noise and may hit platform cron limits (e.g., Vercel Hobby allows 2 daily crons max).

### Affected services (non-exhaustive)

| Service | Idle behavior | Documented window |
|---|---|---|
| Upstash Redis (free) | Database deleted after prolonged inactivity | ~30 days (varies; confirm in console) |
| Neon Postgres (free) | Compute autosuspends | 5 min default; branches suspend after 7 days idle |
| Supabase (free) | Project paused | 7 days inactive |
| Fly.io (free allowance) | VMs stopped | Idle-based; varies by app type |
| Render (free web service) | Service spun down | 15 min inactivity |
| Railway (trial) | Service paused | Credit-based; verify in dashboard |

Before adding a keep-alive, **MUST** verify the current idle window in the provider's console or changelog — free-tier policies change.

### Required implementation

The keep-alive pattern has four required parts:

1. **Cron route** at `/api/cron/<service>-keepalive` (or project-appropriate equivalent) that performs a minimal write-then-read against the service.
2. **Scheduled trigger** (Vercel Cron, GitHub Actions schedule, platform-native cron) that hits the route on an interval `≤` half the provider's idle window.
3. **Bearer auth** via `CRON_SECRET` (or equivalent project secret). Unauthenticated requests return 401.
4. **Bounded write**: TTL on the key (Redis), upsert on a fixed row (Postgres), or any operation that does not accumulate data over time.

```typescript
// ON-STANDARD (Astro + Upstash Redis example)
import type { APIRoute } from 'astro';
import { redis } from '../../../lib/redis';
import { getEnv } from '../../../lib/env';

export const GET: APIRoute = async ({ request }) => {
  const cronSecret = getEnv('CRON_SECRET');
  if (!cronSecret) return new Response('Service unavailable', { status: 503 });
  if (request.headers.get('authorization') !== `Bearer ${cronSecret}`) {
    return new Response('Unauthorized', { status: 401 });
  }
  await redis.set('keepalive:last-ping', new Date().toISOString(), { ex: 60 * 60 * 24 * 14 });
  return new Response(JSON.stringify({ ok: true }), { status: 200 });
};
```

```json
// vercel.json — schedule strictly under provider's idle window
{
  "crons": [
    { "path": "/api/cron/<service>-keepalive", "schedule": "0 3 */3 * *" }
  ]
}
```

### Off-standard examples

```typescript
// OFF-STANDARD: no auth — public abuse vector
export const GET: APIRoute = async () => {
  await redis.set('ping', Date.now());  // also: no TTL → key never expires
  return new Response('ok');
};
```

```json
// OFF-STANDARD: weekly schedule against a 7-day idle window — no margin
{ "path": "/api/cron/keepalive", "schedule": "0 0 * * 0" }
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Cron interval = idle window | One missed run = deletion | Interval ≤ half the idle window |
| Write without TTL/upsert | Data grows until it dominates the free tier | `ex: <seconds>` on SET, or UPSERT on a fixed key |
| Public cron endpoint | Attackers can run it 1000×/sec | Bearer `CRON_SECRET` auth, constant-time compare |
| Keep-alive on paid tier "just in case" | Wastes cron slot (Vercel Hobby: 2/day max) | Skip — paid tiers don't idle-delete |
| Ignoring the provider's changelog | Idle windows shorten without notice | Re-verify window quarterly |

## Deviation guidance

You MAY skip the keep-alive cron when the service has demonstrable continuous traffic (production analytics confirm ≥1 request/day across the idle window). When you do: record the traffic evidence in the project's `CLAUDE.md` with the date checked, and re-verify before removing the cron from a new project.

You MAY use a GitHub Actions scheduled workflow instead of a platform-native cron when the deployment target lacks cron support (e.g., static export). The bearer auth and bounded-write rules still apply.

## Profile inheritance notes

Standalone. No parent standard to extend.

## Compliance test

- [ ] Does the project use any service listed in the Affected Services table?
- [ ] If yes, is there a keep-alive cron route implementing the four required parts?
- [ ] Is the cron interval strictly less than half the provider's documented idle window?
- [ ] Does the route return 401 when the `Authorization: Bearer <CRON_SECRET>` header is missing or wrong?
- [ ] Does the keep-alive write use a TTL, upsert, or other non-growing operation?
- [ ] Is the reference implementation path noted in the project's `CLAUDE.md` or equivalent?

If any check fails: add or fix the keep-alive, or record the deviation (and the traffic evidence justifying it) in `CLAUDE.md`.

## References

- [Upstash free tier policy](https://upstash.com/docs/redis/overall/pricing) — database deletion after inactivity
- [Neon autosuspend](https://neon.tech/docs/introduction/auto-suspend) — compute suspend windows
- [Supabase free tier pause](https://supabase.com/docs/guides/platform/going-into-prod) — 7-day inactivity pause
- [Vercel Cron Jobs](https://vercel.com/docs/cron-jobs) — Hobby tier limits, authentication pattern
- [RFC 2119 — Key words for use in RFCs](https://datatracker.ietf.org/doc/html/rfc2119) — MUST / SHOULD / MAY semantics
- Companion skill: `/bx-keepalive-add` — scaffolds the route + cron entry once a project opts in
- Reference implementation: `boxi-marketing-website/src/pages/api/cron/redis-keepalive.ts` + `vercel.json` (2026-04-23)
