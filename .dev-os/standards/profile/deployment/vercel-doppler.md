<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/deployment/vercel-doppler.md and re-run profile-sync. -->
# Vercel + Doppler Deployment Standards

**Profile:** general (applies to all profiles — webapp, pwa, business, cli)
**Source:** Distilled from `docs/guides/VERCEL_DOPPLER_DEPLOYMENT_GUIDE.md` and `docs/guides/DOPPLER_SETUP_GUIDE.md`

---

## Core Principles

1. **Preview-first** — Deploy to preview by default. Production requires an explicit command.
2. **Team-based** — All deployments go to the team workspace, never a personal account.
3. **Root deployment** — Always run `vercel` from the repo root when Root Directory is configured in Vercel dashboard.
4. **Doppler injection** — Every command that touches secrets must go through `doppler run --config <env> --`.
5. **Local Convex for dev** — When using Convex, always run `npx convex dev --local` during development. Never connect dev workflows to the cloud Convex deployment.

---

## Why These Rules Exist

Running `npx convex dev` (without `--local`) connects to the cloud-hosted Convex deployment.
Every hot-reload, query, and mutation goes over the wire — causing unnecessary cloud billing and
risk of polluting shared data. The `--local` flag runs a local Convex process with zero cloud traffic.

Running commands without `doppler run` causes missing secrets → Clerk infinite redirect loops,
Convex "function not found" errors, and React hooks errors.

---

## Prerequisites

```bash
# Install Doppler CLI
curl -sL https://cli.doppler.com/install.sh | sh

# Install Vercel CLI
bun add -g vercel

# Verify
doppler --version && vercel --version
```

---

## Environment Strategy

| Environment | Purpose | Doppler Config | When to Use |
|-------------|---------|----------------|-------------|
| **dev** | Local development | `dev` | Active development |
| **preview** | Testing / review | `prd` | After committing, code review, demos |
| **production** | Live site | `prd` | Only when explicitly instructed |

```
Did you just commit/push?
├─ YES → Deploy to preview: doppler run --config prd -- vercel
└─ NO  → Use local dev:    doppler run --config dev -- bun run dev
```

---

## One-Time Project Setup

```bash
# 1. Link to team (not personal account)
vercel link --scope=<team-name> --yes

# 2. Disable accidental production deploys in vercel.json
cat > vercel.json << 'EOF'
{
  "github": { "silent": true },
  "production": { "disabled": true }
}
EOF

# 3. Create Doppler project and environments
doppler projects create <project-name>
doppler environments create "Preview" preview --project <project-name>

# 4. Create .doppler.yaml
cat > .doppler.yaml << 'EOF'
project: <project-name>
config: dev
EOF

# 5. Verify team link
cat .vercel/project.json | grep -i team
```

---

## Daily Dev Workflow

```bash
# With Convex backend
# Terminal 1: Local Convex (NOT cloud)
doppler run --project <project> --config dev -- npx convex dev --local

# Terminal 2: Web app
doppler run --project <project> --config dev -- bun run dev

# Without Convex
doppler run --config dev -- bun run dev
```

---

## Deployment Commands

```bash
# Preview (safe default)
doppler run --config prd -- vercel

# Preview without confirmation
doppler run --config prd -- vercel --yes

# Convex + Vercel (when using Convex backend)
doppler run --config prd -- npx convex deploy --yes && \
doppler run --config prd -- vercel --yes

# Production (only when explicitly instructed)
doppler run --config prd -- vercel --prod
```

---

## Pre-Deployment Checklist

### Vercel
- [ ] Project linked to correct **team** (not personal account)
- [ ] Deploying from **repo root** (not subdirectory)
- [ ] `vercel.json` present with production disabled

### Doppler
- [ ] `.doppler.yaml` committed (no secrets)
- [ ] `dev` config has local development keys
- [ ] `prd` config has production keys

### Convex (if applicable)
- [ ] Functions deployed (`npx convex function list`)
- [ ] Using `--local` for dev, explicit `deploy` for prd
- [ ] No hardcoded production URL in client code

### Build
- [ ] `bun run build` passes locally with `doppler run --config prd --`
- [ ] No TypeScript errors (`tsc --noEmit`)
- [ ] All tests passing

---

## Common Issues and Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Module not found" on deploy | Running `vercel` from subdirectory | `cd` to repo root first |
| Deployed to personal account | `vercel link` not run | `rm -rf .vercel && vercel link --scope=<team>` |
| Build fails — "ENV_VAR undefined" | Missing Doppler secrets | `doppler secrets --config prd` to verify |
| "production is disabled" | Safety feature in `vercel.json` | Deploy to preview, or get explicit approval for prod |
| Clerk infinite redirect locally | Running without Doppler | Wrap all commands with `doppler run --config dev --` |
| Convex "function not found" locally | Hitting cloud instead of local | Use `npx convex dev --local` |

---

## Template Files

### `vercel.json`
```json
{
  "github": { "silent": true },
  "production": { "disabled": true }
}
```

### `.doppler.yaml`
```yaml
project: <project-name>
config: dev
```

### `.env.example`
```bash
# Core
NEXT_PUBLIC_CONVEX_URL=
CONVEX_DEPLOYMENT=
AUTH_SECRET=

# Auth (Clerk)
CLERK_SECRET_KEY=
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=

# Optional integrations
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
```

### `.vercelignore`
```
node_modules/
.env.local
.env*.local
*.log
.DS_Store
```
