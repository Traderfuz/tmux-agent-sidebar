# Recovery Error Table Format

Shared snippet providing the standard error table for recovery workflows.

## When to Use

- Include in any recovery workflow that needs to document error cases and recovery actions
- Do not use as a standalone workflow — consumed via `{{include workflows/_shared/recovery/error-table-format}}`

## Process

### Step 1: Include this snippet in the recovery workflow's error handling section.

### Step 2: Extend the table with workflow-specific error cases as needed.

## Display Format

```
| Error | Cause | Recovery Action |
|-------|-------|-----------------|
| <case> | <root cause> | <action> |
```

## Error Table

| Error | Cause | Recovery Action |
|-------|-------|-----------------|
| Session not found | Selected file was moved/deleted | Re-run `recover --list` |
| Invalid selection | Index or path is invalid | Ask user to choose from listed sessions |
| Resume handler failed | Downstream workflow returned non-zero | Show handler output and preserve session for retry |
