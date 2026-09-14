# Client Artifact Review Gate

Shared review gate that a durable client-facing or operator-facing artifact must pass before any `delivered` / `scheduled` / `published` / `exported` claim. This workflow operationalizes the `.dev-os/standards/product/client-artifact-review.md` standard as a runnable state machine.

## When to Use

Include this gate in any DevOS or installed-OS workflow that produces a durable artifact intended for a client, customer, public audience, operator, or downstream OS package — research brief, newsletter, social schedule, creative asset, design preview, client PDF, runbook, onboarding guide, implementation handoff, or API guide.

- Use when an artifact is about to be marked complete, scheduled, exported, published, delivered, or handed off.
- Use when a generated derivative (resized asset, exported PDF, handoff JSON) is delivered separately from its approved source.

**Do not use for** internal planning artifacts, scratch specs, disposable exploration, or abandoned variants that carry no delivery claim. When classification is unclear, treat the artifact as operator-facing and create a review record anyway — never skip the gate to save time.

## When to Include

Embed this snippet in a workflow at the point where the artifact becomes deliverable:

```markdown
## Phase: Client Artifact Review

{{include workflows/_shared/quality/client-artifact-review-gate}}

After the gate reaches `approved` or `waived`, proceed to delivery/export/handoff.
```

To open the artifact for review, use the companion `workflows/_shared/quality/open-artifact-for-review.md` and the `.dev-os/standards/global/open-artifact-viewer.md` standard.

## Gate states

The gate advances an artifact through these states (from the standard):

`draft` → `preview-ready` → `reviewed-pass` / `reviewed-needs-changes` → `approved` / `waived` → `delivered`

**Hard invariant:** a skill MUST NOT claim `delivered`, `scheduled`, `published`, `exported`, or `complete` for a gated artifact unless its state is `approved` or `waived`. If neither holds, describe only the actual state: `draft created`, `preview ready`, or `review needed`.

## Gate Checklist

Run these steps in order. Each step names the state transition it authorizes and a **Gate:** STOP condition that blocks advancement.

### 1. Classify and open the review record

- [ ] Classify the artifact (client-facing, operator-facing, generated derivative, internal, or scratch) per the standard's classification table.
- [ ] Create a review record from `templates/artifact-review/artifact-review.md` (or the JSON form `templates/artifact-review/artifact-review.json`) beside the artifact or in a package registry (`product/reviews/`, `creative/reviews/`, `marketing/reviews/`, `research/reviews/`, `design/reviews/`).
- [ ] Populate the mandatory fields: `artifact_id`, `os_owner`, `source_skill`, `client_or_project`, `artifact_class`, `artifact_path_or_url`, `state` (`draft`).

**Gate:** If the artifact is client- or operator-facing and no review record exists → STOP. Create the record before proceeding. Generated derivatives may inherit the parent review ID instead.

### 2. Produce a preview/open path (`draft` → `preview-ready`)

- [ ] Follow `workflows/_shared/quality/open-artifact-for-review.md` to open the artifact through its correct viewer and record a `preview_open_path`.
- [ ] Write `preview_open_path` into the review record and set `state: preview-ready`.

**Gate:** `draft` → `preview-ready` requires a non-empty, openable `preview_open_path`. If the artifact cannot be opened/rendered → STOP; it is not reviewable.

### 3. Run the six review dimensions (`preview-ready` → `reviewed-pass` / `reviewed-needs-changes`)

- [ ] Preview/render — opens through the declared path and is non-empty/readable.
- [ ] UX/readability — structure, navigation, accessibility, and audience fit are acceptable.
- [ ] Brand — voice, visual identity, tone, and positioning match the brand source.
- [ ] Copy — grammar, claims, CTA, channel fit, AI-tell/human-quality checked.
- [ ] Evidence — claims, screenshots, citations, metrics, or verification commands present where needed.
- [ ] Handoff — downstream owner has enough path, context, status, and next-action metadata.
- [ ] Record each result (`pass` / `needs_changes` / `not_applicable` / `waived` / `pending`) in the review record. For manual review, use `templates/artifact-review/manual-checklist.md`.

**Gate:** If any required dimension is `needs_changes`, set `state: reviewed-needs-changes`, record follow-up tasks, and STOP delivery. Only when all required dimensions pass does `state` become `reviewed-pass`.

### 4. Approve or waive (`reviewed-pass` → `approved`, or any non-terminal → `waived`)

- [ ] Approval: a named reviewer accepts the artifact for its audience; record `reviewer` and `timestamp`; set `state: approved`.
- [ ] Waiver (only if delivery must proceed without full approval): record `waiver_owner`, `reason`, `skipped_checks`, `accepted_risk`, and `expiry/revisit condition`; set `state: waived`. A waiver does not erase failed checks.

**Gate:** `reviewed-pass` → `approved` requires reviewer identity + timestamp. A waiver requires all waiver fields. If neither approval nor a complete waiver exists → STOP; the artifact stays non-deliverable.

### 5. Deliver and record evidence (`approved` / `waived` → `delivered`)

- [ ] Deliver/export/schedule/publish the artifact.
- [ ] Record delivery evidence (destination, timestamp, actor, evidence path/URL) and set `state: delivered`.
- [ ] Propagate the artifact to its registry/index/handoff manifest per the standard's creator-surface propagation rule.

**Gate:** `approved` / `waived` → `delivered` only after delivery evidence is recorded. Never set `delivered` from `draft`, `preview-ready`, or `reviewed-needs-changes`.

## Completion-language guard

Before writing any status line about the artifact, apply the guard from `templates/artifact-review/manual-checklist.md`:

- Do NOT say `delivered`, `scheduled`, `published`, `exported`, or `complete` unless `state` is `approved` or `waived`.
- If not approved/waived, describe only the actual state: `draft created`, `preview ready`, or `review needed`.

## Error Handling

| Scenario | Action |
|----------|--------|
| No review record for a gated artifact | Stop. Create the record from the template before any review claim. |
| Artifact will not open/render | Stop. It is not `preview-ready`; fix rendering or mark `review needed`. |
| A required dimension is `needs_changes` | Stop delivery. Record follow-up tasks; state is `reviewed-needs-changes`. |
| Delivery requested without `approved`/`waived` | Stop. Refuse the completion claim; surface only the real state. |
| Waiver missing owner/reason/risk/expiry | Stop. An incomplete waiver does not authorize delivery. |
| `delivered` claimed but no delivery evidence | Stop. Revert to `approved`/`waived`; record evidence before re-claiming. |

## Output

The gate produces a review record (per `templates/artifact-review/artifact-review.md`) whose terminal `state` and `approval_status` are the deliverability signal:

```
Artifact:   <artifact_id> (<artifact_class>, owner=<os_owner>)
Preview:    <preview_open_path>
Dimensions: preview/ux/brand/copy/evidence/handoff → pass|needs_changes|n/a
State:      draft | preview-ready | reviewed-pass | reviewed-needs-changes | approved | waived | delivered
Verdict:    DELIVERABLE only when state ∈ {approved, waived, delivered-with-evidence}
```

## Usage in Workflows

This gate is referenced by delivery/handoff surfaces such as `deliver-product-slice` and `user-facing-docs`, and by any OS package that emits durable client/operator artifacts (see the **Per-OS Adoption Map** appendix below). Reuse it wherever an artifact crosses from creation to delivery.

## Project-Specific Configuration

When including this gate, customize:

- **Review record location** — `product/reviews/` for DevOS; `creative/reviews/`, `marketing/reviews/`, `research/reviews/`, `design/reviews/` for the owning OS package.
- **Required dimensions** — mark dimensions `not_applicable` with a reason when a class genuinely does not need them (e.g. brand for a pure operator runbook).
- **Reviewer/waiver authority** — name who may approve and who may sign a waiver per OS.
- **Preview/open path** — set the viewer per artifact type via `open-artifact-for-review.md`.

## Per-OS Adoption Map

Per OS package: which artifacts are gated, where the gate attaches, and where review records live.

| OS | Gated artifacts | Adoption point (where the gate attaches) | Review record location |
| --- | --- | --- | --- |
| Research OS | research briefs, competitive analyses, synthesis reports, source packs | before any research handoff/export emits a brief to a client or downstream OS (`consume-research` boundary) | `research/reviews/` |
| Marketing OS | newsletters, social schedules, campaign copy, landing/offer copy | before any schedule/publish/send action (Postiz/boxi-app EmailCampaigns publish, `consume-marketing` handoff) | `marketing/reviews/` |
| Creative OS | hero images, creative assets, design previews, generated derivatives | before asset export/handoff (`consume-creative` handoff, creative export) | `creative/reviews/` |
| Design OS | design previews, screen exports, prototype handoffs | before design handoff to implementation (`consume-design`, design QA export) | `design/reviews/` |
| DevOS | user-facing docs, operator runbooks, implementation handoffs, verification evidence, client PDFs | before delivery closure in `deliver-product-slice`, at `user-facing-docs`/`create-pr`/`summarize` handoff points | `product/reviews/` |

Primary review ownership per OS (from the standard): Research OS — evidence/source quality; Marketing OS — brand voice, copy, scheduling safety; Creative OS — visual brand, asset integrity, platform specs; Design OS — UX flow, screen fidelity, accessibility; DevOS — implementation docs, runbooks, verification evidence, handoff integrity.

### Migration checklist (adopting the gate in a downstream OS)

- [ ] Confirm the OS package can read `.dev-os/standards/product/client-artifact-review.md` (installed via profile sync).
- [ ] Identify the OS's durable client/operator artifacts and their delivery skills/handoffs (adoption-point row above).
- [ ] Choose the review record location (`<os>/reviews/`).
- [ ] Wire `{{include workflows/_shared/quality/client-artifact-review-gate}}` into the delivery/handoff workflow at the deliverable boundary.
- [ ] Reference `open-artifact-for-review.md` from the OS's preview/open step.
- [ ] Add the creator-surface propagation note so the OS records artifact path, review-record path, gate state, source skill, OS owner, client/project, and timestamp.
- [ ] Confirm the OS's completion-language: no `delivered`/`scheduled`/`published`/`exported` claim unless state is `approved` or `waived`.
- [ ] Add or extend a BATS/validation check asserting the gate reference resolves for that OS.
