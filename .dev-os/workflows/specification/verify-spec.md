# Verify Specification Workflow

Validate a spec before task generation.

## When to Use

Run this workflow after writing or updating a spec to verify it meets the structural requirements before handing off to task creation.

Do not run this workflow on specs that are still being written — it is a gate check, not an in-progress review tool.

## Standard Checks (All Specs)

1. **Requirements coverage:** All requirement areas from `planning/requirements.md` appear in `spec.md`.
2. **Scope clarity:** In-scope and out-of-scope boundaries are explicit.
3. **Testability:** Success criteria can be objectively validated.
4. **Path consistency:** References use `product/specs/...` and `product/planning/...`.
5. **Knowledge sources:** `spec.md` header contains a `knowledge_sources` field.
   - Check: scan `spec.md` for `**knowledge_sources:**` in the header block
   - **Backward-compat gate:** only warn if `git status` shows `spec.md` as modified or untracked (i.e., written or updated this session). If the file is clean/unmodified in git, skip this check silently — do not warn on historical specs.
   - Result: **WARN** (not FAIL) if field is absent on a newly-written spec. Spec is still valid; traceability is incomplete.
   - If warn: emit inline note: `"Note: knowledge_sources field not found in spec.md — was --skip-docs used?"`

6. **Frontend skill reference** (frontend-scoped specs only):
   - Run the frontend scope detection logic: check for `tech_stack.frontend` in the active profile config, UI keywords in the spec Summary/Scope sections, `## Emotion-First Direction` in `planning/requirements.md`, or existence of `planning/design-system.md`.
   <!-- MAINTAINER NOTE: The UI keyword list mirrors frontend-scope-detection.md — keep in sync. -->
   - UI keywords to match (case-insensitive): `ui, frontend, component, page, layout, design, style, css, tailwind, animation, dashboard, landing, view, screen, modal, form, interface, web, react, vue, svelte, next, nuxt, html, aesthetics`
   - **If frontend scope detected:** scan `spec.md` body for any of these strings: `frontend-design`, `frontend_design`, `aesthetic direction`, `design skill`, `Frontend Design:`
   - Result: **WARN** (not FAIL) if none of the match strings are found
   - Warning text: `"Note: spec appears frontend-scoped but does not reference the frontend-design skill. Consider adding a ## Frontend Design Guidance section or loading the skill explicitly during implementation."`
   - **If frontend scope not detected:** SKIP this check silently.

## Contract Impact Gate

For a contract-relevant spec, invoke the shared
`contract_impact_preflight --mode verify --phase planning` port using the deterministic
metadata assembly in the write-spec contract: extract the first non-empty line under
`## Problem statement` as `--change-summary`, use the spec path as the proposed path,
extract the sole consumer class and `coverage_intent` from the planning record, and
pass them as `--required-consumer-class` and `--coverage-intent`. If extraction is
ambiguous or capability is explicitly pending, fail/append `--coverage-pending`
respectively; never invent metadata. The record must be valid, fresh, target-matched,
and cover every required consumer class; the spec must include `## Contract Impact`.

Persist only stable ID/path/revision/digest/fingerprint and blocker references.
Never duplicate policy or mutate records manually. Failure before handoff
preserves the prior record/audit and prevents newer downstream revision claims.

## Emotion-First Checks (Eligible Specs Only)

Perform these additional checks when the spec is eligible for emotion-first content. A spec is eligible if:
- `planning/requirements.md` contains an `## Emotion-First Direction` section, OR
- The spec metadata includes `user-facing: true` or `branding-sensitive: true`

### Required Header Validation

Check that `spec.md` contains an `## Emotion & Brand Foundation` section with all required subsections:

1. `### User Emotional Archetype` — present and non-empty
2. `### Desired Emotional Keywords` — present and non-empty
3. `### What This Product Is Not` — present and non-empty
4. `### First Impression Narrative` — present and non-empty
5. `### Visual Metaphor Anchor` — present and non-empty
6. `### Design System Reference` — present and references `planning/design-system.md`

### Design System Artifact Check

Verify that `product/specs/[this-spec]/planning/design-system.md` exists and contains:

1. A `## Color Tokens` section with at least 5 color entries
2. A `## Typography Tokens` section with font family and size entries
3. A `## Spacing Scale` section
4. A `## Component Patterns` section

### Content Quality Check

For each required emotion-first subsection, verify:

1. The section body is at least 20 words (not just a heading with no content).
2. The content is specific — flag generic phrases like "modern and clean" or "user-friendly" as warnings.
3. Anti-patterns section contains at least 3 explicit "not" statements.

### Strictness Mode

- **Default (soft warning):** Report missing or weak emotion-first sections as warnings. Do not block task creation.
- **Strict mode:** Report as errors. Block task creation until resolved. Strict mode is enabled when:
  - Spec metadata includes `emotion-first-strict: true`, OR
  - Profile config includes `emotion_first_strict: true`

## Remediation Guidance

When checks fail, include actionable guidance in the verification report:

| Failure | Remediation |
|---------|-------------|
| Missing `## Emotion & Brand Foundation` section | Run `shape-spec` with emotion-first capture, then re-run write-spec |
| Missing subsection (e.g., no `### Visual Metaphor Anchor`) | Add the missing subsection to spec.md with specific content |
| Empty subsection (heading only, no content) | Fill in the subsection — see write-spec workflow for canonical example |
| Missing `planning/design-system.md` | Run `shape-spec` to generate design preview and persist design system |
| Generic content detected | Replace with specific, actionable emotional direction — see examples in write-spec workflow |
| Missing frontend skill reference (check 6 WARN) | Add `## Frontend Design Guidance` section with the canonical template from `write-spec` workflow, or add `frontend-design` to the spec's implementation notes |

## Output

Write all findings to `product/specs/[this-spec]/verification/spec-verification.md`.

Format:

```markdown
# Spec Verification Report: [spec-name]

**Date:** [date]
**Status:** [Pass | Pass with Warnings | Fail]

## Standard Checks

- [PASS/WARN/FAIL] Requirements coverage
- [PASS/WARN/FAIL] Scope clarity
- [PASS/WARN/FAIL] Testability
- [PASS/WARN/FAIL] Path consistency
- [PASS/WARN/SKIP] Knowledge sources field present (SKIP if spec unmodified in git)
- [PASS/WARN/SKIP] Frontend skill reference (SKIP if frontend_scope=false)

## Emotion-First Checks

- [PASS/WARN/FAIL/SKIP] Eligibility: [eligible | not eligible]
- [PASS/WARN/FAIL] Emotion & Brand Foundation section present
- [PASS/WARN/FAIL] All required subsections present and non-empty
- [PASS/WARN/FAIL] Design system artifact exists
- [PASS/WARN/FAIL] Content quality (specificity check)

## Findings

[Details of any warnings or failures with remediation guidance]

## Recommended Next Command

[Next step based on results]
```
