# Source Reality Check

Verifies that each gap, requirement, or task in a spec still corresponds to missing or incomplete
code on disk before tasks are created. Prevents writing tasks for work that is already done.

## When to Use

Referenced by:
- `create-tasks-list.md` — Step 1c (after spec analysis, before pre-implementation reviews)
- `planning-pipeline.md` — Phase 8 gate (before create-tasks writes tasks.md)



Do not use this workflow to verify runtime behavior — it checks source-to-task alignment only. For runtime verification, use `verify`.

## Process

## Process

1. Read the list of open tasks from `tasks.md`.
2. For each task, grep source files to confirm implementation evidence exists.
3. Flag tasks that lack source evidence as unverified.
4. Report: tasks confirmed in source vs tasks with no source evidence.

### Step 1: Extract Claims from Spec

Read `product/specs/[this-spec]/spec.md` (and `planning/requirements.md` if present). Collect:

- Named files, modules, functions, or classes the spec says need to be created or modified
- Feature flags, config keys, or environment variables the spec references
- Named UI components, routes, or API endpoints the spec proposes
- Any statement like "add X to Y", "create Z", "implement W", "wire in Q"

Record each as a **claim**: a falsifiable statement about what does not yet exist.

### Step 2: Grep Source Files for Each Claim

For each claim, run a targeted search of the actual codebase. The goal is to determine:
- **Already implemented** — code that satisfies the claim already exists
- **Partially implemented** — some parts exist, others do not
- **Not yet implemented** — no evidence on disk

Use these search patterns (adapt to the project's tech stack):

```bash
# Function or method claim
grep -r "function claimName\|def claim_name\|claimName(" src/ scripts/ --include="*.{sh,ts,js,py}" -l

# File or module claim
ls path/to/claimed/file 2>/dev/null && echo "exists" || echo "missing"

# Config key or env var claim
grep -r "CLAIMED_KEY\|claimedKey" . --include="*.{yml,yaml,json,env,toml}" -l

# Route or endpoint claim
grep -r "'/claimed/route'\|\"claimed/route\"\|/claimed-route" src/ --include="*.{ts,js,py,rb}" -l

# UI component claim
find . -name "ClaimedComponent.*" -not -path "*/node_modules/*" 2>/dev/null
```

Record each claim's result: `exists` | `partial` | `missing`.

### Step 3: Classify Results

| Status | Definition | Action |
|--------|-----------|--------|
| `missing` | No code on disk for this claim | Keep in task list — valid work item |
| `partial` | Some code exists but the claim is not fully satisfied | Keep in task list — note what exists |
| `exists` | Code fully satisfies the claim | **Exclude from task list** — mark as pre-resolved |

### Step 4: Report Findings

Display a summary before proceeding to pre-implementation reviews:

```
--- Source Reality Check ---
Spec: [spec-name]
Claims checked: N

✅ Already implemented (exclude from tasks): N
  - [claim description] → found at [file:line]

⚠️  Partially implemented (keep, note existing code): N
  - [claim description] → partial: [what exists] / [what is missing]

🔲 Not yet implemented (keep in tasks): N
  - [claim description]
----------------------------
```

If **all claims are already implemented**, halt and display:

```
⚠️  Source Reality Check: All spec claims appear to be already implemented.
No tasks need to be created. Review the spec — it may describe existing behavior.
If this is intentional (e.g., a refactor spec), run create-tasks --skip-source-check to proceed.
```

If **no already-implemented claims** are found, display:

```
Source Reality Check: Clean — all claims are unimplemented. Proceeding to task creation.
```

### Step 5: Prune the Task Draft

When generating `tasks.md`, skip tasks that directly correspond to claims marked `exists`.

For claims marked `partial`, add a note in the task description:

```
- [ ] 2.3 Implement [X]
  Note: [file path] already exists with [partial implementation]. Task covers the missing [remaining part].
```

## Skip Condition

Pass `--skip-source-check` to bypass this step entirely. Use only when:
- The spec is a refactor (existing code is intentionally replaced, not preserved)
- The spec explicitly calls out that it updates existing behavior
- A previous run of this check produced a clean result in this session

When skipped, write `<!-- source_reality_check: skipped -->` at the top of `tasks.md`.

## Scope

This check is **fast and targeted** — it does not do exhaustive code search. It checks only the
claims explicitly named in the spec. It is NOT a code coverage tool or a test suite. The goal is
to catch the common case: a gap was identified, someone fixed it informally, and the spec was
never updated.

**Time budget:** < 2 minutes for a typical spec with 5–15 claims. If the spec has 30+ claims,
check only CRITICAL and HIGH priority claims (as labelled in the gap-analysis-report or spec).

## Display Format

```
Source Reality Check
  Tasks checked: [N]
  Source confirmed: [N]
  Gaps found: [N] — [list | none]
  Status: [clean | [N] tasks lack source evidence]
```
