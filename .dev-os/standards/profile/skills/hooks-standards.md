<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/hooks-standards.md and re-run profile-sync. -->
# Hooks Standards

Hooks are user-defined shell commands that execute at various points in Claude Code's lifecycle. They provide deterministic control over behavior.

## Hook Events

| Event | When it fires | Uses Match |
|-------|---------------|------------|
| `SessionStart` | Session begins or resumes | No |
| `UserPromptSubmit` | User submits a prompt | No |
| `PreToolUse` | Before tool execution | Yes |
| `PermissionRequest` | Permission dialog appears | Yes |
| `PostToolUse` | After tool succeeds | Yes |
| `PostToolUseFailure` | After tool fails | Yes |
| `SubagentStart` | Spawning a subagent | No |
| `SubagentStop` | Subagent finishes | No |
| `Stop` | Claude finishes responding | No |
| `PreCompact` | Before context compaction | Yes |
| `SessionEnd` | Session terminates | No |
| `Notification` | Claude sends notifications | Yes |
| `Setup` | `--init`, `--init-only`, `--maintenance` | Yes |

## Configuration Structure

Hooks are configured in settings files:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolPattern",
        "hooks": [
          {
            "type": "command",
            "command": "your-command-here",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

### Configuration Fields

| Field | Description |
|-------|-------------|
| `matcher` | Pattern to match tool names (supports regex, `*` for all) |
| `type` | `"command"` for bash, `"prompt"` for LLM-based |
| `command` | Bash command to execute |
| `prompt` | Prompt for LLM evaluation (when `type: "prompt"`) |
| `timeout` | Optional timeout in seconds (default: 60) |
| `once` | Run only once per session (skills only) |

## Common Matchers

**Tools:**
- `Bash` - Shell commands
- `Edit\|Write` - File editing
- `Read` - File reading
- `Task` - Subagent tasks
- `Glob` - File pattern matching
- `Grep` - Content search
- `mcp__.*__.*` - MCP tools

**Notification types:**
- `permission_prompt` - Permission requests
- `idle_prompt` - Waiting for user input
- `auth_success` - Authentication success
- `elicitation_dialog` - MCP tool elicitation

**Setup triggers:**
- `init` - From `--init` or `--init-only`
- `maintenance` - From `--maintenance`

**SessionStart sources:**
- `startup` - New session
- `resume` - From `--resume`, `--continue`, `resume`
- `clear` - After `/clear`
- `compact` - After compaction

## Exit Code Behavior

| Exit Code | Behavior |
|-----------|----------|
| 0 | Success - stdout shown in verbose mode |
| 2 | Blocking error - stderr shown to Claude, blocks action |
| Other | Non-blocking - stderr shown in verbose mode, continues |

**Exit code 2 behavior by event:**
- `PreToolUse` - Blocks tool call
- `PermissionRequest` - Denies permission
- `PostToolUse` - Shows to Claude (already ran)
- `UserPromptSubmit` - Blocks prompt, erases it
- `Stop`/`SubagentStop` - Blocks stoppage

## Non-Blocking Prompt-Path Hooks

`UserPromptSubmit`, `SessionStart`, and advisory `Stop` hooks run on the interaction path. They must not fail closed unless they intentionally return a documented blocking decision.

**MUST** make recoverable hook failures exit `0`.

```bash
set -euo pipefail
trap 'exit 0' ERR
```

**MUST** reassert the non-blocking `ERR` trap after sourcing shared libraries. Sourced shell libraries can install their own traps and replace the hook's top-level trap.

```bash
set -euo pipefail
trap 'exit 0' ERR

source "$DEVOS_DIR/scripts/lib/some-shared-lib.sh"

# Reassert after all sourcing so library traps cannot make the prompt hook fail closed.
trap 'exit 0' ERR
```

**MUST** add a regression test when fixing any prompt-path hook failure. The test should reproduce the environmental condition that caused the failure, not only the happy path.

Examples of environmental conditions to model:
- mixed macOS GNU/BSD command availability
- sourced library trap overrides
- missing optional dependencies
- missing runtime state files

## JSON Output Format

Hooks can return structured JSON (exit code 0):

```json
{
  "continue": true,
  "stopReason": "string",
  "suppressOutput": true,
  "systemMessage": "string"
}
```

### PreToolUse Decision Control

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "reason",
    "updatedInput": {
      "field_to_modify": "new value"
    },
    "additionalContext": "context for Claude"
  }
}
```

### PostToolUse Feedback

```json
{
  "decision": "block",
  "reason": "explanation",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "additional information"
  }
}
```

### UserPromptSubmit Control

```json
{
  "decision": "block",
  "reason": "explanation",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "additional context"
  }
}
```

**Note:** Plain text stdout (non-JSON) with exit code 0 also adds context.

### Stop/SubagentStop Control

```json
{
  "decision": "block",
  "reason": "must continue because..."
}
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `$CLAUDE_PROJECT_DIR` | Absolute path to project root |
| `$CLAUDE_PLUGIN_ROOT` | Plugin directory (plugin hooks) |
| `$CLAUDE_ENV_FILE` | File path for persisting env vars (SessionStart only) |
| `$CLAUDE_CODE_REMOTE` | `"true"` in web environment, not set locally |

## Prompt-Based Hooks

LLM-based hooks use `type: "prompt"`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Evaluate if Claude should stop: $ARGUMENTS",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Response schema:**
```json
{
  "ok": true,
  "reason": "explanation when false"
}
```

**Best practices:**
- Be specific in prompts
- Include decision criteria
- Set appropriate timeouts
- Use for complex decisions (bash is better for simple rules)

## Hooks in Skills

Skills can define hooks in frontmatter (scoped to skill lifecycle):

```yaml
---
name: secure-operations
description: Perform operations with security checks
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
          once: true
---
```

**Supported events in skills:** `PreToolUse`, `PostToolUse`, `Stop`
**Additional option:** `once: true` runs hook only once per session

## Security Best Practices

1. **Validate inputs** - Never trust input blindly
2. **Quote variables** - Use `"$VAR"` not `$VAR`
3. **Block path traversal** - Check for `..` in paths
4. **Use absolute paths** - Or `$CLAUDE_PROJECT_DIR`
5. **Skip sensitive files** - Avoid `.env`, `.git/`, keys
6. **Review before adding** - Test in safe environment

## Common Hook Patterns

### Code Formatting

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "jq -r '.tool_input.file_path' | grep -q '\\.ts$' && npx prettier --write \"$file_path\""
      }]
    }]
  }
}
```

### Command Logging

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "jq -r '\"\\(.tool_input.command) - \\(.tool_input.description // \"No description\")\"' >> ~/.claude/bash-command-log.txt"
      }]
    }]
  }
}
```

### File Protection

```python
#!/usr/bin/env python3
import json, sys

data = json.load(sys.stdin)
path = data.get('tool_input', {}).get('file_path', '')

# Block edits to sensitive files
if any(p in path for p in ['.env', 'package-lock.json', '.git/']):
    sys.exit(2)  # Exit code 2 = blocking error
```

### Notification Hook

```json
{
  "hooks": {
    "Notification": [{
      "matcher": "idle_prompt",
      "hooks": [{
        "type": "command",
        "command": "notify-send 'Claude Code' 'Awaiting your input'"
      }]
    }]
  }
}
```

## Project-Specific Scripts

Use `$CLAUDE_PROJECT_DIR` for project hooks:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check-style.sh"
      }]
    }]
  }
}
```

## Hook Input Schema

All hooks receive JSON via stdin:

```typescript
{
  session_id: string
  transcript_path: string
  cwd: string
  permission_mode: string
  hook_event_name: string
  // Event-specific fields...
}
```

### Bash Tool Input

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "psql -c 'SELECT * FROM users'",
    "description": "Query users table",
    "timeout": 120000,
    "run_in_background": false
  }
}
```

### Write Tool Input

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.txt",
    "content": "file content"
  }
}
```

## Execution Details

- **Timeout:** 60 seconds default (configurable per hook)
- **Parallelization:** All matching hooks run in parallel
- **Deduplication:** Identical commands deduplicated automatically
- **Environment:** Claude Code's environment with additional vars
- **Input:** JSON via stdin
- **Output:** Depends on event type (see Exit Code Behavior)

## Troubleshooting

1. **Check config** - Run `/hooks` to verify registration
2. **Verify syntax** - Ensure valid JSON
3. **Test commands** - Run manually first
4. **Check permissions** - Make scripts executable
5. **Review logs** - Use `claude --debug`

Common issues:
- Unescaped quotes in JSON - use `\"`
- Wrong matcher - case-sensitive
- Command not found - use full paths
