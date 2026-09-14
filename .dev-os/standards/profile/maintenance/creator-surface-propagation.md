<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/creator-surface-propagation.md and re-run profile-sync. -->
# Creator Surface Propagation Standard

## Overview

Any skill that creates a durable artifact must also prove the artifact is visible to the surfaces that discover, route, run, validate, or document it. Creating a file is not enough. The artifact is not complete until its downstream registry, mirror, docs, route config, and verification surfaces are updated or explicitly waived.

## Scope

Applies to creator skills and workflows that author chains, skills, commands, workflows, pipelines, runbooks, standards, agents, profiles, MCP servers, CI workflows, design systems, generated context, or other durable DevOS/project artifacts.

## Rules

### Rule 1: Creator skills MUST name the source of truth

Every creator must state the canonical source path and distinguish generated derivatives from editable source files.

Examples:

- Chains: `profiles/general/chains/<id>.yaml`
- Skills: `<skills-root>/<skill>/SKILL.md`
- Standards: `profiles/<profile>/standards/<category>/<name>.md` or `.dev-os/standards/global/<name>.md`
- Workflows/pipelines: source workflow path plus any installed/project-local mirror

### Rule 2: Creator skills MUST update surfacing artifacts

If an artifact is consumed by a registry, index, command list, launcher, router, docs page, or config map, the creator must update it in the same work slice.

Common surfacing artifacts include:

- `docs/context/*_INDEX.json`
- `docs/context/*_INDEX.md`
- `.dev-os/config.yml` route maps
- `.dev-os/*/README.md` installed-surface docs
- `docs/guides/*.md` human reference docs
- `AGENTS.md` / `CLAUDE.md` generated managed blocks
- package/profile manifests and install manifests

### Rule 3: Creator skills MUST prove runtime discoverability

The creator must verify the consuming runtime can find the new artifact. Examples:

- Chain: registry item exists with `status: available`, matching sequence, clients, keywords, and model route.
- Skill: skill index contains the skill and trigger keywords resolve.
- Command: command appears in the command surface and delegates to the correct backing skill/workflow.
- Standard: standards index and validation checklist include it.
- Agent: agent registry/runtime can load the system prompt.
- CI/MCP/deploy artifacts: the relevant CLI or smoke command lists/validates the new artifact.

### Rule 4: Creator skills MUST run a completion gate

Before declaring completion, run the smallest deterministic validation plus `gap-analysis --dalio --fix` when available. If gap-analysis is unavailable, record a manual waiver with the missing command and completed checks.

Minimum completion checklist:

- [ ] Source artifact exists at canonical path
- [ ] Installed mirror or project-local copy is synced, if applicable
- [ ] Machine registry/index regenerated, if applicable
- [ ] Human docs/README/guides updated, if applicable
- [ ] Runtime/router/launcher can discover it
- [ ] Verification command or smoke check passed
- [ ] `gap-analysis --dalio --fix` completed or explicit waiver recorded

### Rule 5: Derivative files MUST NOT be hand-edited as the fix

If a generated registry or index is stale, fix the source artifact or generator input, then regenerate. Do not patch generated JSON/Markdown by hand unless the generator itself is the defect being fixed.

### Rule 6: Installed-project propagation MUST be checked by layer

When a source artifact is propagated into installed projects, verify each required layer separately: source artifact, installed mirror, generated registry, config route/defaults, human/status surface, and managed AGENTS/CLAUDE block when enabled. Use the propagation contract/check tooling when available instead of assuming a copied file is discoverable.

## Compliance test

A creator skill is compliant when a reviewer can answer “yes” to all questions:

1. Does the skill name the source artifact and generated derivatives?
2. Does it list the surfaces that must be updated for discovery/routing/execution?
3. Does it include an explicit runtime discoverability proof?
4. Does it include verification and gap-analysis completion gates?
5. Does it forbid source/derivative drift and generated-file hand edits?

## Anti-patterns

| Anti-pattern | Why it fails | Correct pattern |
|---|---|---|
| “Created `<file>`” as completion claim | File may not be discoverable | Prove registry/router/docs surfaces updated |
| Hand-editing generated indexes | Drift returns on next generation | Fix source then regenerate |
| Adding route keywords without testing registry entry | Dispatch may still miss it | Inspect generated registry item |
| Updating machine registry but not docs | Human/status surfaces lie | Update both machine and human surfaces |
| Skipping gap-analysis because artifact is small | Small creator gaps cause silent routing failures | Run gap-analysis or record waiver |
