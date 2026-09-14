<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/product/spec-to-qa-traceability.md and re-run profile-sync. -->
# Spec-to-QA Traceability Standard

**Area:** product  
**Added:** 2026-04-13  
**Source:** Dalio gap analysis DES-01 — 99+ specs, 16 QA scenarios, 2-4 week lag

---

## Overview

Every spec that ships a user-facing route accumulates a traceability debt if it closes without a paired QA scenario. Over time this debt compounds: implementations diverge from intent, regressions go undetected for weeks, and the only way to validate a surface is to re-read the original spec from memory. This standard closes that loop by requiring a QA scenario skeleton at spec-close time — when the spec author has the most context about what "correct" means.

A QA scenario is not an automated test. It is a human-readable job-to-be-done description that can be executed by a browser agent, a QA runner, or a manual tester. It takes 5 minutes to write at spec-close and saves hours of archaeology after regressions.

---

## Scope

This standard covers **the requirement to produce a QA scenario skeleton when a spec ships or modifies a user-facing route**. It does NOT cover automated test implementation (see `testing/e2e.md`), spec authoring format (see `product/spec-forward-build-posture.md`), or how QA scenarios are executed.

---

## Principles

1. **Shift-left traceability:** Validation intent is cheapest to capture at spec-close time, when the author's mental model is freshest. Deferring it creates a context loss cliff — within two weeks, the author must re-read the spec to reconstruct what "passing" means. *(Larry Smith, Shift-Left Testing, 2001)*

2. **Job-to-be-done framing:** A QA scenario describes what the operator needs to accomplish, not how the implementation works. "Operator creates an invoice draft and sees a save confirmation" is a better scenario than "POST /billing/invoices returns 201." *(Clayton Christensen, JTBD, The Innovator's Solution, 2003)*

3. **Definition of Done enforceability:** A spec is not complete until validation intent is documented. "QA scenario added" is a DoD gate — not a post-merge task. *(Scrum Guide, Schwaber & Sutherland)*

4. **Minimum viable traceability:** The scenario skeleton does not need to be exhaustive. It needs enough information for a browser agent or human tester to reproduce the primary flow and confirm the pass criteria. Perfect is the enemy of shipped.

---

## Rules

### R1 — When a QA scenario MUST be added (RFC 2119)

A QA scenario skeleton **MUST** be added to `product/specs/2026-04-13-daily-use-scenarios/spec.md` before a spec is marked complete when the spec:

- Adds a new route or page
- Modifies an existing route's primary user flow
- Adds a new CTA, form, modal, or data surface that an operator interacts with

A QA scenario **SHOULD** be added (deviation acceptable with justification) when the spec:

- Modifies secondary UI (copy changes, style fixes, empty state refinements)
- Adds a new API surface with no direct UI entry point

A QA scenario **MAY** be omitted without justification when the spec:

- Is backend-only (migrations, cron jobs, API routes with no UI)
- Is a refactor with no observable behavior change
- Is documentation or tooling only

```
// OFF-STANDARD — spec is marked ✅ Complete with no QA scenario added
| 2026-04-13-invoice-confirmation | ✅ Complete — 2026-04-13 | P2 | Add toast + redirect on invoice save |

// ON-STANDARD — scenario skeleton added before closure
| 2026-04-13-invoice-confirmation | ✅ Complete — 2026-04-13 | P2 | Add toast + redirect on invoice save |
→ S-12 updated in daily-use-scenarios/spec.md: "Invoice save shows success toast, redirects to /billing/invoices/:id"
```

### R2 — Scenario skeleton format

When adding a QA scenario, use this template exactly. Do not omit sections.

```markdown
### S-XX: <Surface Name> — <Job to Be Done>
**User story:** <One sentence: operator does X in order to accomplish Y.>
**Route:** `/<route>`

**Steps:**
1. Navigate to `/<route>`
2. Confirm page loads without crash
3. <Action introduced by this spec — be specific>
4. Verify the expected outcome is visible
5. Confirm no console errors or white screens

**Pass criteria:**
- Page loads without crash
- <Primary action specific to this spec> completes successfully
- <Expected data or UI change> is visible
- No white screen or 500 error

---
```

**Assign the next sequential number** by checking the last `S-XX:` entry in the spec file. Never reuse numbers.

### R3 — Where scenarios live

All QA scenarios **MUST** be appended to the canonical daily-use scenarios spec at:

```
product/specs/2026-04-13-daily-use-scenarios/spec.md
```

Insert before the `## Execution Protocol` section. Do not create separate scenario files per spec.

### R4 — Scenario numbers are permanent

Once assigned, a scenario number **MUST NOT** be reused or renumbered even if the scenario is later superseded. Mark superseded scenarios with a `**Superseded by S-XX**` note instead of deleting them.

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Spec marked ✅ Complete with no scenario | Silent traceability debt — the surface has no documented validation path | Add scenario skeleton before marking complete |
| Scenario describes implementation, not job | "POST /api/invoices returns 201 with id" — not executable by a human | "Operator saves invoice draft and sees success confirmation" |
| Scenario too detailed to maintain | 20-step scripts that break on any UI change | 3-6 steps covering the primary flow only |
| Scenario added after closure as cleanup | Context already lost — author must re-read spec to reconstruct intent | Add at close time, not post-merge |
| Single scenario for a spec that ships 3 new routes | Gaps in coverage invisible because the entry exists | One scenario per distinct user-facing route or flow |
| QA scenario file per spec | Fragmented — 99 specs produce 99 scenario files with no unified view | All scenarios in the canonical daily-use spec |

---

## Before/After: Well-formed vs. under-specified scenario

```markdown
// UNDER-SPECIFIED — fails because steps are vague, pass criteria are not checkable
### S-23: Billing — Invoice
**User story:** User makes an invoice.
**Route:** /billing

**Steps:**
1. Go to billing
2. Make invoice
3. Check it worked

**Pass criteria:**
- Works

---

// WELL-FORMED — passes: JTBD framing, specific steps, binary pass criteria
### S-23: Billing — Create Invoice and Confirm Draft Save
**User story:** Operator creates a new invoice for Apex Roofing Solutions and
confirms the draft saved successfully before sending.
**Route:** `/billing/invoices/new`

**Steps:**
1. Navigate to `/billing/invoices/new`
2. Confirm invoice creation form loads with client selector visible
3. Select "Apex Roofing Solutions" from the client dropdown
4. Add a line item: description "Local SEO — April", qty 1, unit price $1,500
5. Verify total updates to $1,500.00
6. Click "Save as Draft"
7. Verify success toast appears with invoice number
8. Verify redirect lands on `/billing/invoices/:id` (not hub)

**Pass criteria:**
- Invoice form loads with populated client list
- Line item total calculates correctly
- Success toast shows on save
- Browser lands on the specific invoice page, not /billing hub
- No white screen or 500 error

---
```

---

## Deviation guidance

You **MAY** omit a QA scenario when all of the following are true:
1. The spec is backend-only (no user-facing route added or modified)
2. The spec is a refactor with no observable behavior change
3. The spec is documentation, tooling, or standards-only

When deviating for any other reason, **MUST** add a `QA-SKIP:` note to the spec's task file:

```markdown
## QA-SKIP
Reason: <why no scenario was added>
Reviewer: <who approved the skip>
Date: <YYYY-MM-DD>
```

Scenarios marked QA-SKIP are reviewed at the next `gap-analysis` pass and must be backfilled if the surface ships to production.

---

## Enforcement integration

| Hook point | Expected behavior |
|---|---|
| `write-spec` | Appends a `## QA Scenario Skeleton` section at the bottom of every new spec with the template pre-filled for the spec's primary route |
| `verify` | Before reporting a spec complete, checks whether `product/specs/2026-04-13-daily-use-scenarios/spec.md` contains an entry referencing the spec's route. Reports MISSING if not found. |
| `gap-analysis` | Reports QA coverage ratio (scenarios / user-facing specs) and lists routes with no paired scenario |
| `spec-status-summary.md` | QA coverage column tracks `scenario: S-XX` or `QA-SKIP` per spec row |

---

## Compliance test

Answer each question yes/no. A standards-compliant spec-close requires all YES answers for must-fix items.

- [ ] **[MUST]** Does the spec touch a user-facing route, CTA, form, modal, or data surface?
- [ ] **[MUST]** Is a QA scenario skeleton present in `product/specs/2026-04-13-daily-use-scenarios/spec.md` before the spec is marked complete?
- [ ] **[MUST]** Does the scenario use job-to-be-done language in the user story (operator does X to accomplish Y)?
- [ ] **[MUST]** Does the scenario have at least 3 specific, executable steps (not "check it worked")?
- [ ] **[MUST]** Does the scenario have at least 2 binary pass criteria (not "looks correct")?
- [ ] **[MUST]** Is the scenario number unique and sequential (not reused)?
- [ ] **[SHOULD]** Does the scenario cover the primary new action introduced by the spec (not just page load)?
- [ ] **[MAY]** If the spec was omitted (backend-only / refactor), is a `QA-SKIP:` note present in the task file?

**Scoring:**
- 6/6 MUST items pass → **Compliant**
- 5/6 MUST items pass → **Warning** — record the gap in the spec task file
- < 5/6 MUST items pass → **Non-compliant** — spec MUST NOT be marked complete

If any MUST check fails: add the missing scenario skeleton or `QA-SKIP:` note before closing the spec.

---

## References

- **Shift-Left Testing** (Larry Smith, 2001) — moving quality verification earlier in the development lifecycle, at design/spec time rather than post-release. [Widely cited in IEEE Software, 2001.]
- **Jobs-to-be-Done Framework** (Clayton Christensen, *The Innovator's Solution*, 2003) — framing product validation around what the user needs to accomplish, not how the implementation works. Applied here to QA scenario user stories.
- **ISO/IEC/IEEE 29119-3 Test Documentation Standard** (2013) — defines the test design specification artifact that maps directly to a QA scenario skeleton: documented test conditions, cases, and expected results authored before execution.
- **Definition of Done** (Scrum Guide, Schwaber & Sutherland) — the team's shared commitment that no work item is complete until quality criteria are met. Applied here: "QA scenario documented" is a DoD gate for all user-facing specs.
- **RFC 2119 Normative Vocabulary** (IETF, 1997) — MUST / SHOULD / MAY authority levels used throughout the Rules section to distinguish enforced requirements from recommendations.
