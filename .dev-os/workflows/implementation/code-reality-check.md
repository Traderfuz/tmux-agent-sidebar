# Code Reality Check Workflow

Validates that artifact state (tasks.md checkboxes, backlog status, session-state) reflects actual
code on disk. Prevents status commands from reporting progress that only exists in markdown.

## When to Use

Referenced by:
- `show-progress-dashboard` — after every status display
- `triage` — as Scan 6 (code reality)
- `orchestrate` Navigator — before issuing a recommendation



Do not use this workflow to validate test results or deployment health — it checks git/artifact state only, not runtime behavior.

## Process

## Process

1. Establish baseline from git state (`git status --short`, `git diff --stat HEAD`, `git log -1`).
2. Read artifact state (tasks.md checkboxes, backlog status, session-state).
3. Compare artifact state to code state and identify drift.
4. Produce a reality-check report noting any stale entries.

### Step 1: Establish Baseline

Run these commands to read actual code state:

```bash
# Uncommitted changes (tracked files only)
git status --short

# Changed file count since last commit
git diff --stat HEAD

# Last commit SHA and message
git log -1 --oneline

# Commits on this branch not on main
git log main..HEAD --oneline 2>/dev/null || git log origin/main..HEAD --oneline 2>/dev/null
```

Record:
- `uncommitted_files` — count of lines from `git status --short`
- `changed_since_commit` — count of files from `git diff --stat HEAD`
- `branch_commits` — list of commits unique to this branch
- `current_branch` — `git branch --show-current`

### Step 2: Read Artifact State

For the active spec (or each spec in multi-spec mode):

```bash
tasks_file="product/specs/${spec_name}/tasks.md"
```

Count:
- `tasks_checked` — lines matching `^- \[x\]`
- `tasks_open` — lines matching `^- \[ \]`
- `total_tasks` — sum of above

Read `product/specs/feature-backlog.md` and find this spec's status line.

### Step 3: Cross-Check — Detect Discrepancies

Run each check and collect findings:

#### Check A: Completed tasks with no code evidence

Condition: `tasks_checked > 0` AND `branch_commits` is empty AND `uncommitted_files == 0`

Finding (High):
```
Tasks marked complete but no commits or uncommitted changes detected on this branch.
Artifact state may not reflect actual code. Run sync-completed-work to reconcile.
```

#### Check B: Significant uncommitted changes against unchecked tasks

Condition: `uncommitted_files > 5` AND `tasks_open > 0`

Finding (Medium):
```
{uncommitted_files} uncommitted file(s) detected alongside {tasks_open} open task(s).
Work may have been done outside the session system. Run sync-completed-work.
```

#### Check C: Backlog says "Completed" but tasks.md has open items

Condition: backlog status == "Completed" AND `tasks_open > 0`

Finding (Critical):
```
Backlog marks '{spec_name}' as Completed but tasks.md still has {tasks_open} open task(s).
Either update backlog status or reopen the spec.
```

#### Check D: Backlog says "In Progress" but branch has no commits

Condition: backlog status == "In Progress" AND `branch_commits` is empty AND `tasks_checked > 0`

Finding (Medium):
```
Backlog shows '{spec_name}' in progress, but no commits found on this branch.
Implementation may be uncommitted. Run git add + git commit.
```

#### Check E: All tasks checked but code has significant uncommitted changes

Condition: `tasks_open == 0` AND `tasks_checked > 0` AND `uncommitted_files > 0`

Finding (High):
```
All tasks are marked complete but {uncommitted_files} file(s) are uncommitted.
Run merge-feature only after committing all changes.
```

### Step 4: Run Build/Test Probe (when project has a test command)

Detect the project's test command from `.dev-os/config.yml` (`test_command` key) or by
checking for these files in priority order:

| File present | Probe command |
|---|---|
| `package.json` with `"test"` script | `bun test --bail 2>&1 \| tail -5` |
| `Makefile` with `test` target | `make test 2>&1 \| tail -5` |
| `bats/` or `tests/bats/` | `bats tests/bats/ --tap 2>&1 \| tail -5` |
| None found | Skip probe |

Run the probe **only if** a command is detected. Capture exit code and last 5 lines of output.

If exit code != 0:

Finding (Critical):
```
Test probe failed (exit {exit_code}):
  {last 5 lines of output}

Artifact state claims progress but tests are failing. Do not proceed until tests pass.
```

If exit code == 0: no finding — tests clean.

If probe skipped: no finding — note it silently.

### Step 5: Surface Findings

**If no findings from Steps 3-4:**

```
Code reality: verified — artifact state matches code on disk.
```

**If findings exist**, display each with severity label before the normal status output
(insert above the progress table, not below):

```
--- Code Reality Check ---
[CRITICAL] Backlog marks 'my-spec' as Completed but tasks.md has 3 open tasks.
[HIGH]     All tasks checked but 4 files are uncommitted.
[MEDIUM]   12 uncommitted files alongside 5 open tasks — run sync-completed-work.
--------------------------
```

Findings with severity **Critical** or **High** append this line:

```
Resolve code reality issues before acting on this status report.
```

## Scope Variants

### Single-spec mode (called from `show-progress-dashboard`)

Run all checks against the active spec only. Probe tests if a test command exists.

### Multi-spec mode (called from `triage` Scan 6)

Run Check C and Check D against every spec in `product/specs/*/`. Skip Check E (merge-specific).
Run test probe once for the whole project. Report per-spec findings under the spec name.

### Navigator mode (called from `orchestrate` before recommendation)

Run Check A and Check C against every surfaced spec candidate. Skip the project-wide test probe
(too slow for a recommendation flow), but always run the VBS source-reality gate:

```
vbs_verify_spec "$spec_dir"
vbs_audit_spec_code_reality "$spec_dir"   # for partial/open-task specs
```

Blocking verdicts are `resolved_in_code`, `resolved_in_code_manual_validation`, `hardening_only`,
`needs_reconciliation`, and `indeterminate`. Do not emit `implement-tasks`, `build-slice`, or
`create-tasks` as the primary command for those candidates. Route to `sync-completed-work --spec
{spec_name}`, `project-status --spec {spec_name}`, or a focused verification command first. Only
`still_open` may receive a confident implementation recommendation.

## Display Format

```
Code Reality Check
  Uncommitted files: [N]
  Branch commits:    [N]
  Artifact drift:    [detected | none]
  Conclusion:        [artifacts match reality | [N] stale entries]
```
