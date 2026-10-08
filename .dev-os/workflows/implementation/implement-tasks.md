# Implement Tasks Workflow

Implement tasks from `product/specs/[this-spec]/tasks.md` in execution order.

## When to Use

Run this workflow to implement tasks from a `tasks.md` file in execution order, after the task list has been created and reviewed.

Do not run this workflow before `tasks.md` exists, or when the project has critical blocking issues that must be resolved first (use `triage` instead).

## Step 0: Knowledge Pull (per task group)

<!-- per profiles/general/standards/global/knowledge-pull.md -->
{{workflows/_shared/knowledge/knowledge-pull-step}}

Run this step before beginning each task group implementation. This is inline context only when `tasks.md` already carries `knowledge_sources`; otherwise record a task/session note path so the implementation has durable evidence. Key API patterns are summarized in working context for use during implementation.

**If `--skip-knowledge-pull` or legacy `--skip-docs` was passed:** skip this step for all task groups and record the waiver reason.

## Step 0b: Pinned Architecture Check

Before writing code for a feature build, verify that `product/specs/[this-spec]/planning/architecture.md` exists and is the active architecture for the task group. If the spec uses a different pinned architecture path, cite that path before implementation. Do not edit feature files until a pinned architecture artifact exists.

## Step 0c: Frontend Scope Check (per task group)

{{workflows/_shared/skills/frontend-scope-detection}}

Run this step at the start of each task group, after the knowledge pull and before writing any code. Detection uses the **current task group name** as the primary signal — only load the skill if this specific group involves frontend work.

**If `frontend_scope = true` and the frontend-design skill was already loaded for a prior task group in this session:** confirm it is still active in context rather than fully re-loading.

**If `frontend_scope = true` (skill active):** before writing code, confirm or establish the named aesthetic direction:
- Check `spec.md` for an existing `## Frontend Design Guidance` section with a named direction
- If none found: choose one now and state it (e.g. "refined utility", "editorial boldness")
- Apply Color Dominance System, Motion Language Pattern, and Spatial Composition Method from the skill
- Verify against `.claude/context/style-guide.md` and `.claude/context/design-principles.md` if they exist

If the task group produces visible UI changes, run `ui-review` on the live URL or a representative screenshot before moving to the next task group. Use this iterative review step before the final `ui-design-qa --mode verify` path.

## Step 0d: Post-Task Cleanup (conditional)

If the current task group introduced obvious AI slop, run `polish` on the changed files before verification. Keep this scoped to the task group files only.

---

## Process

1. **Knowledge Pull** — Run Step 0 above before starting each task group.
1a. **Pinned Architecture Check** — Run Step 0b above before writing code for each task group.
1b. **Frontend Scope Check** — Run Step 0c above before writing any code for each task group.
2. Select the next incomplete parent task and its subtasks.
2a. **Scope Issuance (read-to-write boundary — blocking).** After the task group is selected and its gates passed, BEFORE the first mutating action, issue and enroll the implementation scope derived from the approved spec + current task group. This workflow is one of exactly two scope issuers (with `quick-fix`); higher-order workflows delegate issuance to us and any third identity is refused by the issuer allowlist with `SCOPE_UNAUTHORIZED_ISSUER`.

   ```bash
   scripts/lib/implementation-scope.sh issue    scope-payload.json LEDGER.jsonl PROJECT_ID implement-tasks
   scripts/lib/implementation-scope.sh activate LEDGER.jsonl SCOPE_ID PROJECT_ID
   scripts/lib/implementation-scope.sh enroll   LEDGER.jsonl SCOPE_ID PROJECT_ID STATE_DIR
   ```

   - Payload carries: declared outcome, exact/subtree path rules for the task group's file set, mutation classes, non-goals, acceptance criteria, verification digest, `approval_source: spec-task` bound to the spec id + task group. Omit `baselines`: `issue` captures them from `repo_identity.root` on a genesis scope and inherits the prior revision's baselines on renewal or widening; supplied baselines are stored untouched.
   - Enroll only after `activate` succeeds; the enrollment marker plus active read model is what turns out-of-scope mutation attempts in an enrolled session into hard blocks. Unenrolled sessions honestly report `bypassed`.
   - If a needed widening fails with `SCOPE_WIDENING_REQUIRES_APPROVAL`: stop the scope (`scripts/lib/implementation-scope.sh stop LEDGER.jsonl SCOPE_ID PROJECT_ID`), mutate nothing further, and disclose non-success naming the operator action — an operator-approved revision (`approval_source: operator`) is required to widen.
   - After the group's fresh verification, close the scope in an order the enrolled session admits: `review` (records `scope-review-receipt/v1`; requires an `active` scope), then `complete` (`scripts/lib/implementation-scope.sh complete LEDGER.jsonl SCOPE_ID PROJECT_ID [STATE_DIR]`, which releases the enrollment), then the group commit, then `finish` (appends `implementation-completion-receipt/v1` against that review; it does not require an active scope). `complete` and `stop` release the enrollment the scope owns, so the session is not left enforcing a finished scope. Declare the exact `review` and `complete` commands in the payload's `operations` so the enforcing hook admits them; `git commit` is blocked until `complete`. A post-review fix to an already reconciled contract-impact group re-runs `contract_impact_preflight --mode reconcile --scope group:<id>`.
   - Delegated workers never issue scope authority; child-authorization/v1 receipts are evidence-only in this slice.
3. Implement code changes for the current subtask.

4. Run targeted verification (tests/lint/build as applicable).
5. Update `tasks.md` checkboxes for completed work.
6. Repeat until requested scope is complete.

## Completion

When all tasks are complete, prompt the user to run `merge-feature`.

## Display Format

```
Implementing: [spec-name]
  Group [N/M]: [group-name]
  Task  [N.M]:  [task-description]
  Status: [implementing | complete | blocked]
  Progress: [N]% ([done]/[total] tasks)
```
