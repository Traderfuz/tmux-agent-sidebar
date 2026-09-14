# Sync Completed Work Workflow

Recovers manual coding progress by detecting file changes and matching them to tasks in tasks.md.

## When to Use

This workflow is invoked:
1. By `/sync-completed-work` command when user has coded outside the system
2. After user codes manually and wants to sync progress back
3. When resuming work after extended manual coding session


Do not use during active implementation — sync after a block of work is done. Do not use as a substitute for `checkpoint`; sync maps completed tasks, checkpoint saves session state.
## Core Principles

1. **Conservative over comprehensive** - Better to miss a task than falsely mark one complete
2. **User confirmation required** - Never auto-mark tasks without approval
3. **Transparent process** - Show all evidence and reasoning
4. **Reversible** - User can easily undo if wrong tasks were marked

## Process

### Step 1: Determine Current Spec

```bash
# Get current branch
current_branch=$(git branch --show-current)

# Extract spec name from feature branch
if [[ "$current_branch" == feature/* ]]; then
    spec_name=$(echo "$current_branch" | sed 's/^feature\///')
elif [[ "$current_branch" == quick-fix/* ]]; then
    echo "💡 Quick fix branches don't have task tracking."
    echo "   Use project-status instead for branch information."
    return 1
else
    # Look for most recent spec
    spec_name=$(find product/specs -name "tasks.md" -type f -printf '%T@ %p\n' 2>/dev/null | \
                sort -rn | head -1 | sed 's|.*/product/specs/\([^/]*\)/.*|\1|')
fi

if [ -z "$spec_name" ]; then
    echo "❌ No spec found."
    echo ""
    echo "Create a spec first:"
    echo "  write-spec"
    return 1
fi

spec_dir="product/specs/${spec_name}"
tasks_file="${spec_dir}/tasks.md"
checkpoints_file="${spec_dir}checkpoints.yml"

echo "📁 Spec: ${spec_name}"
echo "📂 Branch: ${current_branch}"
```

### Step 2: Get Last Checkpoint Reference

```bash
# Find the last checkpoint commit reference
last_checkpoint_ref=""

if [ -f "$checkpoints_file" ]; then
    # Extract the most recent checkpoint with a commit
    last_checkpoint_ref=$(grep -A 5 "checkpoints:" "$checkpoints_file" | \
                          grep "commit:" | head -1 | sed 's/.*commit: //' | tr -d ' ')

    # If no commit in checkpoints, check first checkpoint timestamp
    if [ -z "$last_checkpoint_ref" ]; then
        first_checkpoint_time=$(grep "timestamp:" "$checkpoints_file" | head -1 | sed 's/.*timestamp: //' | tr -d ' ')
        if [ -n "$first_checkpoint_time" ]; then
            last_checkpoint_ref=$(git log --before="$first_checkpoint_time" --format="%H" -1 2>/dev/null || echo "")
        fi
    fi
fi

# Fallback: use branch merge-base with main or HEAD~10
if [ -z "$last_checkpoint_ref" ]; then
    if git rev-parse --verify main >/dev/null 2>&1; then
        last_checkpoint_ref=$(git merge-base main HEAD 2>/dev/null)
    else
        last_checkpoint_ref="HEAD~10"
    fi
fi

# Verify the ref exists
if ! git rev-parse --verify "$last_checkpoint_ref" >/dev/null 2>&1; then
    echo "⚠️  Checkpoint reference not found, using HEAD~10"
    last_checkpoint_ref="HEAD~10"
fi

echo "📍 Since checkpoint: ${last_checkpoint_ref:0:8}"
echo ""
```

### Step 3: Detect Changed Files

```bash
# Get list of modified/created/deleted files since checkpoint
changed_files=$(git diff --name-status "$last_checkpoint_ref" HEAD 2>/dev/null)

# Count by status
added_count=$(echo "$changed_files" | grep -c "^A" 2>/dev/null || echo 0)
modified_count=$(echo "$changed_files" | grep -c "^M" 2>/dev/null || echo 0)
deleted_count=$(echo "$changed_files" | grep -c "^D" 2>/dev/null || echo 0)
total_changes=$((added_count + modified_count + deleted_count))

if [ $total_changes -eq 0 ]; then
    echo "✅ No new changes detected since last checkpoint."
    echo ""
    echo "Your task tracking is up to date."
    return 0
fi

echo "📊 Detected ${total_changes} file changes:"
echo "   Added: ${added_count}"
echo "   Modified: ${modified_count}"
echo "   Deleted: ${deleted_count}"
echo ""

# Filter out non-source files
excluded_patterns=(
    "product/"
    "node_modules/"
    ".git/"
    "dist/"
    "build/"
    "__pycache__/"
    "*.pyc"
    ".DS_Store"
    "coverage/"
    ".next/"
    ".nuxt/"
    "vendor/"
    ".venv/"
    "venv/"
    "*.min.js"
    "*.min.css"
    ".env.example"
    "package-lock.json"
    "yarn.lock"
    "Gemfile.lock"
)

# Build grep exclusion pattern
exclude_pattern=""
for pattern in "${excluded_patterns[@]}"; do
    if [ -n "$exclude_pattern" ]; then
        exclude_pattern="${exclude_pattern}|${pattern}"
    else
        exclude_pattern="${pattern}"
    fi
done

# Get only relevant changed files
relevant_changes=$(echo "$changed_files" | grep -vE "^($exclude_pattern)" || true)

if [ -z "$relevant_changes" ]; then
    echo "ℹ️  No relevant source files changed."
    echo "   (Only excluded files like dependencies/build artifacts detected)"
    return 0
fi
```

### Step 4: Build File Pattern Database from Tasks.md

Parse tasks.md to extract file patterns:

```bash
# Arrays to store patterns and descriptions
declare -A task_patterns
declare -A task_descriptions
declare -A task_ids

current_group=""
current_task_id=""

# Parse tasks.md line by line
while IFS= read -r line; do
    # Track task group
    if [[ "$line" =~ ^####.\ Task.\ Group.\ [0-9]+:\ (.+) ]]; then
        current_group="${BASH_REMATCH[1]}"
        continue
    fi

    # Track parent task (e.g., "- [ ] 1.0 Complete database layer")
    if [[ "$line" =~ ^\-\ \[.\]\ ([0-9]+\.[0-9]+)\ (.+) ]]; then
        current_task_id="${BASH_REMATCH[1]}"
        task_desc="${BASH_REMATCH[2]}"
        task_descriptions[$current_task_id]="$task_desc"

        # Extract patterns from description
        # Pattern 1: Component names (PascalCase or camelCase)
        if [[ "$task_desc" =~ ([A-Z][a-zA-Z0-9]*(Controller|Model|Component|Service|Repository|Factory|Helper|Utility|Manager|Handler)) ]]; then
            component="${BASH_REMATCH[1]}"
            task_patterns["${current_task_id}:component"]="$component"
        fi

        # Pattern 2: Model names (e.g., "User model", "Product model")
        if [[ "$task_desc" =~ ([A-Z][a-z]+)\ model ]]; then
            model="${BASH_REMATCH[1]}"
            task_patterns["${current_task_id}:model"]="$model"
        fi

        # Pattern 3: Resource/controller names (e.g., "user controller", "auth endpoint")
        if [[ "$task_desc" =~ ([a-z]+)\ (controller|endpoint|resource|service) ]]; then
            resource="${BASH_REMATCH[1]}"
            task_patterns["${current_task_id}:resource"]="$resource"
        fi

        # Pattern 4: Form/page names
        if [[ "$task_desc" =~ ([A-Z][a-zA-Z0-9]*)\ (form|page|component|view) ]]; then
            component="${BASH_REMATCH[1]}"
            task_patterns["${current_task_id}:component"]="$component"
        fi
    fi
done < "$tasks_file"
```

### Step 5: Match Files to Tasks

```bash
# Match each changed file against task patterns
declare -A matched_tasks
declare -A matched_files
declare -A confidence_scores
declare -A unmatched_files

while IFS= read -r change_line; do
    [ -z "$change_line" ] && continue

    status=$(echo "$change_line" | cut -c1)
    filepath=$(echo "$change_line" | cut -c2-)
    filename=$(basename "$filepath")
    extension="${filename##*.}"
    basename="${filename%.*}"

    # Skip deleted files for matching (they don't indicate completion)
    if [ "$status" = "D" ]; then
        unmatched_files["$filepath"]="deleted"
        continue
    fi

    matched=false
    best_match=""
    best_confidence=0

    # Try each task pattern
    for task_key in "${!task_patterns[@]}"; do
        pattern_type="${task_key##*:}"
        pattern="${task_patterns[$task_key]}"
        task_id="${task_key%%:*}"

        confidence=0

        case "$pattern_type" in
            component)
                # Exact basename match with component name
                if [[ "$basename" == *"$pattern"* ]] || [[ "$basename" == "${pattern}" ]]; then
                    confidence=90
                # Component name in path
                elif [[ "$filepath" =~ $pattern ]]; then
                    confidence=70
                fi
                ;;
            model)
                # Model name match
                if [[ "$basename" == "${pattern}Model"* ]] || [[ "$basename" == "${pattern}".* ]]; then
                    confidence=85
                elif [[ "$filepath =~ [Mm]odels/${pattern} ]]; then
                    confidence=75
                fi
                ;;
            resource)
                # Resource/controller name match
                if [[ "$basename" == *"$pattern"* ]] || [[ "$basename" == "${pattern}".* ]]; then
                    confidence=80
                elif [[ "$filepath" =~ [Cc]ontroller/${pattern} ]]; then
                    confidence=70
                fi
                ;;
        esac

        # Test file boost
        if [[ "$filename" =~ test|spec ]] && [[ "$filepath" =~ $pattern ]]; then
            confidence=$((confidence + 10))
        fi

        if [ $confidence -gt $best_confidence ]; then
            best_confidence=$confidence
            best_match="$task_id"
        fi
    done

    # Minimum confidence threshold (configurable, default 50)
    min_confidence=${SYNC_MIN_CONFIDENCE:-50}

    if [ $best_confidence -ge $min_confidence ]; then
        # Accumulate files for this task
        matched_files[$best_match]="${matched_files[$best_match]}$filepath\n"
        confidence_scores[$best_match]=$best_confidence
        matched=true
    fi

    if [ "$matched" = false ]; then
        unmatched_files["$filepath"]="$status"
    fi
done <<< "$relevant_changes"
```

### Step 6: Present Findings to User

```bash
# Count results
matched_count="${#matched_tasks[@]}"
unmatched_count="${#unmatched_files[@]}"

if [ $matched_count -eq 0 ] && [ $unmatched_count -eq 0 ]; then
    echo "ℹ️  No tasks could be matched to changed files."
    echo ""
    echo "Changed files didn't match any task descriptions."
    return 0
fi

echo "🔍 Sync Completed Work Analysis"
echo "================================"
echo ""

if [ $matched_count -gt 0 ]; then
    echo "Found ${matched_count} potentially completed task(s):"
    echo ""

    for task_id in "${!matched_tasks[@]}"; do
        confidence=${confidence_scores[$task_id]}
        desc="${task_descriptions[$task_id]}"
        files="${matched_files[$task_id]}"

        # Confidence emoji
        if [ $confidence -ge 80 ]; then
            confidence_emoji="✅"
        elif [ $confidence -ge 60 ]; then
            confidence_emoji="🔄"
        else
            confidence_emoji="⚠️"
        fi

        echo "  📋 ${task_id}: ${desc}"
        echo "     Confidence: ${confidence}% ${confidence_emoji}"
        echo "     Files:"
        echo "$files" | sed 's/^/       - /' | sed '/^$/d'
        echo ""
    done
fi

if [ $unmatched_count -gt 0 ]; then
    echo "${unmatched_count} file(s) not matched to any task:"
    for filepath in "${!unmatched_files[@]}"; do
        status="${unmatched_files[$filepath]}"
        echo "       - $filepath ($status)"
    done
    echo ""
fi

echo "⚠️  Review carefully:"
echo "   • High confidence (≥80%) likely correct"
echo "   • Medium confidence (60-79%) needs verification"
echo "   • Unmatched files can be manually assigned later"
echo ""
```

### Step 7: Process User Confirmation

```bash
read -p "Type 'yes' to mark these tasks complete, or list specific task IDs (e.g., '1.2 2.1'): " user_input

if [[ -z "$user_input" ]] || [[ "$user_input" == "no" ]] || [[ "$user_input" == "n" ]]; then
    echo ""
    echo "❌ Cancelled. No tasks were marked."
    return 0
fi

# Determine which tasks to mark
if [[ "$user_input" == "yes" ]] || [[ "$user_input" == "y" ]]; then
    # Mark all matched tasks
    tasks_to_mark=()
    for task_id in "${!matched_tasks[@]}"; do
        tasks_to_mark+=("$task_id")
    done
else
    # User specified specific tasks
    tasks_to_mark=($user_input)
fi

# Verify tasks exist before marking
for task_id in "${tasks_to_mark[@]}"; do
    if [[ ! -v "task_descriptions[$task_id]" ]]; then
        echo "⚠️  Warning: Task '${task_id}' not found in tasks.md"
    fi
done
```

### Step 8: Update tasks.md

```bash
# Backup tasks.md first
backup_timestamp=$(date +%s)
backup_file="${tasks_file}.backup.${backup_timestamp}"
cp "$tasks_file" "$backup_file"

echo "💾 Backup saved: ${backup_file}"
echo ""

# Mark tasks as complete
marked_count=0
for task_id in "${tasks_to_mark[@]}"; do
    # Check if task exists in tasks.md
    if ! grep -q "^\- \[ \] ${task_id}" "$tasks_file"; then
        echo "⚠️  Task ${task_id} not found or already complete"
        continue
    fi

    # Mark task: - [ ] 1.2 → - [x] 1.2
    sed -i.tmp "s/^- \[ \] ${task_id}/- [x] ${task_id}/" "$tasks_file"
    rm -f "${tasks_file}.tmp"

    echo "  ✅ Marked ${task_id} complete"
    marked_count=$((marked_count + 1))
done

echo ""
echo "✅ Marked ${marked_count} tasks as complete"
```

### Step 9: Update Parent Task Status

```bash
# Check for parent tasks (e.g., 1.0, 2.0) that may now be complete
parent_updated=false

# Find all parent tasks that are still unchecked
grep "^\- \[ \]\ [0-9]\+\.0" "$tasks_file" | while read -r parent_line; do
    parent_id=$(echo "$parent_line" | sed 's/^- \[ \] \([0-9.]*\).*/\1/')
    prefix="${parent_id%.*}"

    # Count subtasks for this parent
    total_subtasks=$(grep -c "^- \[[x ]\] ${prefix\.[1-9]" "$tasks_file" 2>/dev/null || echo 0)
    completed_subtasks=$(grep -c "^- \[x\] ${prefix\.[1-9]" "$tasks_file" 2>/dev/null || echo 0)

    # If all subtasks complete, mark parent complete
    if [ $total_subtasks -gt 0 ] && [ $total_subtasks -eq $completed_subtasks ]; then
        sed -i.tmp "s/^- \[ \] ${parent_id}/- [x] ${parent_id}/" "$tasks_file"
        rm -f "${tasks_file}.tmp"

        parent_desc=$(grep "^\- \[.\] ${parent_id}\ " "$tasks_file" | sed 's/^- \[.\] [0-9.]* //' | head -1)
        echo "  ✅ Parent task ${parent_id} also complete: ${parent_desc}"
        parent_updated=true
    fi
done

if [ "$parent_updated" = true ]; then
    echo ""
fi
```

### Step 10: Create Recovery Checkpoint

```bash
# Save checkpoint to track going forward
{{workflows/implementation/checkpoint}}
```

### Step 11: Display Summary

```bash
echo ""
echo "✅ Sync Complete"
echo ""
echo "Tasks marked as complete: ${marked_count}"
echo "Backup saved: ${backup_file}"
echo ""
echo "Next steps:"
echo "  • Run project-status to see updated progress"
echo "  • Run resume to continue implementation"
echo "  • Run implement-tasks to continue with remaining tasks"
```

## Edge Cases

| Case | Handling |
|------|----------|
| No tasks.md found | Error: "No task file found. Cannot sync." |
| No checkpoint history | Use HEAD~10 or branch merge-base as fallback |
| No changed files | Message: "No new changes detected since last checkpoint." |
| All unmatched files | Offer to manually map files to tasks |
| Git merge conflict | Abort and suggest resolving conflicts first |
| Multiple tasks match same file | Show all matches with confidence, user chooses |
| User cancels | Exit cleanly, no modifications made |
| Task already complete | Skip and inform user |

## Configuration

Respects these config options:

```yaml
sync_completed_work:
  enabled: true
  min_confidence: 50          # Minimum confidence to suggest match
  require_confirmation: true  # Always ask user (never auto-mark)
  backup_before_modify: true  # Create .backup files
```

## Recovery from Errors

If wrong tasks were marked:

```bash
# Find backup files
ls -lt product/specs/[spec-name]/tasks.md.backup.*

# Restore from most recent backup
cp most_recent_backup product/specs/[spec-name]/tasks.md
```

## Notes

- This is a recovery tool, not a replacement for `implement-tasks`
- File matching is heuristic-based - verify before confirming
- Works best when task descriptions reference specific components/models
- Creates checkpoints so future syncs start from updated state
- Backup files are timestamped for easy recovery

## Display

Sync summary:

```
Sync complete
  Tasks detected as done: [N]
  Tasks marked complete:  [N]
  Checkpointed at:        [timestamp]
```
