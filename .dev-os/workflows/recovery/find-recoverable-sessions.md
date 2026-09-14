# Find Recoverable Sessions Workflow

Discovers all recoverable sessions from Agent OS specs and workspace-local plan sources using provider-based detection.

## When to Use

This workflow is invoked:
1. By `recover` command to find all available work
2. By `project-status` to show recent activity across sources


Do not use when you are not in a recovery context — session discovery has overhead. Do not use to find sessions from more than 30 days ago; they are archived and not recoverable.
## Process

### Step 1: Gather Sessions from All Sources

```bash
workspace=$(pwd)
declare -a sessions

# 1. Agent OS spec sessions
spec_sessions=$(find_spec_sessions "$workspace")

# 2. Workspace-local plans (discovered via provider aggregation)
workspace_plans=$(find_workspace_plans "$workspace")

# Combine all sessions
all_sessions=""
for session in $spec_sessions $workspace_plans; do
    if [[ -n "$session" ]]; then
        all_sessions="$all_sessions$session"$'\n'
    fi
done
```

**Provider-Based Directory Scanning:**

The `find_workspace_plans()` function aggregates scan directories from all registered recovery providers:

```bash
# Get scan directories from provider aggregation
get_all_provider_scan_directories()
```

Each provider declares where to find its plan files via `provider_scan_directories()`:

| Provider | Directories Contributed |
|----------|------------------------|
| `product-spec` | `product/specs` |
| `claude-code` | `.claude/plans` |
| `generic` | `.factory/plans`, `.factory-droid/plans`, `.gemini/plans`, `.agent/plans`, `plans`, `.plans`, `planning`, `.planning`, `doc/plans`, `docs/plans`, `.cursor/plans`, `.windsurf/plans` |

### Step 2: Filter by Options

```bash
# Filter by source type if specified
if [[ -n "$RECOVER_SOURCE_FILTER" ]]; then
    filtered_sessions=""
    while IFS= read -r session; do
        source=$(detect_plan_source "$session")
        if [[ "$source" == "$RECOVER_SOURCE_FILTER" ]]; then
            filtered_sessions="$filtered_sessions$session"$'\n'
        fi
    done <<< "$all_sessions"
    all_sessions="$filtered_sessions"
fi

# Filter by age if specified
if [[ -n "$RECOVER_MAX_AGE" ]]; then
    current_time=$(date +%s)
    max_age_seconds=$RECOVER_MAX_AGE

    filtered_sessions=""
    while IFS= read -r session; do
        mtime=$(get_file_mtime "$session")
        age=$((current_time - mtime))
        if [[ $age -le $max_age_seconds ]]; then
            filtered_sessions="$filtered_sessions$session"$'\n'
        fi
    done <<< "$all_sessions"
    all_sessions="$filtered_sessions"
fi
```

### Step 3: Sort by Modification Time

```bash
# Sort by mtime (most recent first)
sorted_sessions=$(echo "$all_sessions" | while read -r session; do
    if [[ -n "$session" && -f "$session" ]]; then
        mtime=$(get_file_mtime "$session")
        echo "$mtime $session"
    fi
done | sort -rn | cut -d' ' -f2-)
```

### Step 4: Apply Result Limit

```bash
# Limit results to configured max (default: 20)
# Metadata extraction will happen in present-recovery-options for displayed files only
max_results=${RECOVER_MAX_RESULTS:-20}
limited_files=()
count=0
for file in $sorted_sessions; do
    [[ $count -ge $max_results ]] && break
    [[ -n "$file" ]] && limited_files+=("$file")
    ((count++))
done
```

### Step 5: Output Results

```bash
# Store file paths only (metadata extracted on-demand during display)
RECOVERABLE_SESSIONS=("${limited_files[@]}")
export RECOVERABLE_SESSIONS

# Count for display
SESSION_COUNT=${#limited_files[@]}
export SESSION_COUNT
```

## Provider-Based Discovery Architecture

The session discovery system uses a provider pattern for extensibility:

```
┌─────────────────────────────────────────────────────────┐
│            Find Recoverable Sessions                     │
└─────────────────────────────────────────────────────────┘
                          │
                          ├──▶ find_spec_sessions()
                          │    └──▶ Scans: product/specs/*/session-state.yml
                          │
                          └──▶ find_workspace_plans()
                               └──▶ get_all_provider_scan_directories()
                                    ├──▶ provider_agent_os_spec_scan_directories()
                                    ├──▶ provider_claude_code_scan_directories()
                                    ├──▶ provider_factory_droid_scan_directories()
                                    └──▶ provider_generic_scan_directories()
```

**Benefits of Provider Aggregation:**

- **Extensibility**: New agents add their own provider with scan directories
- **No Hardcoding**: Centralized directory management per provider
- **Validation**: Providers validated on load, invalid ones skipped
- **Fallback**: Pattern-based discovery (`*-agent/`) handles unknown future agents
- **Performance**: Metadata extraction deferred to display time, only for visible results

## Performance Optimization

The workflow now defers metadata extraction until display time:

1. **Discovery**: Returns file paths only (no metadata parsing)
2. **Sorting**: Sorts by modification time using stat only
3. **Limiting**: Applies limit to file paths before any metadata extraction
4. **Display**: Metadata extracted on-demand in `present-recovery-options`

This provides approximately 50% performance improvement for workspaces with 100+ plan files.

## Edge Cases

{{include workflows/_shared/recovery/error-table-format}}

## Configuration

```yaml
# Sources to scan (provider-based)
recover_sources:
  agent_os_specs: true
  claude_code: true
  factory_droid: true
  generic_plans: true

# Maximum age (seconds, 0 = unlimited)
recover_max_plan_age: 604800  # 7 days

# Display settings
recover_max_results: 20
```

## Debug Mode

Enable verbose provider logging:

```bash
RECOVERY_PROVIDER_DEBUG=1 recover
```

This shows:
- Provider loading status
- Scan directory aggregation
- Provider selection for each file
- Validation warnings

## Display

Recoverable sessions summary:

```
Recoverable sessions found: [N]
  [N] from DevOS plans
  [N] from Claude transcripts
  [N] from git branches
```
