<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/deployment/manual-deploy-discipline.md and re-run profile-sync. -->
# Manual Deploy Discipline

## Problem

The Vercel Git integration auto-deploys on every push to the configured production
branch (`main`). For feature work, this fires many redundant deployments:

- Every WIP commit during a multi-commit feature → a deploy.
- Every `chore(context):` regen commit → a deploy.
- Every `fix:` typo → a deploy.

Vercel costs scale with deployment count + invocation minutes. WIP deploys are
pure waste, and they make "what's actually in prod?" impossible to answer without
`git diff main..last-deploy`.

## Default posture: ignore git-push auto-deploy

The canonical Vercel control for this is `vercel.json:ignoreCommand`. Returning
`exit 0` (or any non-zero exit) tells Vercel to **skip** the auto-deploy hook:

```json
{
  "ignoreCommand": "exit 0"
}
```

The prebuilt manual deploy path (`deploy-prod.sh` or the `deploy` skill) still
works — `ignoreCommand` only affects the git-push trigger.

## Three sanctioned deploy-trigger patterns

Choose ONE based on team rhythm. Document the choice in
`docs/context/DEPLOY_STRATEGY.md`.

### Pattern A — Manual batch (recommended for solo/feature teams)

Deploy when a meaningful batch of work lands.

```bash
# vercel.json
{ "ignoreCommand": "exit 0" }

# Deploy flow (already provided by deploy-prod.sh):
./scripts/deploy-prod.sh

# Or inline:
doppler run --project <slug> --config prd -- vercel build --prod
doppler run --project <slug> --config prd -- bash -c \
  'vercel deploy --prod --prebuilt --archive=tgz --token "$VERCEL_TOKEN" --yes'
```

**Pros:** zero noise, deploys are deliberate, easy rollback point.
**Cons:** requires operator discipline — must remember to deploy after merges.

### Pattern B — `[deploy]` commit marker

Auto-deploy only when a commit message contains `[deploy]`. Useful when you
want CI-driven deploys but only for "ship-ready" commits.

```bash
# vercel.json
{
  "ignoreCommand": "git log -1 --pretty=format:\"%s\" | grep -q '\\[deploy\\]'"
}
```

Then on the merge commit:

```bash
git commit --allow-empty -m "chore(release): ship batch to prod [deploy]"
git push origin main
```

**Pros:** every merge auto-deploys iff operator marked it.
**Cons:** still uses Vercel build (not prebuilt) — defeats Doppler secret injection.
**Override with:** `--build-env` and registered env vars.

### Pattern C — Release branch

Deploys happen on push to a `release` branch, not `main`. `main` accumulates
freely; `release` is bumped and force-pushed when a deploy is intended.

```bash
# vercel.json — configure production branch in Vercel dashboard
# Then: git push origin release:main forces a production rebuild
```

**Pros:** branch is a deploy gate; `main` stays clean.
**Cons:** force-push on `release` is confusing for new collaborators.

## Mandatory: surface the gap

A 3-month deploy drift (production 100+ commits behind `main`) is a **gap** —
not a deployment issue. The `deployment-freshness` check surfaces it. Always
run that check before claiming "we're current."

## Pre-deploy checklist (regardless of pattern)

- [ ] `git status` clean OR dirty files are scoped to runtime/state (not code)
- [ ] Branch matches `DEPLOY_REQUIRED_BRANCH`
- [ ] `bun test` (or equivalent) green
- [ ] `doppler run -- bun run verify:env` green
- [ ] `deployment-freshness` check green (or gap explicitly acknowledged)
- [ ] Last deploy SHA recorded in `.dev-os/runtime/last-deploy.json`

## When NOT to skip auto-deploy

- Hotfix branch where `main` is broken and prod needs the patch in <30 minutes.
  In that case, push the hotfix directly with Pattern B marker, or run
  `./scripts/deploy-prod.sh` immediately after merge.

- Brand-new project on day one — `ignoreCommand: "exit 0"` is a friction gate
  worth keeping even then so you learn the deploy cadence intentionally.

## Related

- `vercel.json:ignoreCommand` — Vercel Git integration control
- `scripts/lib/checks/deployment-freshness.sh` — gap detector
- `scripts/deploy-prod.sh` — canonical manual prebuilt deploy
- `.dev-os/standards/global/deployment.md` — global deployment posture