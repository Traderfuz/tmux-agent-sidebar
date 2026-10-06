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
cd "$(git rev-parse --show-toplevel)"   # RELEASE_FILES paths are repo-root relative
_release_out="$(bash -c 'source "$1" && git_release_run "${@:2}"' _ \
    "${DEVOS_DIR:-$HOME/.dev-os}/scripts/git/git-release.sh" --bump <major|minor|patch> [--no-tag] </dev/null)" && printf '%s\n' "$_release_out"
RELEASE_FILES="$(printf '%s\n' "$_release_out" | sed -n 's/^RELEASE_FILES=//p')"
```

This command:

1. Moves `[Unreleased]` content into a new dated version section.
2. Resets `[Unreleased]` placeholders.
3. Writes/updates root `VERSION`.
4. For an installable-OS package (`scripts/bump-version.sh` + `manifest.json` `os_id`), runs
   `scripts/bump-version.sh X.Y.Z release` so `config.yml`, `manifest.json`, the
   `os-registry.yml` self entry, and `.dev-os/config.yml` match `VERSION`, then asserts
   `$OS_REPO/scripts/lib/version-guard.sh axis` (the installable-OS repo's own guard).
5. Prints `RELEASE_FILES=<paths>` — every file it wrote.
6. Optionally creates annotated git tag `vX.Y.Z`.

### 3. Validate

```bash
git diff -- $RELEASE_FILES
git tag --list "v*"
```

Confirm:

1. New section format is Keep-a-Changelog compliant.
2. `VERSION` matches new release heading.
3. Every version axis matches `VERSION` (installable-OS: `bash $OS_REPO/scripts/lib/version-guard.sh axis`).
4. Tag exists when tagging enabled.

### 4. Commit release metadata

Stage exactly `$RELEASE_FILES`; staging only `CHANGELOG.md VERSION` leaves the other version axes behind (#1666).

```bash
git add -- $RELEASE_FILES
# .dev-os/config.yml is a batchable context artifact; commit the mixed set in all-in mode.
DEVOS_CONTEXT_COMMIT_MODE=all git commit -m "chore(release): finalize changelog and bump version to vX.Y.Z" \
  --trailer "Devos-Context-Commit-Mode: all"
```

## Output

1. Updated `CHANGELOG.md` with a new release section.
2. Updated root `VERSION` (and, for installable-OS packages, every other version axis).
3. Optional annotated git tag `vX.Y.Z`.
