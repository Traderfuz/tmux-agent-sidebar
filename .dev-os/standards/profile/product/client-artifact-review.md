<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/product/client-artifact-review.md and re-run profile-sync. -->
# Client Artifact Review Gate

Shared standard for any durable client-facing or operator-facing artifact produced by DevOS or an installed OS package.

## Scope

This standard applies before an artifact is marked complete, scheduled, exported, published, delivered, or handed off.

## Artifact classification

| Class | Definition | Gate required? | Examples |
| --- | --- | --- | --- |
| Client-facing artifact | Intended for a client, customer, public audience, or downstream client deliverable | Yes | research brief, newsletter, social schedule, creative asset, design preview, client PDF |
| Operator-facing artifact | Used by a client/operator to run, verify, deploy, or maintain a system | Yes | runbook, implementation handoff, onboarding guide, API guide |
| Internal planning artifact | Used only inside planning or implementation | No, unless promoted for delivery | scratch spec notes, implementation checklist |
| Generated derivative | Derived from an approved source artifact | Yes if delivered separately; otherwise inherit parent review ID | resized asset, exported PDF, handoff JSON |
| Disposable scratch output | Temporary exploration with no delivery claim | No | draft prompt, local scratchpad, abandoned variant |

When classification is unclear, classify as `operator-facing artifact` and create a review record.

## Mandatory review record

Every gated artifact MUST have a review record containing:

- `artifact_id`
- `os_owner` (`research-os`, `marketing-os`, `creative-os`, `design-os`, `dev-os`, or other package)
- `source_skill` or workflow name
- `client_or_project`
- `artifact_class`
- `artifact_path_or_url`
- `preview_open_path`
- `state`
- `ux_readability_result`
- `brand_result`
- `copy_result`
- `evidence_render_result`
- `handoff_result`
- `approval_status`
- `reviewer` or `waiver_owner`
- `timestamp`
- `follow_up_tasks`

Review records SHOULD live beside the artifact or in a package registry such as `product/reviews/`, `creative/reviews/`, `marketing/reviews/`, `research/reviews/`, or `design/reviews/`.

## Gate states

Allowed states:

1. `draft` — artifact is being created; no delivery claim allowed.
2. `preview-ready` — artifact has a reviewable path but has not passed review.
3. `reviewed-pass` — checks passed, awaiting explicit approval if required.
4. `reviewed-needs-changes` — review found required changes.
5. `approved` — reviewer approved delivery.
6. `waived` — accountable owner accepted delivery risk without full approval.
7. `delivered` — artifact was delivered after `approved` or `waived`.

Transition rules:

- `draft` → `preview-ready` requires `preview_open_path`.
- `preview-ready` → `reviewed-pass` requires UX/readability, brand, copy, evidence/render, and handoff checks.
- `preview-ready` → `reviewed-needs-changes` records required follow-up tasks.
- `reviewed-pass` → `approved` requires reviewer identity and timestamp.
- Any non-terminal state → `waived` requires waiver owner, reason, risk, and expiry/revisit condition.
- `approved` or `waived` → `delivered` only after delivery/export/schedule evidence is recorded.
- A skill MUST NOT claim complete/delivered/scheduled/published for a gated artifact unless state is `approved`, `waived`, or the statement is explicitly limited to `draft created` / `preview ready`.

## Approval and waiver semantics

Approval means a named reviewer has inspected the preview/open path and accepted the artifact for the intended audience. Waiver means a named accountable owner chose to bypass one or more checks for a documented reason.

A waiver record MUST include:

- owner
- reason
- skipped checks
- accepted risk
- expiry or revisit condition
- timestamp

Waivers do not erase failed checks; they explain why delivery may proceed despite them.

## Review dimensions

| Dimension | Minimum check |
| --- | --- |
| Preview/render | Artifact opens through the declared preview path and is non-empty/readable |
| UX/readability | Structure, navigation, accessibility/readability, and audience fit are acceptable |
| Brand | Voice, visual identity, tone, and positioning match the relevant brand source |
| Copy | Grammar, claims, CTA, channel fit, and AI-tell/human-quality concerns are checked |
| Evidence | Claims, screenshots, source citations, metrics, or verification commands are present where needed |
| Handoff | Downstream owner has enough path, context, status, and next-action metadata |

## Per-OS ownership

| OS | Primary ownership |
| --- | --- |
| Research OS | evidence/source quality, methodology transparency, synthesis clarity |
| Marketing OS | brand voice, copy quality, offer/channel fit, scheduling safety |
| Creative OS | visual brand compliance, asset integrity, platform specs, preview quality |
| Design OS | UX flow, screen fidelity, accessibility, implementation handoff clarity |
| DevOS | implementation docs, operator runbooks, verification evidence, handoff integrity |

## Preview/open contract

Every gated artifact MUST provide a reviewable path using `.dev-os/standards/global/open-artifact-viewer.md` and the shared workflow `.dev-os/workflows/_shared/quality/open-artifact-for-review.md`. Valid preview/open paths include:

- local file opened with the platform default viewer
- HTML opened in a browser
- image/PDF opened in an appropriate viewer
- authenticated URL opened through browser-CDP when required
- external platform URL
- API-rendered preview saved to disk

Opening an artifact is evidence of reviewability, not approval. Approval requires a separate state transition.

## Creator-surface propagation

When a skill creates a durable artifact, it MUST update the relevant registry, index, generation log, handoff manifest, or tracking document with:

- artifact path/URL
- review record path
- current gate state
- source skill/workflow
- OS owner
- client/project
- timestamp

This makes the artifact discoverable by review, export, handoff, and audit workflows.

## Compliance test

- [ ] Client/operator-facing artifacts have a review record.
- [ ] Review record includes mandatory fields.
- [ ] Preview/open path is present and usable or a waiver exists.
- [ ] State is one of the allowed gate states.
- [ ] `delivered` only follows `approved` or `waived`.
- [ ] Review record is linked from a registry/index/tracking surface.
