# Restore Session Workflow

Restores the implementation state from a saved checkpoint.

## When to Use

This workflow is invoked:
1. By `resume` command after finding a session
2. Automatically by `implement-tasks` if existing session detected


Do not use to start a brand new session — this workflow restores an interrupted one. Do not use when no checkpoint exists for the target spec.
## Process

### Step 1: Verify Session File

```bash
session_file="${SESSION_FILE}"  # Passed from find-session

if [ ! -f "$session_file" ]; then
    echo "❌ Session file not found: ${session_file}"
    return 1
fi

# Verify YAML is valid
if ! grep -q "^spec:" "$session_file"; then
    echo "❌ Corrupted session file: ${session_file}"
    echo ""
    echo "Check checkpoint history: product/specs/[spec]checkpoints.yml"
    return 1
fi
```

### Step 2: Read Session State

```bash
spec=$(grep "^spec:" "$session_file" | sed 's/spec: //')
branch=$(grep "^branch:" "$session_file" | sed 's/branch: //')
current_task=$(grep "^current_task:" "$session_file" | sed 's/current_task: //')
current_subtask=$(grep "^current_subtask:" "$session_file" | sed 's/current_subtask: //')
last_action=$(grep "^last_action:" "$session_file" | sed 's/last_action: //')
next_action=$(grep "^next_action:" "$session_file" | sed 's/next_action: //')
has_uncommitted=$(grep "^has_uncommitted_changes:" "$session_file" | sed 's/has_uncommitted_changes: //')
```

### Step 3: Check Git State

```bash
# Check if feature branch exists
if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
    echo "⚠️  Feature branch '${branch}' no longer exists."
    echo ""
    if [[ "${DEVOS_INTERACTIVE:-}" == "true" ]] || [[ "${1:-}" == "--interactive" ]]; then
        echo "Options:"
        echo "  1. Recreate branch from main (last checkpoint: $(date -d @$(stat -c %Y "$session_file") '+%Y-%m-%d %H:%M'))"
        echo "  2. Cancel and handle manually"
        echo ""
        read -p "Recreate branch? (y/n): " recreate
        if [[ "$recreate" == "y" ]]; then
            git checkout main
            git checkout -b "$branch"
        else
            return 1
        fi
    else
        echo "Branch not found. Re-run with --interactive flag to recreate it, or create it manually."
        return 1
    fi
fi

# Check current branch
current_git_branch=$(git branch --show-current)
if [ "$current_git_branch" != "$branch" ]; then
    echo "🔄 Switching to branch: ${branch}"
    git checkout "$branch"
fi
```

### Step 4: Handle Uncommitted Changes

```bash
if [ "$has_uncommitted" = "true" ]; then
    git_status=$(git status --porcelain)

    if [ -n "$git_status" ]; then
        echo "⚠️  Session has uncommitted changes."
        echo ""
        echo "Modified files:"
        echo "$git_status"
        echo ""
        echo "Options:"
        echo "  1. Continue with uncommitted changes"
        echo "  2. Stash changes and restore from last commit"
        echo "  3. Cancel"
        echo ""
        read -p "Choose option (1-3): " uncommitted_choice

        case "$uncommitted_choice" in
            2)
                git stash push -m "checkpoint-stash-$(date +%s)"
                echo "✅ Changes stashed. Use 'git stash pop' to restore."
                ;;
            3)
                return 0
                ;;
        esac
    fi
fi
```

### Step 5: Display Restoration Summary

```
🔄 Restoring Session

Spec: ${spec}
Branch: ${branch}

Resuming from:
  Task: ${current_task}
  Sub-task: ${current_subtask}

Last completed: ${last_action}
Next up: ${next_action}
```

### Step 6: Load Task Context

```bash
spec_dir="product/specs/${spec}"
tasks_file="${spec_dir}/tasks.md"

# Verify tasks.md exists
if [ ! -f "$tasks_file" ]; then
    echo "⚠️  tasks.md not found at ${tasks_file}"
    echo "Cannot verify task status."
    return 1
fi

# Find the current task in tasks.md
echo ""
echo "Current status from tasks.md:"
grep -A 3 "${current_task}" "$tasks_file" || echo "Task not found in tasks.md"
```

### Step 7: Confirm Restoration

```bash
echo ""
echo "Ready to continue implementation."
echo ""
if [[ "${DEVOS_INTERACTIVE:-}" == "true" ]] || [[ "${1:-}" == "--interactive" ]]; then
    read -p "Type 'yes' to confirm and continue: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Restoration cancelled. Session remains active."
        return 0
    fi
else
    echo "Session restored (non-interactive). Continuing with: ${next_action}"
fi
```

### Step 8: Output Restoration Context

For the implementation workflow to continue:

```bash
# Export for use by calling workflow
export RESUME_SPEC="${spec}"
export RESUME_BRANCH="${branch}"
export RESUME_TASK="${current_task}"
export RESUME_SUBTASK="${current_subtask}"
export RESUME_NEXT_ACTION="${next_action}"

echo ""
echo "✅ Session restored. Continuing with: ${next_action}"
```

## Integration with `resume` Command

```markdown
{{workflows/implementation/find-session}}

[Display session summary]
[Get user confirmation]

{{workflows/implementation/restore-session}}

[Continue implementation from restored state]
{{workflows/implementation/implement-tasks}}
```

## Error Recovery

| Error | Recovery |
|-------|----------|
| Branch deleted | Offer to recreate from main |
| tasks.md deleted | Show checkpoint history, offer manual recovery |
| Uncommitted conflicts | Offer stash or manual resolution |
| Corrupted session file | Check checkpoints.yml for fallback |

## Configuration

```yaml
# Auto-checkout to feature branch
auto_checkout_on_resume: true

# Stash uncommitted changes by default
auto_stash_on_resume: false
```

## Notes

- Restoration preserves all checkpoint history
- Session file remains active after restoration
- New checkpoints are appended to existing history
- Manual intervention may be required for complex conflicts

## Display

Session restore confirmation:

```
Session restored:
  Spec:     [spec-name]
  Branch:   feature/[spec-name]
  Resumed:  Task [N.N] — [description]
  Checkpoint: [timestamp]
```
