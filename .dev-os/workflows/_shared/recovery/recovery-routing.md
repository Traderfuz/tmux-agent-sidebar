# Recovery Routing Logic

Shared snippet for routing recovery requests to the appropriate handler based on session type and selection method.

## When to Use

- Include in recovery workflows that need to route user selections (spec, plan, index, file path) to the correct resume handler
- Do not use as a standalone workflow — consumed via `{{include workflows/_shared/recovery/recovery-routing}}`

## Recovery Routing Logic

Routes the recovery request to the appropriate handler based on session type and selection method.

### Selection Methods

User can select by:
1. Index number (from displayed list)
2. `--spec <name>` - Direct spec selection
3. `--plan <name>` - Direct plan selection
4. Direct file path

### Parse Selection

```bash
selection="$1"
session_type=""
target_file=""

# Check for direct spec selection
if [[ "$selection" == --spec* ]]; then
    spec_name="${selection#--spec }"
    spec_name="${spec_name#--spec}"  # Handle no-space variant

    # Validate specs directory exists
    if [[ ! -d "product/specs" ]]; then
        echo "No product/specs directory found in workspace"
        return 1
    fi

    # Find spec session file
    target_file="product/specs/${spec_name}/session-state.yml"
    if [[ ! -f "$target_file" ]]; then
        # Try finding by pattern
        target_file=$(find product/specs -name "session-state.yml" -type f 2>/dev/null | grep -i "$spec_name" | head -1)
    fi

    # Validate file exists
    if [[ ! -f "$target_file" ]]; then
        echo "Spec not found: $spec_name"
        echo "Available specs:"
        find product/specs -maxdepth 1 -type d -not -name "specs" 2>/dev/null | while read dir; do
            echo "  - $(basename "$dir")"
        done
        return 1
    fi
    session_type="spec"

# Check for direct plan selection
elif [[ "$selection" == --plan* ]]; then
    plan_name="${selection#--plan }"
    plan_name="${plan_name#--plan}"

    # Search for plan file in common locations
    target_file=$(find .claude/plans plans .plans .factory-droid/plans 2>/dev/null -name "*${plan_name}*.md" | head -1)
    if [[ -z "$target_file" ]]; then
        target_file=$(find ~/.claude/plans -name "*${plan_name}*.md" 2>/dev/null | head -1)
    fi

    # Validate file exists
    if [[ ! -f "$target_file" ]]; then
        echo "Plan not found: $plan_name"
        echo "Use recover --list to see available plans"
        return 1
    fi
    session_type="plan"

# Check for numeric index
elif [[ "$selection" =~ ^[0-9]+$ ]]; then
    index=$((selection - 1))
    if [[ $index -ge 0 ]] && [[ $index -lt ${#RECOVERABLE_SESSIONS[@]} ]]; then
        # RECOVERABLE_SESSIONS now contains file paths only (not pipe-delimited data)
        target_file="${RECOVERABLE_SESSIONS[$index]}"
        session_type=$(detect_plan_source "$target_file")
    else
        echo "Invalid selection: $selection"
        echo "Please select a number between 1 and ${#RECOVERABLE_SESSIONS[@]}"
        return 1
    fi

# Direct file path
elif [[ -f "$selection" ]]; then
    target_file="$selection"
    session_type=$(detect_plan_source "$selection")
else
    echo "Invalid selection: $selection"
    echo "Use --spec <name>, --plan <name>, a file path, or a number from the list"
    return 1
fi
```

### Route to Handler

```bash
case "$session_type" in
    agent-os|spec)
        # Use existing Agent OS resume workflow
        export SESSION_FILE="$target_file"
        export SPEC_NAME=$(echo "$target_file" | sed 's|product/specs/\([^/]*\)/.*|\1|')
        {{workflows/implementation/restore-session}}
        ;;

    claude-code|factory-droid|generic|generic-plan)
        # Continue plan directly
        export PLAN_FILE="$target_file"
        export PLAN_SOURCE="$session_type"
        export PLAN_TITLE="$(extract_plan_title "$target_file")"
        {{workflows/recovery/continue-plan}}
        ;;

    *)
        echo "⚠️  Unknown session type: $session_type"
        echo "File: $target_file"
        return 1
        ;;
esac
```

### Selection Methods Reference

| Method | Example | Description |
|--------|---------|-------------|
| Index | `1` | Select by displayed list index |
| Spec name | `--spec user-auth` | Select Agent OS spec by name |
| Plan name | `--plan api-refactor` | Select plan by name pattern |
| File path | `/path/to/plan.md` | Direct file path |

## Display Format

```
Routing to <session_type> handler for: <target_file>
```

### Data Format Notes

**Important**: As of the performance optimization, `RECOVERABLE_SESSIONS` contains file paths only (not pipe-delimited session data). Metadata extraction now happens on-demand during display in `present-recovery-options.md`.

**Old format** (pre-optimization):
```
source_type|title|path|mtime|time_ago|status|file_path
```

**New format** (post-optimization):
```
file_path
```

When accessing `RECOVERABLE_SESSIONS` by index, you now get the file path directly:
```bash
# Old way
session_data="${RECOVERABLE_SESSIONS[$index]}"
IFS='|' read -r source_type title path mtime time_ago status file_path <<< "$session_data"

# New way
file_path="${RECOVERABLE_SESSIONS[$index]}"
source_type=$(detect_plan_source "$file_path")
```
