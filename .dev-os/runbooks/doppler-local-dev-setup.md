# Runbook: Local Dev — Doppler First-Time Setup

| Field | Value |
|-------|-------|
| Service | Local Development Environment (Doppler secrets management) |
| Runbook type | Operational |
| Severity | P2 — blocks local development; no production impact |
| Owner team | @Traderfuz / dev-os team |
| Last reviewed | 2026-04-13 |
| Automation status | Manual |
| Related runbooks | `dev-server-startup-failure.md`, `port-conflict-resolution.md` |

---

## 1. Trigger & Detection

This runbook activates when:
- Running `local-dev-startup.md` and Step 1 fails (`doppler me` exits non-zero)
- Running `local-dev-startup.md` and Step 2 fails (`.doppler.yaml` absent)
- Running `local-dev-startup.md` and Step 3 fails (`doppler-validator.sh` reports MISSING keys)
- A developer reports "Doppler not configured" or "cannot find project config"
- A new project has been cloned and Doppler has never been set up for it

**Standard reference:** `profiles/general/standards/global/doppler-dev-config.md`

---

## 2. Impact Assessment — Triage Checklist

Run these in order. First match → jump to that section.

```bash
# T1 — Is doppler CLI installed?
which doppler && doppler --version
# Match (prints version) → Doppler is installed; check auth (T2)
# No match / command not found → Install Doppler (→ Section 3: Step 1)

# T2 — Is doppler authenticated?
doppler me 2>/dev/null
# Prints identity (email/name) → Authenticated; check project pin (T3)
# "Please run 'doppler login'" → Not authenticated (→ Section 3: Step 2)

# T3 — Does .doppler.yaml exist and is it correct?
[ -f .doppler.yaml ] && grep -q "^project:" .doppler.yaml && grep -q "^config:" .doppler.yaml \
  && echo "PIN OK" || echo "MISSING OR INCOMPLETE"
# "PIN OK" → Project pinned; check secrets access (T4)
# "MISSING OR INCOMPLETE" → Create .doppler.yaml (→ Section 3: Step 3)

# T4 — Can secrets be listed?
doppler secrets --config dev --only-names 2>/dev/null | head -5
# Lists secret names → Access confirmed; check key declarations (T5)
# Error / empty → Access denied or project doesn't exist (→ Section 5: Access Request)

# T5 — Does pre-deployment.yml declare required_vars?
[ -f .dev-os/pre-deployment.yml ] && grep -q "required_vars:" .dev-os/pre-deployment.yml \
  && echo "DECLARED" || echo "MISSING"
# "DECLARED" → Declarations present; run key check (→ Section 3: Step 6)
# "MISSING" → Scaffold required_vars (→ Section 3: Step 5)
```

**Severity matrix:**

| Finding | Jump to | Action |
|---------|---------|--------|
| Doppler CLI not installed | Step 1 | Install CLI |
| CLI installed, not authenticated | Step 2 | `doppler login` |
| Authenticated, `.doppler.yaml` missing | Step 3 | Create project pin |
| Pin exists, secrets inaccessible | Section 5 | Request access or create project |
| Access OK, `required_vars` not declared | Step 5 | Scaffold pre-deployment.yml |
| All above OK, validator reports MISSING | Step 6 | Set missing keys in Doppler dev config |

---

## 3. Setup Steps

### Step 1: Install Doppler CLI

**Skip if:** `which doppler` returns a path.

**macOS (Homebrew):**
```bash
brew install dopplerhq/cli/doppler
```
Expected output:
```
==> Installing doppler from dopplerhq/cli
...
🍺  /usr/local/Cellar/doppler/3.x.x: N files
```

**Linux (apt):**
```bash
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
  'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' \
  | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] \
  https://packages.doppler.com/public/cli/deb/debian any-version main" \
  | sudo tee /etc/apt/sources.list.d/doppler-cli.list
sudo apt-get update && sudo apt-get install doppler
```
Expected output (last line): `Setting up doppler ...`

**Linux (curl fallback — no sudo):**
```bash
curl -Ls --tlsv1.2 --proto "=https" --retry 3 \
  https://cli.doppler.com/install.sh | bash
```

**Verify:**
```bash
doppler --version
# Expected: doppler version 3.x.x
```

**If unexpected output:** `command not found` after install — source your shell profile (`source ~/.bashrc` or `source ~/.zshrc`) and retry.

---

### Step 2: Authenticate with Doppler

**Skip if:** `doppler me` exits 0 and prints an email address.

```bash
doppler login
```

Expected output:
```
? Open the authorization page in your browser? Yes
Your auth code is: XXXX-XXXX

Waiting for authorization...
✓ Authentication complete
```

**Verify authentication:**
```bash
doppler me
```
Expected output:
```
┌──────────────────────────────────────────────────────────┐
│ name       │ Your Name                                   │
│ email      │ you@example.com                             │
│ workplace  │ your-workspace                              │
└──────────────────────────────────────────────────────────┘
```

**If `doppler login` cannot open a browser (headless/SSH session):**
```bash
doppler login --no-check
# Prints a URL — open it manually in a browser on another machine
```

**If unexpected output:** `Invalid token` or `Unauthorized` — the token may have expired. Run `doppler logout` then `doppler login` again.

---

### Step 3: Pin Project Configuration

**Skip if:** `.doppler.yaml` exists with both `project:` and `config:` keys.

**Option A — Interactive setup (recommended for first time):**
```bash
doppler setup
```
Expected prompts:
```
? Select a project: my-app-supabase
? Select a config: dev
✓ Wrote /path/to/project/.doppler.yaml
```

**Option B — Manual creation:**
```bash
# Replace <slug> with the Doppler project slug (find it in the Doppler dashboard)
printf 'project: %s\nconfig: dev\n' "<slug>" > .doppler.yaml
cat .doppler.yaml
```
Expected output of `cat`:
```
project: my-app-supabase
config: dev
```

**Commit the file:**
```bash
git add .doppler.yaml
git commit -m "chore: pin Doppler project config"
```

**Verify the pin is not gitignored:**
```bash
git check-ignore -v .doppler.yaml
# Expected: no output (the file is NOT ignored)
# If output appears (shows .gitignore match): remove the offending pattern from .gitignore
```

**If unexpected output:** `project not found` during `doppler setup` — the Doppler project may not exist yet. See Section 5: Access Request / Project Creation.

---

### Step 4: Verify Secrets Access

```bash
doppler secrets --config dev --only-names 2>/dev/null
```
Expected output (list of secret key names):
```
DATABASE_URL
NEXTAUTH_SECRET
NEXTAUTH_URL
CONVEX_DEPLOYMENT
```

**If empty output or error:**
```bash
# Check if the project exists and you have access
doppler projects get
# If "project not found" → you lack access or the project doesn't exist (→ Section 5)

# Check if the dev config exists
doppler configs --project "$(grep project: .doppler.yaml | awk '{print $2}')" 2>/dev/null
# Should show a row with "dev" in the config column
```

---

### Step 5: Declare Required API Keys in pre-deployment.yml

**Skip if:** `.dev-os/pre-deployment.yml` already has a `required_vars:` block.

**Scaffold from `.env.example` (if present):**
```bash
mkdir -p .dev-os
echo "required_vars:" > .dev-os/pre-deployment.yml
grep -E '^[A-Z_][A-Z_0-9]*=' .env.example \
  | cut -d= -f1 \
  | sort \
  | while read -r key; do
      echo "  - $key"
    done >> .dev-os/pre-deployment.yml

echo "" >> .dev-os/pre-deployment.yml
echo "optional_vars: {}" >> .dev-os/pre-deployment.yml

cat .dev-os/pre-deployment.yml
```

**Scaffold from scratch (no .env.example):**
```bash
mkdir -p .dev-os
cat > .dev-os/pre-deployment.yml << 'EOF'
required_vars:
  - DATABASE_URL
  - NEXTAUTH_SECRET
  - NEXTAUTH_URL

optional_vars:
  POSTHOG_KEY:
    description: "Analytics — omit to disable"
  RESEND_API_KEY:
    description: "Transactional email — omit to disable"
EOF
```

**Edit the file to:**
- Move optional/nice-to-have keys into `optional_vars:` with descriptions
- Add any missing required keys

**Commit:**
```bash
git add .dev-os/pre-deployment.yml
git commit -m "chore: declare required Doppler keys"
```

---

### Step 6: Run Required Key Check

```bash
bash scripts/lib/checks/doppler-validator.sh
```

**Expected output (all keys present):**
```
✓ Doppler dev secrets verified
  Project: my-app-supabase  Config: dev
  Required keys present (4/4):
    ✓ DATABASE_URL
    ✓ NEXTAUTH_SECRET
    ✓ NEXTAUTH_URL
    ✓ CONVEX_DEPLOYMENT
```

**If MISSING keys reported:**
```
✗ Required Doppler secrets missing — dev server blocked
  MISSING (required):
    ✗ DATABASE_URL
    ✗ NEXTAUTH_SECRET
```

**Set missing keys:**
```bash
# Set one key interactively (prompts for value):
doppler secrets set DATABASE_URL --config dev

# Set multiple keys at once:
doppler secrets set DATABASE_URL="postgres://..." NEXTAUTH_SECRET="..." --config dev

# Open dashboard to set via browser:
doppler open dashboard
```

Re-run validator after setting keys:
```bash
bash scripts/lib/checks/doppler-validator.sh
# Expected: zero ISSUE lines
```

---

### Step 7: First Dev Server Start

With Doppler configured and all keys present, run the full startup pipeline:

```bash
# From local-dev-startup.md — full pipeline
doppler me                              # Step 1: auth check
# .doppler.yaml check happens automatically via scripts/doppler-run.sh
bash scripts/lib/checks/doppler-validator.sh  # Step 3: key check
scripts/doppler-run.sh bun run dev           # Step 5: start with secret injection
```

Or run the full pipeline as documented in `profiles/general/workflows/pipelines/local-dev-startup.md`.

Expected final output:
```
✓ Dev server ready

  http://localhost:3000 (app-server)

NAME          PORT   PID     STATUS   STARTED
app-server    3000   12345   healthy  2026-04-13T09:15:00Z
```

---

## 4. Offline Fallback (No Network Access)

When Doppler is unavailable (no internet, CAPTCHA, auth service down):

```bash
# Export secrets snapshot from last known-good session
doppler secrets download --no-file --format env --config dev \
  > .env.local.doppler

# Ensure it's gitignored
echo ".env.local.doppler" >> .gitignore
git add .gitignore && git commit -m "chore: gitignore offline secrets snapshot"

# Load into current shell
set -a
source .env.local.doppler
set +a

# Start dev server without Doppler injection
bun run dev
```

**Warning:** This snapshot becomes stale when secrets rotate. Regenerate it with `doppler secrets download` as soon as network access is restored.

**Delete after restoring connectivity:**
```bash
/usr/bin/rm .env.local.doppler   # use full path to bypass rm -i alias
```

---

## 5. Access Request / Project Creation

**If no Doppler project exists for this repository:**

1. Open the Doppler dashboard: `doppler open dashboard`
2. Create a project with slug matching the repository name: `my-app-supabase`
3. Create three configs: `dev`, `preview`, `prd`
4. Add all required secrets to the `dev` config
5. Invite team members with appropriate roles (Developer or Admin)
6. Re-run this runbook from Step 3

**If a project exists but you lack access:**

1. Identify the project admin: check `CLAUDE.md` under `## Doppler` heading, or ask the owner team
2. Request access: provide your Doppler email and the project slug
3. Once access is granted, run `doppler setup` to pin the project

---

## 6. Validation

After completing all steps, run this validation checklist:

```bash
# Check 1: CLI installed and authenticated
doppler me
# Expected: prints name, email, workspace — exits 0

# Check 2: Project pin correct
cat .doppler.yaml
# Expected: two lines — "project: <slug>" and "config: dev" — no secret values

# Check 3: Pin not gitignored
git check-ignore -v .doppler.yaml
# Expected: no output (empty — file is tracked)

# Check 4: Secrets accessible
doppler secrets --config dev --only-names 2>/dev/null | wc -l
# Expected: N > 0 (at least one secret listed)

# Check 5: Key check clean
bash scripts/lib/checks/doppler-validator.sh 2>&1 | grep -c "ISSUE" || true
# Expected: 0 (zero ISSUE lines)

# Check 6: Dev server starts
scripts/doppler-run.sh bun run dev &
DEV_PID=$!
sleep 10
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Expected: 200 (or 3xx redirect)
kill "$DEV_PID" 2>/dev/null || true
```

**Success threshold:** All 6 checks pass. The validator reports 0 ISSUE lines and the server responds HTTP 200/3xx.

---

## 7. Rollback / Undo

No production state is modified by this runbook. Local changes can be undone:

**Remove project pin (if created incorrectly):**
```bash
/usr/bin/rm .doppler.yaml
# Recreate with correct values using Step 3
```

**Remove pre-deployment.yml (if scaffolded incorrectly):**
```bash
/usr/bin/rm .dev-os/pre-deployment.yml
# Recreate with correct required_vars using Step 5
```

**Revoke Doppler CLI session:**
```bash
doppler logout
# Re-authenticate with: doppler login
```

**Remove offline snapshot:**
```bash
/usr/bin/rm -f .env.local.doppler
# Verify: ls .env.local.doppler  → "No such file"
```

---

## 8. Post-Task

- [ ] `doppler me` prints correct identity
- [ ] `.doppler.yaml` is committed to version control with `project: <slug>` and `config: dev`
- [ ] `.doppler.yaml` is NOT in `.gitignore` (verified with `git check-ignore -v .doppler.yaml`)
- [ ] `.dev-os/pre-deployment.yml` is committed with at least one key under `required_vars:`
- [ ] `bash scripts/lib/checks/doppler-validator.sh` exits 0 with zero ISSUE lines
- [ ] Dev server starts cleanly via `scripts/doppler-run.sh bun run dev`
- [ ] If a new Doppler project was created: team members are invited with appropriate roles

**If you discovered a new failure mode during this runbook:** Add it to the Triage Checklist and Severity Matrix in Section 2. Update `Last reviewed` date.

---

## 9. Related Runbooks

- `profiles/cli/runbooks/dev-server-startup-failure.md` — when dev server fails to start after Doppler is configured
- `profiles/general/runbooks/port-conflict-resolution.md` — when dev server port is already occupied
- `profiles/general/workflows/pipelines/local-dev-startup.md` — full startup pipeline (Doppler setup is a prerequisite)
- `profiles/general/standards/global/doppler-dev-config.md` — authoritative standard for `.doppler.yaml` and `required_vars:` declaration
- `profiles/general/standards/global/local-first-development.md` — local-first development standard (why Doppler is required)
