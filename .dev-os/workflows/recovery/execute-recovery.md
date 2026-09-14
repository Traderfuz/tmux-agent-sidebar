# Execute Recovery Workflow

Routes the recovery request to the appropriate handler based on session type.

## When to Use

This workflow is invoked:
1. By `recover` command after user selection
2. After presenting recovery options


Do not use to resume a session that is not interrupted — use `resume` for that. Do not use when the session plan file no longer exists.
## Process

### Step 1: Parse Selection

{{include workflows/_shared/recovery/recovery-routing}}

### Step 2: Validate Selection

```bash
if [[ -z "$target_file" ]] || [[ ! -f "$target_file" ]]; then
    echo "❌ Session not found: $selection"
    echo ""
    echo "Use --list to see available sessions."
    return 1
fi

echo "🔄 Recovering session..."
echo ""
source_label=$(echo "$session_type" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
echo "Source: $source_label"
echo "File: $(format_plan_path "$target_file")"
echo ""
```

### Step 3: Route to Handler

```bash
case "$session_type" in
    agent-os|spec)
        # Use existing Agent OS resume workflow
        echo "Restoring Agent OS spec session..."
        echo ""

        # Set session file for restore-session
        export SESSION_FILE="$target_file"
        export SPEC_NAME=$(echo "$target_file" | sed 's|product/specs/\([^/]*\)/.*|\1|')

        # Delegate to existing restore-session workflow
        {{workflows/implementation/restore-session}}
        ;;

    claude-code|factory-droid|generic)
        # Continue plan directly
        echo "Continuing plan session..."
        echo ""

        # Set plan file for continue-plan workflow
        export PLAN_FILE="$target_file"
        export PLAN_SOURCE="$session_type"
        export PLAN_TITLE="$(extract_plan_title "$target_file")"

        # Delegate to continue-plan workflow
        {{workflows/recovery/continue-plan}}
        ;;

    *)
        echo "⚠️  Unknown session type: $session_type"
        echo ""
        echo "File: $target_file"
        echo ""
        echo "You can manually open this file to continue."
        return 1
        ;;
esac
```

### Step 4: Handle Recovery Result

```bash
recovery_result=$?

if [[ $recovery_result -eq 0 ]]; then
    echo ""
    echo "✅ Session recovered successfully"
else
    echo ""
    echo "⚠️  Recovery encountered an issue (code: $recovery_result)"
    return $recovery_result
fi
```

## Return Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Session not found |
| 2 | Invalid selection |
| 3 | Recovery failed (handler-specific) |

## Edge Cases

{{include workflows/_shared/recovery/error-table-format}}

## Integration

```markdown
{{workflows/recovery/present-recovery-options}}

[User provides selection]

{{workflows/recovery/execute-recovery}}

[Recovery completes]
```

## Display

Recovery execution result:

```
Recovery complete
  Session:  [title]
  Restored: [checkpoint-timestamp]
  Status:   [resumed | partial | failed]
  Next:     [next-action]
```
