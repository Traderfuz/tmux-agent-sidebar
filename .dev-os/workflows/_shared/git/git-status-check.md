# Shared Git Status Check

Run before merge:

```bash
current_branch="$(git branch --show-current)"
git_status="$(git status --porcelain)"
```

Validation:

1. Must be on a `feature/*` branch.
2. Working tree must be clean.
3. If dirty or wrong branch, stop and request user confirmation before continuing.
