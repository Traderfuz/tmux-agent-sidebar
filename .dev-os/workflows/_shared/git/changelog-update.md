# Shared Changelog Finalization Snippet

After merge verification is complete:

1. Choose semantic bump type (`major`, `minor`, `patch`).
2. Run:

```bash
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/git/git-release.sh"
git_release_run --bump <type>
```

3. Confirm:

```bash
git diff -- CHANGELOG.md VERSION
```

4. Commit metadata update:

```bash
git add CHANGELOG.md VERSION
git commit -m "chore(release): finalize changelog for vX.Y.Z"
```
