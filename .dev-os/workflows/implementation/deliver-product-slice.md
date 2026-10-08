# Deliver Product Slice Workflow

Close one product slice end-to-end through one continuous sequence: intake, isolate, shape, converge gaps, task, implement, verify, review, PR, merge, and close out. The executable order is owned by the chain `profiles/general/chains/deliver-product-slice.yaml` (installed mirror `.dev-os/chains/deliver-product-slice.yaml`); the operator contract, decision gate, ledger, and failure handling are owned by the `deliver-product-slice` skill. This workflow is the human-readable map between the two — it never becomes a second executable roster.

Default scope is the current repository/project in the active workspace. A goal string may mention another project as an example, but that does not change the target unless the user explicitly says to switch projects.

## When to Use

Use this workflow when:
- a user wants to keep moving from idea or gap directly into shipping-quality implementation
- a feature area needs to be closed end to end instead of split into disconnected planning and coding passes
- the right next step is not a one-off fix, but a full product slice: workflow, UI, contracts, verification, and backlog sync
- you are operating in autonomous mode and need a deterministic loop for "keep going until this slice is genuinely usable"

Do not use this workflow when:
- the user only wants brainstorming, option exploration, or architecture discussion without implementation (`brainstorm`)
- the task is a narrow bug fix that does not require spec/task reshaping (`quick-fix`)
- the work is purely documentation creation (`user-facing-docs`) or purely design exploration (`ui-design-iteration`)
- the request is for a specialist artifact only (`bx-skill-creator`, `bx-agent-creator`, or `bx-standards-creator`)

## Process

Every step below names the chain step it executes. Phase numbers match the operational phases in the `deliver-product-slice` skill; the skill's 15-phase canonical taxonomy section maps them onto the shared planning/execution taxonomy used by `autonomous`, `gap-analysis` remediation, and `devos-mode`.

1. **Phase 0 — Work intake preflight** (`work-intake-preflight --auto`)
   - Read the root `CLAUDE.md`, `AGENTS.md`, `product/specs/feature-backlog.md`, and any project-local instructions governing the area.
   - Detect an active spec/task package with the authoritative helper (`vbs_list_actionable_specs`), never a bare checkbox grep.
   - Persist the slice ledger at `product/runtime/deliver-product-slice/<slug>.json`; a preflight validator failure is `preflight_blocked`, repaired and re-run at the same phase — never a switch to a planning-only chain.

2. **Phase 1–2 — Isolate and checkpoint** (`worktrees` → `worktree-sessions` → `checkpoint`)
   - Create or resume the `wt/<spec-slug>` worktree at exact `origin/main`; adopt the returned path as the execution root and verify with `worktree_cli_dispatch verify-adoption`.
   - Open a visible `worktree-sessions` session when the host cannot change directory itself.
   - Record the starting state with `checkpoint`.

3. **Phase 3 — Shape and write the spec** (`shape-spec` → `write-spec`)
   - Sub-steps owned by the skill: `brainstorm` design gate for unclear scope, `architecture-creator` (mandatory, approval-attributed), `knowledge-pull` (waivable with a recorded reason).
   - Default to full feature posture: contracts, data path, backend logic, UI/workflow, operator path, and verification. Intended-but-missing capability goes into the spec, not out of scope.
   - **Frontend scope check before planning:** if the slice is frontend-scoped, load the `frontend-design` skill before shaping the spec or tasks, using the same detection logic as `write-spec` and `implement-tasks`. Shared snippet: `{{workflows/_shared/skills/frontend-scope-detection}}`.

4. **Phase 4 — Gap analysis to convergence** (`gap-analysis --dalio --converge --fix`)
   - All three flags are mandatory and match the chain definition exactly.
   - Audit the user flow and operator flow, not isolated code. Write to `product/gap-analysis/` and append to `gap-registry.jsonl`. Every evidence-backed gap closes before tasks; `--skip-gap-analysis` is valid only with an existing report or `--force-skip-gap-analysis`.

5. **Phase 5 — Create tasks** (`create-tasks`)
   - Ordered task groups with real dependencies, each independently verifiable, including product-level verification tasks. Update `feature-backlog.md` so status matches reality.

6. **Phase 6–7 — First verify gate and planning reviews** (`devos-verify`)
   - Verify `spec.md`, `tasks.md`, the architecture artifact, the gap report, and the source-reality check; require at least one anchored open task.
   - Run the architect review and the process optimizer review. Both are mandatory; no flag bypasses them.

7. **Phase 8 — Implement the slice** (`implement-tasks`)
   - Honor `agent_dispatch.implementation_runtime`; otherwise implement inline along the highest-leverage live path: data model → API/actions → UI → operator path.
   - Close the product loop, not just the code loop: seed realistic data, add lifecycle/gating/status/empty-state behavior, keep related surfaces consistent.

8. **Phase 9–10 — Polish, harden, secure, test** (`ai-slop-polish` → `harden` → `devos-security-review` → `test`)
   - `harden` is the canonical test → typecheck → build → validate loop; `devos-security-review` runs whenever the slice touches auth, access, secrets, shell, or external inputs.
   - For frontend/UI slices, run `ui-review --scope page` on the live URL or a representative screenshot during polish.

9. **Phase 11 — Second verify gate** (`devos-verify`)
   - Drain test debt to zero (`test_debt_drain_sync`), then verify all tasks checked, tests pass, build clean.

10. **Phase 11b — Docs refresh** (`user-facing-docs` → `docs-sync` → `audit-docs`)
    - Runs inside the worktree before the first local commit; `--skip-docs` skips it. Merge-dependent artifacts (`map`, `generate-user-flows`, `orchestrate --roadmap`) stay with `merge-feature`.
    - Apply the client artifact review gate before any delivery claim on a durable client/operator-facing artifact.

11. **Phase 12 — Local commits, review phase, reconciliation** (`commit --grouped --local-only` → `devos-code-review` → `sync-completed-work --unattended` → `commit --grouped --local-only`)
    - The review phase R0–R5 runs here, once: R0 URL pre-collection (interactive prompts once; headless records a no-URL skip) → R1 `devos-code-review` → R2 `predeploy-check` → R3 `ui-review --scope page` / `ui-design-qa --mode verify` (frontend + URL + approved-preview HTML) → R4 handoff fidelity (handoff state present) → R5 `e2e` (unless `--skip-e2e`). Full logic: `.claude/skills/deliver-product-slice/references/review-phase.md`.
    - Fix every blocking finding through its owning workflow, reconcile task evidence, then make the second grouped local commit.

12. **Phase 13 — PR and merge** (`create-pr` → `sync-completed-work --unattended` → `merge-feature`)

13. **Phase 14 — Post-merge closure** (`post-deploy-qa --record-debt-only --reason pending_no_url --source-chain deliver-product-slice` → `devos-review` → `commit --stage-only` → `summarize`)
    - Post-deploy QA records URL-dependent debt rather than inventing a deployed target. Update `feature-backlog.md` and the spec status before claiming the slice complete.

After every phase gate the skill prints one ledger line (`done / active / pending / blocked`) and, on a block, exactly one `→ Next:` resume command. `--continue` resumes at the earliest incomplete phase from the persisted ledger.

## Display Format

Use this structure when reporting progress or completion:

```text
=== Deliver Product Slice ===

Area:       <feature area>
Objective:  <what became usable>
Status:     <gap analysis | spec'd | implementing | verified | complete>

Completed
- <implemented capability>
- <implemented capability>

Verified
- <targeted tests>
- <typecheck>
- <build>

Remaining
- <next highest-value gap in this same slice>
```

The review phase prints its own summary block (see the skill's `references/review-phase.md`).

## Notes

- Same-commit parity: any change to phase order, required args, or gates updates the source chain, the installed chain mirror, the `deliver-product-slice` skill, and this workflow together, then runs `chains-registry.sh`, `skills-registry.sh`, and `chain-skill-mirror-contract.py`.
- Frontend slices must always route through the shared frontend scope detector so the `frontend-design` skill is in context before spec shaping and task execution.
- A **workflow** is the correct DevOS artifact for the operating sequence; a **skill** owns one specialized step (standards, seeds, UI review); an **agent** is appropriate only for a dedicated autonomous role prompt that executes this workflow repeatedly.
