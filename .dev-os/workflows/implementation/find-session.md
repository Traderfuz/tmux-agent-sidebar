# Find Session Workflow

Locates the active or most recent session to enable resumption.

## When to Use

This workflow is invoked:
1. By `resume` command to find the session to restore
2. By `project-status` command to show current progress
3. By `implement-tasks` to detect existing sessions before starting


Do not use to start a new session — use `implement-tasks` for that. Do not use when you already know the current session context from `.dev-os/runtime/session-state.yml`.
## Process

### Step 0: Detect Unsynchronized Manual Work

Before locating or displaying the session, check whether the developer has made manual commits that haven't been synced to tasks.md.

1. Read `.dev-os/runtime/session-state.yml` — find the `checkpoint_sha` value.
2. If `checkpoint_sha` is absent or empty → skip to Step 1 (no baseline to compare).
3. Run: `git diff --stat <checkpoint_sha>..HEAD`
4. If the output is non-empty (files changed since checkpoint):
   - Read `last_sync_completed_work` timestamp from `session-state.yml`
   - Run: `git log -1 --format="%ct" HEAD` to get the latest commit unix timestamp
   - If `last_sync_completed_work` is absent, OR the latest commit timestamp is greater than `last_sync_completed_work`:
     - Print the following warning block **before any session summary or dashboard output**:

     ```
     ⚠ Unsynchronized work detected — files changed since last checkpoint.
       Run sync-completed-work to map changes to tasks before proceeding.
       (Skip with --skip-sync-check if you have already synced manually.)
     ```
5. If `--skip-sync-check` was passed by the caller → skip this entire step.

### Step 1: Check Current Branch

```bash
# Get current branch
current_branch=$(git branch --show-current)

# Extract spec name from branch if on feature branch
if [[ "$current_branch" == feature/* ]]; then
    spec_name=$(echo "$current_branch" | sed 's/^feature\///')
else
    spec_name=""
fi
```

### Step 2: Look for Session State

Check for existing session files in priority order:

```bash
# Priority 1: Current feature branch's session
if [ -n "$spec_name" ] && [ -f "product/specs/${spec_name}/session-state.yml" ]; then
    session_file="product/specs/${spec_name}/session-state.yml"
    found_session="current_branch"

# Priority 2: Most recently modified session across all specs
else
    # GNU find (Linux) — -printf is available
    session_file=$(command find product/specs -name "session-state.yml" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    # macOS fallback if empty (GNU -printf not available on BSD find)
    if [[ -z "$session_file" ]]; then
        session_file=$(command find product/specs -name "session-state.yml" -type f 2>/dev/null \
            | while read -r f; do echo "$(stat -f %m "$f") $f"; done \
            | sort -rn | head -1 | cut -d' ' -f2-)
    fi

    if [ -n "$session_file" ]; then
        found_session="most_recent"
    fi
fi
```

### Step 3: Validate Session

```bash
if [ -z "$session_file" ]; then
    echo "No active session found."
    echo ""
    echo "To start a new session, run:"
    echo "  implement-tasks"
    return 1
fi

# Extract spec name from session file path
spec_name=$(echo "$session_file" | sed 's|product/specs/\([^/]*\)/.*|\1|')

# Check if session is stale
current_time=$(date +%s)
session_time=$(stat -c %Y "$session_file" 2>/dev/null || stat -f %m "$session_file" 2>/dev/null)
age_seconds=$((current_time - session_time))
stale_threshold=${CHECKPOINT_STALE_THRESHOLD:-86400}  # 24 hours default; override via checkpoint_stale_threshold in .dev-os/config.yml

if [ $age_seconds -gt $stale_threshold ]; then
    age_hours=$((age_seconds / 3600))
    echo "⚠️  Found stale session (${age_hours}h old)"
    echo ""
    echo "Spec: ${spec_name}"
    echo "Session file: ${session_file}"
    echo ""
    echo "This session may be outdated. Continue anyway?"
    return 2  # Special return code for stale session
fi
```

### Step 4: Extract Session Information

Parse the session-state.yml file:

```bash
# Read session state
spec=$(grep "^spec:" "$session_file" | sed 's/spec: //')
branch=$(grep "^branch:" "$session_file" | sed 's/branch: //')
last_update=$(grep "^last_update:" "$session_file" | sed 's/last_update: //')
current_task=$(grep "^current_task:" "$session_file" | sed 's/current_task: //')
current_subtask=$(grep "^current_subtask:" "$session_file" | sed 's/current_subtask: //')
progress_percent=$(grep "^progress_percent:" "$session_file" | sed 's/progress_percent: //')
last_action=$(grep "^last_action:" "$session_file" | sed 's/last_action: //')
next_action=$(grep "^next_action:" "$session_file" | sed 's/next_action: //')
has_uncommitted=$(grep "^has_uncommitted_changes:" "$session_file" | sed 's/has_uncommitted_changes: //')
```

### Step 5: Output Session Summary

Display the found session information:

```
📍 Found Active Session

Spec: ${spec}
Branch: ${branch}
Last Update: ${last_update}
Progress: ${progress_percent}%

Current Position:
  Task: ${current_task}
  Sub-task: ${current_subtask}

Last Action: ${last_action}
Next: ${next_action}

Uncommitted Changes: ${has_uncommitted}
```

### Step 6: Return Session Path

For programmatic use, output the session file path:

```bash
echo "SESSION_FILE=${session_file}"
echo "SPEC_NAME=${spec_name}"
echo "BRANCH_NAME=${branch}"
```

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Session found and valid |
| 1 | No session found |
| 2 | Stale session found (>24h old) |
| 3 | Corrupted session file |

## Integration

### In `resume` Command

```markdown
{{workflows/implementation/find-session}}

[Handle return codes and prompt user]
{{workflows/implementation/restore-session}}
```

### In `project-status` Command

```markdown
{{workflows/implementation/find-session}}

[Display PROGRESS.md or session summary]
{{workflows/implementation/show-progress-dashboard}}
```

### In `implement-tasks` Command

```markdown
{{workflows/implementation/find-session}}

[If session exists, prompt to resume or start new]
```

## Configuration

```yaml
checkpoint_stale_threshold: 86400  # 24 hours in seconds
```

## Edge Cases

| Case | Handling |
|------|----------|
| Multiple specs with sessions | Return most recently modified |
| Session file corrupted | Return code 3, suggest manual recovery |
| Branch deleted but session exists | Show session, suggest branch recreation |
| Uncommitted changes in session | Flag in output for restore-session to handle |

## Display

Session discovery result:

```
Active session found:
  Spec:     [spec-name]
  Branch:   feature/[spec-name]
  Progress: [N]% ([X]/[Y] tasks)
  Last:     [last-action]
```
