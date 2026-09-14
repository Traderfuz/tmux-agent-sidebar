# Discover Workspace Plans Workflow

Scans the workspace for all plan files using provider-based directory aggregation.

## When to Use

This workflow is invoked:
1. By `recover` command to find local workspace plans
2. By unified discovery to build complete session list


Do not invoke directly for session recovery — use `recover` which calls this internally. Do not use when you already know the target session path.
## Process

### Step 1: Aggregate Provider Scan Directories

```bash
workspace=$(pwd)

# Get scan directories from provider aggregation
provider_dirs=()
if declare -f get_all_provider_scan_directories >/dev/null; then
    while IFS= read -r dir; do
        [[ -n "$dir" ]] && provider_dirs+=("$dir")
    done < <(get_all_provider_scan_directories)
fi
```

### Step 2: Scan Provider-Contributed Directories

```bash
# Scan all provider-contributed directories
for dir in "${provider_dirs[@]}"; do
    if [[ -d "$workspace/$dir" ]]; then
        find "$workspace/$dir" -name "*.md" -type f 2>/dev/null
    fi
done
```

### Step 3: Pattern-Based Discovery (Fallback)

```bash
# Pattern-based discovery for unknown agents (*-agent/, .*-agent/)
# This handles future agents not yet having dedicated providers
find "$workspace" -maxdepth 2 -type d \( -name "*-agent*" -o -name ".*-agent*" \) 2>/dev/null | while read agent_dir; do
    if [[ -d "$agent_dir/plans" ]]; then
        find "$agent_dir/plans" -name "*.md" -type f 2>/dev/null
    fi
done

# Find product-plan* files anywhere in workspace
find "$workspace" -maxdepth 2 -name "product-plan*.md" -type f 2>/dev/null
```

### Step 4: Filter and Validate

```bash
for plan_file in $workspace_plans; do
    # Skip if not a markdown file
    [[ "$plan_file" != *.md ]] && continue

    # Check if file appears to be a plan
    if is_plan_file "$plan_file"; then
        echo "$plan_file"
    fi
done
```

### Step 5: Output Plan Files

Returns list of plan file paths for further processing.

## Provider-Contributed Scan Directories

Each provider declares where to look for its plan files via `provider_scan_directories()`:

| Provider | Directories | Agent/Tool |
|----------|-------------|------------|
| `product-spec` | `product/specs` | Agent OS specs |
| `claude-code` | `.claude/plans` | Claude Code (local) |
| `generic` | `.factory/plans` | Factory agent |
| `generic` | `.factory-droid/plans` | Factory Droid |
| `generic` | `.gemini/plans` | Gemini agent |
| `generic` | `.agent/plans` | Generic agent |
| `generic` | `plans`, `.plans` | Generic plans |
| `generic` | `planning`, `.planning` | Planning documents |
| `generic` | `doc/plans`, `docs/plans` | Documentation plans |
| `generic` | `.cursor/plans` | Cursor agent |
| `generic` | `.windsurf/plans` | Windsurf agent |

## Provider Aggregation Flow

```
┌───────────────────────────────────────────────────────────────┐
│              find_workspace_plans(workspace)                   │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│        get_all_provider_scan_directories()                     │
└───────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│product-spec  │    │claude-code    │    │generic        │
│provider       │    │provider       │    │provider       │
├───────────────┤    ├───────────────┤    ├───────────────┤
│product/specs │    │.claude/plans  │    │.factory/plans │
│               │    │               │    │.factory-droid/│
│               │    │               │    │plans          │
│               │    │               │    │... (11 dirs)  │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              ▼
                    Combined directory list
                              │
                              ▼
                    Scan each directory for *.md
                              │
                              ▼
                    Output plan file paths
```

## Adding New Providers with Custom Directories

To add a new provider that contributes custom scan directories:

### 1. Create Provider File

```bash
# scripts/librecovery/providers/my-agent.sh
```

### 2. Implement Required Functions

```bash
#!/bin/bash

source "${LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")/../..}/output.sh"

# Test if this provider can handle the file
provider_my_agent_can_handle() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1

    # Check for .my-agent/plans path
    local filepath=$(dirname "$file" | tr '[:upper:]' '[:lower:]')
    if [[ "$filepath" == *".my-agent/plans"* ]]; then
        return 0
    fi

    return 1
}

# Get provider priority
provider_my_agent_get_priority() {
    echo 75  # Between claude-code (80) and generic (10)
}

# Get session info
provider_my_agent_get_session_info() {
    local file="$1"
    local title=$(extract_plan_title "$file")
    local path=$(format_plan_path "$file")
    local mtime=$(get_file_mtime "$file")

    echo "title=$title"
    echo "type=my-agent-plan"
    echo "source=my-agent"
    echo "path=$path"
    echo "mtime=$mtime"
}

# Generate resume instructions
provider_my_agent_generate_resume() {
    local file="$1"
    local title=$(extract_plan_title "$file")
    local path=$(format_plan_path "$file")

    cat <<EOF
## Resume: $title

**File:** \`$path\`
**Type:** My Agent Plan

Continue working on this plan using your agent's workflow.
EOF
}
```

### 3. Declare Scan Directories

```bash
# Return directories where this provider's plans are stored
provider_my_agent_scan_directories() {
    echo ".my-agent/plans"
    echo "my-agent-workspace/plans"
}
```

### 4. Provider Auto-Loads

On next load cycle, the provider will:
- Be automatically discovered
- Be validated (required functions checked)
- Contribute its directories to workspace scanning
- Handle files matching its patterns

## Edge Cases

| Case | Handling |
|------|----------|
| Directory doesn't exist | Silently skip |
| Empty directory | No output |
| Non-markdown files | Skip |
| Large plan directories | Scan all, caller can limit |
| No providers loaded | Fallback to hardcoded list |
| Duplicate directories | Deduplicated by aggregator |

## Configuration

The following config options control discovery:

```yaml
# Enable generic plan directory scanning
recover_sources:
  generic_plans: true

# Maximum age for plans (0 = unlimited)
recover_max_plan_age: 604800  # 7 days
```

## Debug Mode

Enable verbose logging to see provider aggregation:

```bash
RECOVERY_PROVIDER_DEBUG=1

# Example output:
# [RECOVERY] DEBUG: Aggregating scan directories from all providers
# [RECOVERY] TRACE:   Added: .claude/plans (from claude-code)
# [RECOVERY] TRACE:   Added: product/specs (from product-spec)
# [RECOVERY] TRACE:   Added: .factory/plans (from generic)
# ...
```

## Integration

```markdown
{{workflows/recovery/discover-workspace-plans}}

[Filter and process discovered plans]
{{workflows/recovery/detect-plan-type}}
```

## Display

Discovered plans list:

```
Found [N] recoverable session(s):
  [source] [title] — [time_ago] ([status])
  ...
```
