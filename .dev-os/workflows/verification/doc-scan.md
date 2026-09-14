# Documentation Scan Workflow

Scans the project before merge to verify tasks are complete and documentation is current.

## When to Use

This workflow is invoked during `merge-feature` before the changelog is finalized.

Do not use to fix documentation — this workflow reports discrepancies only. Do not use as a substitute for `docs-sync`, which applies the fixes.

## Process

### Step 1: Read Tasks and Check Completion

Read the tasks file to verify all tasks are complete:

```bash
# Get the spec name from current branch
spec_name=$(git branch --show-current | sed 's/feature\///')

# Read tasks.md
tasks_file="product/specs/${spec_name}/tasks.md"

# Check for incomplete tasks
incomplete_tasks=$(grep -c "^- \[ \]" "$tasks_file" || echo "0")
total_tasks=$(grep -c "^- \[" "$tasks_file" || echo "0")
```

**Task completion criteria:**
- All parent tasks must be checked `- [x]`
- Sub-tasks may be incomplete if parent is complete
- If tasks.md doesn't exist, warn user but don't block

### Step 2: Scan Documentation Files

Check if documentation exists and is current:

```bash
# Check for documentation files
spec_dir="product/specs/${spec_name}"
docs=(
    "${spec_dir}/spec.md"
    "${spec_dir}/QUICKSTART.md"
    "${spec_dir}/ARCHITECTURE.md"
    "${spec_dir}/CHECKLIST.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo "Found: $doc"
        # Check if file was recently modified
        last_modified=$(stat -f "%Sm" -t "%Y-%m-%d" "$doc")
        echo "  Last modified: $last_modified"
    fi
done
```

### Step 3: Verify Code Against Documentation

Scan the codebase to verify implementation matches documentation:

1. **Identify implemented components:**
   - New files added in this feature
   - Modified files
   - New endpoints, routes, or functions

2. **Compare with spec:**
   - Does spec.md describe all implemented components?
   - Are API endpoints documented?
   - Are data models documented?
   - Are new UI components documented?

3. **Flag discrepancies:**

| Issue Type | Description | Example |
|------------|-------------|---------|
| Missing Documentation | Code exists without docs | New endpoint not in spec |
| Outdated Documentation | Docs don't match code | Spec describes feature not implemented |
| Incomplete Documentation | Partial docs | API listed but parameters missing |

### Step 4: Generate Verification Report

Create a verification report:

```bash
# Create verification directory
mkdir -p "product/specs/${spec_name}/verification"

# Write report
report_file="product/specs/${spec_name}/verification/merge-verification.md"
```

**Report format:**

```markdown
# Merge Verification Report

**Spec:** [spec-name]
**Date:** [ISO 8601 date]
**Phase:** Pre-Merge Verification

## Task Completion

**Status:** ✅ All complete / ⚠️ [X] incomplete tasks

- Total tasks: [X]
- Completed: [X]
- Incomplete: [X]

**Incomplete tasks:**
- [List any incomplete tasks]

## Documentation Status

**Status:** ✅ Current / ⚠️ Issues found

### Documentation Files Found

- ✅ spec.md - Last updated: [date]
- ✅ QUICKSTART.md - Last updated: [date]
- ❌ ARCHITECTURE.md - Not found
- ⚠️ CHECKLIST.md - Outdated (last updated: [old date])

### Discrepancies Found

**[X] issues detected:**

1. [Issue description]
   - Location: [file/line]
   - Severity: Critical/High/Medium/Low
   - Recommendation: [what to do]

## Summary

### Ready to Merge?

**Tasks:** ✅ Yes / ⚠️ No
**Documentation:** ✅ Yes / ⚠️ No

### Recommendation

[PROCEED] / [ADDRESS ISSUES] / [REVIEW MANUALY]

### Configuration

Current settings:
- merge_doc_scan: true
- merge_require_all_tasks: [true/false]
- merge_doc_warnings_only: [true/false]
```

### Step 5: User Confirmation

After generating the report, display summary and wait for user response:

```
📋 Pre-Merge Verification Complete

Spec: [spec-name]

Tasks: ✅ All complete / ⚠️ [X] incomplete
Documentation: ✅ Current / ⚠️ [X] issues found

Full report: product/specs/[spec]/verification/merge-verification.md
```

**If blocking issues exist:**
```
⚠️ Blocking issues detected. Please address before merging:

- [Issue 1]
- [Issue 2]

Type "continue" to proceed anyway, or describe fixes needed.
```

**If warnings only:**
```
ℹ️ Non-blocking issues found. Review the report if desired.

Type "continue" to proceed with merge.
```

**If all clear:**
```
✅ All checks passed. Ready to merge!

Type "continue" to proceed.
```

---

## Configuration Settings

These settings in `config.yml` control verification behavior:

```yaml
# Verification Settings
merge_doc_scan: true                # Enable doc scanning on merge
merge_require_all_tasks: true       # Block merge if tasks incomplete
merge_doc_warnings_only: false      # If true, don't block on doc issues
```

### Behavior Matrix

| `merge_doc_scan` | `merge_require_all_tasks` | `merge_doc_warnings_only` | Result |
|------------------|---------------------------|---------------------------|--------|
| true | true | false | Block on incomplete tasks OR doc issues |
| true | true | true | Block on incomplete tasks only, warn on docs |
| true | false | false | Warn on all issues, never block |
| false | - | - | Skip verification entirely |

---

## Exit Conditions

### Proceed with Merge

User types "continue" or similar affirmation:
- Return to merge workflow
- Continue with changelog finalization

### User Requests Changes

User describes issues to fix:
- Provide guidance on what needs to be done
- Do NOT automatically make changes
- Wait for user to fix and re-run verification

### User Cancels

User wants to cancel merge:
- Exit merge workflow
- Return to feature branch
- Do not make any changes

---

## Edge Cases

| Case | Handling |
|------|----------|
| tasks.md doesn't exist | Warning: "No tasks.md found" |
| tasks.md empty | Warning: "tasks.md is empty" |
| spec.md doesn't exist | Block merge - critical documentation missing |
| All docs missing | Warning only if `merge_doc_warnings_only: true` |
| Quick-fix branch | Skip verification (different workflow) |
| MVP merge (partial completion) | Verify only P1 tasks are complete |

---

## Notes

- This verification runs BEFORE changelog finalization
- The report is saved in the spec's verification folder
- Blocking behavior is configurable via config settings
- Quick-fix workflows bypass this verification entirely

## Display

Doc scan report:

```
Documentation Scan — [project]
  WRONG:   [N] (incorrect counts / versions)
  MISSING: [N] (items in code, not in docs)
  STALE:   [N] (items in docs, removed from code)
  → Run docs-sync to fix
```
