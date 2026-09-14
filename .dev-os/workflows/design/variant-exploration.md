# Variant Exploration

Use git worktrees to explore multiple design directions in parallel without branch switching. Each variant gets its own working directory, so changes don't interfere. After exploration, use the `variant-comparison` workflow to evaluate and select a winner.

## When to Use

- Comparing visual approaches (e.g. light vs dark, card layout vs list layout)
- Exploring architecture alternatives before committing to one
- A/B testing different implementations of the same feature

**Do NOT use when:** The design direction is already decided — this workflow is for exploring options, not implementing a chosen approach. Do not use for non-UI changes. Do not use when only one variant is needed (just build it directly with `new-project-ui` or `ui-from-spec`).

## Naming Convention

- **Feature worktrees:** `wt/<name>` — general parallel work
- **Variant worktrees:** `variant/<name>` — design exploration and comparison

## Process

### Step 1: Create Variant Worktrees

From your feature branch, create a worktree for each variant:

```bash
# Creates ../variant-approach-a with branch variant/approach-a
git_worktree_create "approach-a" "variant"

# Creates ../variant-approach-b with branch variant/approach-b
git_worktree_create "approach-b" "variant"
```

Each variant starts from the same base point and diverges independently.

**Launch parallel tmux session? (optional)**

After worktrees are created, `worktree-sessions` can open each variant in a named pane with port assignments and optional Claude Code launch — one command, all panes ready:

```
-> Say: "set up tmux for my worktrees"
   (invokes the worktree-sessions skill)
```

### Step 2: Develop Each Variant

Work on each variant in its own directory. Each worktree has its own working tree and index, so changes don't interfere:

```
../variant-approach-a/   ← develop variant A here
../variant-approach-b/   ← develop variant B here
./                       ← original feature branch (untouched)
```

Commit progress in each variant independently.

### Step 3: Compare Variants

Use the `variant-comparison` workflow for a structured side-by-side evaluation [G-015]:

```
→ Run: workflows/design/variant-comparison.md
   or say "compare my design variants"
```

The `variant-comparison` workflow handles screenshot capture at both viewports, evaluates each variant against design principles, produces a `variant-comparison.md` document, and writes a `variant-decision.md` record after selection. It is the canonical comparison path — use it rather than performing an ad-hoc comparison here.

**Quick comparison (if variant-comparison is unavailable):**

- **Code diff:** `git diff variant/approach-a..variant/approach-b`
- **Visual comparison:** Use screenshot-based review if design-iteration is available
- **Metrics:** Compare bundle size, test coverage, or performance between variants

### Step 4: Select Winning Variant

Once a variant is chosen:

1. Switch to your feature branch (the original working directory)
2. Merge the winning variant:
   ```bash
   git merge variant/approach-a
   ```
3. Resolve any conflicts with the base feature branch

### Step 5: Clean Up Remaining Variants

Remove the variant worktrees that were not selected:

```bash
# Remove losing variant worktrees
git_worktree_remove "../variant-approach-b"

# Prune any orphaned worktree metadata
git worktree prune
```

The winning variant's branch can also be cleaned up after merge:
```bash
git branch -d variant/approach-a
```

## Notes

- Each worktree uses the global `~/.dev-os/` framework — no per-worktree DEVOS_DIR needed
- Variant comparison screenshots require `/design-iteration` (see design-iteration-workflow-integration spec)
- Worktree paths are absolute — no relative `../` traversal in stored paths
- Dependency install runs automatically on worktree creation (non-blocking on failure)

## Display

Exploration summary:

```
Variant exploration complete
Worktrees created: [N] — [names]
Screenshots: product/specs/[spec]/planning/variants/
Next: ui-design-compare to pick a winner
```
