# Triage Workflow

Diagnose project state and classify inbox items to surface actionable next steps.

## When to Use

Run this workflow when the project state feels inconsistent, when you are unsure what to work on next, or as the first step in a new session after a long break.

Do not use this workflow as a substitute for `project-status` when you simply want to see implementation progress on a specific spec.

## Mode A: Audit (default — no args)

Run a full project state audit across all registered scans.

### Step 1: Detect Project Layout

Identify the project root and locate:
- `product/specs/feature-backlog.md`
- `product/specs/` directories
- `.dev-os/config.yml`
- Git repository root

### Step 2: Run All 7 Scans

Call `scripts/lib/triage.sh` functions (via `command_router_cmd_triage`):

1. **Backlog scan** (`triage_scan_backlog`):
   - Stale "Last updated" header (>14 days)
   - "In Progress" items with all tasks completed
   - "Ready for Implementation" items with no matching spec dir
   - Triage Backlog items with no Tier assignment

2. **Specs scan** (`triage_scan_specs`):
   - Spec dirs with no `tasks.md`
   - Specs with unfinished `- [ ]` tasks (excludes inline examples containing `→`)
   - Spec dirs not referenced in backlog (orphaned)
   - **Backlog/tasks.md reconciliation** → High: spec is in backlog `## Completed` section but tasks.md still has open items

3. **Git scan** (`triage_scan_git`):
   - Uncommitted changes in tracked files → Critical
   - Unpushed commits on main/master → Critical
   - Merged non-main branches → Medium

4. **Config scan** (`triage_scan_config`):
   - Missing `profile:` key in config.yml → Medium
   - Missing `version:` key → Medium
   - Empty or missing standards/ directory → Medium
   - Stale `.last-extracted` hash → Medium

5. **Doc Freshness scan** (`triage_scan_doc_freshness`):

   Compares documentation file timestamps against source file timestamps to detect silently stale docs.

   **Threshold:** Read `triage.doc_freshness_threshold` from `.dev-os/config.yml` (default: 5 commits).

   **Three pairs checked:**
   - `README.md` vs. most recently modified file in `profiles/general/commands/`
   - `docs/user-flows.md` vs. most recently modified file in `profiles/general/commands/`
   - `CHANGELOG.md` vs. `VERSION` file

   **Algorithm for each pair:**
   ```
   1. Find source_mtime = mtime of the source file (latest command file, or VERSION)
   2. Find doc_mtime = mtime of the doc file
   3. If doc_mtime >= source_mtime → doc is current, no finding
   4. If doc_mtime < source_mtime:
        commits_behind = git log --oneline <doc_path>..HEAD -- <source_dir> | wc -l
        threshold = triage.doc_freshness_threshold (default: 5)
        if commits_behind > threshold:
          emit Medium finding: "<doc_path> last updated {commits_behind} commits ago — consider docs-sync"
   5. If doc file does not exist → emit Medium finding: "<doc_path> is missing — consider docs-sync"
   ```

   **Findings output:** Added to the existing `### Medium` section — no new sections created.

6. **Bundles and tokens scan** (`triage_scan_bundles`, `triage_scan_tokens`):
   - Stale or missing bundle manifests → Medium
   - Expired or missing barrier tokens → High

7. **Capture inbox scan** (`triage_scan_inbox`):
   - Reads `product/inbox.jsonl` for unprocessed captures
   - P1 captures → High finding with capture text and suggested action (`quick-fix` or `shape-spec`)
   - Non-P1 unprocessed captures → Medium finding with count

7b. **Tests scan** (`triage_scan_tests`):

   Detects orphaned BATS test files that are not wired into `BATS_SUITES` in `Makefile`. Orphaned
   tests are never run by `make test` or CI, providing zero coverage signal.

   **Algorithm:**
   ```
   1. If tests/bats/ does not exist → skip silently
   2. If Makefile does not exist → skip silently
   3. Extract BATS_SUITES content from Makefile
   4. For each root-level .bats file in tests/bats/:
        If filename does not appear in BATS_SUITES → add to orphan list
   5. For each .bats file in tests/bats/<subdir>/:
        If neither the bare filename nor tests/bats/<subdir>/<filename> appears in BATS_SUITES
        → add tests/bats/<subdir>/<filename> to orphan list
   6. If orphan list is non-empty:
        emit Medium: "Tests: N orphaned .bats file(s) not in BATS_SUITES — add to Makefile BATS_SUITES: <filenames>"
   ```

   **Fix:** Add the reported file paths to `BATS_SUITES` in `Makefile`. See
   `profiles/cli/standards/testing/bats-test-writing.md` Rule 8 for the wiring pattern.

   **Findings output:** Added to the existing `### Medium` section — no new sections created.
   Source label for JSON output: `"tests"`

7c. **Hook registry parity scan** (`triage_scan_hook_registry_parity`):
   - Runs `hook_registry_parity_check ... --json` against the canonical registry and live
     Claude settings file.
   - Missing or duplicate Stop/SessionStart registrations → High finding with
     `repair-hooks --claude-hooks` remediation.
   - Malformed registry/settings JSON → High finding naming the parity checker error.
   - A clean JSON report adds `Hook registry parity` to the Healthy section.

   Source label for JSON output: `"hook_registry_parity"`.

8. **Code Reality scan** (`triage_scan_code_reality`):

   {{workflows/implementation/code-reality-check}}

   Use **multi-spec mode**. Map findings to triage severity:
   - Check C (backlog "Completed" + open tasks) → **Critical**
   - Check A (checked tasks, no commits) → **High**
   - Check E (all tasks checked, uncommitted files) → **High**
   - Check D (in-progress branch, no commits) → **Medium**
   - Check B (uncommitted changes + open tasks) → **Medium**
   - Test probe failure → **Critical**

   Source label for JSON output: `"code_reality"`

### Step 3: Display Report

Format findings by severity:

```
## Triage Report — <project-name>
Date: YYYY-MM-DD

### Critical
- <finding> — <fix suggestion>

### High
- <finding> — <fix suggestion>

### Medium
- <finding>

### Healthy
- Backlog: no findings
- Git: no findings

### Recommended next action
<single most impactful action>
```

### Step 3b: JSON Output (when `--json` flag is present)

When `--json` is passed to `triage`:

1. **Suppress** the normal prose report (Step 3 output is skipped).
2. After collecting all scans, emit a single JSON object to stdout:

```json
{
  "generated_at": "YYYY-MM-DD",
  "project": "<project-name from .dev-os/config.yml or directory name>",
  "findings": [
    {"severity": "critical", "source": "git", "message": "3 uncommitted changes — commit or stash before proceeding"},
    {"severity": "medium", "source": "docs", "message": "docs/user-flows.md last updated 8 commits ago — consider docs-sync"}
  ],
  "summary": {
    "critical": 1,
    "high": 0,
    "medium": 1,
    "low": 0
  }
}
```

3. **Write the same JSON** to `.dev-os/runtime/triage.json` (create `.dev-os/runtime/` if absent).
4. The `source` field for each finding maps to the scan that produced it:
   - Backlog scan → `"backlog"`
   - Specs scan → `"specs"`
   - Git scan → `"git"`
   - Config scan → `"config"`
   - Doc Freshness scan → `"docs"`
   - Bundles scan → `"bundles"`
   - Tokens scan → `"tokens"`
   - Capture inbox scan → `"inbox"`
   - Tests scan → `"tests"`
   - Hook registry parity scan → `"hook_registry_parity"`
   - Code Reality scan → `"code_reality"`
5. The `summary` object always has all four severity keys (even if their count is 0).

**Note:** When `--json` is NOT passed, behavior is identical to before — prose report only. The `triage.json` file is NOT written in prose mode.

### Step 4: Exit Recommendation

- **Critical or High findings** → Tell user to fix before starting new work
  ```
  ⚠️ Critical or High issues detected. Resolve these before beginning new feature work.
  ```
- **Medium only** → Note findings, suggest proceeding
  ```
  ✅ No blocking issues. Medium items can be addressed when convenient.
  Run orchestrate to plan your next implementation.
  ```
- **All healthy** → Celebrate and suggest orchestrate
  ```
  ✅ Project is fully healthy. No issues detected.
  Run orchestrate to plan your next implementation.
  ```

---

## Mode B: Inbox (`--inbox "<text>"`)

Classify unstructured ideas, todos, or notes into actionable categories.

### Step 1: Parse Inbox Content

The shell dispatch (`triage_run_inbox`) handles the I/O scaffolding:
- Splits input by newline
- Calls `triage_classify_inbox()` for each item
- Applies keyword heuristics for deterministic shell-level classification

### Step 2: AI Semantic Override (in Claude context)

When running in the Claude context (not pure ACP), apply semantic classification:

For each item, assess:
- **Spec Now**: Requires a new spec, significant implementation, or new system design
  - Signals: "build X", "create Y system", "implement Z feature", "refactor", "new command", "integrate"
- **Quick Fix**: Small, targeted change completable in one session (<50 lines)
  - Signals: "fix typo", "update version", "rename", "one file", "minor", "patch"
- **Backlog Later**: Worthwhile but not urgent; defer to future planning
  - Signals: "someday", "nice to have", "explore", "research", "consider", "future"
- **Discard**: Too vague, already done, or not actionable
  - Signals: duplicates of existing specs, no clear action, pure notes

### Step 3: Display Classified Report

```
## Inbox Triage Report
Date: YYYY-MM-DD

### Spec Now (needs a spec):
- <item> → suggested name: YYYY-MM-DD_<slug>

### Quick Fix (run quick-fix):
- <item>

### Backlog Later:
- <item> → Tier: 2

### Discard:
- <item> — reason: too vague / already implemented
```

### Step 4: Offer to Write to Backlog

After displaying results, ask:
```
Write Backlog Later items to product/specs/feature-backlog.md? (Y/n)
```
- If yes: append items to appropriate backlog section with today's date
- If no: display results only

---

## Mode C: All (`--all`)

Run Mode A (audit) then Mode B (inbox) sequentially if inbox content is provided.

1. Run full audit first — display severity report
2. If `--inbox "<text>"` was also provided, run inbox classification
3. Display combined output

If `--all` is used without `--inbox`, run audit only with a note:
```
Run triage --all --inbox "<text>" to also process inbox items.
```

## Display Format

```
Triage Report — [timestamp]
  Backlog:     [N issues]
  Specs:       [N open], [N near-complete], [N blocked]
  Git:         [N uncommitted changes | clean]
  Recommended: [action]
```
