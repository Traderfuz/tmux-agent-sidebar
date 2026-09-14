# Guided Git: Ensure Feature Branch

Before implementing changes, ensure you're working on a feature branch (not `main`).

## Process

1. Check the current branch:
   ```bash
   current_branch=$(git branch --show-current)
   ```

2. **If on `main` or `master`**, create a feature branch:
   - Verify the working tree is clean:
     ```bash
     git status --porcelain
     ```
   - If there are uncommitted changes, ask the user to commit or stash them first.
   - Create and switch to a feature branch:
     ```bash
     git checkout -b feature/[spec-name]
     ```
   - Confirm to the user:
     ```
     Created feature branch: feature/[spec-name]

     A feature branch keeps your changes separate from main until they're
     ready. You'll work here, commit as you go, and merge back when done.
     ```

3. **If already on a `feature/*` or `quick-fix/*` branch**, continue without changes.

4. **If on an unrelated branch**, ask the user what to do before proceeding.

## `--no-git` Flag

If the user passed `--no-git`, skip all Git operations in this section and continue directly to implementation. Display:
```
Skipping Git operations (--no-git flag). You are on branch: [current_branch]
```
