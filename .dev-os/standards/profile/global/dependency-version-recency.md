<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/dependency-version-recency.md and re-run profile-sync. -->
# Dependency Version Recency Standards

## Overview

An LLM's version intuitions are calibrated to its training cutoff. For fast-moving ecosystems (npm, pip, cargo, go modules), the model may recommend a package version that is 1–3 major versions behind current. The result is projects bootstrapped with outdated dependencies that require immediate remediation, miss security patches, and produce AI-generated code using deprecated APIs. This standard establishes when and how to verify current package versions before accepting any LLM version recommendation.

This is a companion to `knowledge-pull.md`. Knowledge-pull covers *what the current API looks like*. This standard covers *which version to install*. They are not the same problem.

## Scope

This standard covers dependency version selection and freshness verification when adding, updating, or bootstrapping project dependencies. It does NOT cover library API documentation lookup (see `knowledge-pull.md`) or security vulnerability scanning (see `security.md`).

## Principles

1. **LLM version numbers are training-data snapshots.** Any version number an LLM produces without live registry lookup is a snapshot from its training cutoff — not the current release. Treat it as a starting point, not a recommendation.
2. **Verify before install.** Registry verification is a 5-second operation. A stale dependency pin costs hours of remediation, upgrade churn, or silent API drift.
3. **Audit before implementation begins.** Running `audit-deps` at project start (and before adding new deps) surfaces the current state before any code is written against stale versions.
4. **Recency is a precondition, not a post-check.** Dependency verification happens before specs, before tasks, and before implementation — not after.

## The LLM Training Cutoff Gap

When an LLM writes:
```
npm install react@18.2.0 react-dom@18.2.0
```
it is recalling what was current at training time. React 19 may be the current release. The model has no mechanism to know this without a live lookup. This applies to every ecosystem:

| Ecosystem | Version source | How to check current |
|-----------|---------------|----------------------|
| npm / pnpm / bun | npmjs.com registry | `npm view <pkg> version` |
| pip | PyPI | `pip index versions <pkg>` or `pip install <pkg>==` (errors show current) |
| cargo | crates.io | `cargo search <pkg>` |
| go modules | pkg.go.dev / GOPROXY | `go list -m -versions <module>` |
| homebrew | formulae.brew.sh | `brew info <formula>` |
| apt / system | distro mirrors | `apt-cache policy <pkg>` |

The resolution: before using any LLM-provided version, verify against the package registry. This is cheap (seconds) and eliminates the class of error entirely.

## Rules

### Rule 1 — Audit deps at project start (`MUST`)

Before writing any spec, creating any task, or running any implementation in a project with a dependency manifest, run:

```bash
audit-deps
```

This surfaces current vs. installed version delta for all dependencies in `package.json`, `requirements.txt`, `Cargo.toml`, `go.mod`, or equivalent.

**OFF-STANDARD:**
```
# LLM recommends version, user installs immediately
npm install convex@1.9.0

# Three months of implementation later: Convex is on 2.x, breaking changes landed
```

**ON-STANDARD:**
```bash
# Before any implementation work:
audit-deps
# → Shows: convex current=2.3.1, installed=1.9.0 (OUTDATED)
# Resolve before proceeding
```

### Rule 2 — Verify before adding new deps (`MUST`)

Before adding any new dependency, look up its current version. Never use a version from LLM output without verification.

```bash
# npm
npm view <package> version         # exact latest
npm view <package> versions --json # all versions

# pip
pip index versions <package>

# cargo
cargo search <package> --limit 1
```

**OFF-STANDARD:**
```
# LLM says: "Install zod@3.21.0"
npm install zod@3.21.0
# Actual current: 3.24.x — minor patches missed
```

**ON-STANDARD:**
```bash
npm view zod version  # → 3.24.1
npm install zod@3.24.1
```

### Rule 3 — Never hardcode LLM-stated versions in specs or task files (`MUST NOT`)

When writing specs or task breakdowns that reference package versions, either:
- Omit the version and note "use current stable", or
- Verify and record the actual current version at time of writing

**OFF-STANDARD:**
```markdown
## Task: Install dependencies
- Run: npm install next@14.1.0 react@18.2.0
```

**ON-STANDARD:**
```markdown
## Task: Install dependencies
- Run audit-deps first to confirm current versions
- Install current stable: `npm install next react` (verify versions before pinning)
```

### Rule 4 — Autoresearch for unfamiliar or fast-moving deps (`SHOULD`)

For any dependency the LLM has not seen recently in context, or that moves quickly (AI SDKs, database clients, auth libraries), run `devos-autoresearch` before selecting a version. This prevents installation of a version that is already deprecated or superseded.

Fast-moving categories requiring autoresearch:
- AI/LLM SDKs (Anthropic, OpenAI, Vercel AI SDK — release cycles: weekly)
- Authentication libraries (Clerk, Auth.js — active breaking changes)
- Database clients (Drizzle, Prisma, Convex — schema-level changes)
- Frontend frameworks (Next.js, SvelteKit — major versions regularly)

### Rule 5 — Knowledge pull covers API; this covers version (`MUST` respect boundary)

Do not conflate `knowledge-pull.md` (what the API looks like) with this standard (which version to install). Both must run. A knowledge pull that returns accurate API documentation for version 18.x does not tell you that version 19.x is the current install target.

Correct execution order:
1. Check registry for current version → install correct version
2. Run knowledge pull for that version's API → write accurate code

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Accepting LLM version number without registry check | LLM training data is stale; version may be 1–3 major versions behind | `npm view <pkg> version` before install |
| Running audit-deps only when problems appear | Version drift silently accumulates; broken builds are harder to remediate than prevention | Run audit-deps before implementation starts |
| Using `@latest` tag in lockfiles or manifests | `@latest` resolves differently across environments and CI; not repeatable | Verify current version, pin exact in lockfile |
| Treating knowledge-pull as version verification | API docs and version number are different signals from different sources | Both checks are required; neither substitutes for the other |
| Autoresearching only once per project | Fast-moving deps (AI SDKs, framework core) change between sessions | Re-verify before any new major implementation phase |

## Deviation guidance

MAY skip version verification for internal packages or monorepo packages where the version is controlled by the same repo. MUST still run audit-deps for all external dependencies in the manifest.

MAY pin to a non-latest version when a specific version is required by another dependency constraint or known incompatibility. MUST document the reason as a comment in the manifest or in the spec.

## Compliance test

- [ ] Has `audit-deps` been run before any implementation work began in this project?
- [ ] Has every new dependency been verified against its registry before installation?
- [ ] Does no spec or task file contain LLM-stated version numbers that were not registry-verified?
- [ ] For fast-moving dependencies (AI SDKs, auth, database clients), has devos-autoresearch been run in this session?
- [ ] Is the knowledge-pull step (API documentation) run separately from and after version selection?

If any check fails: run `audit-deps`, verify versions against the registry, and update any spec or task file that references unverified version numbers before proceeding.

## Relationship to Other Standards

| Standard | Relationship |
|---|---|
| `knowledge-pull.md` | Covers API documentation after the correct version is selected. Complement — run after this standard. |
| `security.md` | Covers vulnerability scanning of installed dependencies. Complement — run after this standard confirms freshness. |
| `runtime-standards.md` | Defines canonical runtime versions for the project stack. Input to version selection. |
| `package-manager.md` | Defines which package manager to use. Governs the tool; this standard governs the version selection behavior. |

## References

- [Semantic Versioning 2.0.0](https://semver.org/) — version numbering semantics; why major.minor.patch distinctions matter for upgrade safety
- [npm registry documentation](https://docs.npmjs.com/cli/v10/commands/npm-view) — `npm view` for live version lookup
- [OWASP Software Component Verification Standard (SCVS)](https://owasp.org/www-project-software-component-verification-standard/) — dependency freshness and integrity as a security baseline
- [Renovate documentation](https://docs.renovatebot.com/) — automated dependency update tooling; the continuous version of this standard's one-time verification rule
