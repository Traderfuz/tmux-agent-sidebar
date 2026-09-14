<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/installer-propagation.md and re-run profile-sync. -->
# Installer & Registry Propagation Standards

## Overview

When a project adds a new component — a hook, plugin, route, migration, service, CLI command, or config entry — the component itself gets implemented and tested, but the scripts that *install*, *register*, or *wire* that component often don't get updated. The result is a system that works on the developer's machine (where the component was manually registered during development) but silently fails on fresh installs, new team members' machines, CI environments, or after a clean setup.

This is the **propagation gap**: the distance between creating a component and ensuring every entry point that needs to know about it is updated. This standard governs how to identify, track, and close propagation gaps.

## Scope

This standard covers the practice of updating installer scripts, registration manifests, CI configs, and any other entry points when new components are added to a project. It does NOT cover the design of installer scripts themselves (that's deployment standards) or the architecture of plugin systems (that's modular-integration standards).

## Principles

1. **A component isn't shipped until its registration is shipped:** Implementation + tests is not enough. If a fresh install wouldn't pick it up, it's not done.
2. **Registration points are enumerable:** Every project should be able to answer "which files need updating when I add a new X?" for each component type. If the answer requires tribal knowledge, the project has a propagation debt.
3. **Propagation is verifiable:** A CI check or manual verification step can confirm that all registered components match the components that exist on disk.

## Rules

### Identify registration points per component type

For every component type in the project, maintain a mapping of where that component must be registered. This mapping lives in the project's documentation (CLAUDE.md, AGENTS.md, or a dedicated manifest).

**MUST document the propagation map for each component type:**

```markdown
## Propagation Map

| Component type | Files that must be updated |
|---------------|---------------------------|
| Hook script | install.sh (hook registration), settings.json (runtime) |
| CLI command | install.sh (command allowlist), commands/index |
| API route | routes/index, OpenAPI spec, e2e test fixtures |
| DB migration | migration registry, seed scripts |
| Env variable | .env.example, doppler config, CI secrets, deploy config |
| Service/worker | docker-compose.yml, CI workflow, deploy manifest |
| Skill/plugin | install.sh (if applicable), plugin registry |
```

**OFF-STANDARD — no propagation map exists:**
The developer adds a hook, tests it locally, commits it, and the installer is never updated. Fresh installs silently miss the hook.

**ON-STANDARD — propagation map in project docs:**
The developer consults the propagation map, updates all listed files, and the commit includes both the component and its registrations.

### Include registration updates in the same commit

When adding a new component, the commit that creates the component **MUST** also update all registration points from the propagation map. Do not split component creation and registration into separate commits or tasks — this invites the second commit being forgotten.

**MUST** — single commit contains:
- The new component file(s)
- All registration/installer updates
- Any manifest or index updates

**SHOULD NOT** — "I'll update install.sh in a follow-up" (the follow-up rarely happens)

### Verify propagation on merge

Before merging a branch that adds new components, verify propagation completeness. This can be:

- **Manual:** Check the propagation map and confirm each entry point was updated
- **Automated:** A CI step that compares registered components against components on disk
- **Hook-based:** A pre-commit or pre-push hook that flags new files matching component patterns (e.g., `scripts/hooks/*.sh`) without corresponding registration updates

**Verification approaches by project type:**

```bash
# Example: verify all hook scripts in scripts/hooks/ are registered in install.sh
for hook in scripts/hooks/*.sh; do
  basename="$(basename "$hook")"
  if ! grep -q "$basename" scripts/install.sh; then
    echo "UNREGISTERED: $basename not in install.sh"
  fi
done

# Example: verify all API route files have corresponding e2e tests
for route in app/api/*/route.ts; do
  route_name="$(basename "$(dirname "$route")")"
  if ! find tests/e2e -name "*${route_name}*" | grep -q .; then
    echo "UNTESTED: $route_name has no e2e test"
  fi
done

# Example: verify all env vars in code are in .env.example
grep -roh 'process\.env\.\w\+' src/ | sort -u | while read -r var; do
  name="${var#process.env.}"
  if ! grep -q "$name" .env.example 2>/dev/null; then
    echo "UNDOCUMENTED: $name not in .env.example"
  fi
done
```

### Registration points for common project types

**Web applications (Next.js, Astro, SvelteKit):**
- New API route → OpenAPI spec, e2e tests, rate limit config
- New env var → `.env.example`, Doppler/Vercel env config, CI secrets
- New middleware → middleware chain registration, deploy config
- New cron/scheduled function → cron registry, monitoring config

**CLI tools (Bash, TypeScript CLI):**
- New hook → installer script (hook registration block), settings/config file
- New command → command allowlist, help text, command index
- New lib function → sourcing in dependent scripts

**Backend services (Convex, Supabase, Express):**
- New DB migration → migration index, seed data
- New RPC/function → function registry, type exports, client SDK
- New worker/service → docker-compose, deploy manifest, health check config

**Infrastructure (Cloudflare, Vercel, AWS):**
- New worker → wrangler.toml or deploy config, DNS/routing, secrets
- New secret → secret manager (Doppler, Vault), rotation runbook
- New domain → DNS config, SSL cert, CORS allowlist

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| "Works on my machine" registration | Component was registered manually during dev but never added to installer | Include installer update in same commit as component |
| Registration in a follow-up PR | The follow-up PR is forgotten or deprioritized | Same-commit rule: component + registration together |
| Undocumented registration points | New developers don't know what to update | Maintain a propagation map in project docs |
| Copy-paste registration | Duplicating registration logic across files without a single source of truth | Use a manifest file that registration scripts read from |
| "The CI will catch it" without a CI check | CI doesn't verify propagation unless explicitly configured | Add a propagation verification step to CI or pre-push |

## Deviation guidance

You MAY skip registration updates when the component is behind a feature flag and not yet intended for general use. When you do: add a `TODO(propagation)` comment in the component file with the list of registration points to update when the flag is removed.

You MAY defer registration for experimental or draft components in development branches. When you do: the PR description **MUST** include a "Propagation checklist" section listing what needs updating before merge to main.

## Compliance test

- [ ] Does the project have a documented propagation map (which files to update per component type)?
- [ ] When adding a new component, does the same commit include all registration/installer updates?
- [ ] Can a fresh install (or `install.sh` re-run) pick up every component that exists on disk?
- [ ] Is there a verification step (manual checklist, CI check, or hook) that catches unregistered components before merge?
- [ ] Are there zero `TODO(propagation)` items on the main branch for non-flagged components?

If any check fails: update the propagation map, add the missing registrations, or configure the verification step. For existing gaps, run a one-time audit: list all components on disk, compare against all registration points, and close every gap in a single commit.

## References

- [The Twelve-Factor App: Config](https://12factor.net/config) — treat config and registration as part of the deploy, not an afterthought
- [Release It! by Michael Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/) — "integration points are the #1 killer of systems" — unregistered components are silent integration failures
- [Google SRE: Release Engineering](https://sre.google/sre-book/release-engineering/) — hermetic builds require that every component's registration is captured in the build definition, not in developer-local state
