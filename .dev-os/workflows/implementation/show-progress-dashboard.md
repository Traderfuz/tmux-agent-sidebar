# Show Progress Dashboard Workflow

Generates and displays a human-readable progress overview.

## When to Use

This workflow is invoked:
1. By `project-status` command to show current progress
2. By `resume` command to display session context
3. Automatically after checkpoints for user visibility


Do not use this workflow outside of an active implementation session. For project-level backlog review, use `orchestrate` instead.

## Process

### Step 0: Code Reality Check

Before displaying any progress, verify that artifact state reflects actual code on disk:

{{workflows/implementation/code-reality-check}}

Use **single-spec mode**. Surface any findings above the progress table. If Critical or High
findings are present, prepend a warning header to the entire output:

```
WARNING: Code reality issues detected — progress figures below may not reflect actual code state.
```

### Step 1: Determine Display Mode

```bash
# Check if a specific spec is requested
spec_name="$1"

# If no spec provided, look for active session
if [ -z "$spec_name" ]; then
    current_branch=$(git branch --show-current)
    if [[ "$current_branch" == feature/* ]]; then
        spec_name=$(echo "$current_branch" | sed 's/^feature\///')
    fi
fi
```

### Step 2: Check for Progress File

```bash
progress_file="product/specs/${spec_name}/PROGRESS.md"

if [ -f "$progress_file" ]; then
    # Display existing progress file
    cat "$progress_file"
    return 0
fi
```

### Step 3: Generate Progress from tasks.md

If no PROGRESS.md exists, generate it from tasks.md:

```bash
tasks_file="product/specs/${spec_name}/tasks.md"

if [ ! -f "$tasks_file" ]; then
    echo "No progress file found for: ${spec_name}"
    echo ""
    echo "To see all features:"
    echo "  cat product/specs/feature-backlog.md"
    return 1
fi

# Extract task groups and their status
echo "# Progress: ${spec_name}"
echo ""
echo "**Branch:** feature/${spec_name}"
echo "**Status:** In Progress"
echo ""

# Calculate overall progress
{{include workflows/_shared/status-checking/progress-calculation}}

echo "## Overview"
echo ""
echo "| Metric | Value |"
echo "|--------|-------|"
echo "| Total Tasks | ${total_tasks} |"
echo "| Completed | ${completed_tasks} |"
echo "| Remaining | $((total_tasks - completed_tasks)) |"
echo "| Progress | ${progress_percent}% |"
echo ""

# Parse task groups
echo "## Task Group Progress"
echo ""

# Find all task groups
awk '
/^#### Task Group/ {
    group = $0
    gsub(/^#### Task Group [0-9]+: /, "", group)
    group_name = group
    in_group = 1
    completed = 0
    total = 0
    status = "⏳"
}

in_group && /^- \[x\]/ && !/= done/ && !/→/ {
    completed++
    total++
}

in_group && /^- \[ \]/ && !/= todo/ && !/→/ {
    total++
}

/^#### Task Group/ || /^##/ {
    if (in_group && total > 0) {
        pct = int(completed * 100 / total)
        if (pct == 100) status = "✅"
        else if (pct > 0) status = "🔄"
        else status = "⏳"

        print "### " status " " group_name " (" pct "%)"
    }
    if (/^#### Task Group/) in_group = 1
    else in_group = 0
}
' "$tasks_file"

# List tasks by status
echo ""
echo "## Task Details"
echo ""

awk '
/^#### Task Group/ {
    group = $0
    gsub(/^#### Task Group [0-9]+: /, "", group)
    print "### " group
    print ""
}

/^- \[/ {
    print $0
}
' "$tasks_file"
```

### Step 4: Display Backlog (No Active Session)

If no active session and no PROGRESS.md, show the feature backlog:

```bash
backlog_file="product/specs/feature-backlog.md"

if [ -f "$backlog_file" ]; then
    # Show "In Progress" section from backlog
    echo "# Feature Status"
    echo ""
    awk '/^## In Progress/,/^## [A-Z]/ {print}' "$backlog_file" | head -n -1
else
    echo "No active sessions found."
    echo ""
    echo "Start a new implementation:"
    echo "  implement-tasks"
fi
```

### Step 5: Display Triage Badge

After the main progress dashboard, read `.dev-os/runtime/triage.json` to surface a triage health badge:

```
Triage Badge logic:
1. Check if .dev-os/runtime/triage.json exists
2. If absent:
     Show: ⚠ Triage not run — run triage
3. If exists:
     Read generated_at timestamp
     Compute age in hours since generated_at
     If age > 24 hours:
       Show: ⚠ Triage stale ({date}) — run triage to refresh
     Else if summary.critical > 0 OR summary.high > 0:
       Show: ⚠ Triage: {critical} critical, {high} high ({date})
     Else:
       Show: ✅ Triage: clean ({date})
```

### Step 6: Display Verification Badge

After the triage badge, read `.dev-os/runtime/verification-state.json` to surface a pre-deploy verification badge:

```
Verification Badge logic:
1. Check if .dev-os/runtime/verification-state.json exists
2. If absent:
     Show: ⚠ Not verified since last merge
3. If exists:
     Read status field:
     "verified"   → ✅ Pre-deploy verified ({last_validated date})
     "partial"    → 🔄 Partially verified — e2e pending. Run e2e to complete.
     "unverified" → ⚠ Not verified since last merge
     Additionally: if last_merge_sha != current git HEAD SHA:
       Show: ⚠ Verified on a prior commit — re-run predeploy-check
```

## Output Format

The progress dashboard displays:

1. **Header** - Spec name, branch, status
2. **Overview Table** - Total, completed, remaining, percentage
3. **Task Group Progress** - Each group with status emoji and percent
4. **Recent Activity** - Last 3-5 checkpoints
5. **Next Steps** - What to do next
6. **Triage Badge** - Health status from last triage run
7. **Verification Badge** - Pre-deploy verification status

### Status Emojis

| Emoji | Meaning |
|-------|---------|
| ✅ | Complete (100%) |
| 🔄 | In Progress (>0%, <100%) |
| ⏳ | Not Started (0%) |

## Integration

### In `project-status` Command

```markdown
{{workflows/implementation/show-progress-dashboard}}
```

### After Checkpoint

The checkpoint workflow updates PROGRESS.md automatically.

## Configuration

```yaml
progress_dashboard_enabled: true
progress_dashboard_auto_generate: true
```

## Example Output

```
# Progress: user-authentication

**Branch:** feature/user-authentication
**Status:** In Progress (33% complete)

## Overview

| Metric | Value |
|--------|-------|
| Total Tasks | 24 |
| Completed | 8 |
| Remaining | 16 |
| Progress | 33% |

## Task Group Progress

### ✅ Task Group 1: Data Models (100%)
- [x] 1.1 Write tests for Model functionality
- [x] 1.2 Create User model with validations
- [x] 1.3 Create migration for users table

### 🔄 Task Group 2: API Endpoints (40%)
- [x] 2.1 Write tests for API endpoints
- [🔄] 2.2 Create resource controller
- [ ] 2.3 Implement authentication/authorization

### ⏳ Task Group 3: Frontend Components (0%)
- [ ] 3.1 Write tests for UI components
- [ ] 3.2 Create UserForm component

---

_Type 'resume' to continue • 'checkpoint' to save state_
```
