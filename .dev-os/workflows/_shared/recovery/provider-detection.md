# Provider-Based Source Detection

Shared snippet for detecting plan file source types using a priority-based provider pattern.

## When to Use

- Include in recovery workflows that need to classify plan files by source (claude-code, agent-os, factory-droid, generic)
- Do not use as a standalone workflow — consumed via `{{include workflows/_shared/recovery/provider-detection}}`

## Provider-Based Source Detection

Detects the type and source of a plan file using the provider pattern for determining appropriate recovery strategy.

### Detection Flow

```bash
plan_file="$1"

# Detect source using provider pattern (priority-based selection)
source_type=$(detect_plan_source "$plan_file")
```

**Provider Detection Flow:**

1. **Provider Loading**: All recovery providers are loaded from `scripts/librecovery/providers/`
2. **Provider Selection**: For each file, providers are queried in priority order (highest first)
3. **Matching Logic**: Each provider's `can_handle()` function tests if it can process the file
4. **Source Assignment**: The highest-priority matching provider determines the source type

### Provider Priorities

| Provider | Priority | Source Type | Files Handled |
|----------|----------|-------------|---------------|
| `agent-os-spec` | 90 | `agent-os` | `product/specs/*/session-state.yml` |
| `claude-code` | 80 | `claude-code` | `.claude/plans/*.md` |
| `factory-droid` | 70 | `factory-droid` | `.factory-droid/plans/*.md` |
| `generic` | 10 | `generic` | Any markdown file with headers |

### Provider Output Example

When `detect_plan_source()` is called on a file:

```bash
$ detect_plan_source ".claude/plansrefactor-api.md"
claude-code

$ detect_plan_source "product/specs/user-auth/session-state.yml"
agent-os

$ detect_plan_source "plans/roadmap.md"
generic

$ detect_plan_source "README.md"
unknown
```

### Source Type Definitions

| Source Type | Provider | Description |
|-------------|----------|-------------|
| `agent-os` | `agent-os-spec` | Agent OS spec with session-state.yml |
| `claude-code` | `claude-code` | Claude Code plan (global or local) |
| `factory-droid` | `factory-droid` | Factory Droid agent plan |
| `generic` | `generic` | Generic plans directory |
| `unknown` | (none) | Unknown source (no provider matches) |

## Display Format

```
$ detect_plan_source "<file>"
<source_type>
```

### Adding New Providers

To add a new provider for a custom plan type:

1. **Create Provider File**: `scripts/librecovery/providers/<name>.sh`

2. **Implement Required Functions**:
   ```bash
   provider_<name>_can_handle()     # Return 0 if file matches
   provider_<name>_get_priority()   # Return priority (10-100)
   provider_<name>_get_session_info() # Output metadata
   provider_<name>_generate_resume()  # Output resume instructions
   ```

3. **Provider Auto-Loads**: Next load cycle will automatically discover and validate
