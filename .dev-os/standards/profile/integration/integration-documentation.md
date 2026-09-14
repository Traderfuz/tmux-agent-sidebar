<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/integration/integration-documentation.md and re-run profile-sync. -->
# Integration Documentation Standard

## Overview

Integrations fail silently when their operational knowledge lives only in a spec, a PR, or one maintainer's memory. A working webhook, hook, CLI bridge, MCP server, scheduler, OAuth app, or external API client is not production-ready until another operator can answer: what owns it, how is it configured, how is it verified, and how is it disabled safely?

This standard applies Docs-as-Code and the Diátaxis documentation framework to integration surfaces: the standard defines the contract, while each concrete integration doc/runbook is the source of truth for that integration's commands, secrets, failure modes, and verification evidence.

## Scope

This standard covers required documentation for DevOS integrations. It does NOT cover implementation architecture for the integration itself; see `global/modular-integration.md` and profile-specific API client standards for code structure.

An integration is any boundary where DevOS talks to or is invoked by another runtime, service, CLI, hook system, MCP server, scheduler, browser, OS package, OAuth provider, or external API.

## Principles

1. **Docs are part of the integration contract:** If an operator cannot set up, verify, and disable the integration from docs, the integration is incomplete.
2. **Standards define shape; integration docs define facts:** The standard says which fields are mandatory. The integration doc says the actual commands, env vars, hooks, owners, and failure modes.
3. **Operational paths are first-class:** Setup is not enough. Every integration doc must include verification, troubleshooting, and rollback/disable paths.
4. **Docs-as-Code keeps integration truth reviewable:** Integration docs live in the repo, change with the implementation, and are verified like code.
5. **Diátaxis separates reference from operation:** Stable facts belong in reference docs; step-by-step incident or maintenance procedures belong in runbooks.

## Rules

### R1 — Every shipped integration has a documentation artifact (`MUST`)

Any spec that adds or materially changes an integration MUST create or update one of these artifacts before closure:

| Integration doc type | Use when | Preferred path |
|---|---|---|
| Integration reference | Stable setup/config/runtime facts | `docs/integrations/<integration>.md` |
| Operational runbook | Incident response, rotation, disable/rollback, maintenance | `docs/runbooks/<integration>.md` or `docs/runbooks/<integration>-<operation>.md` |
| Public/operator guide | End-user or operator workflow, not implementation details | `docs/guides/<integration>.md` |

A spec MAY use both a reference doc and a runbook when the integration has nontrivial operations.

### R2 — Integration reference docs use the required contract (`MUST`)

Every `docs/integrations/<integration>.md` file MUST include these sections or an explicit `N/A` reason:

1. **Owner / owning system** — who owns the integration and which OS/project it belongs to.
2. **Purpose and user-facing value** — what job the integration enables.
3. **Architecture / data flow** — what talks to what, including entry points and boundaries.
4. **Auth, secrets, and environment variables** — secret names only; never secret values.
5. **Setup / enable path** — exact commands or UI steps.
6. **Runtime entry points** — hooks, scripts, commands, services, MCP tools, schedules, routes, or files.
7. **Verification** — commands/tests and expected outputs.
8. **Failure modes and troubleshooting** — common failures and how to distinguish them.
9. **Disable / rollback path** — how to turn it off safely without breaking adjacent systems.
10. **Linked lifecycle artifacts** — spec, tasks, tests, ADRs, gap report, and owning standard.
11. **Freshness contract** — when it must be reviewed or what upstream files make it stale.

### R3 — Specs and tasks carry integration-doc work (`MUST`)

If a spec touches an integration, `tasks.md` MUST include an explicit documentation task unless the spec records `DOCS-SKIP:` with a reason.

```markdown
## Integration Documentation
- [ ] Add or update `docs/integrations/rtk.md` with owner, setup, verification, failure modes, and disable path.
- [ ] Verify commands in the doc against the implemented state.
```

### R4 — Generated summaries point, they do not own (`MUST NOT`)

`CLAUDE.md`, `AGENTS.md`, generated context bundles, and public-surface indexes MUST NOT be the only place an integration is documented. They MAY include a short pointer to the canonical integration doc.

```markdown
<!-- ON-STANDARD pointer -->
RTK filtering is managed via `docs/integrations/rtk.md`; do not hand-edit hooks without following its backup/rollback steps.
```

### R5 — Verification commands in docs are testable (`SHOULD`)

Every documented verification command SHOULD be machine-checkable. If a command requires manual console/UI verification, the doc MUST state the exact expected visible result.

### R6 — Secrets are named, never pasted (`MUST`)

Integration docs MUST name required secret keys, Doppler paths, OAuth app names, or env var names, but MUST NOT include secret values, tokens, private keys, refresh tokens, or screenshots exposing credentials.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Integration only described in `spec.md` | Specs are lifecycle artifacts; operators will not search old specs during incidents | Add `docs/integrations/<name>.md` and link the spec |
| Setup steps without disable/rollback | Operators can enable but cannot safely recover from bad state | Add a tested disable path and adjacent-system preservation notes |
| CLAUDE.md contains full integration details | Always-loaded context bloats and drifts | Keep CLAUDE/AGENTS to a one-line pointer |
| Secret values pasted into docs | Leaks credentials into git history | Document secret names and where they are managed |
| Verification says "check it works" | Not binary or repeatable | Provide exact command and expected output |
| Runbook and reference mixed into one long narrative | Under pressure, operators cannot find the action path | Split stable facts into reference and operations into runbook |

## Deviation guidance

You MAY omit a dedicated integration doc when all of the following are true:
1. The integration is a one-off internal helper with no credentials, runtime hooks, external service, or operator action.
2. The setup and verification are fully encoded in tests or generated reference output.
3. The spec records `DOCS-SKIP:` with the reason and reviewer/date.

You SHOULD create only a runbook, not a full reference doc, when the integration already has an authoritative external reference and DevOS only owns an operational procedure against it.

## Enforcement

- `write-spec` SHOULD add an Integration Documentation section when requirements mention integrations, hooks, schedulers, MCP, OAuth, external APIs, webhooks, or CLI bridges.
- `create-tasks` MUST include an integration-doc task for integration-scoped specs.
- `docs-sync` SHOULD detect missing `docs/integrations/<name>.md` when a completed integration spec has no canonical doc.
- `docs-verify` SHOULD verify command/env/path claims inside integration docs.
- `triage` and `gap-analysis` SHOULD surface missing integration docs as Medium findings; High when rollback/disable is undocumented for a hook, auth, scheduler, or production-impacting integration.

## Compliance test

- [ ] Does every shipped integration have a canonical `docs/integrations/<name>.md`, `docs/runbooks/<name>.md`, or documented `DOCS-SKIP:` waiver?
- [ ] Does the doc name owner, purpose, auth/secrets, setup, runtime entry points, verification, failure modes, rollback/disable, linked artifacts, and freshness contract?
- [ ] Are all secret values omitted while secret names/locations are documented?
- [ ] Does every integration-scoped `tasks.md` include an integration-doc task before closure?
- [ ] Do generated context files and CLAUDE/AGENTS only point to the canonical doc rather than owning the full details?
- [ ] Has `docs-verify` or an equivalent command checked that documented commands/paths/env vars match the repo?

If any check fails: add or update the canonical integration doc, add a task/waiver to the active spec, and re-run docs verification before marking the integration complete.

## References

- [Diátaxis documentation framework](https://diataxis.fr/) — separates tutorials, how-to guides, reference, and explanation. Applied here to choose between integration reference docs and operational runbooks.
- [Docs as Code](https://www.writethedocs.org/guide/docs-as-code/) — documentation changes live in version control and follow code review/testing practices.
- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) — normative vocabulary for MUST/SHOULD/MAY compliance language.
- `profiles/general/standards/global/modular-integration.md` — companion standard for runtime integration contracts and module coupling.
- `profiles/general/standards/maintenance/artifact-ownership.md` — companion standard for freshness and ownership of generated/derived artifacts.
- `profiles/general/standards/maintenance/scheduler-ownership.md` — companion standard supplying the ownership/namespace-routing half of the scheduler integration contract (which OS owns a recurring job).
