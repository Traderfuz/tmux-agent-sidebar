# Orchestrate Workflow

Product development navigator with four modes: navigator (default), project-scope roadmap, single-spec track splitting, and goal-based routing.

---

## When to Use

Run this workflow when you need to determine the next highest-value action in the project — at session start, after completing a spec, or when unsure what to work on next.

Do not use this workflow when a specific task is already known and assigned; go directly to `implement-tasks` instead.

## Navigator Mode (default — no args)

Answer the question: "What should I do next to ship fastest?"

### Step 1: Gather Project State

Before ranking work, run safe freshness refreshes automatically when available: `map --update` for stale/missing `docs/context/codebase-map.md`, background bundle refresh for stale bundles, and project-local/context sync when safe. Do not surface stale bundle/map/context maintenance as the user's next task unless auto-refresh fails due missing tools, auth, unsafe/destructive action, or confirmation requirement.

Read the following sources (skip any that don't exist):

1. **Feature backlog** — `product/specs/feature-backlog.md`: extract spec names and statuses
2. **Active specs** — scan `product/specs/*/tasks.md`: count `- [ ]` vs `- [x]` for context only, then verify each candidate with `vbs_verify_spec` and `vbs_audit_spec_code_reality` before surfacing as actionable
3. **Git status** — `git status --short` + `git branch --show-current`: uncommitted work, current branch
4. **Config** — `.dev-os/config.yml`: active profile, enabled integrations
5. **Capture inbox** — `product/inbox.jsonl`: P1/P2 captures verified with `vbs_verify_capture` before surfacing
6. **Artifact ownership** — `product/runtime/artifact-ownership.yml` (if exists): reader-only state, staleness

### Step 2: Classify Specs

Categorize each spec found:

| Category | Condition |
|----------|-----------|
| **Blocked** | Explicitly marked blocked in backlog or spec, or has failing dependency |
| **Near-Complete** | Has tasks.md with >80% tasks checked |
| **In Progress** | Source verdict `still_open` + has tasks.md with unchecked tasks + backlog shows "In Progress" |
| **Ready** | Source verdict `still_open` + has tasks.md with unchecked tasks + backlog shows "Ready for Implementation" |
| **Needs Tasking** | Has spec.md but no tasks.md |
| **Needs Spec** | In backlog but no spec dir exists |
| **Maintenance** | No spec — detected via stale docs, failing tests, or drift warnings |
| **Complete** | `vbs_verify_spec` returns `resolved_in_code` or `not_actionable`, OR the delivery branch already landed on `origin/main` |

### Step 3: Score by Shipping Impact

For each non-complete, non-blocked spec, compute a priority score:

| Factor | Weight | Scoring |
|--------|--------|---------|
| Near-complete (>80%) | 5 | Close it out — highest value per effort |
| Has active branch | 3 | Already in flight, momentum matters |
| Unblocks other specs | 3 | Dependency multiplier |
| P0 label in backlog | 2 | Explicit priority |
| Has session-state.yml | 1 | Existing context to resume |

### Step 3b: Code Reality Check on Top Candidate

Before issuing a recommendation, verify the top-scoring spec's artifact state reflects actual code and apply the `/verify` skill's ground-truth hierarchy: code/tests/runtime evidence outranks task checkboxes, backlog status, captures, and issue tracker state.

{{workflows/implementation/code-reality-check}}

Use **Navigator mode** against every surfaced candidate, not only the top candidate. Run `vbs_verify_spec "$spec_dir"` and, for partial specs, consume `vbs_audit_spec_code_reality "$spec_dir"` evidence. Verdict handling is blocking:

- `resolved_in_code` or `not_actionable` → suppress from implementation and delivery recommendations and classify Complete.
- Backlog says only review/PR/merge remains → check `origin/main..<branch>`; zero unique commits or a merge/squash commit naming the branch or slug means Complete and a backlog reconciliation finding, never `create-pr` or `merge-feature`.
- `resolved_in_code_manual_validation` → suppress implementation; surface only manual/operator proof if relevant.
- `hardening_only` → do not emit `implement-tasks`; route to hardening/spec update.
- `needs_reconciliation` → do not emit `implement-tasks`; route to `sync-completed-work --spec {spec_name}` or `project-status --spec {spec_name}`.
- `still_open` → may emit implementation command when other routing checks pass.
- `indeterminate` → do not emit a confident implementation command; route to verification first.

Never present stale markdown as truth. If any blocking verdict fires, the recommendation must be verification/reconciliation first, not implementation.

### Step 3c: Check Capture Inbox

Before issuing a recommendation, check `product/inbox.jsonl` for unprocessed P1 or P2 captures and verify each with `vbs_verify_capture` before surfacing it. If a capture verifies as `resolved_in_code`, auto-flip it through `vbs_autoflip_resolved` and suppress it. If verification is unavailable or indeterminate, label it `unverified` and recommend `verify` or `sync-completed-work` before implementation.

```bash
if [[ -f "product/inbox.jsonl" ]]; then
    DEVOS_LIB="${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib"
    [[ -f "$DEVOS_LIB/verify-before-surface.sh" ]] && source "$DEVOS_LIB/verify-before-surface.sh" 2>/dev/null || true
    grep '"status":"unprocessed"' product/inbox.jsonl | grep -E '"priority":"P[12]"' || true
fi
```

If verified P1 or P2 captures remain, prepend them to the recommendation output:

```
Inbox (high-priority):
  cap-YYYYMMDD-HHMMSS [<type> P1] — "<text>"
  → Recommended: quick-fix or shape-spec --from-capture <id>

  cap-YYYYMMDD-HHMMSS [<type> P2] — "<text>"
  → Recommended: shape-spec --from-capture <id>
```

P3/P4 captures are not surfaced here — they appear only in `triage` and `capture --list`.

If no P1/P2 captures exist, skip this block silently.

### Step 4: Rank and Recommend

Select the top-scoring spec and generate a single recommendation:

```
=== DevOS Navigator ===

Project: <project name>
Branch:  <current branch>
State:   <N> specs in progress, <N> ready, <N> blocked

RECOMMENDATION: <action description>
  Spec:    <spec-name> (<completion %>)
  Reason:  <why this is highest impact>
  Command: <recommended-command> --spec <name>
  Verification: <verdict> — <source/test evidence summary>

Other options:
  2. <spec-name> — <brief reason>; Verification: <verdict> — <evidence summary>
  3. <spec-name> — <brief reason>; Verification: <verdict> — <evidence summary>
```

If no specs exist or all are complete:

```
=== DevOS Navigator ===

No active specs found. Options:
  - shape-spec    — Start a new feature
  - triage        — Diagnose project state
  - docs-sync     — Sync documentation
```

---

## Mode A: Project-Scope Roadmap (`--roadmap`)

Scan all specs, detect dependencies, and produce a unified project roadmap.

### Step 1: Read Feature Backlog

Read `product/specs/feature-backlog.md`:
- Extract all spec names and their current status
- Note any Tier assignments

### Step 2: Scan Spec Directories

For each directory under `product/specs/*/`:
- Check for `spec.md` — determines if spec is defined
- Check for `tasks.md` — determines if tasks are created
- Count `- [ ]` vs `- [x]` task lines — context only, not source of truth
- Run `vbs_verify_spec` / `vbs_audit_spec_code_reality` per spec and record `source_verdict`, `verification`, and `next_action`
- Cross-reference with backlog entry only after source verdict is known

Categorize each spec:

| Category | Condition |
|----------|-----------|
| **In Progress** | Source verdict `still_open` + has tasks.md with unchecked tasks + backlog shows "In Progress" |
| **Ready** | Source verdict `still_open` + has tasks.md with unchecked tasks + backlog shows "Ready for Implementation" |
| **Needs Tasking** | Has spec.md but no tasks.md |
| **Needs Spec** | In backlog but no spec dir exists |
| **Blocked** | Explicitly marked blocked in backlog or spec |
| **Complete** | Source verdict `resolved_in_code` or `not_actionable` OR the delivery branch already landed on `origin/main` |

### Step 3: Dependency Analysis

Detect cross-spec blocking relationships:
- Read each spec.md "Dependencies" section
- Look for explicit references to other spec names
- Build a dependency graph (spec A blocks spec B)

### Step 4: Identify Parallel-Safe Specs

Mark specs as parallel-safe if:
- Status is "Ready"
- No unresolved dependencies on other in-progress specs
- Not blocked

### Step 5: Produce `product/specs/project-roadmap.md`

Every roadmap row must include `source_verdict`, `verification`, and `next_action`. Raw checkbox/backlog counts are advisory only and must not decide actionable status without the VBS/source-reality verdict.

Write the roadmap file:

```markdown
# Project Roadmap
Generated: YYYY-MM-DD

## Summary
- In Progress: N specs
- Ready: N specs
- Needs Tasking: N specs
- Complete: N specs

## Active Work

### In Progress
- **[spec-name]** — X tasks remaining
  - Next: [first unchecked task from tasks.md]

### Ready for Parallel Execution
- **[spec-name]** — X tasks ready
- **[spec-name]** — X tasks ready

### Blocked / Waiting
- **[spec-name]** — waiting on: [dependency]

## Recommended Execution Order
1. [spec-name] -> [reason]
2. [spec-name] -> [reason]

## Dependency Graph
- [spec-b] depends on [spec-a] completing task X
```

### Step 6: Offer Worktree Setup

If parallel-ready specs exist:
```
Parallel-safe specs detected:
  - spec-a (8 tasks)
  - spec-b (12 tasks)

Create worktrees for parallel execution? (Y/n)
```

---

## Mode B: Single-Spec Track Splitting (`--spec <name>`)

Analyze one spec's task breakdown and split into parallel execution tracks.

### Step 1: Read Spec Tasks

Read `product/specs/<name>/tasks.md`:
- Parse all task groups and their dependencies
- Extract the "Execution Order" section if present

### Step 2: Identify Tracks

Classify each task group:
- **Independent tracks**: task groups with no dependencies on other groups (can run in parallel)
- **Sequential tracks**: task groups that depend on other groups (must run in order)

### Step 3: Present Track Analysis

```
## Orchestration Plan: <spec-name>

### Independent Tracks (can run in parallel):
- Track A — Task Group 1: [name] (N tasks)
- Track B — Task Group 3: [name] (N tasks)
- Track C — Task Group 4: [name] (N tasks)

### Sequential Tracks (must run in order):
1. Task Group 2 (depends on: Group 1) — N tasks
2. Task Group 5 (depends on: Groups 1, 3, 4) — N tasks
3. Task Group 6 (depends on: Groups 2, 3, 4, 5) — N tasks
4. Task Group 7 (depends on: all above) — N tasks

### Recommended Execution:
1. Start independent tracks A + B + C in parallel
2. When all complete: run sequential tracks 2 -> 5 -> 6 -> 7
```

### Step 4: Write Orchestration Plan

Write `product/specs/<name>/planning/orchestration-plan.md`:

```markdown
# Orchestration Plan: <spec-name>
Generated: YYYY-MM-DD

## Tracks

### Independent (parallel-safe)
- Track A: [task group name]
- Track B: [task group name]

### Sequential
1. [task group] (after: [dependency])
2. [task group] (after: [dependency])

## Verification
- [ ] All independent tracks complete
- [ ] Sequential tracks complete in order
- [ ] All task groups marked [x] in tasks.md
```

### Step 5: Offer Worktree Creation

For each independent track, offer to create worktrees:
```
Create worktrees for parallel tracks? (Y/n)
  wt/track-a -> Track A
  wt/track-b -> Track B
  wt/track-c -> Track C
```

---

## Mode C: Goal Routing (`--goal "<description>"`)

Route a specific goal to the appropriate DevOS command sequence via qualifying questions.

### Step 1: Ask 3 Qualifying Questions

Ask the user:

1. **What's the goal?** (confirm/clarify the `--goal` argument)
   - "What exactly do you want to achieve?"

2. **What do you already have?** (assess starting point)
   - Options: "Nothing yet", "A rough idea", "A spec without tasks", "Tasks without implementation", "Partial implementation"

3. **What's your constraint?** (guide routing)
   - Options: "Ship as fast as possible (MVP)", "High quality with full tests", "Small targeted fix only", "Planning only (no code yet)"

### Step 2: Map to Routing Table

Each row maps to a formal pipeline definition in `workflows/pipelines/`. The pipeline file defines the full step sequence, gates, skip conditions, and resume points.

| Goal type | Starting point | Constraint | Pipeline | Entry point |
|-----------|---------------|------------|----------|-------------|
| Ambiguous request | Broad or unclear | Planning | `clarify` → `shape-spec` → {{workflows/pipelines/feature-delivery}} | Step 1 (clarify interview) |
| Research-heavy goal | Unfamiliar domain | Planning | `devos-research` → `clarify` → `shape-spec` → {{workflows/pipelines/feature-delivery}} | Step 1 (research loop) |
| Clone existing UI | URL / screenshot / Figma | Design | `ui-clone` → `ui-review` → {{workflows/pipelines/feature-delivery}} | Step 1 (clone scaffold) |
| New feature | Nothing | Any | {{workflows/pipelines/feature-delivery}} | Step 1 (shape-spec) |
| New feature | Has rough idea | MVP | {{workflows/pipelines/feature-delivery}} | Step 2 (write-spec), `--mvp` |
| Has spec | No tasks | Any | {{workflows/pipelines/feature-delivery}} | Step 3 (create-tasks) |
| Has tasks | Partial impl | Any | {{workflows/pipelines/feature-delivery}} | Step 4 (implement-tasks) |
| Small fix | Anything | Fix only | {{workflows/pipelines/quick-fix}} | Step 1 (diagnose) |
| Code review | Has implementation | Quality | {{workflows/pipelines/code-quality-loop}} | Step 1 (review) |
| Planning only | Nothing | Planning | `shape-spec` -> `orchestrate` | N/A (no pipeline) |

### Step 3: Output Handoff Context Block

```
## Orchestration Routing Result
Goal: <user goal>
Starting point: <assessed state>
Constraint: <user constraint>

### Recommended Command Sequence:
1. clarify — resolve ambiguity into a scoped brief (if needed)
2. devos-research — deepen unfamiliar domain context (if needed)
3. shape-spec — gather requirements (estimated: interactive)
4. write-spec — draft specification
5. gap-analysis --mode 6 --converge — multi-angle gap analysis with convergence (always runs)
6. Architect review + process optimizer review (skippable with --skip-reviews)
7. create-tasks — break into actionable tasks
8. implement-tasks — build it

### Context for Next Command:
- Goal: <compressed goal summary>
- Constraint: <constraint>
- Existing artifacts: <list if any>

Run: <first routed command from the sequence above>.
```

### Step 4: Write Orchestration State

The AI layer writes `product/specs/orchestration-state.md`:

```markdown
# Orchestration State
Updated: YYYY-MM-DD

## Active Goal
<goal description>

## Current Position
Command: <first routed command>
Status: Starting

## Routing Decision
Sequence: clarify* -> devos-research* -> shape-spec -> write-spec -> gap-analysis (mode 6 --converge) -> gap-closure* -> architect-review -> process-optimizer -> create-tasks -> implement-tasks
Constraint: <constraint>

## Context
<compressed context for handoff>
```

The shell dispatch (`command_router_cmd_orchestrate`) creates the scaffold directory (`product/specs/`) only. The AI layer populates the file content.

---

## Context Tiers

Selective context passing — compress, don't dump:

| Tier | Content | When to Pass |
|------|---------|--------------|
| 1 | Goal + constraints only | Goal routing (Mode C) |
| 2 | Goal + spec summary | Single-spec orchestration (Mode B) |
| 3 | Goal + roadmap + active specs | Project-scope (Mode A / `--roadmap`) |
| 4 | Current state summary only | Navigator (default) |

## Display Format

```
Product Navigator — recommended next action:
  Spec:   [spec-name]   Status: [In Progress | Ready | Near-Complete]
  Action: [implement-tasks | gap-analysis | merge-feature | write-spec]
  Why:    [brief rationale]
```
