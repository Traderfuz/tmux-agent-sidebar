<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/version-alignment.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/version-alignment.md and re-run profile-sync. -->
# Version Alignment Standards

## Overview

Version drift between artifacts in the same project creates invisible breakage: a `VERSION` file says 1.75.0, a skill says 1.0.0, a CHANGELOG says 1.74.0, and no one knows which is canonical. This standard establishes a single source of truth for the project version and defines how every versioned artifact stays aligned with it.

## Scope

This standard covers version alignment across all versioned artifacts within a DevOS-managed project or OS package. It does NOT cover version numbering policy (when to bump major/minor/patch — that is a semver judgment call) or release automation tooling (CI/CD pipelines, GitHub Actions).

## Principles

1. **Single source of truth:** Every project has exactly one canonical version location. All other version declarations derive from it — never the reverse.
2. **Drift is a bug:** A version mismatch between the canonical source and any derivative artifact is treated as a defect, not an inconvenience.
3. **Explicit over implicit:** Every artifact that displays, embeds, or checks a version must reference the canonical source or be updated in the same commit that bumps the canonical source.

## Rules

### Canonical version source

- **OS packages and CLI projects:** The canonical version lives in the `VERSION` file at the repository root (`MUST`)
- **npm/bun packages:** The canonical version lives in `package.json` `"version"` field. A root `VERSION` file, if present, must match (`MUST`)
- **Skills:** Each skill has its own independent version in `SKILL.md` frontmatter `version:` field. Skill versions are NOT aligned to the project version — they follow their own semver lifecycle (`MUST`)
- **OS packages (creative-os, research-os, etc.):** Each OS package has its own `VERSION` file. OS package versions are independent of each other and of dev-os (`MUST`)

```
# OFF-STANDARD — version only in config, no canonical source
# .dev-os/config.yml
version: 1.75.0
# VERSION file: (does not exist)

# ON-STANDARD — VERSION file is canonical, config derives from it
# VERSION
1.75.0
# .dev-os/config.yml
version: 1.75.0   # must match VERSION file
```

### Derivative locations that must match the canonical source

- **`.dev-os/config.yml` `version:` field:** Must match the project's canonical version (`MUST`)
- **`install.sh` version display:** Must read from the `VERSION` file at runtime, never hardcode a version string (`MUST`)
- **CHANGELOG.md latest entry:** The topmost `## vX.Y.Z` heading must match the canonical version after a release commit (`MUST`)
- **Git tags:** When a version tag exists, it must match the canonical version at that commit (`SHOULD`)
- **README badges or version mentions:** Must either read dynamically or be updated in the same commit as the version bump (`SHOULD`)

```
# OFF-STANDARD — hardcoded version in script
echo "DevOS v1.74.0"

# ON-STANDARD — reads from VERSION file
VERSION="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || echo "0.0.0")"
echo "DevOS v${VERSION}"
```

### Version bump commit protocol

- **Atomic version bump:** When bumping the project version, update ALL derivative locations in the same commit (`MUST`)
- **Commit message format:** `chore(release): bump to vX.Y.Z` or `chore(release): vX.Y.Z` (`SHOULD`)
- **No partial bumps:** Never update only the `VERSION` file without updating `config.yml` and CHANGELOG in the same commit (`MUST NOT`)

```
# OFF-STANDARD — partial bump across multiple commits
git commit -m "bump VERSION to 1.76.0"     # commit 1
git commit -m "update config.yml version"    # commit 2 (later, maybe forgotten)

# ON-STANDARD — atomic bump in single commit
# Update VERSION, .dev-os/config.yml, CHANGELOG.md in one commit
git commit -m "chore(release): bump to v1.76.0"
```

### Skill versioning (independent lifecycle)

- **Skills are independently versioned:** A skill at `v2.1.0` in a project at `v1.75.0` is correct — skill versions track skill changes, not project changes (`MUST`)
- **SKILL.md `version:` field is the skill's canonical source:** The CHANGELOG.md in the skill directory must match (`MUST`)
- **Version bump triggers:** Structural-only fix = patch, content change = minor, scope overhaul = major (`SHOULD`)

### OS package versioning (independent lifecycle)

- **Each OS package versions independently:** `creative-os` at v2.23.0 and `dev-os` at v1.75.0 is correct (`MUST`)
- **Each OS package has its own `VERSION` file** at its repository root (`MUST`)
- **Cross-OS version references:** When one OS package references another's version (e.g., `requires: dev-os >= 1.70.0`), use minimum version constraints, not exact pins (`SHOULD`)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Version only in `config.yml`, no `VERSION` file | Scripts and installers can't read YAML cheaply; no universal canonical source | Create `VERSION` file, derive config from it |
| Hardcoded version strings in scripts | Guaranteed drift on next bump | Read from `VERSION` file at runtime |
| Skill versions locked to project version | Skill that hasn't changed gets phantom bumps; skill with breaking changes hides behind project minor | Independent skill versioning |
| Bumping VERSION without updating CHANGELOG | Users see new version but no record of what changed | Atomic commit with both |
| Using git tags as the version source | Tags are mutable, can be deleted, and don't appear in the working tree | `VERSION` file is the source; tags are derived |

## Deviation guidance

You MAY omit the `VERSION` file for projects that are exclusively npm packages where `package.json` is the universal entry point (e.g., published libraries). When you do: document in the project's `CLAUDE.md` that `package.json` is the canonical version source.

You MAY pin exact OS package versions (instead of minimum constraints) when a known breaking change in a specific version must be avoided. When you do: add a comment explaining which version introduced the breakage.

## Named frameworks

### Semantic Versioning 2.0.0 (Tom Preston-Werner)
The MAJOR.MINOR.PATCH format with defined increment rules: MAJOR for incompatible API changes, MINOR for backward-compatible additions, PATCH for backward-compatible fixes. Pre-release and build metadata follow the patch number.
**Reference:** [semver.org](https://semver.org/)
**Applied here:** All version strings in the project follow semver format. This standard does not govern *when* to bump — only that all locations stay aligned *after* a bump.

### Single Source of Truth (SSOT)
A data management principle: every data element is mastered in exactly one place. Other locations derive from it, never originate independently. Applied to versioning: the `VERSION` file (or `package.json`) is the master; all other version appearances are read-only derivatives.
**Applied here:** The canonical version source rule. Prevents the "which version is correct?" question that arises when multiple files independently declare versions.

### Conventional Commits (conventionalcommits.org)
A commit message convention that ties commit messages to versioning: `feat:` triggers minor bump, `fix:` triggers patch, `BREAKING CHANGE:` triggers major. The `chore(release):` prefix signals a version bump commit.
**Applied here:** The version bump commit message format. Not enforcing full Conventional Commits for all commits — only requiring the `chore(release):` pattern for version bump commits so they're identifiable in git log.

## Compliance test

- [ ] Does the project have exactly one canonical version source (`VERSION` file or `package.json`)?
- [ ] Does `.dev-os/config.yml` `version:` match the canonical source?
- [ ] Do all scripts read the version at runtime rather than hardcoding it?
- [ ] Does the latest CHANGELOG entry heading match the canonical version?
- [ ] Are skill versions independent of the project version (no phantom bumps)?
- [ ] Are version bumps atomic — all derivative locations updated in a single commit?

If any check fails: update the drifted location to match the canonical source, or if the canonical source is missing, create a `VERSION` file and align all derivatives to it.

## References

- [Semantic Versioning 2.0.0](https://semver.org/) — version format and increment rules
- [Conventional Commits](https://www.conventionalcommits.org/) — commit message convention tied to versioning
- [The Twelve-Factor App: Codebase](https://12factor.net/codebase) — one codebase, one version, multiple deploys
