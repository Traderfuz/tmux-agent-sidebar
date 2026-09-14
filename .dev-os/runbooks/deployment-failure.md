# Runbook: Deploy Skill — Adapter Failure Recovery

| Field | Value |
|-------|-------|
| Service | DevOS deploy skill (`deploy`) |
| Runbook type | Diagnostic / Multi-Platform Deployment |
| Severity | P2 (blocked release) — P1 if hotfix deploy for active outage |
| Owner team | Developer running the deploy |
| Last reviewed | 2026-04-13 |
| Automation status | Manual — this runbook runs when the deploy automation fails |

---

## 1. Trigger & Detection

**Trigger:** `deploy` exits non-zero at any stage.

Failure stages (in execution order):

```
Shared gate     → Doppler auth / .doppler.yaml / prd confirmation
Supabase        → db push / functions deploy
Convex          → npx convex deploy
Vercel          → vercel build (Step 1) / vercel deploy --prebuilt (Step 2)
Cloudflare      → wrangler deploy / wrangler pages deploy
iOS             → fastlane beta/release / eas build / eas submit
Post-deploy     → curl validation / migration list check
```

**Detection signal:** Non-zero exit code, error message in terminal output, or
missing expected output (e.g., no deployment URL returned).

---

## 2. Impact Assessment

**Triage checklist** — complete in order, stop when severity is determined:

- [ ] Is this a hotfix deploy for an active production outage? → **P1** — escalate immediately, fix deploy blocker before anything else
- [ ] Did the deploy fail at the Supabase migration step (`supabase db push`)? → **P2** — schema may be in partial state; check migration list before retrying
- [ ] Did the deploy fail AFTER Vercel `vercel build` but BEFORE `vercel deploy`? → **P2** — artifact built locally, secrets baked in; safe to retry Step 2 only
- [ ] Did the deploy fail at validation (curl returns non-2xx) but deploy completed? → **P2** — code is live but unhealthy; may need rollback
- [ ] Did the deploy fail at the shared gate (Doppler/auth)? → **P3** — nothing deployed; fix auth and retry
- [ ] Did the deploy fail at iOS (Fastlane/EAS) only? → **P3** — web is unaffected; iOS release blocked only

**Blast radius by stage:**

| Stage | State modified? | Rollback complexity |
|-------|----------------|---------------------|
| Shared gate | None | None — retry |
| Supabase migrations | Yes — schema changed | High — write reverse migration |
| Supabase functions | Yes — functions updated | Low — redeploy previous tag |
| Convex functions | Yes — functions updated | Low — redeploy previous tag |
| Vercel build (Step 1) | No — local only | None — retry build |
| Vercel deploy (Step 2) | Yes — live traffic | Low — `vercel rollback` |
| Cloudflare deploy | Yes — live traffic | Low — `wrangler rollback` |
| Post-deploy validation | None | Depends on what's unhealthy |

---

## 3. Prerequisites

- `doppler` CLI authenticated: `doppler me`
- `git` available: `git --version`
- Adapter-specific CLI (whichever failed):
  - Vercel: `vercel --version`
  - Cloudflare: `wrangler --version`
  - Convex: `npx convex --version`
  - Supabase: `supabase --version`
  - iOS/Expo: `fastlane --version` or `eas --version`
- `.doppler.yaml` present: `cat .doppler.yaml`
- On the correct branch: `git branch --show-current`

---

## 4. Investigation Steps

### Step 4.1: Identify which stage failed

```bash
# Read the full error output from the failed deploy
# Look for the last non-zero exit in the terminal scroll

# Confirm current branch
git branch --show-current
# Expected: main (for prd deploys)

# Confirm Doppler auth
doppler me
# Expected: "Logged in as <email>"

# Confirm .doppler.yaml slug
grep "^project:" .doppler.yaml
# Expected: "project: <your-slug>"
```

### Step 4.2: Stage-specific investigation

**Shared gate failure (Doppler / auth):**
```bash
# Test Doppler auth
doppler me
# If: "Error: you are not authenticated" → go to section 5A

# Test secret access
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler secrets --project "$SLUG" --config prd --only-names 2>&1 | head -5
# If: permission error → go to section 5A
# If: success but missing key → go to section 5B
```

**Supabase migration failure:**
```bash
# Check migration status
supabase migration list
# Look for: migrations with local timestamp but no remote timestamp (pending)
# Look for: any ERROR rows

# Check if partial migration applied
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler run --project "$SLUG" --config prd -- bash -c \
  'supabase link --project-ref "$SUPABASE_PROJECT_ID" && supabase migration list'
# Decision tree:
#   All rows have remote timestamp → migration succeeded despite exit code → go to 4.3
#   Some rows missing remote timestamp → partial apply → go to section 5C
#   Error: "already applied" → idempotency issue → go to section 5D
```

**Vercel build failure (Step 1):**
```bash
# Check .vercel/output exists (was build artifact written?)
ls .vercel/output 2>/dev/null && echo "BUILD ARTIFACT EXISTS" || echo "NO ARTIFACT"
# If artifact exists → build succeeded, error was cosmetic → retry Step 2 directly
# If no artifact → build failed → go to section 5E
```

**Vercel deploy failure (Step 2 — artifact upload):**
```bash
# Check VERCEL_TOKEN is present in prd secrets
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler secrets --project "$SLUG" --config prd --only-names | grep -q "VERCEL_TOKEN" \
  && echo "VERCEL_TOKEN: present" || echo "VERCEL_TOKEN: MISSING"

# Check team linking
python3 -c "import json; d=json.load(open('.vercel/project.json')); \
  print('orgId:', d.get('orgId','MISSING'))"
# Expected: orgId: team_xxxx
# If "MISSING" or null → go to section 5F
```

**Cloudflare failure:**
```bash
# Check wrangler auth
wrangler whoami
# Expected: "You are logged in..."
# If not → go to section 5G

# Check wrangler.toml has correct name/account
grep -E "^(name|account_id)" wrangler.toml
```

**Convex failure:**
```bash
# Check Convex auth
npx convex whoami 2>/dev/null || echo "NOT AUTHENTICATED"

# Check CONVEX_DEPLOYMENT in prd secrets
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler secrets --project "$SLUG" --config prd --only-names | grep -q "CONVEX_DEPLOYMENT" \
  && echo "CONVEX_DEPLOYMENT: present" || echo "CONVEX_DEPLOYMENT: MISSING"
```

**Post-deploy validation failure (HTTP non-2xx):**
```bash
# Test the deployment URL directly
DEPLOY_URL="<URL from deploy output>"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$DEPLOY_URL"
# If 5xx → app is deployed but crashing → go to section 5H
# If 4xx → auth/routing issue, not a crash → check vercel.json routes
# If connection refused → deploy may not have propagated → wait 30s and retry
```

### Step 4.3: Decision tree

```
Shared gate failure (Doppler/auth)    → Section 5A or 5B
Supabase migration partial apply      → Section 5C
Supabase migration idempotency error  → Section 5D
Vercel build failed (no artifact)     → Section 5E
Vercel deploy failed (upload/auth)    → Section 5F
Cloudflare auth failed                → Section 5G
Post-deploy app crash (5xx)           → Section 5H
iOS/EAS failure                       → Section 5I
Convex auth/secret missing            → Section 5J
```

---

## 5. Resolution Steps

### 5A — Doppler not authenticated

```bash
# Re-authenticate
doppler login
# Follow browser OAuth flow
# Expected: "Welcome, <email>"

# Retry deploy
deploy
```
Expected after fix: `doppler me` returns email without error.

### 5B — Secret missing from Doppler prd config

```bash
# Identify missing secret from error output
# Add via Doppler dashboard or CLI:
doppler secrets set <SECRET_NAME> --config prd
# Enter value when prompted
# Expected: "Secret <SECRET_NAME> has been saved"

# Retry deploy
deploy
```

### 5C — Supabase migration partial apply

```bash
# Check exactly which migration failed
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler run --project "$SLUG" --config prd -- bash -c \
  'supabase link --project-ref "$SUPABASE_PROJECT_ID" && supabase migration list'

# Option 1: Migration is idempotent — retry push
doppler run --project "$SLUG" --config prd -- bash -c \
  'supabase link --project-ref "$SUPABASE_PROJECT_ID" && supabase db push'
# Expected: remaining migrations apply cleanly

# Option 2: Migration is NOT idempotent — write reverse migration
# Create: supabase/migrations/<timestamp>_rollback_<name>.sql
# Content: reverse the partial change (DROP COLUMN, DROP TABLE, etc.)
supabase migration new rollback_<original_name>
# Edit the file, then:
doppler run --project "$SLUG" --config prd -- bash -c \
  'supabase link --project-ref "$SUPABASE_PROJECT_ID" && supabase db push'
```
Expected: `supabase migration list` shows all rows with remote timestamps.

⚠️ **Never run `supabase db reset` on production** — it wipes the database.

### 5D — Supabase migration "already applied" error

```bash
# Verify migration is truly applied
supabase migration list
# If remote timestamp exists for that migration → it is applied, error was cosmetic
# Safe to continue: retry the full deploy or skip to next step

# If remote timestamp is missing despite "already applied" error:
# The migration table is out of sync — contact Supabase support
```

### 5E — Vercel build failed (no .vercel/output artifact)

```bash
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')

# Run build with full output visible
doppler run --project "$SLUG" --config prd -- vercel build --prod 2>&1 | tee /tmp/vercel-build.log
# Read /tmp/vercel-build.log for the specific error

# Common causes:
# "ENV_VAR undefined" → secret missing from Doppler prd (go to 5B)
# "Module not found" → dependency issue → run: bun install && retry
# "Type error" → TypeScript compile error → fix in code, commit, retry
# "Out of memory" → increase Node memory: NODE_OPTIONS=--max-old-space-size=4096 vercel build --prod

# After fixing root cause:
doppler run --project "$SLUG" --config prd -- vercel build --prod
```
Expected: `.vercel/output/` directory created.

### 5F — Vercel deploy failed (upload / auth / team)

```bash
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')

# Fix 1: VERCEL_TOKEN missing → add to Doppler prd (section 5B)

# Fix 2: Linked to personal account (not team)
rm -rf .vercel
vercel link --scope=<team-name>
# Re-run full two-step:
doppler run --project "$SLUG" --config prd -- vercel build --prod
doppler run --project "$SLUG" --config prd -- bash -c \
  'vercel deploy --prod --prebuilt --archive=tgz --token "$VERCEL_TOKEN" --yes'

# Fix 3: Upload limit (>5000 files)
# Confirm --archive=tgz is present in the deploy command
# If already present → check .vercelignore excludes node_modules, .git
```
Expected: terminal prints production URL `https://<project>.vercel.app`.

### 5G — Cloudflare wrangler not authenticated

```bash
wrangler login
# Follow browser OAuth flow
# Expected: "Successfully logged in"

# Retry deploy
deploy
```

### 5H — Post-deploy app crash (HTTP 5xx after deploy)

```bash
# 1. Check deployment logs
vercel logs <deployment-url> --limit 100
# OR for Cloudflare:
wrangler tail

# 2. Common causes:
# Missing runtime env var → check Vercel/Cloudflare dashboard environment vars
# DB connection failure → check SUPABASE_URL / DATABASE_URL is correct for prd
# Startup error → read first error in logs, fix code

# 3. If unhealthy and must restore service NOW → rollback (section 7)
```

### 5I — iOS/EAS failure

```bash
# Fastlane (ios-native / ios-rn):
# Read full Fastlane error output
# Common fixes:
#   "Code signing error" → check provisioning profile in Xcode
#   "api_key.json invalid" → verify APP_STORE_CONNECT_API_KEY_CONTENT base64 encoding
#   "Build number conflict" → increment_build_number must run before build_app

# EAS (ios-expo):
# Check EAS build log URL from output
eas build:list --limit 1
# Open the build log URL for full error details
# Common: "SDK version mismatch" → run: expo upgrade

# See adapter-ios-stub.md / adapter-ios-expo.md for full failure tables
```

### 5J — Convex auth or CONVEX_DEPLOYMENT missing

```bash
# Fix auth
npx convex login

# Fix missing secret
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler secrets set CONVEX_DEPLOYMENT --config prd
# Enter value from: npx convex dashboard → Settings → URL and Deploy Key

# Retry
deploy
```

---

## 6. Validation

After any fix, verify the correct outcome before declaring resolved:

**Shared gate fixed:**
```bash
doppler me                              # returns email
doppler secrets --project "$SLUG" --config prd --only-names | grep <SECRET>
```

**Supabase fixed:**
```bash
supabase migration list                 # all rows have remote timestamp
curl -s -H "apikey: $SUPABASE_ANON_KEY" \
  "https://${SUPABASE_PROJECT_ID}.supabase.co/rest/v1/" \
  | grep -q "definitions" && echo "✓ API responding" || echo "✗ API not responding"
```

**Vercel fixed:**
```bash
DEPLOY_URL="<URL from deploy output>"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$DEPLOY_URL"
# Expected: HTTP 200 or HTTP 3xx
```

**Cloudflare fixed:**
```bash
wrangler deployments list               # new deployment at top
curl -s -o /dev/null -w "HTTP %{http_code}\n" "https://<worker-route>"
# Expected: HTTP 200
```

**Convex fixed:**
```bash
npx convex dashboard                    # functions list updated
```

**Success criteria:** All of the following within 5 minutes of deploy:
- Deployment URL returns HTTP 2xx or 3xx
- No new errors in deployment logs
- Auth flows complete (if tested)
- Key API endpoints respond within normal latency

---

## 7. Rollback

**Trigger condition for rollback:** Deploy completed but validation fails (5xx, auth broken, critical feature non-functional) AND fix is not immediately obvious.

### Vercel rollback

```bash
# Instant rollback to previous deployment
vercel rollback
# Expected: "Rollback to <previous-url> successful"

# OR swap alias to specific previous deployment:
vercel deployments ls --prod           # find previous healthy URL
vercel alias set <previous-url> <production-domain>
```
Validate after: `curl -s -o /dev/null -w "HTTP %{http_code}\n" "https://<production-domain>"`

### Cloudflare Workers rollback

```bash
wrangler deployments list              # find previous deployment ID
wrangler rollback <deployment-id>
# Expected: "Rolled back to deployment <id>"
```

### Supabase rollback

```bash
# Write reverse migration (see section 5C)
# Supabase has no automatic rollback — the reverse migration IS the rollback
supabase migration new rollback_<name>
# Edit file with reverse SQL
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler run --project "$SLUG" --config prd -- bash -c \
  'supabase link --project-ref "$SUPABASE_PROJECT_ID" && supabase db push'
```

### Convex rollback

```bash
git checkout <previous-stable-tag>
SLUG=$(grep "^project:" .doppler.yaml | awk '{print $2}')
doppler run --project "$SLUG" --config prd -- npx convex deploy --yes
```

### iOS rollback

iOS deploys to TestFlight/App Store cannot be rolled back via CLI. Use App Store
Connect dashboard to remove the build from TestFlight or reject the review submission.

---

## 8. Post-Deploy / Post-Recovery

**After successful recovery:**

```bash
# 1. Confirm deploy completed cleanly
deploy --check        # runs preflight only — confirms all signals green

# 2. Record what broke and what fixed it
# File a note: product/inbox.jsonl (via capture)
# Include: which adapter failed, which section fixed it, whether runbook needs update
```

**Runbook update instruction:**
If you executed a fix not covered in section 5 that worked, add it to the
appropriate 5.x subsection before closing. The next deploy failure will thank you.

**Postmortem trigger:**
- P1 (hotfix deploy for active outage): write postmortem within 24 hours
- P2 repeated (same adapter fails twice in a sprint): file issue + update adapter reference

**Related runbooks:**
- `profiles/general/runbooks/doppler-local-dev-setup.md` — if shared gate fails repeatedly
- `profiles/general/runbooks/port-conflict-resolution.md` — if dev server blocks pre-deploy validation
- `~/.claude/skills/deploy/references/adapter-vercel.md` — Vercel deep reference
- `~/.claude/skills/deploy/references/adapter-cloudflare.md` — Cloudflare deep reference
- `~/.claude/skills/deploy/references/adapter-supabase.md` — Supabase deep reference
- `~/.claude/skills/deploy/references/adapter-ios-stub.md` — iOS native deep reference
- `~/.claude/skills/deploy/references/adapter-ios-rn.md` — React Native deep reference
- `~/.claude/skills/deploy/references/adapter-ios-expo.md` — Expo deep reference
