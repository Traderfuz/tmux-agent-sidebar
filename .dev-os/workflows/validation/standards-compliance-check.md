# Standards Compliance Check Workflow

Validate a project's compliance against its active DevOS profile standards by parsing compliance test sections and evaluating each checklist item.

## When to Use

Run this workflow to audit a project's active DevOS profile standards compliance — either as a standalone check or as part of a maintenance session.

Do not use this workflow when you only need to check one specific file — pass `--standard <name>` to restrict scope. Do not run it on projects without a `.dev-os/config.yml` (not a DevOS project).

## Inputs

- `--area <area>` (optional) — restrict to one area
- `--standard <name>` (optional) — restrict to one standard by filename (without `.md`)
- `--profile <name>` (optional) — override profile detection
- `--verbose` (optional) — show passing checks
- `--json` (optional) — output as JSON

## Workflow

### Step 1: Read project profile

Read `.dev-os/config.yml` and extract the `profile` field.

If `--profile` was provided, use that value instead.

If `.dev-os/config.yml` does not exist and `--profile` was not provided:
- Report: "Not a DevOS-initialized project — .dev-os/config.yml not found."
- Stop.

### Step 2: Resolve inheritance chain

Run `get_inheritance_chain(profile)` from `scripts/lib/profile-resolver.sh`.

Display to user:
```
Profile: <profile> (<profile> -> <parent> -> <root>)
```

### Step 3: Collect applicable standards

Run `standards_collect_for_profile(profile, [area])` from `scripts/lib/standards-enforcer.sh`.

Apply filters:
- If `--area` is set, pass it as the area parameter.
- If `--standard` is set, filter the collected results to only include files matching `<name>.md`.
- If neither is set, collect all standards.

Track the collected files grouped by area for report organization.

### Step 4: Filter by area applicability

Run `detect_applicable_areas(project_dir)` from `scripts/lib/standards-enforcer.sh`.

For each area in the collected standards:
- If the area is in the applicable list, proceed.
- If the area is NOT applicable AND `--area` was not explicitly set, skip with note:
  ```
  Skipping area '<area>' — not applicable (no <signal> detected)
  ```
- If `--area` was explicitly set, always check that area regardless of applicability.

### Step 5: Parse compliance tests

For each collected standard file:
1. Run `standards_parse_compliance_tests(filepath)`.
2. If it returns 1 (no compliance test section), record as skipped:
   ```
   <area>/<filename> — no compliance test section
   ```
3. If it returns 0, collect the checklist items for evaluation.

### Step 6: Classify and evaluate

For each checklist item, classify into a tier based on signal words:

| Signal pattern | Tier | Confidence |
|---|---|---|
| "exist", "named", "file", "directory", "present" | 1 | HIGH |
| "kebab-case", "camelCase", "snake_case", "lowercase" | 1 | HIGH |
| "under N characters", "less than", "at most" | 1 | HIGH |
| "frontmatter", "YAML", "starts with `---`" | 1 | HIGH |
| "in `.gitignore`", "committed", "tracked" | 1 | HIGH |
| "quoted", "delimited" | 1 | HIGH |
| "written as", "starts with", "includes", "documents" | 2 | MEDIUM |
| "provides", "specifies", "names", "lists" | 2 | MEDIUM |
| "describes", "explains", "covers" | 2 | MEDIUM |
| "exactly one", "coherent", "focused", "consistent" | 3 | LOW |
| "stable", "not renamed", "compatible", "appropriate" | 3 | LOW |
| (no match) | 2 | MEDIUM |

Evaluate each item:

**Tier 1 (file-checkable):** Use Bash/Glob/Grep to deterministically check the condition. Report PASS or FAIL with specific file references.

**Tier 2 (content-checkable):** Read relevant project files and evaluate content against the criterion. Report PASS, FAIL, or WARN with excerpts.

**Tier 3 (semantic-checkable):** Evaluate with AI judgment. Always report as WARN (flagged for human review), never as hard FAIL. Include reasoning.

For each failure or warning, collect:
- Standard name and area
- Check index and text
- Specific file paths and line numbers where violations occur
- A remediation hint (what to fix)

### Step 7: Generate report

**Terminal format (default):**

```
Standards Compliance Report
Profile: <profile> (<chain>)
Project: <project_path>
Date: <date>

--- FAILURES (<count>) ------------------------------------------

[FAIL] <standard> / Check <N>
  "<check text>"
  Violations:
    - <file>:<line> — <detail>
  Fix: <remediation hint>
  Confidence: HIGH (Tier 1)

--- WARNINGS (<count>) ------------------------------------------

[WARN] <standard> / Check <N>
  "<check text>"
  Flagged for review:
    - <file>:<line> — <detail>
  Confidence: MEDIUM (Tier 2)

--- SKIPPED (<count>) -------------------------------------------

  <area>/<standard> — <reason>

--- SUMMARY -----------------------------------------------

Standards checked:    <N> (across <N> areas)
Compliance tests:     <N>
Passed:               <N> (<percent>%)
Failed:               <N>
Flagged for review:   <N>
Skipped (no test):    <N>
Skipped (N/A area):   <N>
```

If `--verbose`, include a PASSED section before FAILURES showing all passing checks.

**JSON format (`--json`):**

Write JSON to stdout with structure:
```json
{
  "timestamp": "ISO-8601",
  "profile": "<profile>",
  "chain": ["<leaf>", "<parent>", "<root>"],
  "project": "<path>",
  "results": [
    {
      "standard": "<name>",
      "area": "<area>",
      "profile_source": "<profile>",
      "check_index": <N>,
      "check_text": "<text>",
      "tier": <1|2|3>,
      "result": "PASS|FAIL|WARN|SKIP",
      "confidence": "HIGH|MEDIUM|LOW",
      "violations": [...],
      "fix": "<hint>"
    }
  ],
  "summary": {
    "standards_checked": <N>,
    "checks_total": <N>,
    "passed": <N>,
    "failed": <N>,
    "warned": <N>,
    "skipped_no_test": <N>,
    "skipped_na_area": <N>
  }
}
```

### Step 8: Write runtime state

Write compliance summary to `.dev-os/runtime/standards-compliance.json`:

```json
{
  "timestamp": "ISO-8601",
  "profile": "<profile>",
  "chain": ["<chain>"],
  "standards_checked": <N>,
  "checks_total": <N>,
  "checks_passed": <N>,
  "checks_failed": <N>,
  "checks_warned": <N>,
  "checks_skipped": <N>
}
```

This enables `project-status` to display a cached compliance summary without re-running the full check.

## Display Format

```
Standards Compliance — profile: [profile-name]
  Standards checked: [N]
  PASS:  [N]
  FAIL:  [N]  ← [list failing checks]
  SKIP:  [N]  (excluded by config)
  Status: [PASS | FAIL]
```
