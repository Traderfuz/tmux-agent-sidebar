# Continue Plan Workflow

Continues execution of a Claude Code or external agent plan.

## When to Use

This workflow is invoked:
1. By `recover` for non-spec plans
2. When user selects a Claude Code, Factory Droid, or generic plan


Do not use this workflow to start a new implementation from scratch — use `implement-tasks` instead. Do not use when no recoverable session exists.

## Process

### Step 1: Display Plan Summary

```bash
plan_file="${PLAN_FILE}"
plan_source="${PLAN_SOURCE}"
plan_title="${PLAN_TITLE}"

echo "📋 $plan_title"
echo ""
echo "Source: $plan_source"
echo "Location: $(format_plan_path "$plan_file")"
echo "Modified: $(time_ago "$(get_file_mtime "$plan_file")")"
echo ""
```

### Step 2: Parse Plan Structure

```bash
# Read plan content
plan_content=$(cat "$plan_file")

# Detect plan structure
has_sections=$(echo "$plan_content" | grep -c "^##" || echo 0)
has_tasks=$(echo "$plan_content" grep -c "^-\s" || echo 0)
has_verification=$(echo "$plan_content" | grep -qi "verification\|testing\|complete" && echo 1 || echo 0)

# Estimate completion
if grep -qiE "(approved|implemented|merged|complete)" "$plan_file"; then
    estimated_status="Completed"
elif grep -qiE "(in progress|wip|todo|pending)" "$plan_file"; then
    estimated_status="In progress"
else
    estimated_status="Not started"
fi

echo "Status: $estimated_status"
echo "Structure: $has_sections sections, $has_tasks task items"
echo ""
```

### Step 3: Show Plan Preview

```bash
# Show first ~20 lines as preview
echo "Plan preview:"
echo "---"
head -20 "$plan_file"
echo "..."

# Show total line count
total_lines=$(wc -l < "$plan_file")
echo "(File has $total_lines lines total)"
echo ""
```

### Step 4: Offer Continuation Options

```bash
echo "Recovery options:"
echo ""
echo "  1. Read full plan and continue"
echo "  2. Jump to specific section"
echo "  3. Open file in editor"
echo "  4. Cancel"
echo ""
```

### Step 5: Handle User Choice

```bash
# In the actual command, user choice comes from conversation
# For now, provide the plan content for continuation

# Export for use by AI
export RECOVERY_PLAN_FILE="$plan_file"
export RECOVERY_PLAN_SOURCE="$plan_source"
export RECOVERY_PLAN_TITLE="$plan_title"
export RECOVERY_PLAN_CONTENT="$plan_content"

echo "✅ Plan loaded for continuation"
echo ""
echo "The plan is now available. You can:"
echo "  • Ask questions about the plan"
echo "  • Request to continue from a specific section"
echo "  • Ask for a summary of remaining work"
```

### Step 6: Provide Section Summary (Optional)

```bash
# If user wants to see sections
if [[ "$SHOW_SECTIONS" == "true" ]]; then
    echo ""
    echo "Plan sections:"
    echo "---"
    grep "^##" "$plan_file" | while read section; do
        echo "  $section"
    done
    echo ""
fi
```

## Plan Structure Detection

| Pattern | Indicates |
|---------|-----------|
| `^##` | Section headers |
| `^- ` | Task list items |
| `(approved|implemented|complete)` | Completed work |
| `(wip|todo|pending)` | Pending work |
| `(verification|testing)` | Verification section |

## Estimated Status

| Status | Detection Pattern |
|--------|------------------|
| Completed | Contains "approved", "implemented", "complete" |
| In progress | Contains "wip", "in progress", partial task markers |
| Not started | No task markers found |

## Continuation Modes

| Mode | Description |
|------|-------------|
| Read and continue | Load full plan, AI continues execution |
| Jump to section | Navigate to specific section |
| Open in editor | Open file for manual editing |
| Summarize | AI provides summary of remaining work |

## Edge Cases

| Case | Handling |
|------|----------|
| Empty plan file | Warning, offer to open anyway |
| Very large plan | Show summary first, offer section jump |
| Malformed markdown | Best-effort parsing |
| No sections | Treat as single-section plan |
| Binary file | Error, skip |

## Integration

```markdown
{{workflows/recovery/execute-recovery}}

[Routes here for non-spec plans]

[Plan content loaded, AI continues]
```

## Output Variables

| Variable | Description |
|----------|-------------|
| `RECOVERY_PLAN_FILE` | Full path to plan file |
| `RECOVERY_PLAN_SOURCE` | Source type (claude-code, etc.) |
| `RECOVERY_PLAN_TITLE` | Extracted plan title |
| `RECOVERY_PLAN_CONTENT` | Full plan content |
| `RECOVERY_PLAN_STATUS` | Estimated completion status |
