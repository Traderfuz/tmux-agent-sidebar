<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/visual-review-gate.md and re-run profile-sync. -->
# Visual Review Gate Standards

## Overview

AI agents producing visual output — design drafts, PDF renders, diagrams, UI screenshots — routinely claim completion without anyone looking at what was produced. The agent writes a file, prints a summary, and moves on. The user discovers the output is wrong hours later when they open it. This standard requires two gates before any visual output can be called done: the agent verifies its own output visually, and the user confirms it meets intent.

## Scope

This standard covers completion review gates for skills and workflows that produce visual output. It does NOT cover visual context collection mechanics (see `visual-context-for-agents.md`), visual regression testing methodology (see `e2e-testing-standards.md`), or design quality scoring criteria.

## Principles

1. **No invisible output:** If a skill produces something meant to be seen, someone must see it before it ships. A file written to disk without visual verification is a draft, not a deliverable.
2. **Two-gate verification:** Automated self-check catches mechanical failures (blank renders, missing assets, broken layout). Human review catches intent failures (wrong direction, misunderstood brief, aesthetic mismatch). Neither gate alone is sufficient.
3. **Evidence over assertion:** "The PDF looks correct" is an assertion. A screenshot of the rendered PDF presented to the user is evidence. Gate passage requires evidence, not assertion.
4. **Explicit approval, not silence:** The user must actively confirm ("approved", "looks good", "yes"). Absence of objection is not approval. Proceeding without response is a gate violation.

## Visual Output Definition

A skill produces **visual output** when any of these conditions hold:

- It generates rendered HTML, PDF, or image files meant for human viewing
- It produces diagram source (Excalidraw JSON, Mermaid, SVG, ASCII art) or a
  **text-form visual artifact** (ASCII wireframe, Mermaid source, SVG source,
  diagram source) that represents a visual artifact
- It creates or modifies UI components, design tokens, or style systems
- It generates design specs, wireframes, or mockups in any format
- It produces screenshots, visual diffs, or comparison reports with visual evidence

**Not visual output:** log files, JSON data, JSONL records, CLI text output, configuration files, test results, code-only changes with no rendered surface.

## Affected Skills

These skills produce visual output and MUST implement both gates:

| Skill | Visual output type | Current gate status |
|---|---|---|
| `ai-design-draft` | HTML wireframes + design previews | Candidate gates required by this standard; implementation tracked separately |
| `ui-design-qa --mode verify` | PASS/FAIL comparison reports with screenshots | Automated check only — no user approval gate |
| `ui-review --scope full` | Severity-scored visual audit reports | Automated check only — no user approval gate |
| `ui-design-qa` | Classification reports with visual diffs | Automated check only — no user approval gate |
| `consume-design` | Scaffold HTML from Creative OS handoff | Neither gate — no rendered output verification |
| `frontend-design` | Production UI components | Neither gate — no screenshot review |
| `ai-pdf-design` | PDF/markup output | Neither gate — no rendered output verification |
| `excalidraw` | Diagram JSON | Neither gate — no diagram review |

Any new skill that produces visual output MUST implement both gates before release.

## Rules

### Gate 1: Automated Visual Check (Agent Self-Verification)

Before presenting output to the user, the producing skill MUST verify its own visual output:

1. **Render the artifact** — open the HTML in a browser, render the PDF, display the diagram. File existence alone is not verification.
2. **Capture evidence** — take a screenshot or capture the rendered output as an image. This screenshot is the evidence artifact for Gate 2.
3. **Validate against intent** — check the rendered output against the original brief, spec, or user request. Flag obvious failures: blank pages, missing content, broken layout, unresolved placeholders, default/lorem-ipsum content still present.
4. **Fail loudly on mechanical defects** — if the render is blank, crashes, shows errors, or is missing critical content, do NOT proceed to Gate 2. Fix the defect and re-render.

When browser tools are unavailable, the skill MUST state that automated visual verification was skipped and note the reason. Browser evidence capture MUST follow `browser-review-policy.md`: Playwright CLI is the default automation driver, `browser-cdp` is the default visible local review target when watchable local QA is appropriate, Playwright-managed headed/headless browsers are fallback/CI targets, and Playwright MCP is the fallback automation interface. The user review gate (Gate 2) becomes the sole verification — it cannot be skipped.

### Gate 2: User Review (Explicit Confirmation)

After Gate 1 passes, the skill MUST present visual evidence and obtain explicit user approval:

1. **Present the evidence** — show the screenshot, render it in a viewer, or
   open the artifact. For a text-form visual artifact, the assistant message
   that asks for approval MUST include the artifact body verbatim; use a fenced
   code block when alignment is load-bearing. A file path, tool-call read, or
   prose description is not presentation for a text-form visual artifact.
2. **Ask for explicit approval** — use a clear prompt: "Review this [output type]. Approve? (yes / revise / reject)"
3. **Wait for response** — do NOT proceed to completion claims, commit suggestions, downstream skill invocations, or "done" statements until the user responds.
4. **Handle rejection** — if the user says revise: apply feedback, re-run Gate 1, re-present for Gate 2. If the user says reject: stop and report the rejection.
5. **Cap iteration** — after 5 revision rounds without approval, pause and ask the user to describe the desired outcome explicitly rather than continuing incremental revisions.

### Completion Claim Rules

These actions are BLOCKED until both gates pass:

- Printing "done", "complete", "finished", or equivalent
- Suggesting a git commit that includes the visual artifact
- Invoking a downstream skill that consumes the visual output
- Updating task checkboxes or spec status for the visual deliverable
- Moving to the next pipeline step in a chain

### Evidence Artifact Preservation

The Gate 1 screenshot SHOULD be preserved alongside the visual output:

- For design drafts: `planning/screenshots/<artifact-name>-review.png`
- For PDF output: `planning/screenshots/<document-name>-render.png`
- For diagrams: `planning/screenshots/<diagram-name>-preview.png`

If screenshot preservation is impractical (e.g., ephemeral browser session), the skill MUST note that evidence was shown but not persisted.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| "File written to `output.html` — done!" | No one looked at the output; could be blank or broken | Render → screenshot → present to user → wait for approval |
| Describing the visual output in prose instead of showing it | Prose descriptions mask layout, spacing, color, and rendering failures | Capture and present the actual rendered screenshot |
| Proceeding after showing output without waiting for response | Silence is not approval; user may not have seen it | Explicit approval prompt with wait |
| Running Gate 2 on source (JSON, markup) instead of rendered output | Users review what they see, not what generates it | Render first, then present the rendered form |
| Skipping Gate 1 when "the template is known to work" | Templates break when populated with real content | Always render and verify, even for known templates |
| Re-running Gate 2 without re-running Gate 1 after changes | Post-revision render may introduce new mechanical defects | Both gates re-run on every revision cycle |


| Presenting an ASCII wireframe, Mermaid source, or diagram source only as a file path or collapsed tool card | The reviewer cannot see the visual structure at approval time | Inline the complete artifact body in the approval message; fence alignment-sensitive text |
## Deviation Guidance

You MAY skip Gate 1 (automated check) when:
- Browser/rendering tools are genuinely unavailable AND the limitation is stated to the user
- The output is a minor text-only change to an already-approved visual artifact

You MUST NOT skip Gate 2 (user review) for any visual output. Gate 2 has no deviation path. If the user explicitly says "skip review" or "I trust it", that counts as approval — log it and proceed.

You MAY reduce the iteration cap below 5 when the user requests faster throughput, but MUST NOT set it below 2 (one initial review + one revision minimum).

## Profile Inheritance Notes

This is a general profile standard. Child profiles:
- MAY add domain-specific evidence requirements (e.g., `webapp` profile may require multiple viewport screenshots)
- MAY add tool-specific rendering instructions that extend `browser-review-policy.md` without weakening its driver/target/auth/backend routing
- MAY tighten the iteration cap or add additional automated checks
- MUST NOT weaken or remove Gate 2 (user review requirement)
- MUST NOT allow completion claims before both gates pass

## Compliance Test

- [ ] Does every skill that produces visual output render the artifact and capture a screenshot before presenting to the user?
- [ ] Does every visual output skill present rendered evidence (not prose description) to the user with an explicit approval prompt?
- [ ] Does every text-form visual artifact appear verbatim in the same assistant message that asks for approval, fenced when alignment is load-bearing?
- [ ] Does the skill block all completion claims, commit suggestions, and downstream invocations until the user explicitly approves?
- [ ] When the user requests revisions, does the skill re-run both Gate 1 and Gate 2 before re-presenting?
- [ ] Does the skill cap revision rounds and escalate when the cap is reached rather than looping indefinitely?
- [ ] When automated rendering is unavailable, does the skill state the limitation rather than silently skipping verification?
If any check fails: add the missing gate, evidence capture, or approval prompt before claiming the skill is complete.

## References

- [Stage-Gate Process (Robert G. Cooper)](https://www.stage-gate.com/) — phase-gate methodology requiring quality criteria at each decision point before progression. Visual review gate applies Cooper's principle: output quality is verified at a defined checkpoint, not discovered downstream.
- [Human-in-the-Loop Approval Pipeline](https://galileo.ai/blog/human-in-the-loop-agent-oversight) — AI-generated outputs routed to human review before finalization. Gate 2 implements this pattern for visual artifacts.
- [Iterative Feedback Loop pattern](https://www.mindstudio.ai/blog/iterative-kanban-pattern-ai-agents-feedback-loop) — "done" in agent workflows means mutual agreement between human and agent output, not just task completion. The revision cycle with capped iterations follows this model.
- [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) — normative vocabulary for MUST, SHOULD, MAY.
- `visual-context-for-agents.md` — sibling standard covering observation mechanics and screenshot escalation (how to capture visual context). This standard covers when to require visual review (completion gates).
- `ai-design-draft` skill — candidate-gate implementation tracked separately; this standard defines the shared presentation contract.
