## Session Metadata Extraction

Extracts metadata from plan files including title, modification time, path, and status.

### Extract Metadata

```bash
# Get plan title
title=$(extract_plan_title "$plan_file")

# Get modification time
mtime=$(get_file_mtime "$plan_file")

# Get formatted path
workspace=$(pwd)
path=$(format_plan_path "$plan_file" "$workspace")

# Get time ago string
time_ago_str=$(time_ago "$mtime")
```

### Determine Status

```bash
# For Agent OS specs, read session state
if [[ "$source_type" == "agent-os" ]]; then
    spec_dir=$(dirname "$plan_file")
    if [[ -f "$spec_dir/session-state.yml" ]]; then
        progress=$(grep "^progress_percent:" "$spec_dir/session-state.yml" 2>/dev/null | sed 's/progress_percent: //')
        current_task=$(grep "^current_task:" "$spec_dir/session-state.yml" 2>/dev/null | sed 's/current_task: //')
        status="In progress (${progress:-0}%)"
    else
        status="No session state"
    fi

# For Claude Code plans, estimate completion from content
elif [[ "$source_type" == "claude-code" ]]; then
    # Check for completion markers
    if grep -qi "approved\|implemented\|complete" "$plan_file"; then
        status="Completed"
    else
        status="In progress"
    fi

# For other plans, basic status
else
    status="Not started"
fi
```

### Session Data Format

Each session is stored as a pipe-delimited string:

```
source_type|title|path|mtime|time_ago|status|file_path
```

Example:
```
agent-os|User Authentication|product/specs/user-auth/session-state.yml|1736890800|2h ago|In progress (33%)|/path/to/session-state.yml
claude-code|API Refactoring|.claude/plans/api-refactor.md|1736887200|3h ago|In progress|/path/to/.claude/plans/api-refactor.md
```

### Field Definitions

| Field | Description | Example |
|-------|-------------|---------|
| `source_type` | Provider-detected source | `agent-os`, `claude-code` |
| `title` | Plan/session title | `User Authentication` |
| `path` | Relative path from workspace | `product/specs/user-auth/` |
| `mtime` | Unix timestamp | `1736890800` |
| `time_ago` | Human-readable time ago | `2h ago` |
| `status` | Completion status | `In progress (33%)` |
| `file_path` | Full absolute path | `/path/to/session-state.yml` |
