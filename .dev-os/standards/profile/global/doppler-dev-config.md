<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/doppler-dev-config.md and re-run profile-sync. -->
# Doppler Dev Config Pinning Standard

## Overview

Every Doppler-enabled project pins its Doppler project slug and default config to a committed
`.doppler.yaml` file at the repository root. This file contains no secrets — only the project
identifier and environment name — making it safe and necessary to commit. Without it, every
developer must know the project slug by memory, CI/CD must pass explicit flags, and the
`doppler-validator.sh` key-check cannot auto-detect the project context.

Required API keys are declared in `.dev-os/pre-deployment.yml` under `required_vars:`. This
declaration is the contract that `doppler-validator.sh` enforces: before any dev server starts,
every required key is confirmed present in the `dev` config and surfaced to the developer.

## Scope

This standard covers the `.doppler.yaml` project-pin file and the `.dev-os/pre-deployment.yml`
required-key declaration for local development. It does NOT cover Doppler secret values, secret
rotation, production deployment secrets, or the commands used to invoke Doppler at runtime (see
`local-first-development.md` for invocation patterns).

## Named Frameworks

### OWASP Secrets Management Cheat Sheet

OWASP's canonical secrets management guidance distinguishes between **project configuration**
(which environment and project slug to use — safe to commit) and **secret values** (which must
never appear in version control). The `.doppler.yaml` pattern follows this distinction precisely:
the file is pure configuration, not a secret. Only `.env.example` (documenting key names, not
values) is committed alongside it.

Reference: [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

### Convention over Configuration (Rails Doctrine, DHH 2004)

The `.doppler.yaml` pin applies Convention over Configuration: a sensible default (`config: dev`)
is declared once in a committed file, and all tooling (`doppler-run.sh`, `doppler-validator.sh`,
`start`) discovers it without flags. Deviation (using `preview` or `prd` locally)
requires an explicit override — `DOPPLER_CONFIG=preview`. The default is never ambiguous.

### Twelve-Factor App — Factor III: Config

> "Store config in the environment. An app's config is everything that is likely to vary between
> deploys (staging, production, developer environments, etc)."

`.doppler.yaml` stores *which* environment to use (the config selector), not the config values
themselves. The values are always injected at runtime via `doppler run`. This preserves the
12-Factor separation: code knows nothing about which environment it is targeting.

Reference: [12factor.net/config](https://12factor.net/config)

## Principles

1. **Project context is explicit, not assumed:** Every tool that reads Doppler secrets discovers
   the project slug from `.doppler.yaml` — no memorization, no ambient environment variables,
   no per-developer configuration drift.

2. **Required keys are declared, not discovered at failure time:** The system surfaces missing
   keys before the process starts, not after it crashes. `required_vars:` is the machine-readable
   contract between the application and its secrets store.

3. **Configuration files are not secrets:** `.doppler.yaml` is safe to commit because it contains
   only selector metadata. The distinction between "which vault" (safe) and "what is in the
   vault" (never commit) is the foundation of sound secrets hygiene.

4. **Configs are environment-typed, not count-based:** Three named configs cover all use cases:
   `dev`, `preview`, `prd`. No ad-hoc environment names, no numeric suffixes, no per-developer
   forks.

## Rules

### Rule 1: `.doppler.yaml` MUST be present, pinned, and committed (`MUST`)

Every Doppler-enabled project MUST have `.doppler.yaml` at the repository root. The file MUST
contain exactly two top-level keys:

```yaml
# OFF-STANDARD — absent: every tool must be told the project slug manually
# (no .doppler.yaml)

# OFF-STANDARD — partial: config key missing, tools default to wrong environment
project: my-app

# OFF-STANDARD — secret value in file
project: my-app
config: dev
NEXTAUTH_SECRET: abc123   # ← NEVER

# ON-STANDARD — project pin only, no secrets
project: my-app
config: dev
```

**`config: dev` is always the committed default.** It is overridden at runtime via
`DOPPLER_CONFIG=preview` when targeting a non-dev environment locally. Never commit
`config: prd` — production config must be invoked explicitly, never assumed.

**`.doppler.yaml` MUST NOT appear in `.gitignore`.** Run `git check-ignore -v .doppler.yaml`
to verify. If it is ignored, remove the ignore rule and commit the file.

### Rule 2: Project slug in `.doppler.yaml` MUST match CLAUDE.md declaration (`MUST`)

When a project has a `CLAUDE.md` that documents a Doppler project slug (under a heading such
as `## Production Deploy` or `## Doppler`), the `project:` value in `.doppler.yaml` MUST match
it exactly.

```yaml
# CLAUDE.md documents: doppler project: my-app-supabase

# OFF-STANDARD — slug mismatch
project: my-app    # ← different from CLAUDE.md declaration

# ON-STANDARD — matches CLAUDE.md exactly
project: my-app-supabase
config: dev
```

The slug is the single source of truth for the Doppler project identity. CLAUDE.md documents it
for humans; `.doppler.yaml` declares it for tools.

### Rule 3: Required API keys MUST be declared in `.dev-os/pre-deployment.yml` (`MUST`)

Every Doppler-enabled project MUST declare its required secrets in `.dev-os/pre-deployment.yml`
under the `required_vars:` key. This file is the machine-readable API-key contract read by
`scripts/lib/checks/doppler-validator.sh`.

**Minimal format:**

```yaml
# .dev-os/pre-deployment.yml
required_vars:
  - DATABASE_URL
  - NEXTAUTH_SECRET
  - NEXTAUTH_URL

optional_vars:
  ANALYTICS_KEY:
    description: "PostHog analytics — omit to disable tracking"
  RESEND_API_KEY:
    description: "Email sending — omit to disable outbound email"
```

**Full format with project-type examples:**

```yaml
# Next.js + Convex + Supabase project
required_vars:
  - DATABASE_URL          # Supabase connection string
  - NEXTAUTH_SECRET       # Next-Auth signing secret
  - NEXTAUTH_URL          # Auth callback base URL (http://localhost:3000 for dev)
  - CONVEX_DEPLOYMENT     # Convex deployment name or URL

optional_vars:
  POSTHOG_KEY:
    description: "Analytics — omit to disable"
  STRIPE_SECRET_KEY:
    description: "Payment — omit to disable checkout flows"
  RESEND_API_KEY:
    description: "Transactional email — omit to disable outbound email"
```

**When `.dev-os/pre-deployment.yml` is absent or has no `required_vars:` block,**
`doppler-validator.sh` falls back to auto-detecting required keys from `package.json` and
`.env.example` patterns (Next-Auth, Convex, DATABASE_URL, API_KEY prefixes). This fallback
SHOULD NOT be relied upon — explicit declaration is the standard.

### Rule 4: Doppler config hierarchy is `dev` / `preview` / `prd` only (`MUST`)

Three config names are recognized across all DevOS projects:

| Config name | Purpose | Who sets it |
|-------------|---------|-------------|
| `dev` | Local development — all developers | Default in `.doppler.yaml` |
| `preview` | PR/staging deployments | Set by CI; override locally with `DOPPLER_CONFIG=preview` |
| `prd` | Production | Set by deploy pipeline only |

```bash
# OFF-STANDARD — ad-hoc environment names
project: my-app
config: local_tafadzwa    # ← per-developer config, not a recognized tier

# OFF-STANDARD — numeric suffix
project: my-app
config: dev2              # ← ambiguous; what is dev1?

# ON-STANDARD — recognized tier
project: my-app
config: dev
```

**No ad-hoc or per-developer config names.** If different developers need different values,
those values belong in the Doppler `dev` config with feature-flag-style fallbacks, not separate
configs.

### Rule 5: Required key check output MUST be surfaced before dev server registers (`MUST`)

When `doppler-validator.sh` runs its key check, the output is surfaced to the developer before
the server process registers in the registry. The output format is:

**All keys present (success path):**

```
✓ Doppler dev secrets verified
  Project: my-app-supabase  Config: dev
  Required keys present (4/4):
    ✓ DATABASE_URL
    ✓ NEXTAUTH_SECRET
    ✓ NEXTAUTH_URL
    ✓ CONVEX_DEPLOYMENT
```

**Missing required keys (blocked path):**

```
✗ Required Doppler secrets missing — dev server blocked
  Project: my-app-supabase  Config: dev

  MISSING (required — server will not start):
    ✗ DATABASE_URL
    ✗ NEXTAUTH_SECRET

  Fix options:
    doppler secrets set DATABASE_URL="postgres://..." --project my-app-supabase --config dev
    doppler open dashboard   # → manage secrets in browser

  Run again after fixing missing keys.
```

**Optional keys absent (warning path — non-blocking):**

```
  WARNING (optional — degraded functionality):
    ⚠ POSTHOG_KEY   (Analytics disabled — see .dev-os/pre-deployment.yml)
    ⚠ RESEND_API_KEY (Email disabled — see .dev-os/pre-deployment.yml)
```

### Rule 6: Creating the `.doppler.yaml` scaffold (`SHOULD`)

**Interactive setup (preferred for first-time):**

```bash
doppler setup
# → prompts: select project, select config
# → writes .doppler.yaml automatically
```

**Manual creation:**

```bash
printf 'project: %s\nconfig: dev\n' "$(basename "$PWD")" > .doppler.yaml
# → verify: cat .doppler.yaml
# → verify: doppler run -- env | grep DOPPLER
```

**`start` scaffold prompt (when `.doppler.yaml` absent):**

When `start` detects that `.doppler.yaml` is missing, it displays:

```
⚠  .doppler.yaml not found — Doppler secrets will not be injected automatically.

   To create it:
     doppler setup                        # interactive (recommended)
     # OR
     printf 'project: <slug>\nconfig: dev\n' > .doppler.yaml

   Then commit it:
     git add .doppler.yaml && git commit -m "chore: pin Doppler project config"

   Skip with: DEVOS_SKIP_DOPPLER_CHECK=1 start
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| No `.doppler.yaml` at all | Every tool needs explicit `--project` / `--config` flags; breaks `doppler-validator.sh` auto-detect | `doppler setup` → commit `.doppler.yaml` |
| `.doppler.yaml` in `.gitignore` | Each developer creates their own; configs diverge; CI has no pin | Remove from `.gitignore`, commit the file |
| `config: prd` committed in `.doppler.yaml` | All local runs use production secrets; local mistakes affect live data | Always `config: dev`; override explicitly with `DOPPLER_CONFIG=prd` |
| Secret value in `.doppler.yaml` | Secrets in version control — the primary threat the file was designed to prevent | Only `project:` and `config:` keys in the file |
| No `required_vars:` in `pre-deployment.yml` | Key check falls back to heuristics; missing keys not caught until runtime crash | Declare all required keys explicitly |
| Ad-hoc config names (`local_dev`, `dev2`) | Not recognized by `doppler-run.sh` branch mapping; breaks CI config | Use only `dev`, `preview`, `prd` |

## Scaffolding `.dev-os/pre-deployment.yml` from Scratch

Run this to generate a starter file from `.env.example`:

```bash
# Extract key names from .env.example and scaffold required_vars
echo "required_vars:" > .dev-os/pre-deployment.yml
grep -E '^[A-Z_][A-Z_0-9]*=' .env.example | cut -d= -f1 | sort | while read -r key; do
  echo "  - $key"
done >> .dev-os/pre-deployment.yml

echo "" >> .dev-os/pre-deployment.yml
echo "optional_vars: {}" >> .dev-os/pre-deployment.yml

cat .dev-os/pre-deployment.yml   # verify output
```

Then edit the file to move optional keys to `optional_vars:` with descriptions.

## Deviation Guidance

**MAY** omit `.doppler.yaml` in projects that do not use Doppler. The standard applies only when
a Doppler project exists for the repository. Presence of `.doppler.yaml` in any ancestor project
does not impose this standard on a sub-directory project.

**MAY** use `DEVOS_SKIP_DOPPLER_CHECK=1` to bypass the `start` warning during initial
setup before Doppler is configured. MUST configure Doppler and commit `.doppler.yaml` before
the first dev server registration.

**MUST NOT** deviate from the three-config hierarchy (`dev`, `preview`, `prd`). If a project
genuinely needs a fourth tier, document the reasoning in `CLAUDE.md` and raise it for review.

## Enforcement Points

| Enforcement | Where | Action |
|---|---|---|
| `.doppler.yaml` presence | `start` | Warn; show scaffold command; non-blocking with `DEVOS_SKIP_DOPPLER_CHECK=1` |
| `.doppler.yaml` presence | `local-dev-startup.md` pipeline Step 1 | Fail with remediation hint |
| `required_vars:` declared | `start` check | Warn if `pre-deployment.yml` has no `required_vars:` |
| Required key presence | `doppler-validator.sh` | Block dev server start on MISSING keys |
| Slug consistency | `triage` command | Flag when `.doppler.yaml` project slug differs from CLAUDE.md declaration |

## Compliance Test

Run this checklist when setting up a new project or reviewing an existing one:

- [ ] `.doppler.yaml` exists at project root?
- [ ] `.doppler.yaml` contains `project: <slug>` and `config: dev` (exactly these two keys, no secret values)?
- [ ] `.doppler.yaml` is committed to version control and NOT in `.gitignore` (verified with `git check-ignore -v .doppler.yaml`)?
- [ ] `.dev-os/pre-deployment.yml` exists with at least one key under `required_vars:`?
- [ ] All `required_vars` are present in the Doppler `dev` config (verified by running `scripts/lib/checks/doppler-validator.sh`)?
- [ ] Doppler project slug in `.doppler.yaml` matches the slug documented in `CLAUDE.md` (if `CLAUDE.md` documents one)?

If any check fails: fix it before running `local-dev-startup.md`. Record any intentional deviation with justification in `CLAUDE.md` under `## Doppler Deviations`.

## References

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) — configuration vs secret value distinction; vault-first posture
- [Twelve-Factor App — Factor III: Config](https://12factor.net/config) — store config in the environment; separate selector from value
- [Doppler CLI: doppler setup](https://docs.doppler.com/docs/cli) — interactive `.doppler.yaml` creation
- `scripts/lib/checks/doppler-validator.sh` — required key checker (reads `pre-deployment.yml` + `.env.example`)
- `profiles/general/standards/global/local-first-development.md` — companion standard covering invocation patterns
- `profiles/general/workflows/pipelines/local-dev-startup.md` — startup pipeline that enforces this standard at Step 1
