# Checkpoint Workflow

Saves the current implementation state to enable resumption after interruption.

## When to Use

This workflow is invoked:
1. After each sub-task completion during `implement-tasks`
2. Before each auto-commit
3. After each task group completion
4. On manual request via `checkpoint` command
5. On interruption detection (SIGINT/SIGTERM)


Do not invoke manually mid-task unless interrupted — checkpoints are designed to be automatic. Do not use on non-feature branches (main, hotfix); the workflow will exit early.
## Process

### Step 1: Determine Current Context

```bash
# Get current branch
current_branch=$(git branch --show-current)

# Get current spec name from branch or context
spec_name=$(echo "$current_branch" | sed 's/^feature\///')

# Check if this is a feature branch
if [[ "$current_branch" != feature/* ]]; then
    echo "Not on a feature branch. Checkpoints only saved during implementation."
    exit 0
fi
```

{{include workflows/_shared/status-checking/git-state-validation}}

### Step 2: Gather Session State

```bash
# Get current timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get git info
last_commit=$(git log -1 --format="%H %s" | head -1)
has_uncommitted=$(git status --porcelain | wc -l)

# Get current task status from tasks.md
spec_dir="product/specs/${spec_name}"
tasks_file="${spec_dir}/tasks.md"

# Count total and completed tasks
total_tasks=$(grep -c "^\- \[[ x]\]" "$tasks_file" 2>/dev/null || echo 0)
completed_tasks=$(grep -c "^\- \[x\]" "$tasks_file" 2>/dev/null || echo 0)

# Calculate progress percentage
if [ "$total_tasks" -gt 0 ]; then
    progress_percent=$((completed_tasks * 100 / total_tasks))
else
    progress_percent=0
fi

# Get modified files
modified_files=$(git diff --name-only HEAD 2>/dev/null | tr '\n' '\n' | sed 's/^/  - /')
```

{{include workflows/_shared/status-checking/progress-calculation}}

### Step 3: Detect Current Position

Read `tasks.md` to determine current position:

```bash
# Find the current task group and task being worked on
# Look for the most recent completed task or the next incomplete task

current_task_group=$(grep -A 5 "^#### Task Group" "$tasks_file" | grep -B 5 "\[ \]" | head -1)
current_task=$(grep "^\- \[ \]" "$tasks_file" | head -1 | sed 's/^- \[ \] //')
```

### Step 4: Update session-state.yml

Create or update `product/specs/[spec]/session-state.yml`:

```yaml
spec: [spec-name]
branch: feature/[spec-name]
started_at: [timestamp from first checkpoint or session start]
last_update: [current timestamp]

# Current position
current_task_group: [detected task group name]
current_task: [detected parent task]
current_subtask: [detected sub-task or "starting"]

# Progress
total_tasks: [count]
completed_tasks: [count]
progress_percent: [percentage]

# Files being modified
modified_files:
  [list of modified files or empty]

# Context for resumption
last_action: [description of last completed action]
next_action: [description of what to do next]

# Uncommitted changes
has_uncommitted_changes: [true/false]
last_commit: [commit hash and message]
```

### Step 5: Update checkpoints.yml

Append or update `product/specs/[spec]checkpoints.yml`:

```yaml
checkpoints:
  - id: cp-[incremental-id]
    timestamp: [current timestamp]
    task_group: [current task group]
    task: [current task]
    subtask: [current sub-task]
    status: [completed | in_progress | failed]
    commit: [commit hash if any, or null]
```

**Checkpoint rotation:** Keep only the last N checkpoints (configurable via `checkpoint_max_history`).

### Step 6: Generate PROGRESS.md

Create or update `product/specs/[spec]/PROGRESS.md`:

```markdown
# Progress: [spec-name]

**Started:** [start date]
**Status:** In Progress ([X]% complete)
**Branch:** feature/[spec-name]

## Overview

| Metric | Value |
|--------|-------|
| Total Tasks | [count] |
| Completed | [count] |
| Remaining | [count] |
| Progress | [X]% |

## Task Group Progress

[List all task groups with their status and progress]

### ✅ [Completed Group Name] (100%)
- [x] all completed tasks

### 🔄 [In Progress Group Name] (X%)
- [x] completed tasks
- [IN_PROGRESS] current task **<-- CURRENT**
- [ ] pending tasks

### ⏳ [Not Started Group Name] (0%)
- [ ] all pending tasks

## Recent Activity

[Bulleted list of recent checkpoints with timestamps]

## Next Steps

1. [Current next action]
2. [Following actions]

---

_Last updated: [timestamp] UTC_
```

### Step 7: Commit State Files

Unless `--no-commit` was passed, commit the checkpoint state files to Git:

```bash
git add "${spec_dir}/session-state.yml"
git add "${spec_dir}checkpoints.yml"
git add "${spec_dir}/PROGRESS.md"
git commit -m "chore([spec]): checkpoint at [current task]

- Progress: [X]% ([completed]/[total])
- Position: [current task description]"
```

{{include workflows/_shared/git/commit-message-format}}

This commit happens by default so that checkpoint progress is tracked in Git history. Users can skip it with `--no-commit` if they prefer to commit manually.

**Note:** Checkpoint commits are separate from feature implementation commits and can be squashed during merge if desired.

### Step 7b: Write runtime session anchor

After the Step 7 git commit succeeds, write the new commit SHA to the runtime session-state file so `sync-detector.sh` can detect manual work since this checkpoint.

**Skip Step 7b if:**
- `--no-commit` was passed (no new commit exists to record)
- The git commit in Step 7 failed (no new SHA to record)

```bash
if [ "${NO_COMMIT:-false}" != "true" ]; then
    runtime_dir=".dev-os/runtime"
    runtime_state="${runtime_dir}/session-state.yml"
    checkpoint_sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    # Guard: skip if SHA could not be resolved
    if [ "$checkpoint_sha" != "unknown" ]; then
        ts=$(date -u +%s)
        command mkdir -p "$runtime_dir"

        if [ ! -f "$runtime_state" ]; then
            # Create path: write fresh file
            printf "checkpoint_sha: %s\nlast_update: %s\n" "$checkpoint_sha" "$ts" > "$runtime_state"
        else
            # Update path: single awk pass, then atomic mv (not sed -i — macOS incompatible)
            tmp=$(mktemp "${runtime_dir}/session-state.XXXXXX")
            awk -v sha="$checkpoint_sha" -v ts="$ts" \
                'BEGIN { saw_sha=0; saw_ts=0 }
                 /^checkpoint_sha:/ { print "checkpoint_sha: " sha; saw_sha=1; next }
                 /^last_update:/    { print "last_update: " ts;    saw_ts=1;  next }
                 { print }
                 END {
                     if (!saw_sha) print "checkpoint_sha: " sha
                     if (!saw_ts)  print "last_update: " ts
                 }' "$runtime_state" > "$tmp"
            command mv "$tmp" "$runtime_state"
        fi
    fi
fi
```

**Note:** Step 7b is skipped if the git commit in Step 7 fails — no anchor is written unless a new commit SHA exists.

## Configuration

Checkpoints respect these config options:

```yaml
# Checkpoint Settings
checkpoint_enabled: true
checkpoint_frequency: auto  # auto, after_subtask, after_taskgroup
checkpoint_max_history: 50  # Max checkpoints to keep
```

## Integration Points

### In implement-tasks Workflow

Call after each sub-task completion:

```markdown
{{workflows/implementation/checkpoint}}
```

### In auto-commit Workflow

Call before committing code changes:

```markdown
{{workflows/implementation/checkpoint}}
```

### Manual Checkpoint

User can run `checkpoint` to force a checkpoint at any time.

## Error Handling

{{include workflows/_shared/error-handling/error-handling-table}}

| Error | Handling |
|-------|----------|
| `tasks.md` not found | Warning: "No tasks file found. Cannot create checkpoint." |
| Cannot write state file | Error with file path, suggest checking permissions |
| Invalid git state | Warning: "Not in a valid git state. Checkpoint skipped." |
| Corrupted existing state file | Backup existing file, create new one |

## Notes

- Checkpoints are lightweight text files (YAML/Markdown)
- State files are tracked in git for full history
- Old checkpoints are rotated automatically
- PROGRESS.md is human-readable for quick overview
- Session state enables precise resumption after interruption

## Display

Checkpoint confirmation:

```
Checkpoint saved
  Spec:   [spec-name]
  Branch: feature/[spec-name]
  Task:   [current-task]
  SHA:    [git-sha]
  File:   .dev-os/runtime/session-state.yml
```
