# Guided Git: Push and Pull Request

After completing a milestone (task group, full implementation, or quick fix), offer to push and create a PR.

## Process

### 1. Check for Unpushed Commits

```bash
git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null
```

If the remote branch doesn't exist yet, all local commits are unpushed.

### 2. Offer Push

If there are unpushed commits, ask the user:

```
You have [N] unpushed commit(s) on [branch-name].

Push to GitHub? This makes your code visible on the remote repository.
  - yes: Push commits to GitHub
  - no: Keep commits local for now
```

If yes:
```bash
git push -u origin [branch-name]
```

Confirm:
```
Pushed [N] commit(s) to origin/[branch-name].
```

### 3. Offer PR Creation

After pushing, check if `gh` CLI is available:
```bash
command -v gh >/dev/null 2>&1
```

If available and user pushed, ask:
```
Create a Pull Request on GitHub?

A PR creates a record of your changes with a description, diff view, and
a URL you can reference later — even as a solo developer.
  - yes: Create PR (recommended before merging to main)
  - no: Skip PR creation
```

If yes, create the PR:
```bash
gh pr create \
  --title "[type]([scope]): [summary from commits]" \
  --body "## Summary
- [bullet points derived from commit messages]

## Test Plan
- [from spec tasks or manual verification steps]"
```

Display the PR URL to the user.

### 4. If `gh` Not Available

If `gh` CLI is not installed, skip PR creation and inform:
```
Tip: Install the GitHub CLI (gh) to create Pull Requests directly from
the terminal. See: https://cli.github.com
```

## `--no-git` Flag

If the user passed `--no-git`, skip this entire section.
