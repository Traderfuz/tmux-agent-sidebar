<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/runtime-standards.md and re-run profile-sync. -->
# Runtime Standards — General Profile

Extends: [../../../default/standards/global/runtime-standards.md](../../../default/standards/global/runtime-standards.md)

## Overview

The `general` profile keeps the default runtime contract and adds one operational emphasis: runtime choices must support Git-driven, multi-workflow DevOS usage without surprising local or CI behavior. This document exists as a thin extension so the `general` profile can add workflow-facing guidance without forking the base runtime standard.

**Sibling standards:**
- [`shell-safety.md`](./shell-safety.md) — alias bypass and pipefail discipline for shell scripts that run inside this runtime context
- [`observability.md`](./observability.md) — structured telemetry emitted by processes running in this runtime

## Scope

This standard covers the `general` profile's runtime-selection emphasis for multi-command, multi-workflow DevOS projects. It does NOT replace the default profile's language and tool runtime baseline.

## Principles

1. **Default runtime policy still applies:** `general` inherits the parent runtime baseline instead of redefining it.
2. **Operational predictability matters:** Runtimes chosen in `general`-profile projects must behave consistently across local development, automation scripts, and CI.
3. **Workflow support beats novelty:** Prefer runtime choices that work cleanly with the surrounding DevOS commands, hooks, and verification workflow.

## Rules

### Rule 1: The default runtime baseline MUST be treated as authoritative

Use the parent standard for language versions, installation expectations, and primary runtime policy.

This profile adds guidance; it does not replace the parent runtime contract.

### Rule 2: Runtime additions SHOULD be justified by workflow needs

If a `general`-profile project adds another runtime, the justification should be operational rather than stylistic.

Valid examples:

- a Python helper because the toolchain already depends on Python automation
- Bun for JS/TS scripting because the project needs fast script execution and package management

Poor examples:

- adding another runtime only because one contributor prefers it
- duplicating the same automation layer in multiple languages without a real boundary

### Rule 3: Cross-workflow compatibility MUST be considered before changing runtime defaults

Before changing runtime assumptions in a `general`-profile project, verify the impact on:

- scripts
- local setup
- CI
- hooks
- release automation

If the new runtime choice complicates those surfaces without real benefit, keep the inherited default.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Forking the parent runtime standard for minor wording changes | Creates stale-parent drift | Keep a thin extension and rely on the parent |
| Adding a new runtime because it is trendy | Expands setup and verification cost without clear gain | Add runtimes only when workflow needs justify them |
| Ignoring CI and automation when changing runtime choices | Local success diverges from operational reality | Check all workflow surfaces before changing defaults |

## Deviation Guidance

- Projects MAY tighten runtime requirements locally when a framework requires it, but the project should document the reason explicitly.
- Teams MUST NOT treat this extension as a replacement for the parent runtime baseline.

## Related Standards

- `../../../default/standards/global/runtime-standards.md`
- `shell-safety.md`
- `observability.md`

### Rule 4: Prefer latest stable at build time

When a new project or feature is started, verify the current stable version of every runtime it depends on. Do not assume installed versions reflect current stable.

- Check current stable before declaring a version in `package.json`, `pyproject.toml`, `.tool-versions`, `.nvmrc`, or equivalent
- Do not pin to a version more than 2 majors behind current stable without documented justification
- For fast-moving runtimes (Node.js, Python, Bun): check current LTS before starting implementation

## Compliance Test

- [ ] Does this project still rely on the parent runtime baseline as the authoritative contract?
- [ ] Are any runtime additions justified by actual workflow needs rather than contributor preference?
- [ ] Were CI, hooks, scripts, and automation considered before changing runtime expectations?
- [ ] For new features: was the current stable runtime version verified before pinning?
