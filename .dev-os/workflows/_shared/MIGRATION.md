# Workflow Snippet Migration Guide

This guide helps profile authors migrate existing workflows to use shared snippets.

## When to Use

- Migrating existing workflows to use `{{include}}` shared snippets
- Extracting repeated content from multiple workflows into `_shared/`
- Onboarding new profile authors to the snippet system

**Not for:** Creating new workflows from scratch (use `bx-workflow-creator`), or editing snippet content (edit the snippet file directly).

## Overview

Shared snippets reduce duplication by extracting common patterns into reusable components. The `{{include}}` directive allows workflows to reference these shared snippets.

## Path Compatibility Notes

- Canonical workspace paths use `product/specs/...`.
- Legacy `specs/...` paths are compatibility fallback only and should not be used in new active workflows.
- Keep any legacy-path mentions limited to migration/reference documentation like this guide.

## Migration Process

### Step 1: Identify Shared Content

Look for patterns that appear in multiple workflows:

1. **Read related workflows** in a category (e.g., all git workflows)
2. **Identify repeated sections** - Look for identical or similar content
3. **Note the context** - Is the content truly shared or workflow-specific?

### Step 2: Extract to Snippet

Create a new snippet file in `profiles/general/workflows/_shared/`:

```bash
# Determine the appropriate subdirectory
# - git/ for git-related patterns
# - recovery/ for recovery patterns
# - error-handling/ for error patterns
# - status-checking/ for status patterns

# Create the snippet file
profiles/general/workflows/_shared/[category]/[snippet-name].md
```

**Snippet Template:**

```markdown
## [Snippet Title]

[Brief description of what this snippet provides]

### Usage

[When to use this snippet]

### Code

```bash
# Bash code or markdown content
```

### Notes

[Any important notes about this snippet]
```

### Step 3: Replace with Include

Replace the duplicated content in source workflows with:

```markdown
{{include workflows/_shared/[category]/[snippet-name]}}
```

**Example - Before:**

```markdown
# My Workflow

## Check Git Status

Always check git status before proceeding:

```bash
git status --porcelain
```

If the working directory is dirty, ask the user what to do.
```

**Example - After:**

```markdown
# My Workflow

{{include workflows/_shared/git/git-status-check}}
```

### Step 4: Test Compilation

Verify the template processor correctly expands includes:

```bash
# Run the include processing tests
bash scriptstests/template-processor/include-processing-test.sh
```

### Step 5: Validate References

Run profile validation to check all include references:

```bash
bash scriptsvalidate-profile.sh --profile general
```

## Examples

### Example 1: Git Status Check

**Original Content (in 3 workflows):**

```markdown
## Git Status Check

```bash
git status --porcelain
```

If there are uncommitted changes, ask the user to commit, stash, or discard.
```

**Migration:**

1. **Create snippet:** `profiles/general/workflows/_shared/git/git-status-check.md`
2. **Replace in workflows:** `{{include workflows/_shared/git/git-status-check}}`
3. **Result:** 3 workflows now reference the same snippet

### Example 2: Error Table Format

**Original Content (in multiple workflows):**

```markdown
## Error Cases

| Case | Handling |
|------|----------|
| File not found | Report error and exit |
| Invalid input | Show usage |
```

**Migration:**

1. **Create snippet:** `profiles/general/workflows/_shared/error-handling/error-handling-table.md`
2. **Add error cases** - Include the table format and common patterns
3. **Replace in workflows:** `{{include workflows/_shared/error-handling/error-handling-table}}`

### Example 3: Progress Calculation

**Original Content (in 2 workflows):**

```bash
# Count tasks
total_tasks=$(grep -c "^\- \[[ x]\]" "$tasks_file")
completed_tasks=$(grep -c "^\- \[x\]" "$tasks_file")

# Calculate percentage
if [ "$total_tasks" -gt 0 ]; then
    progress_percent=$((completed_tasks * 100 / total_tasks))
else
    progress_percent=0
fi
```

**Migration:**

1. **Create snippet:** `profiles/general/workflows/_sharedstatus-checking/progress-calculation.md`
2. **Add functions** - Include task counting and percentage calculation functions
3. **Replace in workflows:** `{{include workflows/_shared/status-checking/progress-calculation}}`

## Regression Testing

After migration, verify workflows produce the same output:

### 1. Save Baseline

Before migrating, save the current workflow content:

```bash
# Create baseline directory
mkdir -p .baseline/workflows

# Copy current workflows
cp -r profiles/general/workflows/* .baseline/workflows/
```

### 2. Apply Migration

Migrate workflows to use includes as described above.

### 3. Compare Output

The template processor should produce identical output:

```bash
# For workflows, the include expansion happens during compilation
# Compare the expanded output with baseline content

# The key is that workflow behavior remains identical
```

## Common Patterns

Here are common patterns to extract:

### Git Operations
- Status checking - `git-status-check.md`
- Branch operations - `branch-operations.md`
- Commit message format - `commit-message-format.md`

### Error Handling
- Error table format - `error-handling-table.md`
- Return codes - `return-codes.md`
- Edge case handling - `edge-case-handling.md`

### Status Checking
- Git state validation - `git-state-validation.md`
- Progress calculation - `progress-calculation.md`
- Timestamp formatting - `timestamp-formatting.md`

### Recovery
- Provider detection - `provider-detection.md`
- Session metadata - `session-metadata.md`
- Recovery routing - `recovery-routing.md`

## Best Practices

### DO

- Keep snippets focused on a single concept
- Use descriptive, hyphenated names
- Group related snippets in subdirectories
- Document snippet purpose and usage
- Include code examples in snippets
- Validate all include references

### DON'T

- Create snippets for workflow-specific content
- Make snippets too complex or broad
- Include workflow-specific context
- Use unclear abbreviations in names
- Skip testing after migration

## Troubleshooting

### Include Not Found

**Error:** `⚠️ This snippet file was not found`

**Solution:** Check the path in the `{{include}}` directive:
- Must start with `workflows/_shared/`
- Path is relative to the profile's workflows directory
- File extension (.md) is implied

### Circular Include Warning

**Error:** `⚠️ Circular include detected`

**Solution:** Check for circular references:
- Snippet A includes snippet B
- Snippet B includes snippet A
- Break the cycle by extracting shared content to a third snippet

### Depth Limit Exceeded

**Error:** `Maximum include depth (10) exceeded`

**Solution:** Reduce nesting depth:
- Refactor deeply nested includes
- Extract common content to reduce nesting
- Consider if the complexity is necessary

## Profile Inheritance

Child profiles can override parent snippets:

### Parent Profile (general)

```
profiles/general/workflows/_shared/git/commit-message-format.md
```

### Child Profile (custom)

```
profiles/custom/workflows/_shared/git/commit-message-format.md
```

The child profile's snippet will be used instead of the parent's when the `custom` profile is active.

## Display Format

```
Migration complete:
  Extracted: _shared/<category>/<snippet>.md (N lines)
  Replaced in: <count> workflow(s)
  Include directive: {{include workflows/_shared/<category>/<snippet>}}
```

## Summary

1. **Identify** shared content across workflows
2. **Extract** to a new snippet in `_shared/`
3. **Replace** duplicated content with `{{include}}`
4. **Test** that includes expand correctly
5. **Validate** all references exist
6. **Verify** workflow behavior is unchanged

For questions or issues, refer to the main README or run `validate-profile.sh --help`.
