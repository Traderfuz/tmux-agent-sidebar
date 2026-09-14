# Ship Safely Pipeline

Gated deploy sequence: tests pass → migration dry-run → Vercel preview → Playwright smoke → promote → health monitor → auto-rollback on failure. Each gate halts promotion. Browser smoke follows `profiles/general/standards/global/browser-review-policy.md`; CI/PR uses Playwright-managed headed/headless targets and never requires `browser-cdp`.

## When to Use

- Deploying a change that modifies DB schema, API contracts, or shared UI primitives
- Deploying at end of day or before a known high-traffic window
- User says "ship it safely", "deploy with guards", "safe deploy", "gated deploy"
- **Do NOT use** for emergency hotfix under active incident — use direct `deploy` with `--hotfix`; hotfix needs bypass, not gates
- **Do NOT use** for platforms other than Vercel in MVP — Cloudflare Workers, Railway, etc. require platform adapter (see spec)
- **Do NOT use** when there are no changed files — pipeline has no-op guard but running is wasteful

## Prerequisites

- `git` with clean working tree or stashed changes
- Platform CLI installed: `vercel` (MVP — other platforms via adapter)
- `doppler` configured for environment secrets
- Playwright available (`npx playwright` or bundled)
- `.dev-os/runtime/reports/routes.json` exists — list of smoke-test URLs per route
- `curl` for health checks
- Project is a DevOS-managed project with `.dev-os/config.yml`

## Steps

### Step 1: Preflight Check

**Command:** `bash scripts/lib/ship-safely/preflight.sh`
**Input:** Current git state + `.dev-os/config.yml`
**Output:** `.dev-os/runtime/ship-safely/<run-id>/preflight.json` — records git SHA, branch, changed files, platform target
**Gate to next step:** preflight.json exists, `platform` field is non-empty, `changed_files` is non-empty
**Skip if:** never — always establishes baseline

### Step 2: Run Tests

**Skill:** `test`
**Input:** preflight.json from Step 1
**Output:** `.dev-os/runtime/ship-safely/<run-id>/test-results.json` — counts, duration, failed suite names
**Gate to next step:** test-results.json exists, `failed: 0`, `status: pass`
**Skip if:** `DEVOS_SHIP_SAFELY_SKIP_TESTS=1` AND a matching `--skip-tests` waiver is recorded (operator emergency only; logged to telemetry)

### Step 3: Migration Dry-Run

**Command:** `bash scripts/lib/ship-safely/migration-dryrun.sh`
**Input:** preflight.json, ORM detection (Prisma / Drizzle / none)
**Output:** `.dev-os/runtime/ship-safely/<run-id>/migration-dryrun.json` — pending migrations list, diff summary, exit code
**Gate to next step:** Exit 0, `blocking_changes: 0` (no destructive column drops without `--force`)
**Skip if:** no ORM detected AND no `migrations/` directory present

### Step 4: Deploy Preview

**Command:** `bash scripts/lib/ship-safely/adapters/vercel.sh deploy-preview`
**Input:** Project root + Doppler config
**Output:** `.dev-os/runtime/ship-safely/<run-id>/preview.json` — preview URL, deploy ID, platform
**Gate to next step:** `preview_url` HTTP 200 within 120s
**Skip if:** `SHIP_SAFELY_SKIP_PREVIEW=1` (dangerous — only for local integration tests that do not need a hosted preview)

### Step 5: Playwright Smoke

**Command:** `bash scripts/lib/ship-safely/smoke.sh`
**Input:** preview.json, routes from `.dev-os/runtime/reports/routes.json`
**Output:** `.dev-os/runtime/ship-safely/<run-id>/smoke-results.json` — per-route HTTP status, console errors, visual diff score, light + dark screenshots, selected driver, selected target, auth path, backend, artifact paths, and fallback reason
**Gate to next step:** All routes return 200, no console errors, visual diff score ≤ 0.5% per route
**Skip if:** `.dev-os/runtime/reports/routes.json` missing AND user confirms `--skip-smoke` with a recorded waiver

### Step 5b: UI Pre-Flight Validation (conditional)

**Trigger:** When `preflight.json` `changed_files` matches UI trigger conditions (see `profiles/default/standards/frontend/ui-preflight.md`)
**Process:** Invoke `scripts/ui-preflight.sh --diff HEAD` — verify 4-screenshot bundle or waiver
**Gate:** ui-preflight.sh exits 0
**Skip if:** No UI files changed (`changed_files` contains no `.tsx`/`.vue`/`.svelte`/`tokens*`/`theme*`)

### Step 6: Promote to Production

**Command:** `bash scripts/lib/ship-safely/adapters/vercel.sh promote`
**Input:** preview.json deploy ID
**Output:** `.dev-os/runtime/ship-safely/<run-id>/promote.json` — production URL, alias set timestamp
**Gate to next step:** `production_url` HTTP 200, returns the deploy ID from preview.json
**Skip if:** never — promotion is the whole point; if we reached here, we promote

### Step 7: Health Monitor

**Command:** `bash scripts/lib/ship-safely/health-monitor.sh`
**Input:** promote.json, health endpoint (default `/api/health`)
**Output:** `.dev-os/runtime/ship-safely/<run-id>/health.json` — 10 samples over 5 minutes (30s interval), status distribution
**Gate to next step:** Zero 5xx responses, zero timeouts > 10s, fewer than 2 consecutive failures in any window
**Skip if:** `.dev-os/config.yml` `shipSafely.skipHealthMonitor: true` (not recommended; logged to telemetry)

### Step 7b: Auto-Rollback (conditional)

**Trigger:** Step 7 gate fails — 3 consecutive 5xx OR single timeout > 10s OR status 5xx count ≥ 3
**Process:** `bash scripts/lib/ship-safely/adapters/vercel.sh rollback` restores the prior production deploy; writes `rollback.json` with prior deploy ID, timestamp, trigger reason
**Gate:** Rollback completes, prior production alias restored, `/api/health` returns 200 within 60s
**Skip if:** Step 7 passed — no rollback needed

### Step 8: Notify + Record

**Command:** `bash scripts/lib/ship-safely/notify.sh`
**Input:** All prior JSON outputs from this run
**Output:** `.dev-os/runtime/ship-safely/<run-id>/summary.json` + append to `product/runtime/ship-safely-log.jsonl`
**Gate to next step:** summary.json written, log line appended
**Skip if:** `SHIP_SAFELY_NO_NOTIFY=1` (suppresses external channel posts; local log still written)

## Pipeline Variants

### Standard Deploy (default)
All 8 steps run in order. Step 5b fires only when UI changed.

### MVP Deploy (`--mvp`)
Skip Step 3 (migration dry-run) when repo has no ORM. Useful for pure-frontend projects without database.
1. Steps 1, 2 run
2. Step 3 skipped (no ORM detected via preflight)
3. Steps 4, 5, 5b, 6, 7, 7b, 8 run normally

### Preview Only (`--preview-only`)
Run through Step 5 (smoke); stop before Step 6 promote. Useful for PR review pipelines.
1. Steps 1-5, 5b run
2. Steps 6-8 skipped
3. Exits with preview_url for reviewer to open

### Hotfix (`--hotfix <incident-id>`)
Bypass Steps 2, 3, 5 with logged waiver. Run 1, 4, 6, 7, 7b, 8 only. Incident ID required; rollback threshold tightened to 1 consecutive 5xx.
1. Step 1 runs
2. Steps 2, 3, 5, 5b skipped with `Preflight-waiver: incident <id>` entry in summary.json
3. Steps 4, 6, 7 run
4. Step 7b rollback threshold lowered (any 5xx → rollback)
5. Step 8 runs and flags `hotfix: true`

## Resume Points

| Artifact | Indicates | Resume at |
|---|---|---|
| `.dev-os/runtime/ship-safely/<run-id>/preflight.json` | Step 1 complete | Step 2 (tests) |
| `.dev-os/runtime/ship-safely/<run-id>/test-results.json` (status: pass) | Step 2 complete | Step 3 (migration dry-run) |
| `.dev-os/runtime/ship-safely/<run-id>/migration-dryrun.json` (exit 0) | Step 3 complete | Step 4 (preview deploy) |
| `.dev-os/runtime/ship-safely/<run-id>/preview.json` | Step 4 complete | Step 5 (smoke) |
| `.dev-os/runtime/ship-safely/<run-id>/smoke-results.json` | Step 5 complete | Step 5b or Step 6 |
| `.dev-os/runtime/ship-safely/<run-id>/promote.json` | Step 6 complete | Step 7 (health monitor) |
| `.dev-os/runtime/ship-safely/<run-id>/health.json` (pass) | Step 7 complete | Step 8 (notify) |
| `.dev-os/runtime/ship-safely/<run-id>/rollback.json` | Step 7b fired | Step 8 (notify with rollback flag) |

Resume rule: inspect the run-id directory; find the highest-numbered artifact present; continue from the next step.

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Changed files empty | Halt; nothing to ship. Exit 0 with "no-op" |
| Step 1 | Platform not detectable (no vercel.json, no wrangler.toml) | Halt exit 64; ask user to configure deploy adapter |
| Step 2 | Test suite fails | Halt; surface failed suite names. Run `systematic-debugging` to triage. Do not auto-retry |
| Step 3 | Blocking migration (column drop, non-nullable add without default) | Halt; show the blocking diff. Require `--force` AND explicit user confirmation to continue |
| Step 4 | Preview deploy times out (> 120s) | Retry once; if second timeout, halt and surface Vercel deploy logs |
| Step 4 | Preview URL 4xx/5xx | Halt; platform adapter dumps last 50 lines of deploy log |
| Step 5 | Route returns non-200 | Halt; list failing routes. Check preview URL manually before re-running |
| Step 5 | Visual diff > 0.5% on any route | Halt with diff image paths. User inspects, confirms intended, re-runs with `SHIP_SAFELY_VISUAL_DIFF_OK=1` |
| Step 5b | UI pre-flight missing bundle | Halt; point to `scripts/ui-preflight.sh --fix` to scaffold |
| Step 6 | Alias set fails | Retry once; if second failure, halt and leave preview URL operational for manual promotion |
| Step 7 | 3 consecutive 5xx in 90s | Trigger Step 7b (auto-rollback) |
| Step 7 | Single timeout > 10s | Trigger Step 7b |
| Step 7b | Rollback itself fails | Page operator via notify.sh with priority: critical; keep production in broken state is not safer than keep trying; loop rollback max 3 attempts then halt |
| Step 8 | Notification channel unavailable (Slack, Linear) | Log locally; do not halt pipeline — production is already good |

## Run ID Convention

`<run-id> = <utc-date>-<short-sha>-<branch-slug>`
Example: `2026-04-19-1b2d253-main`

All artifacts live under `.dev-os/runtime/ship-safely/<run-id>/`. This directory is the durable record of one ship-safely run; it is gitignored but preserved for at least 30 days for post-incident review.

## Output Format

Terminal output, stage by stage, with a final summary block:

```
[ship-safely] run-id: 2026-04-19-1b2d253-main
[step 1 preflight] ✓ platform=vercel files=14 branch=main
[step 2 tests] ✓ 417 passing in 23s
[step 3 migration-dryrun] ✓ 1 pending, no blocking
[step 4 preview-deploy] ✓ https://myapp-git-main.vercel.app
[step 5 smoke] ✓ 8 routes × 2 modes — all 200
[step 5b ui-preflight] ✓ 4 screenshots verified
[step 6 promote] ✓ https://myapp.com → dpl_xyz
[step 7 health-monitor] ✓ 10/10 pass, p50 82ms
[step 8 notify] ✓ telemetry written
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SHIPPED  run-id=2026-04-19-1b2d253-main  duration=7m43s
  preview:    https://myapp-git-main.vercel.app
  production: https://myapp.com
```

On halt:
```
[step 5b ui-preflight] ✗ FAIL — no pre-flight bundle found
HALT at step 5b: ui-preflight failed
Fix: run scripts/ui-preflight.sh --fix; re-invoke
```

On rollback:
```
[step 7 health-monitor] ✗ 3 consecutive 5xx
[step 7b auto-rollback] restoring prior production (dpl_prev)
ROLLED BACK  run-id=...  duration=6m12s
```

## Telemetry Contract

Every run appends one line to `product/runtime/ship-safely-log.jsonl`:

```json
{"ts":"2026-04-19T10:30:00Z","run_id":"...","variant":"standard","status":"shipped|rolled_back|halted","halt_step":null|N,"duration_ms":123456,"preview_url":"...","production_url":"...","rollback_reason":null|"string"}
```

Consumed by `project-status`, trend dashboards, and `pipeline-guardian` when wrapping this pipeline.
