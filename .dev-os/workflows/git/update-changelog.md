# Update Changelog and Version

Finalize release notes during feature merge by converting `[Unreleased]` entries into a dated semantic version release.

## When to Use

Run this workflow when a feature branch is ready to merge and the changelog needs to reflect the completed work — typically as part of the feature-delivery pipeline.

Do not run this workflow on every commit or mid-implementation. Use it only when a releasable unit is complete and the merge is imminent.

## Inputs

1. `bump_type`: `major` | `minor` | `patch` (default: `patch`)
2. `create_tag`: `true` | `false` (default: `true`)

## Preconditions

1. `CHANGELOG.md` exists at repository root.
2. `## [Unreleased]` section exists.
3. `CHANGELOG.md` already contains generated implementation notes for this merge.

## Version Source of Truth

1. Repository `VERSION` file, if present.
2. Otherwise latest semver heading in `CHANGELOG.md`.

## Process

### 1. Select bump type

Use change impact:

1. `major` for breaking changes.
2. `minor` for backwards-compatible feature additions.
3. `patch` for fixes/docs/internal maintenance.

### 2. Finalize release notes and bump version

Run:

```bash
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/git/git-release.sh"
git_release_run --bump <major|minor|patch> [--no-tag]
```

This command:

1. Moves `[Unreleased]` content into a new dated version section.
2. Resets `[Unreleased]` placeholders.
3. Writes/updates root `VERSION`.
4. Optionally creates annotated git tag `vX.Y.Z`.

### 3. Validate

```bash
git diff -- CHANGELOG.md VERSION
git tag --list "v*"
```

Confirm:

1. New section format is Keep-a-Changelog compliant.
2. `VERSION` matches new release heading.
3. Tag exists when tagging enabled.

### 4. Commit release metadata

```bash
git add CHANGELOG.md VERSION
git commit -m "chore(release): finalize changelog and bump version to vX.Y.Z"
```

## Output

1. Updated `CHANGELOG.md` with a new release section.
2. Updated root `VERSION`.
3. Optional annotated git tag `vX.Y.Z`.
