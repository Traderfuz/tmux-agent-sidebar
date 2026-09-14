<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/conventions.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/conventions.md and re-run profile-sync. -->
# Conventions Standards

## Overview

Conventions are the meta-standard: the agreements that make a codebase navigable by any team member, new or veteran, without a guided tour. They cover how projects are structured, how changes are recorded in version control, how configuration is separated from code, and how features in progress are safely isolated. Consistent conventions reduce cognitive load — the less a developer has to rediscover, the more they can focus on the problem.

## Scope

This standard covers project directory and file organisation patterns, git commit message format, environment configuration discipline, dependency management governance, feature flag usage, and changelog maintenance. It does NOT cover language-specific naming conventions (see `coding-style.md`) or deployment pipeline configuration (see `deployment.md`).

## Principles

1. **Consistency over personal preference:** When a convention exists, follow it — even if a different choice would have been made in isolation. The value of a convention is in its uniformity, not its optimality.
2. **Configuration belongs in the environment:** Code that reads its operational parameters from environment variables is portable and auditable; code with embedded configuration is fragile and frequently insecure.
3. **History is documentation:** A well-maintained git history and changelog are searchable, auditable records of intent that outlive any individual contributor's memory.

## Rules

### Project structure

Organise files in a predictable structure that a new team member can navigate within minutes. Use the following baseline layout, adapted to the framework where necessary:

```
<project-root>/
├── src/              # All source code
├── tests/            # All test files, mirroring src/ structure
├── scripts/          # Automation scripts (build, deploy, seed)
├── docs/             # Architecture decisions, runbooks, API guides
├── .env.example      # Template listing all required environment variables with descriptions (no values)
├── README.md         # Setup, architecture overview, and contribution guide
└── CHANGELOG.md      # Release history in Keep a Changelog format
```

- Source files live under `src/`; test files live under `tests/` and mirror the `src/` path structure so that the test for `src/payments/processor.ts` is at `tests/payments/processor.test.ts`.
- Scripts that are not part of the application runtime live under `scripts/` with executable permissions.
- No application source files at the repository root. Config files (e.g., `tsconfig.json`, `pyproject.toml`) at root are acceptable; business logic is not.

### Commit message format (Conventional Commits)

Every commit message must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

Format:
```
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

Required types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `revert`.

OFF-STANDARD — untyped, non-descriptive:
```
fix stuff
```

OFF-STANDARD — describes implementation, not change:
```
updated the payment file to add a new method and fixed a bug
```

ON-STANDARD — typed, scoped, present-tense imperative description:
```
feat(payments): add idempotency key support to charge endpoint

Prevents duplicate charges when the client retries on network timeout.
Idempotency keys are stored for 24 hours and scoped per merchant.

Closes DEV-4201
```

ON-STANDARD — small, atomic fix:
```
fix(auth): correct token expiry comparison to use UTC timestamps
```

Rules:
- Description is imperative mood, present tense ("add" not "added", "fix" not "fixed").
- Description does not end with a period.
- Body explains the why, not the what. What is visible in the diff.
- Breaking changes are marked with `!` after the type/scope (`feat!:`) and described in the footer with `BREAKING CHANGE:`.
- Commits must be atomic: one logical change per commit. Do not bundle unrelated changes.

### Environment configuration

All values that vary between environments (development, staging, production) or that are sensitive must live in environment variables, not in source code.

OFF-STANDARD — hardcoded credentials and environment-specific values:
```typescript
const db = new Database({
  host: "prod-db.internal",
  password: "s3cr3t",
  poolSize: 10,
});
```

ON-STANDARD — all configuration read from environment:
```typescript
const db = new Database({
  host: requireEnv("DB_HOST"),
  password: requireEnv("DB_PASSWORD"),
  poolSize: parseInt(requireEnv("DB_POOL_SIZE"), 10),
});
```

OFF-STANDARD (Python):
```python
API_KEY = "sk-live-abc123"
```

ON-STANDARD (Python):
```python
import os
API_KEY = os.environ["STRIPE_API_KEY"]  # Raises KeyError early if not set — intentional
```

Rules:
- Provide a `.env.example` file at the repository root listing every required environment variable with a description and, where safe, a non-sensitive example value. This file is committed and kept up to date.
- Never commit `.env`, `.env.local`, or any file containing real values. These must appear in `.gitignore`.
- Applications must fail fast at startup if a required environment variable is absent, not silently fall back to a default that may hide a misconfiguration.
- Use a secret manager (Doppler, AWS Secrets Manager, Vault) for production secrets. Do not store production secrets in any file, even encrypted at rest in the repository.

### Dependency management

- Every dependency added to a project must have a documented rationale recorded in the commit message or PR description at the time of addition. This rationale is the only reliable record of why a dependency was chosen.
- Prefer libraries with active maintenance, a clear license, and minimal transitive dependency graphs.
- Pin dependencies to exact versions in lockfiles (`bun.lockb`, `package-lock.json`, `poetry.lock`, etc.). Lockfiles are committed and kept current.
- Evaluate and remove unused dependencies on a regular cadence (at minimum before each major release).
- Do not add a dependency to solve a problem that can be solved with a ten-line function and no ongoing maintenance burden.

### Feature flags for incomplete work

Incomplete features must be isolated behind a feature flag rather than kept on a long-lived feature branch. Long-lived branches accumulate merge debt and make integration testing impossible.

- Feature flags must be named descriptively: `ENABLE_NEW_CHECKOUT_FLOW`, not `FF_1234`.
- Flags must be removed — along with the old code path — within one release cycle of the feature graduating to full rollout.
- Document every active feature flag in `docs/feature-flags.md` with: flag name, purpose, owner, and planned removal date.
- Never ship a feature flag that defaults to `true` in production without explicit sign-off.

### Changelog maintenance

Maintain a `CHANGELOG.md` at the repository root in [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]

## [1.3.0] — 2026-01-15
### Added
- Payment idempotency key support (DEV-4201)

### Fixed
- Token expiry comparison now uses UTC timestamps (#892)

### Removed
- Legacy `v1/charge` endpoint (deprecated in 1.0.0)
```

- The `[Unreleased]` section is updated with every merged PR.
- Entries are written for humans, not machines — use plain language that a non-technical stakeholder can parse.
- Breaking changes are listed under a `### Breaking Changes` subsection and cross-referenced to migration notes in `docs/`.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Hardcoded secrets or environment-specific URLs in source code | Rotated secrets require a code change and re-deploy; leaked history is permanent | Read all configuration from environment variables at runtime |
| Vague commit messages ("fix", "wip", "changes") | Makes `git log`, `git bisect`, and blame archaeology useless | Conventional Commits format with type, scope, and imperative description |
| Long-lived feature branches (> 1 sprint) | Accumulates merge conflicts; prevents integration testing of the combined system | Merge early behind a feature flag; delete the branch |
| Undocumented dependency additions | Future maintainers cannot evaluate whether to keep or replace a library | Document the why in the commit/PR at addition time |
| Stale `[Unreleased]` changelog section (never updated) | Releases carry no human-readable record of what changed | Update `[Unreleased]` as part of every PR that changes user-visible behaviour |
| `.env` files committed to the repository | Exposes credentials in git history permanently — rotation does not undo this | Add `.env` to `.gitignore`; use `.env.example` for templates |

## Deviation guidance

- Teams MAY adopt a squash-merge strategy where individual commit messages are replaced by a single PR-level Conventional Commits message, provided the PR title itself follows the format.
- Teams MAY use a changelog generation tool (e.g., `git-cliff`, `conventional-changelog`) to automate `CHANGELOG.md` updates, provided the output is reviewed and edited for human readability before release.
- Teams MUST NOT store production secrets in any version-controlled file, regardless of encryption, without explicit security review.
- Teams MUST NOT merge a PR that introduces a new environment variable without updating `.env.example` in the same PR.

## Compliance test

- [ ] Does every commit message follow the Conventional Commits format (`<type>(<scope>): <description>`)?
- [ ] Is there a `.env.example` in the repository root that lists every required environment variable with descriptions?
- [ ] Is `.env` (and all files containing real secrets) listed in `.gitignore` and absent from the git history?
- [ ] Does every dependency addition in the last 30 days have a documented rationale in its commit or PR?
- [ ] Is the `CHANGELOG.md` `[Unreleased]` section current (updated since the last release)?

## References

- [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/) — the exact format this standard mandates for commit messages, including type vocabulary, breaking change notation, and footer conventions
- [The Twelve-Factor App — Config](https://12factor.net/config) — the canonical argument for strict separation of configuration from code, motivating the environment variable rules in this standard
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — the format mandated for `CHANGELOG.md`, including section names and the principle that changelogs are for humans
