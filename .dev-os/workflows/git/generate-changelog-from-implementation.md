# Generate Changelog from Implementation

Generate comprehensive changelog entries based on actual implementation vs original specification.

## When to Use

This workflow is invoked during feature merge (Step 5.2 of merge-branch.md), AFTER doc-scan but BEFORE update-changelog finalization.


Do not use this workflow when the changelog already reflects the current commits, or when generating a changelog for an unreleased draft spec.

## Process

### Step 1: Gather Context

```bash
# Get the spec name from current branch
spec_name=$(git branch --show-current | sed 's/feature\///')

# Get the base branch merge point for diff
merge_base=$(git merge-base HEAD main)

# Read the original spec
spec_file="product/specs/${spec_name}/spec.md"
```

### Step 2: Analyze Git Diff

Analyze what was actually implemented:

```bash
# Get list of changed files
changed_files=$(git diff --name-only ${merge_base} HEAD)

# Get summary of changes by type
added_files=$(git diff --diff-filter=A --name-only ${merge_base} HEAD)
deleted_files=$(git diff --diff-filter=D --name-only ${merge_base} HEAD)
modified_files=$(git diff --diff-filter=M --name-only ${merge_base} HEAD)

# Get commit messages for context
commits=$(git log ${merge_base}..HEAD --pretty=format:"%h %s")
```

### Step 3: Compare Against Original Spec

```bash
# Read spec requirements
requirements=$(grep -A 100 "## Requirements" "${spec_file}" 2>/dev/null || echo "")

# Identify gaps between spec and implementation
# - Features in spec but not implemented
# - Features implemented but not in spec (scope creep)
# - Features implemented differently than specified
```

### Step 4: Invoke Changelog Skill

Use the changelog-generator skill to generate user-friendly entries:

**Call the changelog-generator skill with the following context:**
- Git diff from `${merge_base}` to HEAD
- Commit messages: `${commits}`
- Spec name: `${spec_name}`
- Original requirements from spec.md

**Expected output:**
- Keep-a-Changelog format entries categorized by Added, Changed, Fixed, Breaking
- User-facing language (not implementation details)
- Feature descriptions that highlight value to users

**Integration:**
- Entries will be written to CHANGELOG.md [Unreleased] section
- Used by update-changelog.md workflow for finalization

### Step 5: Generate Changelog Entry

Create a comprehensive changelog entry in the [Unreleased] section:

```markdown
## [Unreleased]

### Added
- [Feature 1] - User-facing description
- [Feature 2] - User-facing description

### Changed
- [Change 1] - User-facing description
- [Change 2] - User-facing description

### Fixed
- [Bug fix 1] - User-facing description

### Breaking
- [Breaking change] - Description with migration notes
```

### Step 6: Comparison Report

Generate a spec vs implementation comparison:

```markdown
# Implementation vs Spec Comparison

**Spec:** [spec-name]
**Date:** [ISO 8601 date]

## Spec Requirements Delivered

| Requirement | Status | Notes |
|-------------|--------|-------|
| [Req 1] | ✅ Delivered | As specified |
| [Req 2] | ✅ Delivered | Modified for [reason] |
| [Req 3] | ⚠️ Partial | P2/P3 deferred |
| [Req 4] | ❌ Not Delivered | [Reason] |

## Scope Additions (Not in Original Spec)

| Addition | Rationale |
|----------|-----------|
| [Feature] | [Why it was added] |

## Implementation Notes

- Total commits: [X]
- Files changed: [X]
- Lines added: [X]
- Lines removed: [X]
```

Save to: `product/specs/${spec_name}/verification/implementation-report.md`

## Output

Return to merge-branch workflow with:
1. Changelog entries ready for finalization in CHANGELOG.md
2. Implementation comparison report generated
3. Any discrepancies flagged for user review

## Example

```
📊 Changelog Generated from Implementation

Spec: user-authentication
Merge base: abc1234..HEAD

Changes analyzed:
- 12 commits
- 45 files changed
- 1,234 additions(+)
- 89 deletions(-)

Changelog entries added to [Unreleased]:
- ✅ User authentication with login form
- ✅ OAuth provider integration
- ✅ Session token expiration fix

Implementation report: product/specs/user-authentication/verification/implementation-report.md
```
