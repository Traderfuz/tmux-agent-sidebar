# Feature Delivery Pipeline

End-to-end pipeline for taking a new feature from requirements through to a merged, released branch on main.

## When to Use

- Starting a new feature from scratch (no existing artifacts)
- Resuming a partially-completed feature (spec exists, tasks exist, or implementation in progress)
- Orchestrate Mode C routes here for goal types: "New feature", "Has spec", "Has tasks"

Do not use for hotfixes or quick fixes — use the `quick-fix` pipeline. Do not start without a product context (`product/mission.md`).

## Prerequisites

- DevOS initialized in the project (`start` has been run)
- Git repository with a clean working directory (or willingness to stash)
- Product context files populated (`product/mission.md`, `product/roadmap.md`) — warned if stubs
- **Codebase map is current** (`docs/context/codebase-map.md` exists, <7 days old, <5 commits since generated). Run `map` if absent or stale — Step 3 (gap-analysis) hard-gates on map freshness and will block if this is not satisfied.

## Steps

### Step 0: Brainstorm / Design Gate

**Skill:** `brainstorm`
**Input:** User's feature idea, product context, existing code/docs, and any handoff state
**Output:** Approved design spec or explicit approved-design waiver
**Gate to next step:** Approved design exists, or waiver states why this feature already has an approved design
**Skip if:** Resuming from an existing `spec.md` or `tasks.md` where design/spec approval has already happened

Do not start implementation, write a spec from a raw idea, or scaffold project work until this gate is satisfied. For tiny changes that fit quick-fix scope, route to the `quick-fix` pipeline instead.

### Step 1: Shape Requirements

**Skill:** `shape-spec`
**Input:** User's feature idea or rough description
**Output:** `product/specs/[spec]/planning/requirements.md`
**Gate to next step:** `planning/requirements.md` exists and is non-empty
**Skip if:** `planning/requirements.md` already exists (prior shape-spec run)

### Step 2: Write Specification

**Skill:** `write-spec --spec [spec]`
**Input:** `planning/requirements.md`
**Output:** `product/specs/[spec]/spec.md`, `verification/spec-verification.md`
**Gate to next step:** `spec.md` exists and passes verification (no FAIL results)
**Skip if:** `spec.md` already exists and passes verification

Before authoring, run the shared knowledge-pull step unless it already ran for the same targets in this session or the work is pure local structure/git/file movement:

`{{workflows/_shared/knowledge/knowledge-pull-step}}`

Use `--skip-knowledge-pull` only as an explicit waiver. Legacy `--skip-docs` means the same thing but should not be used in new workflow text.

Feature builds also require a pinned `/architecture-creator` artifact before implementation starts. The normal path is `product/specs/[spec]/planning/architecture.md`; do not start implementation until the artifact exists and is current for the active requirements.
Interactive runs pause for human approve/revise on the artifact; headless autonomous runs record canonical `auto-approved` only after persisting it, with headless context in approval provenance.

### Step 3: Gap Analysis

**Skill:** `gap-analysis --dalio --converge --fix` (Multi-Angle Dalio convergence on `spec.md`)
**Input:** `spec.md`
**Output:** `product/specs/[spec]/planning/gap-analysis-report.md`
**Gate to next step:** Report written; zero unresolved gaps at any severity. Convergence loop re-analyzes after closure until 0 new gaps per pass and no open Critical/High/Medium/Low findings remain.
**Skip if:** Never skipped — gap analysis always runs
**Override:** Pass `--mode N` to force a specific mode (e.g., `--mode 2` for process-only on simple specs)

> **Map staleness:** gap-analysis hard-gates on `docs/context/codebase-map.md` freshness (see Prerequisites). If gap-analysis halts with a map staleness error, run `map --update` and re-run Step 3. Do not pass `--skip-map` unless `map` was already run in this session.

### Step 3b: Gap Closure (conditional)

**Trigger:** Any unresolved gap at any severity
**Process:** Update `spec.md` or create required remediation tasks to address each Critical/High/Medium/Low gap → re-run verify-spec → re-run gap-analysis
**Gate:** No unresolved gaps remain before proceeding to Step 4
**Skip if:** Gap analysis report is clean and records no open findings

### Step 4: Architect Review

**Command:** `review --mode architect`
**Input:** `spec.md`, `planning/gap-analysis-report.md`
**Output:** `product/specs/[spec]/planning/architect-review.md`
**Gate to next step:** Review recorded; BLOCK status requires spec update before continuing
**Skip if:** `--skip-reviews` flag was passed

> When using autonomous mode (`autonomous`), this phase runs automatically as part of the planning pipeline. For standalone use, invoke `review --mode architect --spec [spec]`.

### Step 5: Process Optimizer Review

**Command:** `review --mode process-optimizer`
**Input:** `spec.md`, `planning/architect-review.md`
**Output:** `product/specs/[spec]/planning/process-optimizer-review.md`
**Gate to next step:** Review recorded; BLOCK status requires spec update before continuing
**Skip if:** `--skip-reviews` flag was passed

> When using autonomous mode, this phase runs automatically. For standalone use, invoke `review --mode process-optimizer --spec [spec]`.

### Step 5b: Source Reality Check

**When:** Always runs before Step 6 (create-tasks). Not skippable by default.
**Process:** `{{workflows/implementation/source-reality-check}}`
**Input:** `spec.md`, `planning/gap-analysis-report.md` (if exists)
**Output:** Claims classified as `exists` / `partial` / `missing`
**Skip if:** `--skip-source-check` flag passed, or spec is explicitly a refactor

> Before creating tasks, grep actual source files to confirm each gap still exists in code.
> Writing tasks for already-fixed issues wastes implementation cycles and creates false "done" accounting.

### Step 6: Create Tasks

**Skill:** `create-tasks --spec [spec]`
**Input:** `spec.md`, `planning/process-optimizer-review.md` (if exists), source-reality-check results
**Output:** `product/specs/[spec]/tasks.md` (with `exists` claims excluded)
**Gate to next step:** `tasks.md` has at least one `- [ ]` item
**Skip if:** `tasks.md` already exists with unchecked items

### Step 7: Implement Tasks

**Skill:** `implement-tasks --spec [spec]`
**Input:** `tasks.md`, `spec.md`
**Output:** Code changes, checked-off tasks in `tasks.md`
**Gate to next step:** All `- [ ]` items in `tasks.md` are checked `- [x]`
**Skip if:** All tasks already complete

### Step 7a: Polish the Slice (conditional)

**Skill:** `polish [--since <commit>|<path>]`
**Trigger:** The implemented diff contains obvious AI slop, tombstone comments, impossible-case handlers, or redundant wrappers.
**Input:** Changed files from the current slice
**Output:** Cleaned implementation files with noise removed
**Gate to next step:** Changed files are cleaned before verification
**Skip if:** The diff is already clean or the slice is code-free

### Step 7b: Local Dev Server Check (conditional)

**Trigger:** The slice includes any frontend/UI changes, or Step 8b (Design Check) will run.
**Gate to next step:** Dev server starts and responds HTTP 2xx/3xx before running tests or design check.
**Skip if:** Backend-only or CLI-only changes with no UI output.

```bash
# Verify dev server is running (check registry first)
scripts/devos-dev-server-registry.sh list 2>/dev/null | grep -q "healthy" \
  && echo "✓ Dev server already running" \
  || {
    echo "→ Starting dev server for test/design-check..."
    # Follow local-dev-startup.md pipeline:
    bash scripts/lib/checks/doppler-validator.sh   # confirm keys present
    scripts/doppler-run.sh bun run dev &           # start with Doppler injection
    DEV_PID=$!
    sleep 5
    curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -qE "^[23]" \
      && echo "✓ Dev server ready at http://localhost:3000" \
      || { echo "✗ Dev server not responding — see dev-server-startup-failure.md runbook"; exit 1; }
  }
```

**On failure:** Follow `profiles/cli/runbooks/dev-server-startup-failure.md`.

### Step 8: Run Tests and Harden

**Skill:** `test`
**Input:** Implemented code
**Output:** Test results summary
**Gate to next step:** Test command exits 0 (all tests pass)
**Skip if:** No test framework configured (CLI/docs-only projects)

**Doppler injection for integration/e2e tests:** Tests that call real services MUST use `scripts/doppler-run.sh` (not bare `bun run test`). Unit tests that mock all dependencies may run without injection.

**Escalation path:** For non-trivial slices, user-facing work, or multi-group changes, run `harden` as the canonical test → typecheck → build → validate loop before merge.

### Step 8a: Security Review (conditional)

**Command:** `security-review --area [spec]`
**Trigger:** The slice touches auth, access control, secrets, external inputs, shell execution, or data exposure.
**Input:** Implemented code and changed paths
**Output:** Security review report under `product/security/`
**Gate to next step:** No CRITICAL/HIGH findings remain
**Skip if:** The slice is clearly non-security-sensitive

### Step 8b: Design Check (conditional)

**Skill:** `ui-review --url <url> --spec [spec]`
**Trigger:** The slice includes frontend/UI changes and a live URL or screenshot is available.
**Input:** Live implementation URL or screenshot
**Output:** Design-check report under `product/design-check/`
**Gate to next step:** PASS or accepted conditional findings
**Skip if:** No frontend/UI work changed

**URL unavailable fallback [G-007]:** If a live URL is not available, use one of these alternatives rather than skipping entirely:

1. **Playwright static capture** — render the built output directly:
   ```bash
   npx playwright screenshot --viewport-size="1440,900" file://$(pwd)/dist/index.html product/design-check/<spec>/capture-desktop.png
   ```
2. **Provided screenshot** — if the user can supply a screenshot:
   ```bash
   ui-review --screenshot <path-to-screenshot> --spec <spec>
   ```
3. **Local dev server** — start the dev server locally first (with Doppler injection):
   ```bash
   scripts/doppler-run.sh bun run dev &
   sleep 5
   ui-review --url http://localhost:3000 --spec <spec>
   ```

Skip entirely only when none of the above are feasible AND the slice is a non-visual backend change. If the slice has any frontend output, use one of the fallbacks.

### Step 9: Review Quality

**Command:** `review`
**Input:** Implemented code, spec for comparison
**Output:** Review findings with severity ratings
**Gate to next step:** Review clean, or user confirms proceed despite warnings
**Skip if:** `--skip-reviews` flag was passed

### Step 10: Create User-Facing Docs

**Skill:** `user-facing-docs --spec [spec]`
**Trigger:** The slice changes a reader-facing workflow, command, API, onboarding path, operator procedure, seed path, or recovery path.
**Input:** `spec.md`, `tasks.md`, implemented code, tests, and changed public surfaces
**Output:** Reader-facing docs package or explicit no-docs waiver
**Gate to next step:** Required docs exist or waiver states why no reader job changed
**Skip if:** The slice is purely internal and has no new reader job

Run `docs-sync` after docs creation to validate paths, command names, counts, and generated context surfaces.

### Step 11: Merge Feature

**Skill:** `merge-feature`
**Input:** Feature branch with all changes
**Output:** Merged to main, changelog updated, version bumped, feature branch deleted
**Gate to completion:** Merge succeeds, tests pass on main
**Skip if:** N/A (final step)

## Pipeline Variants

### MVP Mode (`--mvp`)

1. Steps 1-6 run normally (including gap-analysis and reviews)
2. Step 7 implements only P1-labeled tasks
3. Steps 7a-11 run normally, but merge keeps the feature branch active
4. After merge: run `implement-tasks --continue` for P2/P3 tasks
5. Repeat Steps 8-11 for each subsequent iteration

### Skip Reviews (`--skip-reviews`)

Omit Steps 4 and 5 (architect + process optimizer). Gap analysis (Step 3) still runs.
Proceed directly from Step 3b/gap-closure to Step 6 (create-tasks). Steps 8a/8b remain conditional and should be used when their triggers are present.

### Entry at Any Step

If prior artifacts exist, start from the appropriate step:
- `planning/requirements.md` exists → start at Step 2
- `spec.md` exists → start at Step 3 (gap analysis)
- `planning/gap-analysis-report.md` exists, no unresolved gaps at any severity → start at Step 4 (architect review)
- `planning/architect-review.md` exists → start at Step 5 (process optimizer)
- `tasks.md` exists with unchecked items → start at Step 7
- All tasks checked → start at Step 8

Orchestrate detects the entry point automatically from artifact existence.

## Resume Points

| Artifact | Indicates | Resume at |
|----------|-----------|-----------|
| `planning/requirements.md` | Shape complete | Step 2 (write-spec) |
| `spec.md` + `verification/spec-verification.md` | Spec complete | Step 3 (gap analysis) |
| `planning/gap-analysis-report.md` (any unresolved gaps) | Gap analysis done, closure needed | Step 3b (gap closure) |
| `planning/gap-analysis-report.md` (clean; zero open findings) | Gap analysis done, clean | Step 4 (architect review) |
| `planning/architect-review.md` | Architect review done | Step 5 (process optimizer) |
| `planning/process-optimizer-review.md` | Reviews done | Step 5b (source reality check) |
| `tasks.md` with `- [ ]` items | Tasks created | Step 7 (implement) |
| `tasks.md` with all `- [x]` | Implementation complete | Step 8 (test) |
| `.dev-os/runtime/session-state.yml` | Mid-implementation | Step 7 (checkpoint restore) |
| Branch prefix `feature/*` | Feature in progress | Detect from artifacts above |
| `product/specs/orchestration-state.md` | Orchestrate tracking | Read `Current Position` field |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 0 | User declines design gate without approved artifact | Record waiver reason, or redirect to quick-fix if scope truly fits |
| Step 1 | User abandons shape-spec | No artifacts created; safe to restart |
| Step 2 | Spec verification fails | Fix issues in spec.md, re-run verification |
| Step 3 | Gap analysis finds any unresolved gap | Run Step 3b gap closure before proceeding |
| Step 3b | Gap closure introduces any new gap | Loop Step 3b; max 3 iterations before escalating to user |
| Step 4 | Architect review BLOCK | Address blockers in spec.md, re-run architect review |
| Step 5 | Process optimizer BLOCK | Address blockers in spec.md, re-run process optimizer |
| Step 7 | Implementation error (build/test failure) | Run diagnose-first workflow automatically; retry task |
| Step 8 | Tests fail | Fix failing tests, re-run Step 8 |
| Step 9 | Review finds CRITICAL issues | Fix issues, re-run Steps 8-9 |
| Step 10 | Required docs missing | Run `user-facing-docs`, or record a no-docs waiver if no reader job changed |
| Step 11 | Merge conflict | Resolve conflicts manually, complete merge |

## Display

Pipeline progress tracker:

```
Feature Delivery Pipeline — [spec-name]
  ✅ Step 1: Shape requirements
  ✅ Step 2: Write spec
  🔄 Step 3: Gap analysis        ← CURRENT
  ⏳ Step 4: Create tasks
  ...
```
## Lifecycle receipt gate

Successful delivery includes a verified lifecycle postcondition receipt. The
delivery pipeline must not report completion when acceptance evidence is open or
ownership is ambiguous:

```bash
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/spec-lifecycle.sh"
spec_lifecycle_postcondition "$PWD" feature-delivery true "${USER:-unknown}" shell "<spec-slug>"
```
