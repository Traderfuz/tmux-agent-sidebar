# Shared Changelog Finalization Snippet

Finalize `[Unreleased]` into a dated release section and stage every file the release wrote.

## When to Use

Run after merge verification is complete, when a releasable unit is ready to land.
Do not run it mid-implementation or on every commit.

## Steps

1. Choose semantic bump type (`major`, `minor`, `patch`).
2. Run:

```bash
cd "$(git rev-parse --show-toplevel)"   # RELEASE_FILES paths are repo-root relative
_release_out="$(bash -c 'source "$1" && git_release_run "${@:2}"' _ \
    "${DEVOS_DIR:-$HOME/.dev-os}/scripts/git/git-release.sh" --bump <type> </dev/null)" && printf '%s\n' "$_release_out"
RELEASE_FILES="$(printf '%s\n' "$_release_out" | sed -n 's/^RELEASE_FILES=//p')"
```

Installable-OS packages (`scripts/bump-version.sh` + `manifest.json` `os_id`) are routed
through their own `bump-version.sh`, so every version axis moves with `VERSION`.

3. Confirm:

```bash
git diff -- $RELEASE_FILES
```

4. Commit metadata update (stage every file the release wrote):

```bash
git add -- $RELEASE_FILES
# .dev-os/config.yml is a batchable context artifact; commit the mixed set in all-in mode.
DEVOS_CONTEXT_COMMIT_MODE=all git commit -m "chore(release): finalize changelog for vX.Y.Z" \
  --trailer "Devos-Context-Commit-Mode: all"
```

## Output Format

- `RELEASE_FILES=<paths>` line from `git_release_run`, then one `chore(release)` commit containing exactly those paths.
