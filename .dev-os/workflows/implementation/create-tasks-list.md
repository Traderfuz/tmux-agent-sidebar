# Task List Creation — CLI Profile

CLI-profile override of `profiles/general/workflows/implementation/create-tasks-list.md`.

## When to Use

- Breaking a CLI spec into ordered, implementable task groups with BATS test companions
- Creating `tasks.md` for any spec under the `cli` profile

**Not for:** Webapp or general-profile specs (use the general `create-tasks-list` workflow), or implementing tasks (use `implement-tasks`).

**Key differences from the general workflow:**
- No database layer, API layer, or frontend/UI task groups
- Testing uses BATS (not Vitest/Jest) — see `profiles/cli/standards/testing/bats-test-writing.md`
- Each implementation task group gets a companion BATS test task
- Final task always wires the new test files into Makefile `BATS_SUITES`

## Core Responsibilities

1. **Analyze spec and requirements**: Read the spec and requirements files to understand the scope.
2. **Run pre-implementation reviews**: Perform architect and process optimization reviews.
3. **Plan task execution order**: Break requirements into tasks ordered by dependency.
4. **Group tasks by shell module**: Group tasks around library files (`scripts/lib/`) or scripts.
5. **Inject BATS test tasks**: Add a companion test task after each implementation group.
6. **Create Tasks list**: Write the markdown task list with test wiring check at the end.

## Workflow

### Step 0: Knowledge Pull

{{workflows/_shared/knowledge/knowledge-pull-step}}

After the knowledge pull, add a comment block at the very top of `tasks.md`:
```
<!-- knowledge_sources: <lib> (<tier>), <lib> (<tier>), ... -->
```
If no libraries were detected: `<!-- knowledge_sources: none (no libraries detected) -->`

### Step 1: Analyze Spec & Requirements

Read (whichever are available):
- `product/specs/[this-spec]/spec.md`
- `product/specs/[this-spec]/planning/requirements.md`

### Step 1b: Source Reality Check

Before creating any tasks, verify that gaps and requirements are not already implemented.

{{workflows/implementation/source-reality-check}}

**Skip condition:** Pass `--skip-source-check` or set `skip_source_check: true` if this is a
refactor spec or source check was already run this session.

After the check: exclude tasks for claims marked `exists`; add notes for `partial`; keep all for `missing`.

### Step 2: Pre-Implementation Reviews

#### Architect Review

{{workflows/architecture/architect-review}}

Architectural findings are WARNINGS ONLY.

#### Process Optimization Review

{{workflows/optimization/process-optimizer-review}}

Process recommendations are SUGGESTIONS ONLY.

#### Review Summary

```
Pre-Implementation Reviews Complete

Architect Review:
- Impact: [High/Medium/Low]
- Findings: [X critical, X high, X medium, X low]

Process Optimization Review:
- Gaps identified: [X]
- Optimizations proposed: [X]

[If critical issues found]
Critical findings detected. Consider updating the spec before creating tasks.

[If no critical issues]
No blocking issues. Proceeding to task creation.
```

### Step 3: MVP Priority Detection

{{workflows/implementation/mvp-detect}}

Priority labels will be added to tasks as comments: `(P1)`, `(P2)`, `(P3)`

### Step 4: Create Tasks Breakdown

Generate `product/specs/[current-spec]/tasks.md`.

**Canonical checkbox format** — all tasks MUST use bullet-list checkboxes:
- Unchecked: `- [ ] N.N description`
- Checked: `- [x] N.N description`

Do NOT use the legacy inline header format. Only the `- [ ]` / `- [x]` bullet format is machine-readable.

**Note:** CLI projects have no database migrations, REST API controllers, or UI components.
Task groups map to bash libraries or scripts. Adapt the structure below to the actual feature.

```markdown
# Task Breakdown: [Feature Name]

<!-- knowledge_sources: none (no libraries detected) -->

## Overview
Total Tasks: [count]
Testing: BATS (Bash Automated Testing System) — see profiles/cli/standards/testing/bats-test-writing.md

## Task List

### Module 1: [Library or Script Name]
**Dependencies:** None

- [ ] 1.0 Implement [module name] (P1)
  - [ ] 1.1 Implement [function/feature description]
    - File: scripts/lib/[libname].sh
    - Key behaviors: [list]
  - [ ] 1.2 Implement [second function/feature]
    - Accepts: [inputs]
    - Returns: [outputs or side effects]
  - [ ] 1.3 Handle edge cases and error paths
    - [specific edge case]
    - Exit codes: [what signals what]

- [ ] 1.T Write BATS tests for [libname] (P1)
  - Create tests/bats/lib/[libname].bats (see bats-test-writing.md)
  - Test scope: [list 2–6 key behaviors to cover]
  - Add [libname].bats to BATS_SUITES in Makefile
  - Run: bats tests/bats/lib/[libname].bats
  - Acceptance: all tests pass, suite is wired into make test

**Acceptance Criteria:**
- Core behaviors work as specified
- BATS tests pass
- [libname].bats is registered in BATS_SUITES

### Module 2: [Second Library or Script]
**Dependencies:** Module 1

- [ ] 2.0 Implement [module name] (P2)
  - [ ] 2.1 Implement [function description]
    - File: scripts/lib/[libname2].sh
    - Depends on: [libname].sh
  - [ ] 2.2 Integrate with [first module]
    - Call pattern: [describe]
    - Error handling: [describe]

- [ ] 2.T Write BATS tests for [libname2] (P2)
  - Create tests/bats/lib/[libname2].bats (see bats-test-writing.md)
  - Stub [libname].sh dependency functions in setup()
  - Test scope: [list 2–5 key behaviors]
  - Add [libname2].bats to BATS_SUITES in Makefile
  - Run: bats tests/bats/lib/[libname2].bats
  - Acceptance: all tests pass, suite is wired into make test

**Acceptance Criteria:**
- Integration with Module 1 works correctly
- BATS tests pass
- [libname2].bats is registered in BATS_SUITES

### Wiring Check

#### Task Group N: Test Suite Wiring Verification
**Dependencies:** All implementation and test tasks

- [ ] N.0 Verify all new .bats files are wired into BATS_SUITES (P1)
  - [ ] N.1 Run: grep "BATS_SUITES" Makefile and confirm all new test files appear
  - [ ] N.2 Run: make test and confirm exit 0
  - [ ] N.3 Fix any orphaned test files reported by triage

**Acceptance Criteria:**
- make test exits 0
- No orphaned .bats files (grep confirms all files in BATS_SUITES)
- triage shows no Tests findings

## Execution Order

1. Module 1 implementation + tests (Task Groups 1 + 1.T)
2. Module 2 implementation + tests (Task Groups 2 + 2.T)
3. ... (additional modules)
4. Wiring Check (Task Group N)
```

**Adapt this structure:** The actual task groups, function names, and BATS test scopes must
reflect the real spec. The example above shows the pattern; replace all bracketed placeholders
with concrete details from the spec.

### Step 5: User Flows Documentation Check

After generating the tasks breakdown, check for `docs/user-flows.md` and inject an appropriate
task group using the same logic as the general workflow:

{{workflows/documentation/user-flows-standard}}

## Display Format

```markdown
# Task Breakdown: [Feature Name]

<!-- knowledge_sources: <lib> (<tier>), ... -->

## Overview
Total Tasks: N
Testing: BATS

## Task List

### Module 1: [Name]
- [ ] 1.0 Implement [module] (P1)
  - [ ] 1.1 ...
- [ ] 1.T Write BATS tests for [module] (P1)

### Wiring Check
- [ ] N.0 Verify all .bats files in BATS_SUITES
```

## Important Constraints

- **Testing framework is BATS, not Vitest/Jest** — every test task references BATS and
  `tests/bats/lib/` paths; never mention Vitest, Jest, or `npm test` in CLI profile tasks
- **Every implementation group gets a companion test task** — numbered `N.T` after the group
- **BATS_SUITES wiring is mandatory** — include the wiring check as the final task group
- **2–8 focused tests per group** — not exhaustive coverage; test the contract, not every branch
- **Test tasks run only their own suite** — `bats tests/bats/lib/[libname].bats`, never `make test`
  during implementation (that is the final wiring check step)
- **Create tasks that are specific and verifiable** with concrete file paths and acceptance criteria
## Contract Impact Coverage Gate

Contract-relevant CLI tasks must source `${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/contract-impact-preflight.sh`
and invoke `contract_impact_preflight --mode verify --phase planning` against the planned record before task generation.
Every applicable row and proof obligation maps to one stable one-way `row_id -> task_ref -> proof_ref`;
duplicate or orphan references, stale fingerprints, relocated records, and missing coverage block
verification. Keep checkbox status in tasks.md only. Non-contract-relevant work uses the shared complete
`not_applicable` receipt, never a local checklist.
