<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/skills/stateful-operation-orchestration.md and re-run profile-sync. -->
# Stateful Operation Orchestration Standard

## Overview

This standard defines when a skill must become a stateful operational orchestrator. It governs resumable, mutating, evidence-gated work that coordinates multiple owners or execution phases. It does NOT govern lightweight intent routers, read-only reports, or short fixed workflows whose safe retry behavior is obvious.

A stateful operational orchestrator is a process manager, not a long checklist. It owns the lifecycle of one bounded operation while domain skills own their checks and mutations. Its durable record must make interruption, retry, partial success, and cleanup understandable without reconstructing intent from logs.

**Named frameworks used:**

- **Durable Execution / Event History:** persist enough history and state to resume without replaying completed side effects blindly.
- **Process Manager pattern:** one coordinator owns cross-step progress; domain participants own their local behavior.
- **Idempotent API contract:** every mutating action carries a stable identity so retry cannot create an unrelated second effect.
- **RFC 2119 requirement language:** MUST, SHOULD, and MAY express enforceable strength.
- **Design by Contract:** owner evidence has declared preconditions, postconditions, and failure outcomes.

## Scope

**Covers:** architecture selection, state ownership, execution lifecycle, evidence contracts, action identity, resume semantics, concurrency, cleanup, and creator verification for multi-step operational skills.

**Does NOT cover:**

- Trigger phrase quality or general `SKILL.md` structure
- The internal business logic of an owning domain skill
- Chain registry distribution mechanics already governed by the chain mirror contract
- Runtime implementation details that do not affect the public orchestration contract
- Lightweight `start-here` routing that selects one next skill and exits

## Architecture Selection Gate

Before authoring or materially upgrading a multi-step skill, answer these questions:

1. Can execution be interrupted after one or more durable effects?
2. Can the skill resume an earlier operation rather than always starting fresh?
3. Can one operation contain parent and child work owned by different skills or OS packages?
4. Must missing, stale, malformed, conflicting, or ambiguous evidence block success?
5. Can retrying the same requested action create a duplicate external or repository effect?
6. Must human approval survive across turns or be invalidated when the material plan changes?
7. Can primary work succeed while cleanup, propagation, or verification remains incomplete?
8. Can concurrent sessions target the same project, worktree, or operation?

**Selection rule:** use the stateful operational orchestrator archetype when three or more answers are yes. Also use it whenever both question 1 and question 5 are yes, regardless of total. Otherwise choose the smallest fitting workflow pattern.

The author MUST record the gate answers in the design or review evidence. A creator MUST NOT generate the heavyweight archetype merely because a skill has many steps.

## Required Architecture

### 1. One canonical executable plan

Exactly one source MUST own executable phase order and dependencies. For DevOS multi-skill operations, this is normally the canonical chain YAML.

Every executable step MUST declare:

- A stable `step_id`
- Explicit `depends_on` edges
- Whether it is safe to run in parallel
- The owning skill
- The required evidence contract
- Required arguments and excluded scope

The human-facing skill MAY explain the sequence, but MUST NOT maintain an independent executable roster. A mirror validator MUST detect drift between the canonical plan and the skill guidance.

### 2. One bounded operation identity

Every run MUST have an immutable `run_id` and a stable target identity. The target identity MUST bind evidence to the intended project and execution boundary, including the project root and worktree or equivalent physical root when applicable.

A run MUST NOT consume a receipt solely because its skill name or action label matches. Evidence lookup MUST include the bounded target and action identity.

### 3. Parent and child lifecycle records

The orchestrator MUST keep one parent record for the overall operation and one child record for each independently owned or independently recoverable unit.

At minimum, lifecycle state MUST distinguish:

- `planned`
- `active`
- `blocked`
- `paused` or `interrupted`
- `complete`
- `failed`
- `cleanup_pending` when primary work is complete but required cleanup is not

Unknown, malformed, or unrecognized state MUST fail closed. It MUST NOT be normalized to success.

Child records MUST preserve their owner, action identity, evidence reference, attempt history, timestamps, and last material outcome. The parent MAY aggregate child state but MUST NOT rewrite or manufacture owner claims.

### 4. Durable state versus transient coordination

Durable project-bound evidence MUST live in the canonical project state surface. Locks, heartbeats, temporary prompts, and process handles MAY live in transient runtime state.

Transient state MUST NOT be the sole proof of completion. Durable receipts MAY be compacted or archived only under an explicit retention policy that preserves the current verdict and audit trail.

### 5. Versioned owner evidence contracts

Each owning skill MUST publish a versioned evidence contract with:

- `owner_skill_id`
- `contract_id`
- `contract_version`
- `check_entry`
- canonical arguments
- timeout and freshness policy
- status vocabulary
- remediation class
- evidence and child-finding schema

The orchestrator MUST consume owner-produced evidence. It MUST NOT recreate an owner's readiness logic from filenames, assumed defaults, or private heuristics.

Evidence status MUST distinguish at least `complete`, `missing`, `drifted`, `blocked`, `failed`, `unknown`, and `not_applicable` where that vocabulary applies. `Unknown` and stale evidence are not success.

### 6. Material plan and approval identity

Before mutation, the orchestrator MUST calculate a deterministic digest over the material plan: target, ordered actions, owner, canonical arguments, exclusions, and approval-relevant settings.

Approval MUST bind to that digest. A material plan change MUST invalidate prior approval and require a new decision. Non-material display changes MUST NOT create a new action identity.

### 7. Idempotent mutation and correlated receipts

Every mutating action MUST have a deterministic idempotency identity derived from the bounded run, target, action, material plan, and canonical arguments.

A successful mutation MUST emit a receipt correlated to that identity. A retry MUST do one of the following:

- Return the existing successful receipt without repeating the effect
- Resume an incomplete action from its last safe checkpoint
- Block with a conflict that names the ambiguous or mismatched receipt

The orchestrator MUST NOT claim exactly-once execution unless the effect boundary actually enforces it. The portable contract is **at-least-once invocation with idempotent effects and correlated receipts**.

### 8. Concurrency, revision, and resume

Mutating transitions MUST use an atomic project-scoped lock and an expected revision or equivalent compare-and-set guard. A stale writer MUST fail rather than overwrite newer state.

Resume MUST:

1. Resolve the same target and run identity
2. Load the latest durable parent and child records
3. Revalidate the canonical plan and material digest
4. Recheck stale or missing owner evidence
5. Skip only actions with valid correlated success receipts
6. Continue from the earliest actionable incomplete dependency

Resume MUST NOT restart the whole operation blindly.

### 9. Primary outcome versus cleanup outcome

Primary action status and cleanup status MUST be recorded separately. A completed primary action with failed cleanup is not equivalent to a fully successful operation.

Reports MUST expose partial completion honestly. Cleanup MAY be retryable without repeating the primary effect.

### 10. Reporting as projection

Human and machine reports MUST be projections of the same durable records. The report renderer MUST NOT independently decide completion.

A machine result SHOULD include:

- target identity and classification
- parent and child counts
- ordered plan and exclusions
- action outcomes
- evidence references and freshness
- receipt and checkpoint references
- conflicts or backups
- primary and cleanup status
- final verdict and next action

### 11. Operator authority

The orchestrator MAY automate execution after approval, but MUST NOT silently approve a human decision gate. Headless or autonomous flags remove repetitive prompts; they do not grant authority absent from the operator contract.

A delegated worker MUST return dependency requirements to the active host for host-owned skill dispatch. It MUST NOT claim that an owning skill ran when it only requested the run.

### 12. Propagation and discoverability

When the archetype creates or changes a canonical chain, evidence contract, schema, template, or standard, the author MUST update every owned registry, installed mirror, route map, creator reference, and human documentation surface. Generated derivatives MUST be regenerated from source rather than hand-edited.

## Minimum Data Contract

A parent operation record SHOULD contain the following shape:

```json
{
  "schema": "operation-run/v1",
  "run_id": "immutable-id",
  "target": {
    "project_id": "stable-project-id",
    "project_root": "/canonical/root",
    "worktree_root": "/canonical/root"
  },
  "revision": 4,
  "status": "active",
  "plan_digest": "sha256:...",
  "approval": {
    "decision": "approved",
    "plan_digest": "sha256:..."
  },
  "children": ["phase.init", "phase.deploy"],
  "primary_status": "active",
  "cleanup_status": "not_started",
  "last_successful_action": "phase.init",
  "updated_at": "RFC3339 timestamp"
}
```

An action receipt SHOULD contain:

```json
{
  "schema": "operation-receipt/v1",
  "run_id": "immutable-id",
  "action_id": "deterministic-action-id",
  "owner_skill_id": "setup-deploy",
  "target_id": "stable-project-id",
  "plan_digest": "sha256:...",
  "attempt": 2,
  "outcome": "complete",
  "primary_status": "complete",
  "cleanup_status": "cleanup_pending",
  "evidence": ["path-or-contract-reference"],
  "created_at": "RFC3339 timestamp"
}
```

Exact field names MAY vary when an established repository schema exists. The invariants above MUST remain machine-checkable.

## Worked Examples

### Example A: deployment coordinator

A deployment workflow mutates infrastructure, waits for verification, and can be interrupted. It answers yes to interruption, resume, fail-closed evidence, duplicate effects, approval persistence, and cleanup separation. It MUST use this archetype.

The chain owns `prepare -> migrate -> deploy-preview -> verify -> promote -> monitor`. Database, deployment, and browser-test skills own their evidence. Promotion approval binds to the plan digest. Retrying `promote` returns the correlated receipt rather than creating a second deployment. A monitoring failure records `primary_status: complete` and `cleanup_status: cleanup_pending` if rollback cleanup remains.

### Example B: credential rotation coordinator

A credential rotation spans several providers. Each provider is a child owner. The parent records the intended provider set and rotation order. Each rotation uses a stable action ID and receipt. If interruption occurs after two providers, resume revalidates the plan, skips their valid receipts, and continues with the third. A changed provider set invalidates the old approval.

### Example C: lightweight router

A `start-here` skill reads project state, recommends one next skill, and exits without mutation. It answers no to the selection gate. It SHOULD remain a lightweight routing orchestrator and MUST NOT acquire run ledgers, locks, child records, or receipt machinery.

## Anti-Patterns

| Anti-pattern | Why it fails | Required correction |
|---|---|---|
| A long numbered checklist described as an orchestrator | It has no durable lifecycle or safe resume behavior | Apply the selection gate; use a fixed workflow or implement this archetype fully |
| Duplicate phase lists in chain and skill | The executable plan drifts | Make the chain canonical and validate the mirror |
| Success inferred from file existence | Empty, stale, or unrelated evidence passes | Consume a versioned owner contract and validate content/freshness |
| Receipt matched only by skill name | A recent unrelated action can satisfy the gate | Bind receipt to target, action, run, plan digest, and arguments |
| Approval stored as a boolean | Changed work can reuse stale consent | Bind approval to the material plan digest |
| Exactly-once claim over retryable external effects | The boundary cannot prove it | Use idempotent effects plus correlated receipts |
| Runtime lock used as completion proof | Locks disappear or become stale | Persist durable outcome evidence separately |
| Parent overwrites child verdicts | Ownership and provenance disappear | Aggregate owner claims without rewriting them |
| Cleanup failure overwrites primary success | Resume may repeat the primary side effect | Track primary and cleanup outcomes independently |
| Heavy state added to a router | Complexity grows without a recovery need | Keep the lightweight router archetype |

## Deviation Protocol

A project MAY use an equivalent architecture when all required invariants are preserved. The deviation record MUST name:

1. The exact rule being replaced
2. Why the canonical mechanism does not fit
3. The substitute invariant and owner
4. How interruption, retry, stale evidence, and duplicate effects are tested
5. The removal or review condition

A deviation MUST NOT weaken fail-closed evidence, project-bound identity, approval binding, or idempotent effect requirements.

## Compliance Test

Answer yes or no before shipping a stateful operational orchestrator:

- [ ] Was the architecture selection gate completed and retained as evidence?
- [ ] Does exactly one canonical plan own executable order and dependencies?
- [ ] Does every step have a stable ID, owner, dependency set, parallel-safety value, and evidence contract?
- [ ] Are run and target identities immutable and project/worktree-bound?
- [ ] Are parent and child lifecycle states explicit, with unknown state failing closed?
- [ ] Is durable completion evidence separate from transient locks and process state?
- [ ] Does every owner publish a versioned evidence contract?
- [ ] Does approval bind to a deterministic material plan digest?
- [ ] Does every mutation use a stable idempotency identity and correlated receipt?
- [ ] Can resume skip valid completed work without blindly replaying side effects?
- [ ] Do atomic locking and revision checks reject stale concurrent writers?
- [ ] Are primary and cleanup outcomes represented separately?
- [ ] Are human and machine reports projections of the same durable records?
- [ ] Are human approval and active-host dispatch boundaries preserved?
- [ ] Are canonical artifacts propagated through all owned mirrors and discovery surfaces?
- [ ] Do tests cover interruption, retry, stale evidence, changed approval scope, receipt mismatch, concurrent mutation, and cleanup failure?
- [ ] Does a negative benchmark prove that a lightweight router remains lightweight?

Any `no` blocks release unless an approved deviation record covers that exact item.

## References

- AWS Builders' Library, [Making retries safe with idempotent APIs](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/)
- AWS Durable Execution SDK, [Idempotency and retries](https://docs.aws.amazon.com/durable-execution-sdk/latest/dg/durable-execution-idempotency.html)
- Temporal, [Workflow execution and event history](https://docs.temporal.io/workflow-execution/event)
- Temporal, [How the Temporal platform works](https://docs.temporal.io/encyclopedia/architecture/how-the-temporal-platform-works)
- IETF, [RFC 2119: Key words for use in RFCs to Indicate Requirement Levels](https://www.rfc-editor.org/rfc/rfc2119)
- DevOS, `profiles/general/standards/global/single-source-of-truth.md`
- DevOS, `profiles/general/standards/global/artifact-write-verification.md`
- DevOS, `profiles/general/standards/global/lifecycle-stages.md`
- DevOS, `profiles/general/standards/skills/skill-workflow-patterns.md`
- DevOS, `profiles/general/standards/maintenance/chain-skill-mirror-contract.md`
