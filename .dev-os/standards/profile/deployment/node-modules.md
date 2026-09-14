<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/deployment/node-modules.md and re-run profile-sync. -->
# Node Modules Deployment Standards

## Overview

Shipping `node_modules` to production is the most common source of bloated deployment artifacts, accidental dev-dependency exposure, and supply-chain risk in JavaScript projects. This standard applies the Convention over Configuration principle to the Bun ecosystem: the convention is that build output ships, not sources — and it documents what to do when that convention does not apply (unbundled Node servers).

## Scope

This standard covers whether and how `node_modules` appears in deployment artifacts for Bun-based projects. It does NOT cover dependency version pinning, lockfile management, or package security scanning (see `dependency-management.md`).

## Principles

1. **Build output, not sources** — the deployment artifact is the compiled output (`dist/`, `.next/`, `out/`), never the source tree with its dev dependencies.
2. **Platform-native installation** — platforms (Vercel, Cloudflare Workers) install dependencies themselves from the lockfile; shipping `node_modules` duplicates work and inflates artifact size.
3. **Production deps only in server bundles** — when `node_modules` must ship (unbundled Express/Remix Node adapter), install with `--production` flag; dev dependencies in production are a supply-chain risk.

---

## Decision Table

| Deployment Type | Ship node_modules? | Strategy |
|---|---|---|
| Next.js → Vercel | No | Platform installs + bundles automatically |
| Vite/React → static hosting | No | Deploy `dist/` only |
| Next.js → Docker | No | Multi-stage build, copy `.next/standalone` only |
| Express (unbundled) | Yes — prod deps only | `bun install --production` |
| Remix (Node adapter) | Yes — prod deps only | `bun install --production` |

**Default rule:** If your framework has a build step that produces a self-contained output directory, `node_modules` never ships to production.

---

## Rules

### Rule 1: Framework with build step — exclude node_modules from artifact

**MUST NOT** include `node_modules` in the deployment artifact when the project has a build step that produces a self-contained output directory.

```bash
# OFF-STANDARD: .gitignore missing node_modules/; it ships
# .gitignore
dist/

# ON-STANDARD
# .gitignore
node_modules/
dist/
.next/
```

### Rule 2: Vercel deployments — do not add node_modules to .vercelignore

**MUST NOT** add `node_modules/` as an explicit entry to `.vercelignore`. Vercel runs `bun install` and `bun run build` automatically. Adding it explicitly is redundant and can mask misconfigured ignore rules.

```
# OFF-STANDARD: .vercelignore
node_modules/   ← already ignored; explicit entry masks config errors

# ON-STANDARD: .vercelignore
.env.local
.env.development.local
*.log
.DS_Store
```

### Rule 3: Docker deployments — use multi-stage build with standalone output

**MUST** use a multi-stage Dockerfile. **MUST** copy only `.next/standalone` (or equivalent framework output), not `node_modules`, into the runner stage.

```dockerfile
# OFF-STANDARD: single stage copies everything including node_modules
FROM node:20
COPY . .
RUN npm install
CMD ["node", "server.js"]

# ON-STANDARD: multi-stage, standalone output only
FROM oven/bun:1 AS builder
WORKDIR /app
COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

FROM oven/bun:1-slim AS runner
WORKDIR /app
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
CMD ["bun", "server.js"]
```

Also include a `.dockerignore` to prevent source-stage bloat:

```
node_modules/
.git/
.env.local
*.log
.DS_Store
coverage/
.next/
dist/
```

### Rule 4: Unbundled Node servers — install production deps only

When `node_modules` must ship (Express, Fastify, raw Hono Node adapter with no build step), **MUST** install with `--production` flag. **MUST NOT** include any dev dependency.

```bash
# OFF-STANDARD: ships devDependencies
bun install

# ON-STANDARD
bun install --production
```

### Rule 5: Cloudflare Workers — no manual module upload

Workers bundle at build time via Wrangler. **MUST NOT** include `node_modules` in `wrangler.toml` assets or upload modules manually. Use `wrangler deploy` exclusively.

```toml
# OFF-STANDARD: wrangler.toml including node_modules as asset
[assets]
directory = "."          ← includes node_modules, conflicts with Wrangler bundler

# ON-STANDARD: wrangler.toml with no asset directory override
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"
```

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `node_modules` not in `.gitignore` | Hundreds of MB in repo; dependency drift between machines | Add `node_modules/` to `.gitignore` unconditionally |
| Deploying source tree instead of build output | Dev deps in production; security risk; bloated artifact | Run build step; deploy `dist/` or `.next/standalone` only |
| Docker single-stage copy of entire project | Multi-GB image; rebuild required for any source change | Multi-stage build: builder + slim runner with standalone output only |
| `bun install` without `--production` in Docker runner stage | Dev deps inflate image and expose unnecessary packages | `bun install --production` in runner stage |
| Manually uploading `node_modules` to Cloudflare | Conflicts with Wrangler bundler; inflates worker size; may exceed limits | Use `wrangler deploy`; let Wrangler bundle from source |

---

## Deviation guidance

You MAY include `node_modules` in the deployment artifact when using an unbundled Node.js HTTP server (Express, Fastify, raw Hono Node adapter) with no build step. When you do:

- MUST use `bun install --production` — no dev dependency may be present
- MUST NOT include any dev dependency
- MUST document the deviation in the project's `CLAUDE.md` or deployment runbook with the reason no build step is used

---

## Profile inheritance notes

This standard is defined at the `general` profile level and is inherited by all profiles: `webapp`, `pwa`, `cli`, `business`, `cloudflare-workers`, `installable-os`. Child profiles do not need to restate these rules.

The `cloudflare-workers` profile adds Worker-specific bundling requirements. The `webapp` profile adds Next.js standalone output requirements. Neither overrides the core rules above.

---

## Compliance test

- [ ] `node_modules/` is listed in `.gitignore`?
- [ ] No `node_modules/` copy step exists in the Dockerfile (i.e., runner stage receives only standalone output)?
- [ ] Docker build uses a multi-stage pattern with a slim runner stage?
- [ ] Unbundled Node servers use `bun install --production` (not bare `bun install`)?
- [ ] Cloudflare Workers deploy via `wrangler deploy` with no manual module upload?

If any check fails: fix the artifact configuration, or record the deviation in the project's `CLAUDE.md` with explicit justification.

---

## References

- [Bun install — production flag](https://bun.sh/docs/cli/install#production) — `--production` omits devDependencies from install
- [Next.js standalone output](https://nextjs.org/docs/app/api-reference/next-config-js/output#automatically-copying-needed-files) — self-contained server bundle for Docker deployments
- [Vercel Build Output API](https://vercel.com/docs/build-output-api/v3) — how Vercel installs deps and builds projects automatically
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/) — builder + runner pattern for minimal production images
- [Cloudflare Workers bundling with Wrangler](https://developers.cloudflare.com/workers/wrangler/bundling/) — Wrangler handles all module resolution; manual uploads conflict
