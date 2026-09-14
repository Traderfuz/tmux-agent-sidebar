<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/global/tech-stack.md and re-run profile-sync. -->
# CLI Profile Tech Stack Standards

Extends: [../../default/standards/tech-stack.md](../../default/standards/tech-stack.md)
Source of truth for versions: `profiles/cli/profile-config.yml` `tech_stack` block

## Overview

The CLI profile narrows the default stack toward terminal-first tools, automation scripts, and command-line runtimes. It does not inherit the default profile's browser-heavy assumptions as defaults. This standard exists to state the CLI profile's real paved road without turning the file into a giant vendor inventory.

## Scope

This standard covers recommended stack deltas for CLI-profile projects. It does NOT describe project-specific chosen stacks or replace the parent tech-stack ownership contract.

## Principles

1. **Terminal-first defaults:** The default path for this profile is command-line tooling, not web UI.
2. **Cross-platform execution matters:** Runtime and library choices should work predictably on macOS and Linux shells.
3. **Dependency footprint should stay proportionate to the tool:** Simple command-line tools should not inherit unnecessary browser or SaaS assumptions.

## Framework Basis

- **Profile Extension Template:** this file extends the parent stack standard and states CLI-only deltas.
- **Convention over Configuration:** the inherited default applies unless the CLI profile narrows it here.
- **Paved Road Strategy:** choose a small, predictable set of runtimes and libraries for CLI work.

## Rules

### Rule 1: CLI projects SHOULD default to Bun or Python rather than browser-heavy stacks

Recommended default:

- Bun for TypeScript/JavaScript CLI tools and scripting
- Python for automation, data processing, or stdlib-friendly tooling

Next.js, React, and browser-oriented libraries are not default assumptions in this profile.

### Rule 2: Persistence SHOULD be optional and minimal

CLI projects should default to:

- no database when the tool can remain file-based or stateless
- SQLite for lightweight local persistence
- PostgreSQL or other remote data stores only when the product genuinely requires shared state

### Rule 3: Verification defaults SHOULD favor fast local execution

Recommended baseline:

- Vitest for JS/TS unit tests
- Pytest for Python
- BATS when the product is shell-heavy
- focused smoke verification for command behavior instead of browser E2E by default

### Rule 4: Tooling choices MUST support cross-platform shell use

Choose dependencies and runtime assumptions that behave reliably across:

- macOS and Linux
- non-interactive shells
- CI execution

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Treating browser frameworks as the CLI default | Pulls in irrelevant complexity | Start with Bun or Python for terminal-first tools |
| Requiring a remote database for a simple local tool | Raises setup and failure cost unnecessarily | Stay stateless or use lightweight local persistence first |
| Defaulting to browser E2E tooling for CLI verification | Mismatches the actual risk surface | Use command-level tests and shell-safe smoke checks |
| Assuming one shell/platform behavior everywhere | Breaks for users and CI | Prefer cross-platform-safe tooling and scripts |

### Rule 5: CLI projects adding a web surface MUST adopt the approved stack for that surface

When a CLI project adds a web surface (config UI, dashboard, auth-gated pages), choose from the approved stacks below rather than making an ad hoc choice. These align with the portfolio-wide standards so that graduating to the full target profile later requires no re-platforming.

| Web surface type | Approved stack | Target profile when surface becomes primary |
|---|---|---|
| React SaaS product UI + auth | Next.js App Router + Clerk + Convex or Postgres + Drizzle | `webapp` |
| Content/marketing site on Vercel | Astro 5/6 + Clerk/Auth.js + Neon + Drizzle | `astro-vercel` |
| Astro site on Cloudflare Workers | Astro 7 static by default; explicit full-stack adapter and services when required | `astro-cloudflare` |
| Mobile-first PWA | Next.js or Astro + Clerk/Supabase Auth + Supabase | `pwa` |
| Business/marketing site | Next.js 15 + Supabase Auth + shadcn | `business` |
| Cloudflare Workers API or MCP server | Hono + JWT + KV/D1 | `cloudflare-workers` (already a child profile) |

Do NOT invent a one-off auth or data choice for "just this web page." Pick the row above and stay aligned.

See `profiles/cli/standards/frontend/web-surface-extension.md` for UX/frontend standards that apply before graduation.

---

## Profile Graduation

A CLI project should graduate to a target profile when **the web surface becomes the primary product surface** — i.e. when the CLI is a secondary tool or admin interface rather than the main user-facing artifact.

| When your project... | Graduate to |
|---|---|
| Ships a persistent React UI with auth for end users | `webapp` |
| Is primarily a content/marketing site (Vercel) | `astro-vercel` |
| Is primarily a content/marketing site (Cloudflare) | `astro-cloudflare` |
| Becomes a mobile-first PWA | `pwa` |
| Is primarily a business/SEO site | `business` |
| Is primarily an AI agent system | `agents` |
| Adds a Cloudflare Workers API layer | `cloudflare-workers` (profile-config switch, no full reinit) |

**Graduation command:**
```bash
devos-init --profile <target-profile>
```

Run from the project root. Re-applies standards, updates `.dev-os/config.yml`, syncs hooks and context.

See `profiles/PROFILE-SELECTION.md` for the full decision guide across all 14 profiles.

---

## Deviation Guidance

- CLI projects MAY include a lightweight web surface when the product truly has one. When they do, use the approved stack from Rule 5.
- When the web surface becomes the primary surface, graduate the profile — do not extend indefinitely.
- Teams MUST NOT use this file as project-truth inventory or machine-readable stack config.

## Profile Inheritance Notes

Overrides: default profile browser-heavy assumptions as defaults
Adds: terminal-first runtime and verification guidance

## Compliance Test

- [ ] Does the project default to Bun or Python rather than browser-first stacks?
- [ ] Is persistence optional or lightweight unless shared state is genuinely required?
- [ ] Does verification focus on command behavior rather than browser flows by default?
- [ ] Are tooling choices compatible with cross-platform shell execution?
- [ ] Does this file describe CLI-specific deltas rather than duplicating the parent inventory?
- [ ] If the project has a web surface, is it using an approved stack from Rule 5?
- [ ] If the web surface has become primary, has the profile been graduated via `devos-init --profile <target>`?
