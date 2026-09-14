#!/usr/bin/env bash
# deploy-prod.sh — DevOS generic production deploy script
#
# Reusable wrapper for Doppler + Vercel + optional Prisma deploy flows.
# Designed to be copied into any DevOS-managed project's `scripts/` folder
# and configured via environment variables, or wrapped by a project-specific
# thin script that exports the config and execs this one.
#
# This file lives in `profiles/general/scripts/` so that every profile
# downstream (webapp, cli, cloudflare-workers, pwa, ...) inherits it
# automatically. Profile inheritance: default → general → <leaf>.
#
# ─────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────
#
# Option 1 — copy directly into your project:
#   cp ~/.dev-os/profiles/general/scripts/deploy-prod.sh ./scripts/
#   # then edit the CONFIG section at the top, or export env vars
#
# Option 2 — call from a project-specific wrapper (recommended):
#   # Your project's scripts/deploy-prod.sh:
#   #!/usr/bin/env bash
#   export DEPLOY_DOPPLER_PROJECT="your-project"
#   export DEPLOY_DOPPLER_CONFIG="prd"
#   export DEPLOY_REQUIRED_BRANCH="main"
#   export DEPLOY_PROD_URL="https://your.domain.com"
#   export DEPLOY_HEALTH_PATH="/api/health"
#   exec ~/.dev-os/profiles/general/scripts/deploy-prod.sh "$@"
#
# Option 3 — set env vars inline:
#   DEPLOY_DOPPLER_PROJECT=myapp DEPLOY_DOPPLER_CONFIG=prd \
#     DEPLOY_PROD_URL=https://myapp.com \
#     ./deploy-prod.sh
#
# ─────────────────────────────────────────────────────────────────
# Configuration (environment variables)
# ─────────────────────────────────────────────────────────────────
#
# Required:
#   DEPLOY_DOPPLER_PROJECT   Doppler project slug (e.g. "boxi-app-supabase")
#   DEPLOY_DOPPLER_CONFIG    Doppler config name (usually "prd")
#   DEPLOY_PROD_URL          Production alias URL (e.g. "https://myapp.com")
#
# Optional (with defaults):
#   DEPLOY_REQUIRED_BRANCH   Git branch that must be checked out  (default: main)
#   DEPLOY_HEALTH_PATH       Health check endpoint path           (default: /api/health)
#   DEPLOY_USE_PRISMA        "1" to run prisma migrate deploy     (default: auto-detect
#                            presence of prisma/schema.prisma)
#   DEPLOY_PKG_MANAGER       Package manager to use: bun|pnpm|npm (default: auto-detect
#                            from lockfile — bun.lockb/bun.lock → bun,
#                            pnpm-lock.yaml → pnpm, fallback → npm)
#   DEPLOY_VERCEL_ARCHIVE    Archive format for vercel deploy     (default: tgz)
#   DEPLOY_SKIP_REMOTE_SYNC  "1" to skip the remote-sync check    (default: 0)
#
# Supabase / PgBouncer note:
#   When using Supabase, set DIRECT_URL in your Doppler prd config (port 5432,
#   direct connection). The migrate step will use DIRECT_URL automatically to
#   avoid PgBouncer transaction-mode advisory lock issues that cause the deploy
#   script to hammer connections and exhaust free-tier compute hours.
#
# ─────────────────────────────────────────────────────────────────
# Flags
# ─────────────────────────────────────────────────────────────────
#
#   --skip-preflight    Skip branch/clean/sync checks
#   --skip-migrate      Skip prisma migrate deploy
#   --skip-smoke        Skip post-deploy health check
#   --dry-run           Print what would run without executing
#   -h, --help          Show this header and exit
#
# ─────────────────────────────────────────────────────────────────
# Requirements
# ─────────────────────────────────────────────────────────────────
#
#   - doppler CLI, authenticated
#   - vercel CLI
#   - git (on $DEPLOY_REQUIRED_BRANCH with clean tree)
#   - VERCEL_TOKEN available from Doppler prd config
#   - one of: bun/bunx, pnpm, or npm/npx (for prisma, if DEPLOY_USE_PRISMA=1)
#
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Config resolution with defaults
# ──────────────────────────────────────────────────────────────
: "${DEPLOY_DOPPLER_PROJECT:=}"
: "${DEPLOY_DOPPLER_CONFIG:=}"
: "${DEPLOY_PROD_URL:=}"
: "${DEPLOY_REQUIRED_BRANCH:=main}"
: "${DEPLOY_HEALTH_PATH:=/api/health}"
: "${DEPLOY_VERCEL_ARCHIVE:=tgz}"
: "${DEPLOY_SKIP_REMOTE_SYNC:=0}"

# Auto-detect Prisma if not explicitly set
if [[ -z "${DEPLOY_USE_PRISMA:-}" ]]; then
  if [[ -f "prisma/schema.prisma" ]]; then
    DEPLOY_USE_PRISMA=1
  else
    DEPLOY_USE_PRISMA=0
  fi
fi

# Auto-detect package manager if not explicitly set.
# Precedence: explicit env var > bun lockfile > pnpm lockfile > npm fallback.
if [[ -z "${DEPLOY_PKG_MANAGER:-}" ]]; then
  if [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
    DEPLOY_PKG_MANAGER="bun"
  elif [[ -f "pnpm-lock.yaml" ]]; then
    DEPLOY_PKG_MANAGER="pnpm"
  else
    DEPLOY_PKG_MANAGER="npm"
  fi
fi

# Validate the value — must be one of the three supported managers
case "$DEPLOY_PKG_MANAGER" in
  bun|pnpm|npm) ;;
  *)
    printf '\033[31m✗ Invalid DEPLOY_PKG_MANAGER=%s (must be bun|pnpm|npm)\033[0m\n' "$DEPLOY_PKG_MANAGER" >&2
    exit 1
    ;;
esac

# Resolve the exact runner command for each manager.
# This is the binary that executes node_modules/.bin binaries (prisma, tsx, etc.).
#   bun  → `bunx` (bun's npx equivalent)
#   pnpm → `pnpm exec` (pnpm's npx equivalent)
#   npm  → `npx`
case "$DEPLOY_PKG_MANAGER" in
  bun)  PKG_RUNNER="bunx" ;;
  pnpm) PKG_RUNNER="pnpm exec" ;;
  npm)  PKG_RUNNER="npx" ;;
esac

# ──────────────────────────────────────────────────────────────
# Color output
# ──────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  readonly C_RED=$'\033[31m'
  readonly C_GREEN=$'\033[32m'
  readonly C_YELLOW=$'\033[33m'
  readonly C_BLUE=$'\033[34m'
  readonly C_DIM=$'\033[2m'
  readonly C_BOLD=$'\033[1m'
  readonly C_RESET=$'\033[0m'
else
  readonly C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_DIM='' C_BOLD='' C_RESET=''
fi

log()     { printf '%s▸%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()      { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()    { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()     { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }
section() { printf '\n%s━━━ %s ━━━%s\n' "$C_BOLD" "$*" "$C_RESET"; }

# ──────────────────────────────────────────────────────────────
# Required-config validation
# ──────────────────────────────────────────────────────────────
validate_config() {
  local missing=()
  [[ -z "$DEPLOY_DOPPLER_PROJECT" ]] && missing+=("DEPLOY_DOPPLER_PROJECT")
  [[ -z "$DEPLOY_DOPPLER_CONFIG"  ]] && missing+=("DEPLOY_DOPPLER_CONFIG")
  [[ -z "$DEPLOY_PROD_URL"        ]] && missing+=("DEPLOY_PROD_URL")

  if (( ${#missing[@]} > 0 )); then
    printf '%s✗ Missing required environment variables:%s\n' "$C_RED" "$C_RESET" >&2
    for var in "${missing[@]}"; do
      printf '   - %s\n' "$var" >&2
    done
    printf '\nSee script header comment for configuration options, or run with --help.\n' >&2
    exit 1
  fi
}

# ──────────────────────────────────────────────────────────────
# Flag parsing
# ──────────────────────────────────────────────────────────────
SKIP_PREFLIGHT=0
SKIP_MIGRATE=0
SKIP_SMOKE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --skip-preflight) SKIP_PREFLIGHT=1 ;;
    --skip-migrate)   SKIP_MIGRATE=1 ;;
    --skip-smoke)     SKIP_SMOKE=1 ;;
    --dry-run)        DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,/^# ─*$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      die "Unknown flag: $arg (see --help)"
      ;;
  esac
done

validate_config

# PKG_RUNNER is already resolved above in the config section based on
# DEPLOY_PKG_MANAGER (bun → bunx, pnpm → pnpm exec, npm → npx).

run() {
  if (( DRY_RUN )); then
    printf '%s  [dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
  else
    "$@"
  fi
}

# ──────────────────────────────────────────────────────────────
# Cleanup trap
# ──────────────────────────────────────────────────────────────
cleanup() {
  local ec=$?
  if (( ec != 0 )); then
    printf "\n%s✗ deploy aborted (exit %d)%s\n" "$C_RED" "$ec" "$C_RESET" >&2
  fi
}
trap cleanup EXIT

# ──────────────────────────────────────────────────────────────
# Dependency check
# ──────────────────────────────────────────────────────────────
section "Dependency check"
required_cmds=(doppler vercel git curl)
case "$DEPLOY_PKG_MANAGER" in
  bun)  required_cmds+=(bun bunx) ;;
  pnpm) required_cmds+=(pnpm node) ;;
  npm)  required_cmds+=(node npm npx) ;;
esac

for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Required command not found: $cmd"
  fi
done
ok "All required CLIs present: ${required_cmds[*]}"

log "Config: project=$DEPLOY_DOPPLER_PROJECT config=$DEPLOY_DOPPLER_CONFIG branch=$DEPLOY_REQUIRED_BRANCH"
log "Prisma: $( (( DEPLOY_USE_PRISMA )) && echo "enabled" || echo "disabled" )  |  Package manager: $DEPLOY_PKG_MANAGER  |  Runner: $PKG_RUNNER"

# ──────────────────────────────────────────────────────────────
# 1. Pre-flight
# ──────────────────────────────────────────────────────────────
section "1. Pre-flight"
if (( SKIP_PREFLIGHT )); then
  warn "Pre-flight checks SKIPPED (--skip-preflight) — you are on your own"
else
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")
  if [[ "$current_branch" != "$DEPLOY_REQUIRED_BRANCH" ]]; then
    die "Not on $DEPLOY_REQUIRED_BRANCH branch (current: $current_branch). Checkout first, or pass --skip-preflight."
  fi
  ok "On $DEPLOY_REQUIRED_BRANCH branch"

  if ! git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
    die "Working tree has uncommitted changes. Commit or stash first."
  fi
  if ! git diff --quiet --cached --ignore-submodules HEAD 2>/dev/null; then
    die "Index has staged but uncommitted changes. Commit first."
  fi
  ok "Working tree is clean"

  if (( ! DEPLOY_SKIP_REMOTE_SYNC )); then
    git fetch origin "$DEPLOY_REQUIRED_BRANCH" --quiet 2>/dev/null || warn "git fetch failed — continuing without remote check"
    local_sha=$(git rev-parse HEAD)
    remote_sha=$(git rev-parse "origin/$DEPLOY_REQUIRED_BRANCH" 2>/dev/null || echo "")
    if [[ -n "$remote_sha" && "$local_sha" != "$remote_sha" ]]; then
      die "Local $DEPLOY_REQUIRED_BRANCH ($local_sha) is out of sync with origin/$DEPLOY_REQUIRED_BRANCH ($remote_sha). Pull or push first."
    fi
    ok "Local $DEPLOY_REQUIRED_BRANCH matches origin/$DEPLOY_REQUIRED_BRANCH"
  fi

  if ! doppler me --json >/dev/null 2>&1; then
    die "Doppler CLI not authenticated. Run: doppler login"
  fi
  ok "Doppler CLI authenticated"
fi

# ──────────────────────────────────────────────────────────────
# 2. Prisma migrate deploy (optional)
# ──────────────────────────────────────────────────────────────
PRISMA_DB_URL=""
PRISMA_DB_URL_SOURCE=""

resolve_prisma_db_url() {
  local resolution prisma_resolve_script
  prisma_resolve_script="$(cat <<'PRISMA_RESOLVE_SCRIPT'
    if [[ -n "${DIRECT_URL:-}" ]]; then
      printf "DIRECT_URL\t%s" "$DIRECT_URL"
    else
      if [[ -z "${DATABASE_URL:-}" ]]; then
        echo "Neither DIRECT_URL nor DATABASE_URL is set in the Doppler config." >&2
        exit 1
      fi
      echo "⚠ DIRECT_URL not set — using DATABASE_URL (pooler). This may hang on PgBouncer." >&2
      printf "DATABASE_URL\t%s" "$DATABASE_URL"
    fi
PRISMA_RESOLVE_SCRIPT
  )"
  resolution="$(doppler run --project "$DEPLOY_DOPPLER_PROJECT" --config "$DEPLOY_DOPPLER_CONFIG" -- bash -c "$prisma_resolve_script")" || return 1

  PRISMA_DB_URL_SOURCE="${resolution%%$'\t'*}"
  PRISMA_DB_URL="${resolution#*$'\t'}"

  [[ -n "$PRISMA_DB_URL" ]] || return 1
}

run_prisma_migrate() {
  local action="$1"
  local cmd quoted_url

  if [[ -n "$PRISMA_DB_URL" ]]; then
    printf -v quoted_url '%q' "$PRISMA_DB_URL"
    cmd="export DATABASE_URL=$quoted_url; $PKG_RUNNER prisma migrate $action"
  else
    cmd="$PKG_RUNNER prisma migrate $action"
  fi

  run doppler run --project "$DEPLOY_DOPPLER_PROJECT" --config "$DEPLOY_DOPPLER_CONFIG" -- bash -c "$cmd"
}

run_with_retry() {
  local max_attempts="$1"
  local initial_delay="$2"
  shift 2

  local attempt=1
  local retry_delay="$initial_delay"

  while (( attempt <= max_attempts )); do
    if "$@"; then
      return 0
    fi

    if (( attempt < max_attempts )); then
      warn "Attempt $attempt/$max_attempts failed — retrying in ${retry_delay}s..."
      sleep "$retry_delay"
      retry_delay=$((retry_delay * 2))
    fi

    attempt=$((attempt + 1))
  done

  return 1
}

section "2. Apply pending DB migrations"
if (( !DEPLOY_USE_PRISMA )); then
  log "Prisma not enabled (no prisma/schema.prisma found or DEPLOY_USE_PRISMA=0). Skipping."
elif (( SKIP_MIGRATE )); then
  warn "Prisma migrate deploy SKIPPED (--skip-migrate) — prod schema may drift"
else
  log "Running: prisma migrate deploy against $DEPLOY_DOPPLER_PROJECT/$DEPLOY_DOPPLER_CONFIG"
  if ! resolve_prisma_db_url; then
    die "Unable to resolve a Prisma database URL from Doppler (DIRECT_URL or DATABASE_URL)"
  fi

  # IMPORTANT: prisma migrate deploy acquires advisory locks which PgBouncer
  # (transaction mode, port 6543) cannot handle — it retries indefinitely,
  # hammering connections and burning Supabase free-tier compute hours.
  # Override DATABASE_URL with DIRECT_URL (port 5432, direct connection) for
  # migrations only. If DIRECT_URL is not set, falls back to DATABASE_URL with
  # a warning (non-Supabase setups may not need this distinction).
  # prisma migrate status exits non-zero when pending migrations exist —
  # that's expected, not a failure. Run it informational-only before deploy.
  if [[ "$PRISMA_DB_URL_SOURCE" == "DIRECT_URL" ]]; then
    log "Preflight: prisma migrate status (using DIRECT_URL)"
  else
    log "Preflight: prisma migrate status (using DATABASE_URL — DIRECT_URL not set)"
  fi
  run_prisma_migrate status || true

  if [[ "$PRISMA_DB_URL_SOURCE" == "DIRECT_URL" ]]; then
    log "Apply: prisma migrate deploy (using DIRECT_URL)"
  else
    log "Apply: prisma migrate deploy (using DATABASE_URL)"
  fi
  run_with_retry "${RETRY_MAX_ATTEMPTS:-3}" "${RETRY_DELAY_SECONDS:-4}" run_prisma_migrate deploy
  ok "Migrations applied (or no-op if already up to date)"
fi

# ──────────────────────────────────────────────────────────────
# 3. Local build with Doppler secrets
# ──────────────────────────────────────────────────────────────
section "3. Build locally with Doppler secrets"
log "Running: vercel build --prod (with Doppler $DEPLOY_DOPPLER_CONFIG secrets)"
run doppler run --project "$DEPLOY_DOPPLER_PROJECT" --config "$DEPLOY_DOPPLER_CONFIG" -- vercel build --prod
ok "Build complete"

# ──────────────────────────────────────────────────────────────
# 4. Deploy prebuilt output
# ──────────────────────────────────────────────────────────────
section "4. Deploy prebuilt output to Vercel"
log "Running: vercel deploy --prod --prebuilt --archive=$DEPLOY_VERCEL_ARCHIVE"

DEPLOY_URL=""
if (( DRY_RUN )); then
  printf '%s  [dry-run]%s doppler run ... vercel deploy --prod --prebuilt --archive=%s\n' "$C_DIM" "$C_RESET" "$DEPLOY_VERCEL_ARCHIVE"
  DEPLOY_URL="https://dry-run-example.vercel.app"
else
  DEPLOY_OUTPUT=$(doppler run --project "$DEPLOY_DOPPLER_PROJECT" --config "$DEPLOY_DOPPLER_CONFIG" -- bash -c \
    "vercel deploy --prod --prebuilt --archive=$DEPLOY_VERCEL_ARCHIVE --token \"\$VERCEL_TOKEN\" --yes" 2>&1 | tee /dev/stderr)
  DEPLOY_URL=$(printf '%s\n' "$DEPLOY_OUTPUT" | grep -oE 'https://[a-z0-9-]+\.vercel\.app' | tail -n1)
  if [[ -z "$DEPLOY_URL" ]]; then
    die "Could not extract deployment URL from vercel output"
  fi
fi
ok "Deployed: $DEPLOY_URL"

# ──────────────────────────────────────────────────────────────
# 4b. Record last-deploy fingerprint (consumed by deployment-freshness check)
# ──────────────────────────────────────────────────────────────
if (( !DRY_RUN )); then
  mkdir -p .dev-os/runtime
  LAST_DEPLOY_FILE=".dev-os/runtime/last-deploy.json"
  DEPLOY_HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  DEPLOY_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  jq -n \
    --arg sha "$DEPLOY_HEAD_SHA" \
    --arg branch "$DEPLOY_BRANCH" \
    --arg url "$DEPLOY_URL" \
    --arg alias "$DEPLOY_PROD_URL" \
    --arg deployed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{sha: $sha, branch: $branch, deployment_url: $url, production_alias: $alias, deployed_at: $deployed_at}' \
    > "$LAST_DEPLOY_FILE"
  ok "Recorded deploy fingerprint â $LAST_DEPLOY_FILE"
fi


# ──────────────────────────────────────────────────────────────
# 5. Smoke test
# ──────────────────────────────────────────────────────────────
section "5. Smoke test"
if (( SKIP_SMOKE )); then
  warn "Smoke test SKIPPED (--skip-smoke)"
else
  health_url="${DEPLOY_PROD_URL}${DEPLOY_HEALTH_PATH}"
  log "Hitting $health_url"
  if (( DRY_RUN )); then
    printf '%s  [dry-run]%s curl -fsS -m 10 %s\n' "$C_DIM" "$C_RESET" "$health_url"
  else
    sleep 3  # give Vercel functions a moment to warm up
    response_file=$(mktemp -t deploy-health.XXXXXX)
    http_status=$(curl -s -o "$response_file" -w "%{http_code}" -m 10 "$health_url" || echo "000")
    if [[ "$http_status" == "200" ]]; then
      ok "Health check PASS (HTTP 200)"
    else
      warn "Health check returned HTTP $http_status — response body:"
      cat "$response_file" 2>/dev/null || true
      printf '\n'
      warn "Deploy completed but smoke test failed. Inspect manually:"
      warn "  $DEPLOY_PROD_URL"
      warn "  doppler run ... vercel inspect $DEPLOY_URL --logs"
      warn "If broken, roll back: doppler run ... vercel promote <previous-url>"
      # Non-fatal: deploy succeeded; smoke test is advisory
    fi
    rm -f "$response_file"
  fi
fi

# ──────────────────────────────────────────────────────────────
# 6. Summary
# ──────────────────────────────────────────────────────────────
section "Deploy summary"
printf '  %sProduction alias:%s %s\n' "$C_BOLD" "$C_RESET" "$DEPLOY_PROD_URL"
printf '  %sDeployment URL:%s   %s\n'  "$C_BOLD" "$C_RESET" "$DEPLOY_URL"
printf "  %sInspect:%s          doppler run --project %s --config %s -- bash -c 'vercel inspect %s --logs --token \"\$VERCEL_TOKEN\"'\n" \
  "$C_BOLD" "$C_RESET" "$DEPLOY_DOPPLER_PROJECT" "$DEPLOY_DOPPLER_CONFIG" "$DEPLOY_URL"
printf "  %sRollback:%s         doppler run --project %s --config %s -- bash -c 'vercel promote <previous-url> --token \"\$VERCEL_TOKEN\"'\n" \
  "$C_BOLD" "$C_RESET" "$DEPLOY_DOPPLER_PROJECT" "$DEPLOY_DOPPLER_CONFIG"
printf '\n%s✓ Deploy complete.%s\n' "$C_GREEN" "$C_RESET"
