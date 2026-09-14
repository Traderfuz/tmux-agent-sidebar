# Variant Comparison

Compare design variants side by side using screenshots and design principles. Evaluates each variant against the project's design criteria, produces a ranked comparison, and records the selection decision. Use after `variant-exploration` has created and developed the variants.

**Dependency:** Requires worktree utility functions from `git-worktrees-workflow-integration` for creating and managing variant worktrees.

**Prerequisite:** [variant-exploration](variant-exploration.md) — use to create variant worktrees before comparing.

## When to Use

- After developing two or more design variants in separate worktrees
- When the user needs to choose between visual approaches
- During design review with stakeholders

**Do NOT use when:** Comparing implementations that differ only in non-visual ways (logic, data). Do not use when only one variant exists — this workflow requires at least two variants to compare.

## Process

### Step 1: Enumerate Variant Worktrees

Identify all active variant worktrees:

```bash
# List worktrees with variant/ prefix branches
git worktree list --porcelain | grep -A1 "branch refs/heads/variant/"
```

Display to user:
```
Active design variants:
  variant/approach-a — ../variant-approach-a (3 commits)
  variant/approach-b — ../variant-approach-b (2 commits)
```

### Step 2: Capture Screenshots Per Variant

For each variant worktree:

1. Start the dev server in the variant's working directory
2. Capture screenshots at:
   - Desktop viewport (1920x1080)
   - Mobile viewport (375x812)
3. Save to: `product/specs/<spec>/planning/variants/<variant-name>/`
   - `desktop.png`
   - `mobile.png`
4. Stop the dev server

### Step 3: Evaluate Against Design Principles

For each variant, check compliance with `.claude/context/design-principles.md`:

- Typography hierarchy
- Spacing consistency
- Color palette adherence
- Contrast ratios (WCAG AA)
- Component state completeness
- Alignment and layout

### Step 4: Produce Comparison Document

Create `product/specs/<spec>/planning/variant-comparison.md`:

```markdown
# Variant Comparison: <spec-name>

## Variants

### variant/approach-a
- **Screenshots:** [desktop](variants/approach-a/desktop.png) | [mobile](variants/approach-a/mobile.png)
- **Design compliance:** 6/6 principles met
- **Strengths:** [list]
- **Weaknesses:** [list]

### variant/approach-b
- **Screenshots:** [desktop](variants/approach-b/desktop.png) | [mobile](variants/approach-b/mobile.png)
- **Design compliance:** 5/6 principles met
- **Strengths:** [list]
- **Weaknesses:** [list]

## Trade-offs

| Dimension | approach-a | approach-b |
|-----------|-----------|-----------|
| Visual complexity | ... | ... |
| Accessibility | ... | ... |
| Implementation effort | ... | ... |

## Recommendation

[Based on design principles and trade-offs, recommend variant X]
```

### Step 5: Present to User for Decision

Display comparison summary and ask:
> Which variant should we merge?
> 1. variant/approach-a
> 2. variant/approach-b
> 3. Need more iteration — continue exploring

### 5a. Post-selection visual review

After the user chooses a winner, run `ui-review` on the selected variant or its implementation scaffold before merge/cleanup. If an approved design artifact exists, follow with `ui-review --scope full` or `ui-design-qa` as appropriate for the implementation stage.

### 5b. Write decision record [G-006]

After the user selects a winner, write `product/specs/<spec>/planning/variant-decision.md`:

```markdown
# Variant Decision: <spec-name>

**Date:** YYYY-MM-DD
**Selected:** variant/<winning-variant>
**Rejected:** variant/<losing-variant(s)>

## Rationale

[Why this variant was selected over the alternatives — from the comparison and user decision]

## Design Principles Compliance

| Variant | Score | Key strength |
|---------|-------|-------------|
| <winner> | N/6 | [main reason for selection] |
| <loser> | N/6 | [main reason for rejection] |

## Trade-offs Accepted

[What was given up by not choosing the other variant]

## Reviewer

<name or "user" if decision was made interactively>
```

This record persists in the spec's planning directory and ensures future contributors can understand the design direction without re-examining the worktree branches (which are deleted after merge).

### Step 6: Merge and Clean Up

After selection:

1. Merge the winning variant into the feature branch:
   ```bash
   git merge variant/<selected>
   ```
2. Remove remaining variant worktrees:
   ```bash
   git_worktree_remove "../variant-<losing>"
   ```
3. Run `git worktree prune` to clean up metadata

## Notes

- Dev server port detection: check 3000, 3001, 5173, 8080
- If screenshots cannot be captured (no dev server), produce a code-diff-only comparison
- The comparison document persists in the spec's planning directory for reference

## Display

Comparison report location:

```
Variant comparison complete
Report: product/specs/[spec]/planning/variant-comparison.md
Variants compared: [N]
Recommendation: [variant-name]
```
