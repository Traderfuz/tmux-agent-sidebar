# MVP Iteration Workflow

Handles the continuation of development after an MVP has been merged to main.

## When to Use

This workflow is invoked when `implement-tasks --continue` is run after an MVP has been merged.


Do not use when implementing all tasks at once (non-MVP mode). Do not use when no P1 tasks remain — switch to `merge-feature` instead.
## Context

After MVP merge:
- Feature branch remains active (not deleted)
- P1 tasks are complete and merged
- P2 and P3 tasks remain in tasks.md
- Branch is ready for continued development

## Process

### Step 1: Verify Branch State

Check that we're on the correct branch with pending tasks:

```bash
# Get current branch
current_branch=$(git branch --show-current)

# Expected: feature/[spec-name] (still active after MVP merge)

# Verify P2/P3 tasks exist
remaining_tasks=$(grep -c "(P2)" product/specs/[spec-name]/tasks.md || echo 0)
remaining_tasks=$((remaining_tasks + $(grep -c "(P3)" product/specs/[spec-name]/tasks.md || echo 0)))
```

**If not on feature branch:**
```
⚠️ You're not on a feature branch.

Current branch: [current-branch]

Expected: feature/[spec-name]

Please checkout the feature branch first:
git checkout feature/[spec-name]
```

**If no P2/P3 tasks remain:**
```
✅ All tasks are already complete!

No remaining P2/P3 tasks to implement.

Ready for final merge? Run `merge-feature` to complete the feature.
```

### Step 2: Determine Iteration Scope

Decide which tasks to implement this iteration:

**Option A:** All remaining tasks (P2 + P3 together)
**Option B:** Only P2 tasks
**Option C:** Specific task groups

```
🔄 Continuing Development After MVP

Branch: feature/[spec-name]
MVP Status: ✅ Shipped to main
Remaining Tasks: [X] P2 tasks, [X] P3 tasks

What would you like to implement?

1. All remaining tasks (P2 + P3)
2. Only P2 tasks (important but not MVP)
3. Specific task groups (you choose)
4. Just P2, then P3 in separate iterations

Enter your choice (1-4):
```

### Step 3: Implement Selected Tasks

Based on user choice, filter tasks and implement:

**If Option 1 (All remaining):**
- Implement all P2 and P3 tasks
- Treat as normal implementation (no MVP filtering)

**If Option 2 (Only P2):**
- Filter tasks.md for (P2) only
- Implement P2 tasks with auto-commits
- After completion, prompt about P3

**If Option 3 (Specific groups):**
- User specifies which task groups
- Implement only those groups
- Mark completed tasks

**If Option 4 (P2 then P3):**
- Implement P2 tasks first
- After P2 complete, prompt: "Merge P2 to main or continue with P3?"
- If merge: perform partial merge, then resume for P3

### Step 4: Auto-Commit Implementation

For each task/group implemented:

```bash
git add .
git commit -m "feat([spec-name]): implement [task/group name]

- [change description]
- [change description]"
```

### Step 5: Update Tasks Checklist

Mark completed tasks as done:

```markdown
- [x] 2.1 [task name] (P2)
- [x] 2.2 [task name] (P2)
- [ ] 2.3 [task name] (P2)
```

### Step 6: Post-Iteration Prompt

After selected tasks are complete:

```
✅ Iteration Complete!

Implemented: [X] tasks
Remaining: [X] tasks

What's next?

1. Merge to main → Ship this iteration
2. Continue implementing → Add more tasks
3. Stop here → Keep branch active, continue later

Enter your choice (1-3):
```

### Step 7: Handle Merge Decision

**If user chooses "Merge to main":**
- Run `merge-feature` workflow
- Keep feature branch active (don't delete)
- Update backlog status: "Partial iteration shipped"
- Return to Step 2 for next iteration

**If user chooses "Continue implementing":**
- Return to Step 2 to select more tasks
- Resume on same branch

**If user chooses "Stop here":**
- Confirm branch is left active
- Remind user about uncommitted changes (if any)
- Summary of what's been accomplished

---

## Branch State Tracking

The feature branch maintains state through MVP iterations:

```
feature/[spec-name] (active)
├── MVP commit (merged to main)
├── P2 iteration commit (merged to main)
├── P3 iteration commit (not yet merged)
└── Final merge (when all complete)
```

## Final Merge

When all P2 and P3 tasks are complete:

```
✅ All Tasks Complete!

All P1, P2, and P3 tasks are implemented.

Ready for final merge? Run `merge-feature` to complete the feature.

This will:
- Merge final changes to main
- Update backlog to "Completed"
- Delete feature branch
```

---

## Configuration

```yaml
mvp_require_merge: true         # Require MVP merge before continuing
mvp_auto_continue: false        # Automatically continue to P2 after MVP
```

## Edge Cases

| Case | Handling |
|------|----------|
| Branch was deleted after MVP | Recreate branch from main's MVP state |
| New tasks added post-MVP | Include in iteration options |
| Tasks were re-prioritized | Respect new priorities, not original labels |
| Conflicts during iteration | Resolve before continuing |
| User wants to skip iteration | Allow, leave branch as-is |

## Notes

- Feature branch stays active throughout all iterations
- Each iteration can be independently merged to main
- Final merge cleans up the branch
- Backlog updates with each merge

## Display

MVP iteration status:

```
MVP iteration [N] complete
  P1 merged:  [spec-name] v[N]
  P2 backlog: [N] tasks remaining
  Branch:     main (P1 shipped)
```
