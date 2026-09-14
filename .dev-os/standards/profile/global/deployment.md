<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/deployment.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/deployment.md and re-run profile-sync. -->
# Deployment Standard

## Purpose

Use this standard for any project deployed with Vercel so deployments stay predictable and recoverable.

## Default Safety Posture (Vercel)

- Deploy previews by default.
- Never run `vercel --prod` unless the user explicitly asks for production deployment.
- Never run `vercel promote` unless the user explicitly asks to move a deployment to production aliases.
- Keep Git auto deployments disabled for managed projects:
  - `gitProviderOptions.createDeployments = "disabled"`
- Keep ignored build guard enabled:
  - `commandForIgnoringBuildStep = "exit 0"`

## Team and Project Scope Guardrail

Before any deploy, verify project link and scope so deployments do not go to a personal account by mistake.

```bash
cat .vercel/project.json
# Confirm correct team/account and project linkage.
```

Use explicit scope in deploy commands when possible:

```bash
vercel --scope <team-slug> --yes
```

## Critical Gotcha: READY deployment with NOT_FOUND

This failure appears as:

- Deployment status: `Ready`
- URL response: `404 NOT_FOUND`
- `vercel inspect <url>` shows `Builds: . [0ms]`

This means Vercel created a deployment record with no runnable output.

Common cause:

- `commandForIgnoringBuildStep="exit 0"` is enabled, but Git deployment creation is still enabled.

## Required Baseline for Next.js Projects

For Next.js projects with app in subdirectory:

- `framework`: `nextjs`
- `rootDirectory`: project-specific (for example `app`)
- `installCommand`: project-specific install command (for example `bun install`)
- `buildCommand`: project-specific build command (for example `bun run build`)
- `outputDirectory`: project-specific output directory (for example `.next`)

If `rootDirectory` is configured to a subdirectory (for example `app`), run deploy commands from repository root to avoid path mismatch issues.

Always verify settings before debugging routing behavior.

## Pre-Deploy Verification

```bash
TOKEN=$(jq -r '.token' "$HOME/.local/share/com.vercel.cli/auth.json")
TEAM_ID="<your-team-id>"
PROJECT_ID="<your-project-id>"

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.vercel.com/v9/projects/$PROJECT_ID?teamId=$TEAM_ID" | \
  jq '{
    name,
    framework,
    rootDirectory,
    installCommand,
    buildCommand,
    outputDirectory,
    ignoreBuild: .commandForIgnoringBuildStep,
    createDeployments: .gitProviderOptions.createDeployments
  }'
```

## Deployment Workflow

1. Verify settings (above).
2. Create manual preview deploy (`vercel --yes`).
3. Validate route and API endpoint.
4. If `NOT_FOUND`, run recovery steps below.

Recommended validation commands:

```bash
curl -I https://<deployment-url>/
curl -s https://<deployment-url>/api/health
```

## NOT_FOUND Recovery Workflow

1. Inspect deployment:
   - `vercel inspect <deployment-url>`
2. Check build section:
   - If `Builds` is only `.` with `0ms`, treat deployment as invalid.
3. Verify project settings and safety controls.
4. Redeploy manually.

## API-Based Team-Wide Hardening

### Disable Git deployment creation

```bash
TOKEN=$(jq -r '.token' "$HOME/.local/share/com.vercel.cli/auth.json")
TEAM_ID="<your-team-id>"

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.vercel.com/v9/projects?limit=100&teamId=$TEAM_ID" | \
  jq -r '.projects[] | [.id,.name] | @tsv' | \
while IFS=$'\t' read -r PID NAME; do
  curl -s -X PATCH \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.vercel.com/v9/projects/$PID?teamId=$TEAM_ID" \
    --data '{"gitProviderOptions":{"createDeployments":"disabled"}}' > /dev/null
  echo "updated: $NAME"
done
```

### Set ignored build guard

```bash
TOKEN=$(jq -r '.token' "$HOME/.local/share/com.vercel.cli/auth.json")
TEAM_ID="<your-team-id>"

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.vercel.com/v9/projects?limit=100&teamId=$TEAM_ID" | \
  jq -r '.projects[] | select(.commandForIgnoringBuildStep != "exit 0") | [.id,.name] | @tsv' | \
while IFS=$'\t' read -r PID NAME; do
  curl -s -X PATCH \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.vercel.com/v9/projects/$PID?teamId=$TEAM_ID" \
    --data '{"commandForIgnoringBuildStep":"exit 0"}' > /dev/null
  echo "updated: $NAME"
done
```

## Health Endpoint Caveat

`/api/health` can return app status `down` even when frontend pages render correctly, if backend functions were not deployed yet.

Example signal:

- `Could not find public function for 'auth:getCurrentUser'`

Action:

- Deploy backend functions first, then retest health endpoint.

## Operational Hygiene

- Do not treat older preview URLs as canonical; use the latest deployment URL from `vercel list`.
- Keep one known-good preview URL documented per project for quick rollback/reference.
- Remove invalid `NOT_FOUND` deployments so they are not reused by mistake.
