# Detect Plan Type Workflow

Identifies the type and source of a plan file to determine appropriate recovery strategy.

## When to Use

This workflow is invoked:
1. By `recover` command to classify each discovered session
2. By workspace plan discovery to filter relevant plans


Do not invoke directly — this is called by `recover` and `discover-workspace-plans`. Do not use to classify non-session plan files.
## Process

### Step 1: Provider-Based Source Detection

{{include workflows/_shared/recovery/provider-detection}}

### Step 2: Extract Metadata

{{include workflows/_shared/recovery/session-metadata}}

### Step 3: Output Session Data

Return structured data for display:

```bash
# Output as space-delimited for parsing
echo "$source_type|$title|$path|$mtime|$time_ago_str|$status|$plan_file"
```

## Integration

```markdown
{{workflows/recovery/detect-plan-type}}

[Parse output and build session list]
{{workflows/recovery/present-recovery-options}}
```

## Display

Plan type classification result (pipe-delimited):

```
[source_type]|[title]|[path]|[mtime]|[time_ago]|[status]|[plan_file]
```
