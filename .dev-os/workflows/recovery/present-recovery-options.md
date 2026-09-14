# Present Recovery Options Workflow

Displays discovered recoverable sessions in a user-friendly format.

## When to Use

This workflow is invoked:
1. After `find-recoverable-sessions` to show options
2. By `recover` command for user selection


Do not use this workflow when no recovery candidates exist. Do not invoke it to resume a session that was cleanly closed — use `resume` instead.

## Process

### Step 1: Check for Sessions

```bash
if [[ ${SESSION_COUNT:-0} -eq 0 ]]; then
    echo "📂 Recoverable Work Sessions"
    echo ""
    echo "No recent work found in this workspace."
    echo ""
    echo "To start new work:"
    echo "  plan-product   - Plan a new feature"
    echo "  write-spec     - Write a specification"
    echo "  quick-fix      - Small changes"
    return 0
fi
```

### Step 2: Display Header

```bash
echo "📂 Recoverable Work Sessions"
echo ""
echo "Most recent in this workspace:"
echo ""
```

### Step 3: Display Sessions with On-Demand Metadata Extraction

```bash
index=1
workspace=$(pwd)

# Check if quick mode is enabled (skip content scanning)
quick_mode="${RECOVER_QUICK_MODE:-false}"

for file_path in "${RECOVERABLE_SESSIONS[@]}"; do
    # Extract metadata on-demand (only for files being displayed)
    source_type=$(detect_plan_source "$file_path")
    title=$(extract_plan_title "$file_path")
    path=$(format_plan_path "$file_path" "$workspace")
    mtime=$(get_file_mtime "$file_path")
    time_ago=$(time_ago "$mtime")

    # Estimate status based on source type and content
    # Skip content scanning in quick mode for better performance
    if [[ "$quick_mode" == "true" ]]; then
        status="Unknown (run recover without --quick to check)"
    elif [[ "$source_type" == "agent-os" ]]; then
        # For Agent OS specs, read session state if available
        spec_dir=$(dirname "$file_path")
        if [[ -f "$spec_dir/session-state.yml" ]]; then
            progress=$(grep "^progress_percent:" "$spec_dir/session-state.yml" 2>/dev/null | sed 's/progress_percent: //')
            status="In progress (${progress:-0}%)"
        else
            status="No session state"
        fi
    elif [[ "$source_type" == "claude-code" ]]; then
        # Check for completion markers in plan content
        if grep -qi "approved\|implemented\|complete" "$file_path" 2>/dev/null; then
            status="Completed"
        else
            status="In progress"
        fi
    elif [[ -n "$source_type" && "$source_type" != "unknown" ]]; then
        # For known sources, estimate from content
        if grep -qiE "^(#.*completed|##.*done|✓|completed)" "$file_path" 2>/dev/null; then
            status="Completed"
        else
            status="In progress"
        fi
    else
        status="Not started"
    fi

    # Format source type emoji
    case "$source_type" in
        agent-os|spec)
            emoji="📋"
            source_label="Agent OS"
            ;;
        claude-code)
            emoji="🤖"
            source_label="Claude Code"
            ;;
        factory-droid)
            emoji="🔧"
            source_label="Factory Droid"
            ;;
        generic-plan)
            emoji="📝"
            source_label="Plan"
            ;;
        *)
            emoji="📄"
            source_label="Unknown"
            ;;
    esac

    # Display session
    echo "  $emoji [$source_label] $title"
    echo "     $path"
    echo "     Modified: $time_ago"
    echo "     Status: $status"
    echo ""

    ((index++)) || true
done
```

### Step 4: Display Options

```bash
echo "Select a session to recover, or use:"
echo "  --spec <name>    Recover specific Agent OS spec"
echo "  --plan <name>    Recover specific plan"
echo "  --source <type>  Filter by source (claude-code, factory-droid, etc.)"
echo "  --age <duration> Show only recent sessions (e.g., 1d, 1w)"
echo "  --quick          Skip content scanning for faster results"
echo ""
echo "Source types: spec, claude-code, factory-droid, generic-plan"
```

### Step 5: Handle Empty Results with All Workspaces

```bash
if [[ $SESSION_COUNT -eq 0 ]] && [[ "$RECOVER_ALL_WORKSPACES" == "true" ]]; then
    echo ""
    echo "Use --all to see sessions from other workspaces."
fi
```

## Display Format

```
📂 Recoverable Work Sessions

Most recent in this workspace:

  📋 [Agent OS] User Authentication
     product/specs/user-auth/session-state.yml
     Modified: 2h ago
     Status: In progress (33%)

  🤖 [Claude Code] API Refactoring
     ~/.claude/plans/api-refactor.md
     Modified: 3h ago
     Status: In progress

  🔧 [Factory Droid] Database Migration
     .factory-droid/plans/db-migration.md
     Modified: 1d ago
     Status: Not started

Select a session to recover, or use:
  --spec <name>    Recover specific Agent OS spec
  --plan <name>    Recover specific plan
  --source <type>  Filter by source
```

## Source Labels and Emojis

| Source | Emoji | Label |
|--------|-------|-------|
| `agent-os` / `spec` | 📋 | Agent OS |
| `claude-code` | 🤖 | Claude Code |
| `factory-droid` | 🔧 | Factory Droid |
| `generic-plan` | 📝 | Plan |
| `unknown` | 📄 | Unknown |

## Status Messages

| Status | When Shown |
|--------|------------|
| `In progress (X%)` | Spec with active session |
| `No session state` | Spec without session file |
| `In progress` | Plan without completion markers |
| `Completed` | Plan with completion markers |
| `Not started` | Generic plan file |
| `Unknown` | Quick mode enabled (content scanning skipped) |

## Performance Optimization

Metadata extraction now happens on-demand during display:

1. **Discovery phase**: Returns file paths only (fast)
2. **Display phase**: Extracts metadata only for visible results
3. **Quick mode**: Skip content scanning entirely with `--quick` flag
4. **Benefit**: ~50% performance improvement for workspaces with 100+ plan files

## Edge Cases

| Case | Display |
|------|---------|
| No sessions | "No recent work found" message |
| Single session | Still show list with "Most recent" header |
| Very long title | Truncate with "..." if >60 chars |
| Very long path | Show relative path only |
| Duplicate titles | Show path to distinguish |
| All sessions filtered | Show "No matching sessions found" |

## Integration

```markdown
{{workflows/recovery/find-recoverable-sessions}}

{{workflows/recovery/present-recovery-options}}

[Get user selection]
{{workflows/recovery/execute-recovery}}
```
