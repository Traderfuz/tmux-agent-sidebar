<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/local-first-development.md and re-run profile-sync. -->
# Local-First Development Standard

## Overview

All development work runs and is verified locally — with production-equivalent secrets injected via
Doppler — before any deployment command is issued. This standard eliminates the "works on my
machine" failure class by enforcing environment parity at every stage of the local workflow.

When secrets are missing from a dev process, the application may appear to start successfully
while silently failing to connect to APIs, databases, or third-party services. The resulting false
confidence is more dangerous than an outright crash. This standard closes that gap by mandating
secret injection and required-key surfacing as pre-conditions for any dev server invocation.

## Scope

This standard covers local development server startup, local build verification, and the
pre-deploy gate that confirms local work before any deployment command runs. It does NOT cover
Doppler project provisioning, secret rotation procedures, or production deployment configuration
(see `standards/deployment/vercel-doppler.md` for those).

## Named Frameworks

### The Twelve-Factor App — Factor X: Dev/Prod Parity (Heroku, 2011)

> "Keep development, staging, and production as similar as possible."

Factor X identifies three parity gaps that cause production failures: the **time gap** (slow
deploys hide divergence), the **personnel gap** (devs don't own ops), and the **tools gap**
(different backing services per environment). This standard addresses the tools gap directly:
secrets must be drawn from the same Doppler project in `dev` config as production uses in `prd`
config — same secret names, different values.

**Factor III (Config):** "Store config in the environment." Doppler satisfies this by injecting
environment variables at process start without storing them in code or version-controlled files.

Reference: [12factor.net/dev-prod-parity](https://12factor.net/dev-prod-parity)

### Shift-Left Testing (Larry Smith, 2001)

Move defect detection to the earliest possible point in the lifecycle. A defect caught on the
developer's local machine costs 1× to fix; the same defect in production costs 60–100× more
(IBM Systems Sciences Institute). Running locally with real secrets shifts auth failures,
misconfiguration, and integration errors left — before they reach CI, preview, or production.

Reference: [IBM: What is Shift-Left Testing](https://www.ibm.com/think/topics/shift-left-testing)

## Principles

1. **Parity before promotion:** A feature is not ready to deploy until it runs correctly
   locally with `dev` secrets. Local is the first environment, not a pre-environment.

2. **Secrets are not optional at dev time:** Running without secrets is not "running without
   external services" — it is running in an undefined state. Required keys must be present and
   confirmed before the dev server starts.

3. **The canonical runner is the authoritative invoker:** `scripts/doppler-run.sh` is the
   single entry point for all dev commands. It encodes branch-to-config mapping so the correct
   secrets are always selected without manual flag passing.

4. **The project pin is mandatory:** `.doppler.yaml` at the project root pins the project slug
   and default config. Without it, every developer must know the project slug by memory — an
   onboarding failure vector.

5. **Surface required keys actively:** The system tells the developer which keys are required
   and confirms they are present before startup. Silent empty-value failures are not acceptable.

## Rules

### Rule 1: `.doppler.yaml` MUST be present and pinned to the project

Every Doppler-enabled project MUST have a `.doppler.yaml` at the repository root containing at
minimum:

```yaml
project: <your-project-slug>
config: dev
```

The `config: dev` default ensures all local invocations resolve to the development environment
without additional flags.

```bash
# OFF-STANDARD — no .doppler.yaml, developer must know the slug
doppler run --project my-app --config dev -- bun run dev

# ON-STANDARD — .doppler.yaml present, no flags needed
scripts/doppler-run.sh bun run dev
# → Branch: feature/auth-flow
# → Config: dev
# → Running: doppler run --config dev -- bun run dev
```

**Enforcement:** `start` warns when `.doppler.yaml` is absent. The warning is not
skippable until the file is created.

**`.doppler.yaml` is committed to the repository.** It contains no secrets — only the project
slug and default config name. It is not git-ignored.

### Rule 2: `scripts/doppler-run.sh` is the canonical dev invocation (`MUST`)

All dev server start commands, local builds, and local test runs MUST be prefixed with
`scripts/doppler-run.sh`. This script:

- Reads the current git branch
- Maps `feature/*`, `fix/*`, `chore/*`, `refactor/*`, `docs/*`, `test/*`, `hotfix/*` → `dev` config
- Maps `main` → `prd` config
- Allows override via `DOPPLER_CONFIG=preview scripts/doppler-run.sh <cmd>`

```bash
# OFF-STANDARD — bare invocation, empty secrets on Doppler-enabled project
bun run dev
npm run dev

# OFF-STANDARD — manual flag, bypasses branch detection
doppler run --config dev -- bun run dev

# ON-STANDARD — canonical dev server skill
dev-server start

# ON-STANDARD — canonical Doppler runner when skill is unavailable
scripts/doppler-run.sh bun run dev          # single server
scripts/doppler-run.sh bun run test         # test suite with secrets
scripts/doppler-run.sh bun run build        # local build verification

# ON-STANDARD — override when explicitly needed
DOPPLER_CONFIG=preview scripts/doppler-run.sh bun run dev
```

### Rule 3: Required API keys MUST be surfaced before dev server startup (`MUST`)

Before the dev server process is registered and started, the project MUST surface which Doppler
secrets are required and confirm they are present in the `dev` config. This check is performed
by `scripts/lib/checks/doppler-validator.sh`.

**Declaration sources (checked in order):**
1. `.dev-os/pre-deployment.yml` — `required_vars:` block (explicit, project-controlled)
2. `.env.example` — any key matching `API_KEY`, `SECRET_KEY`, `PRIVATE_KEY`, `DATABASE_URL`,
   `NEXTAUTH_*`, `CONVEX_DEPLOYMENT` patterns (auto-detected fallback)

**Output format when keys are confirmed:**

```
✓ Doppler dev secrets verified
  Project: my-app  Config: dev
  Required keys present: DATABASE_URL, NEXTAUTH_SECRET, CONVEX_DEPLOYMENT
```

**Output format when keys are missing:**

```
✗ Required Doppler secrets missing — dev server will not start correctly
  ISSUE: Required secret 'DATABASE_URL' not found in Doppler project 'my-app'
  ISSUE: Required secret 'NEXTAUTH_SECRET' not found in Doppler project 'my-app'

  Fix: doppler secrets set DATABASE_URL="..." --project my-app --config dev
  Or:  doppler open dashboard
```

The dev server SHOULD NOT start when ISSUE-level secrets are missing. WARNING-level absences
(optional vars) are surfaced but do not block startup.

### Rule 4: Local build MUST pass before any deploy command (`MUST`)

Before running any deploy command — preview, staging, or production — the local build MUST have
passed using `dev` secrets:

```bash
# OFF-STANDARD — first build is a remote deploy
doppler run --config prd -- vercel build --prod

# ON-STANDARD — local build verified first, then deploy
scripts/doppler-run.sh bun run build        # Step 1: local build with dev secrets
scripts/doppler-run.sh bun run type-check   # Step 2: type safety (if applicable)
# Step 3: deploy (only after steps 1-2 pass)
doppler run --config prd -- vercel build --prod
doppler run --config prd -- bash -c 'vercel deploy --prod --prebuilt --archive=tgz ...'
```

The `feature-delivery.md` pipeline enforces this gate at Step 8 (test/harden) before Step 10
(merge/deploy).

### Rule 5: Multi-server projects use coordinated startup (`SHOULD`)

Projects requiring multiple servers (e.g., Convex backend + application server) MUST start both
processes through `doppler-run.sh` and register both with the dev server registry:

```bash
# OFF-STANDARD — only one process has secrets, coordination is manual
npx convex dev --local &
bun run dev

# ON-STANDARD — both processes have secrets, registry tracks both
scripts/doppler-run.sh npx convex dev --local &   # Terminal 1 — registers as convex-dev
scripts/doppler-run.sh bun run dev                  # Terminal 2 — registers as app-server

# Verify both running
scripts/devos-dev-server-registry.sh list
```

Use the `local-dev-startup.md` pipeline for coordinated multi-server startup with health checks.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `bun run dev` (bare) | Loads empty secrets; auth/DB silently broken | `scripts/doppler-run.sh bun run dev` |
| `doppler run --project X --config dev --` every time | Requires slug memorization; breaks if slug changes | `.doppler.yaml` + `scripts/doppler-run.sh` |
| No `.doppler.yaml` committed | Onboarding friction; each dev guesses config name | Commit `.doppler.yaml` with `project:` + `config: dev` |
| Skipping local build before deploy | Remote build catches failures too late; secrets differ | `scripts/doppler-run.sh bun run build` first |
| Storing secrets in `.env.local` or `.env` | Version control risk; out of sync with Doppler | Doppler is the single source; no `.env` files |
| Starting dev server without key check | Silent failure on missing secrets appears as success | Run `doppler-validator.sh` pre-startup |
| `DOPPLER_CONFIG=prd scripts/doppler-run.sh bun run dev` | Uses production secrets locally — dangerous | Only `dev` config for local development |

## Offline / Doppler Unavailable Fallback

When Doppler is unreachable (no network, VPN down), the following fallback is permitted:

1. Export a snapshot of dev secrets to a local file **that is git-ignored**:
   ```bash
   doppler secrets download --no-file --format env --config dev > .env.local.doppler
   echo ".env.local.doppler" >> .gitignore
   ```
2. Source the file for the session:
   ```bash
   set -a; source .env.local.doppler; set +a
   bun run dev
   ```
3. Delete the file when connectivity is restored.

**MUST NOT** commit `.env.local.doppler` to version control. This fallback is session-scoped
only. The file MUST be listed in `.gitignore` before the snapshot is created.

## Deviation Guidance

**MAY** run bare `bun run dev` when the project has no Doppler integration (no `.doppler.yaml`,
no Doppler secrets). The prohibition applies only to projects where `.doppler.yaml` is present.

**MAY** use `DOPPLER_CONFIG=preview scripts/doppler-run.sh bun run dev` to test against preview
secrets locally when debugging a preview-environment-specific issue. Document the reason.

**MUST NOT** use `DOPPLER_CONFIG=prd` locally under any circumstances.

## Enforcement Points

| Enforcement | Where | Action |
|---|---|---|
| `.doppler.yaml` presence | `start` | Warn on absent; provide scaffold command |
| `.doppler.yaml` presence | `local-dev-startup.md` pipeline Step 1 | Fail with remediation hint |
| Required key check | `local-dev-startup.md` pipeline Step 3 | Block server start on ISSUE-level missing keys |
| Required key check | `dev-server start` command | Surface key check output to user |
| Doppler prefix on test | `test` | Prepend `scripts/doppler-run.sh` to test command |
| Local build before deploy | `feature-delivery.md` pipeline Step 8 | Gate before Step 10 (merge/deploy) |

## Profile Inheritance Notes

This standard lives in `general/standards/global/` and applies to all profiles that inherit from
`general`. Profile-specific extensions:

- `webapp` profile: additionally requires `vercel-doppler.md` compliance for deploy steps
- `cli` profile: dev server rules apply only when the CLI project has a companion web process;
  otherwise only Rules 1, 2, and 5 (key surfacing) apply

## Compliance Test

Run this checklist before declaring a project's local dev setup complete:

- [ ] `.doppler.yaml` exists at project root with `project:` and `config: dev` set?
- [ ] `.doppler.yaml` is committed to version control (not git-ignored)?
- [ ] All dev server start commands in runbooks and scripts use `scripts/doppler-run.sh` (not bare `bun run dev`)?
- [ ] `required_vars:` declared in `.dev-os/pre-deployment.yml` OR secrets documented in `.env.example`?
- [ ] Required key check (`doppler-validator.sh`) runs before dev server registers as healthy?
- [ ] Local build (`scripts/doppler-run.sh bun run build`) passes before any deploy command runs?
- [ ] `.env.local.doppler` (offline fallback) listed in `.gitignore` if the file exists?

If any check fails: fix it, or explicitly record the deviation with justification in `CLAUDE.md`
under a `## Doppler Deviations` heading.

## References

- [The Twelve-Factor App — Factor X: Dev/Prod Parity](https://12factor.net/dev-prod-parity) — canonical dev/prod parity methodology; Heroku (2011)
- [The Twelve-Factor App — Factor III: Config](https://12factor.net/config) — store config in environment variables
- [IBM: Shift-Left Testing](https://www.ibm.com/think/topics/shift-left-testing) — catch defects at the earliest possible stage
- `scripts/doppler-run.sh` — branch-aware canonical dev runner (this repo)
- `scripts/lib/checks/doppler-validator.sh` — required API key checker (this repo)
- `scripts/lib/dev-server.sh` — server lifecycle library (this repo)
- `scripts/devos-dev-server-registry.sh` — server registry CLI (this repo)
- `profiles/general/workflows/pipelines/local-dev-startup.md` — startup pipeline (this repo)
