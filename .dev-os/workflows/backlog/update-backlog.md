# Update Feature Backlog Workflow

Maintains an auto-updated `product/specs/feature-backlog.md` file that tracks all specs with their status, tasks, and priorities.

## When to Use

This workflow is invoked:
1. After `write-spec` completes - Add new spec to backlog
2. After `create-tasks` completes - Update with task counts
3. After `implement-tasks` completes all tasks - Mark as implementation complete
4. After `merge-feature` completes - Mark as completed


Do not invoke directly to read or view the backlog — use `project-status --all` for that. Do not use to create new specs; use `write-spec` instead.
## Backlog Location

`product/specs/feature-backlog.md` in the project root

## Backlog Format

```markdown
# Feature Backlog

Last updated: [ISO 8601 date]

## In Progress

### [spec-name] - Priority: High
- **Status:** [status description]
- **Created:** [creation date]
- **Tasks:** [X] tasks across [X] groups
- **Link:** [spec.md](product/specs/[spec-name]/spec.md)

## Ready for Implementation

### [spec-name] - Priority: Medium
- **Status:** Spec written, awaiting tasks
- **Created:** [creation date]
- **Tasks:** TBD
- **Link:** [spec.md](product/specs/[spec-name]/spec.md)

## Completed

### [spec-name] - Priority: High
- **Status:** Merged to main
- **Created:** [creation date]
- **Completed:** [completion date]
- **Tasks:** [X] tasks completed
- **Link:** [spec.md](product/specs/[spec-name]/spec.md)

## Quick Fixes

- [date] [description] (quick-fix)
```

## Process

### Step 1: Read Current Backlog

```bash
# Check if backlog exists
if [ -f "product/specs/feature-backlog.md" ]; then
    cat product/specs/feature-backlog.md
else
    # Create new backlog with header
    echo "# Feature Backlog" > product/specs/feature-backlog.md
fi
```

### Step 2: Determine Trigger Context

Identify which workflow phase is calling this:

| Calling Context | Action |
|-----------------|--------|
| `write-spec` just completed | Add new entry under "Ready for Implementation" |
| `create-tasks` just completed | Move to "In Progress", add task count |
| `implement-tasks` all tasks done | Update status to "Implementation complete — pending merge" |
| `merge-feature` just completed | Move to "Completed", add completion date |
| `quick-fix` just completed | Add entry to "Quick Fixes" section |

### Step 3: Extract Spec Information

Read the spec to gather backlog data:

```bash
# Get spec name from current context
spec_name="[current-spec]"

# Read spec.md for title
spec_title=$(grep "^# " product/specs/[spec_name]/spec.md | head -1)

# Read tasks.md if exists for task count
if [ -f "product/specs/[spec_name]/tasks.md" ]; then
    task_groups=$(grep "^### Task Group" product/specs/[spec_name]/tasks.md | wc -l)
    total_tasks=$(grep "^- \[" product/specs/[spec_name]/tasks.md | wc -l)
fi

# Get creation date from file timestamp
created_date=$(stat -c "%y" product/specs/[spec_name]/spec.md | cut -d' ' -f1)
```

### Step 4: Determine Priority

Priority is determined by:

1. **User-specified priority** in requirements.md (if present)
2. **Roadmap priority** from product/roadmap.md (if exists)
3. **Default:** Medium

Priority levels: Critical, High, Medium, Low

### Step 5: Update Backlog

Based on the calling context:

#### Context A: After write-spec (New Spec)

Add entry under "Ready for Implementation":

```markdown
## Ready for Implementation

### [spec-name] - Priority: [High/Medium/Low]
- **Status:** Spec written, awaiting tasks
- **Created:** [YYYY-MM-DD]
- **Tasks:** TBD
- **Link:** [spec.md](product/specs/[spec-name]/spec.md)
```

#### Context B: After create-tasks (Tasks Created)

Move entry from "Ready for Implementation" to "In Progress", add task details:

```markdown
## In Progress

### [spec-name] - Priority: [High/Medium/Low]
- **Status:** Task creation complete, implementation in progress
- **Created:** [YYYY-MM-DD]
- **Tasks:** [X] tasks across [X] groups
- **Link:** [spec.md](product/specs/[spec-name]/spec.md)
```

#### Context C: After implement-tasks (All Tasks Done)

Update the "In Progress" entry to reflect implementation is complete but not yet merged:

```markdown
## In Progress

### [spec-name] - Priority: [High/Medium/Low]
- **Status:** Implementation complete — pending merge-feature
- **Created:** [YYYY-MM-DD]
- **Tasks:** [X] tasks completed
- **Link:** [spec.md](product/specs/[spec-name]/spec.md)
```

#### Context D: After merge-feature (Completed)

Move entry from "In Progress" to "Completed", add completion date:

```markdown
## Completed

### [spec-name] - Priority: [High/Medium/Low]
- **Status:** Merged to main
- **Created:** [YYYY-MM-DD]
- **Completed:** [YYYY-MM-DD]
- **Tasks:** [X] tasks completed
- **Link:** [spec.md](product/specs/[spec-name]/spec.md)
```

#### Context E: After quick-fix (Quick Fix)

Add to "Quick Fixes" section:

```markdown
## Quick Fixes

- [YYYY-MM-DD] [brief description] (quick-fix)
```

### Step 6: Handle Special Cases

#### MVP Mode

If implementing in MVP mode, append to status:

```markdown
- **Status:** MVP shipped to main, P2/P3 tasks pending
```

#### Spec Deleted

If a spec folder is removed during backlog update:
- Add note: `(Spec removed)`
- Move to "Completed" with removal note
- Or remove entry entirely (after confirmation)

#### Duplicate Entries

If spec already exists in a section:
- Update the existing entry instead of creating duplicate
- Move to appropriate section if status changed

### Step 7: Commit the Update

After updating the backlog, commit the change:

```bash
git add product/specs/feature-backlog.md
git commit -m "chore: update feature backlog

- Updated [spec-name] status to [new-status]
- [additional notes]"
```

**Note:** This commit is separate from the main workflow commit to keep changelog clean.

---

## Backlog File Structure

```
product/specs/feature-backlog.md
├── Header (Last updated date)
├── In Progress (specs currently being built or implementation complete)
├── Ready for Implementation (specs written, awaiting tasks)
├── Completed (specs shipped to main)
└── Quick Fixes (small changes via quick-fix)
```

---

## Example Backlog

```markdown
# Feature Backlog

Last updated: 2025-01-14

## In Progress

### [user-authentication] - Priority: High
- **Status:** Implementation in progress (Group 1/4 complete)
- **Created:** 2025-01-10
- **Tasks:** 12 tasks across 4 groups
- **Link:** [spec.md](product/specs/user-authentication/spec.md)

## Ready for Implementation

### [oauth-integration] - Priority: Medium
- **Status:** Spec written, awaiting tasks
- **Created:** 2025-01-12
- **Tasks:** TBD
- **Link:** [spec.md](product/specs/oauth-integration/spec.md)

### [user-notifications] - Priority: Low
- **Status:** Spec written, awaiting tasks
- **Created:** 2025-01-13
- **Tasks:** TBD
- **Link:** [spec.md](product/specs/user-notifications/spec.md)

## Completed

### [user-profile] - Priority: High
- **Status:** Merged to main
- **Created:** 2025-01-05
- **Completed:** 2025-01-08
- **Tasks:** 8 tasks completed
- **Link:** [spec.md](product/specs/user-profile/spec.md)

### [api-rate-limiting] - Priority: Critical
- **Status:** Merged to main
- **Created:** 2025-01-01
- **Completed:** 2025-01-03
- **Tasks:** 6 tasks completed
- **Link:** [spec.md](product/specs/api-rate-limiting/spec.md)

## Quick Fixes

- 2025-01-14 Fixed login redirect loop (quick-fix)
- 2025-01-12 Updated API timeout from 30s to 60s (quick-fix)
- 2025-01-10 Corrected typo in error message (quick-fix)
```

---

## Configuration

These settings in `config.yml` control backlog behavior:

```yaml
backlog_enabled: true              # Enable/disable backlog updates
backlog_path: product/specs/feature-backlog.md  # Custom path
backlog_auto_prioritize: true       # Use priority from roadmap if available
```

---

## Notes

- The backlog is a project-level view, not a replacement for specs
- Task counts are approximate (based on markdown checklist items)
- Dates are based on file timestamps, not manual entry
- The backlog is committed separately to avoid cluttering feature commits
- "In Progress" covers both active implementation AND implementation-complete-pending-merge states

## Display

After each update, confirm the change with:

```
Backlog updated: [spec-name] moved to [section] (status: [new-status])
File: product/specs/feature-backlog.md
```
## Lifecycle adapter

Backlog status and placement are projections, not completion evidence. Use the
shared lifecycle result and its format-preserving adapter:

```bash
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/spec-lifecycle.sh"
spec_lifecycle_evaluate "$PWD" plan update-backlog false "${USER:-unknown}" shell "<spec-slug>"
```

Mutating callers may apply only the returned `safe_repairs`; `spec_required` and
`manual_review` actions stay blocked for operator disposition.
