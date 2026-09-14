# Design Approval Review

Single-design scorecard review used before design handoff. Evaluates one design artifact or implementation candidate against six design principles and returns **Approved**, **Approved with conditions**, or **Rejected**. Browser capture follows `profiles/general/standards/global/browser-review-policy.md`; reports include selected driver, selected target, auth path, backend, artifact paths, and fallback reason.

## When to Use

- After a design draft is complete and needs approval before handoff
- Before running the design-handoff workflow
- When reviewing one frontend PR for visual quality
- When a client asks for design approval before development begins

**Do NOT use when:** auditing an entire live project or route set. Use `design-review.md` for the whole-project audit pipeline.

## Process

1. Capture screenshots at desktop and mobile viewports.
2. Score each of the 6 design principles against defined criteria.
3. Identify blocking issues (any criterion below threshold).
4. Produce pass/fail verdict with per-criterion scores and remediation guidance.

### Step 1: Capture screenshots

Capture the design at two viewport sizes:

- **Desktop:** 1440 x 900
- **Mobile:** 375 x 812

If the design is a live URL, use the browser-review policy route: Playwright CLI/default Playwright tooling as driver, `browser-cdp` as visible local target when watchable review is appropriate, managed headed/headless fallback, and Playwright MCP fallback only when CLI is unavailable or insufficient. If it is an HTML file, open it in a browser and screenshot it.

### Step 2: Evaluate against design principles

Score each criterion as **Pass**, **Needs work**, or **Fail**.

#### Criterion 1: Visual hierarchy
- Is the most important element the most visually prominent?
- Does the eye flow from primary → secondary → tertiary content?
- Are there competing focal points?

#### Criterion 2: Contrast and readability
- Does body text meet WCAG AA contrast (4.5:1)?
- Do large headings meet WCAG AA contrast (3:1)?
- Are interactive elements distinguishable from static content?

#### Criterion 3: Consistency
- Are similar elements styled identically?
- Does the design use design-system tokens?
- Are spacing patterns consistent?

#### Criterion 4: Spacing and alignment
- Do spacing values align to the 4px grid?
- Are edges, centers, and baselines aligned?
- Is vertical rhythm maintained?

#### Criterion 5: Typography
- Does the type scale follow a modular ratio?
- Is body text line length between 45–75 characters?
- Are font sizes chosen intentionally?

#### Criterion 6: Accessibility
- Are interactive elements keyboard-accessible?
- Do form inputs have visible labels?
- Are focus states visible?
- Does the design work with reduced motion preferences?

### Step 3: Generate review report

Compile:
- overall status: **Approved** / **Approved with conditions** / **Rejected**
- per-criterion scores with findings
- screenshots with annotations when possible
- specific recommendations for every `Needs work` or `Fail`

### Step 4: Approve or request changes

- **All Pass** → Approve. Proceed to design-handoff.
- **All Pass or Needs Work (no Fails)** → Approved with conditions. Write `product/design-check/<spec>/design-conditions.md`.
- **Any Fail** → Rejected. Return to design iteration before re-review.

Condition tracking artifact:

```markdown
# Design Conditions: <spec>
**Date:** YYYY-MM-DD
**Review status:** APPROVED WITH CONDITIONS

## Open Conditions
- [ ] <condition 1>
- [ ] <condition 2>

## Closed Conditions
(moved here when confirmed fixed during implementation)

## Verified by
(reviewer name and date)
```

## Display Format

```
Design Approval Review — [spec-name]
  Visual Hierarchy:        [pass | needs work | fail]
  Contrast & Readability:  [pass | needs work | fail]
  Consistency:             [pass | needs work | fail]
  Spacing & Alignment:     [pass | needs work | fail]
  Typography:              [pass | needs work | fail]
  Accessibility:           [pass | needs work | fail]
  ─────────────────────────────────────────────────
  Verdict: [APPROVED | APPROVED WITH CONDITIONS — N items | REJECTED — N criteria failed]
```
