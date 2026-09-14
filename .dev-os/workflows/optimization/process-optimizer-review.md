# Process Optimizer Review Workflow

Analyze the proposed workflow/feature for process inefficiencies, gaps, and automation opportunities **before implementation begins**. This review produces RECOMMENDATIONS only - it does not block task creation.

## When to Use

This workflow is invoked after a spec is written but before tasks are created. It evaluates the **proposed business process or user workflow** that the feature will implement, identifying inefficiencies before they're built.


Do not use after implementation has started — this review is a pre-implementation gate. Do not use to review already-shipped features; use `gap-analysis` for post-ship audits.
## Process

### 1. Gather Specification Context

Read and analyze the specification documents:

```bash
# Read the spec
cat product/specs/[this-spec]/spec.md

# Read the requirements
cat product/specs/[this-spec]/planning/requirements.md

# Check for visual assets (workflow diagrams, mockups)
ls -la product/specs/[this-spec]/planning/visuals/ 2>/dev/null
```

### 2. Identify Workflow to Analyze

Determine the scope of process analysis:

**Business Process Analysis:**
- Map the end-to-end user/business workflow being proposed
- Identify the steps users will take
- Understand the value stream

**Context to capture:**
- Process name and purpose
- Start trigger and end condition
- User goals (optimize for speed, accuracy, simplicity?)
- Expected volume/frequency
- Known constraints or pain points

### 3. Forward Documentation (Proposed State)

Map the complete end-to-end workflow as specified.

**For each step in the proposed workflow:**

| # | Action | Actor | Inputs | Outputs | Estimated Time |
|---|--------|-------|--------|---------|----------------|
| 1 | [Step description] | [User/System] | [Required inputs] | [Produced outputs] | [Duration] |

**Capture:**
- Decision points and branching logic
- Handoffs between user and system
- Waiting states and dependencies
- External integrations or dependencies

### 4. Reverse-Gap Analysis

Work backwards through the proposed workflow to uncover potential issues.

**Process:**
1. Rewrite steps in reverse order (end → start)
2. For EACH reverse step, ask: "What could go wrong getting TO this step?"
3. Identify gaps using these labels:

| Gap Type | Label | Description |
|----------|-------|-------------|
| Handoff | `[GAP-HANDOFF]` | Unclear transition between steps |
| Validation | `[GAP-VALIDATION]` | Missing input/output validation |
| Error Handling | `[GAP-ERROR]` | No recovery path for failures |
| Feedback Loop | `[GAP-FEEDBACK]` | No confirmation of success |
| Documentation | `[GAP-DOCS]` | Missing user guidance |
| Redundancy | `[GAP-REDUNDANCY]` | Unnecessary duplication |
| Complexity | `[GAP-COMPLEXITY]` | Overly complicated for user goal |

**Minimum 3 substantive observations required** - dig deeper if needed.

### 5. Optimization Opportunities

Propose workflow improvements to address before implementation.

**Improvement types:**
- **Eliminate**: Remove unnecessary steps before building them
- **Parallelize**: Design for concurrent operations
- **Consolidate**: Merge similar steps in the design
- **Automate**: Identify what should be system-handled vs user-initiated
- **Simplify**: Reduce complexity in the spec

**Document each opportunity:**

| Improvement | Type | Current Spec | Proposed Change | Impact |
|-------------|------|--------------|-----------------|--------|
| [Description] | [Type] | [What spec says] | [Recommended change] | [Benefit] |

### 6. Automation Feasibility

Evaluate proposed manual steps for automation potential.

**For each user action, assess:**

| Step | Feasibility | Pros | Cons | Recommendation |
|------|-------------|------|------|----------------|
| [Step] | Low/Medium/High | [Benefits] | [Drawbacks] | Automate/Partial/Keep Manual |

**Feasibility factors:**
- **Repetitiveness**: Will users do this often?
- **Rule-based**: Can it be codified, or requires judgment?
- **Error-proneness**: Is manual input likely to cause mistakes?
- **User value**: Does manual control add value?

### 7. Generate Report

Create a process optimization report in `product/specs/[this-spec]/planning/process-optimizer-review.md`:

```markdown
# Process Optimization Review Report

**Date:** [ISO 8601 date]
**Spec:** [Spec name]
**Reviewer:** Automated Process Optimizer Review
**Phase:** Pre-Implementation

## Workflow Analyzed

**Process:** [Brief description of the workflow being built]
**Trigger:** [What starts this workflow]
**Outcome:** [What success looks like]

## Proposed Workflow Map

| # | Action | Actor | Inputs | Outputs | Est. Time |
|---|--------|-------|--------|---------|-----------|
| 1 | ... | ... | ... | ... | ... |

## Gap Analysis

### Identified Gaps

1. `[GAP-TYPE]` [Description of gap in proposed design]
2. `[GAP-TYPE]` [Description of gap]
3. `[GAP-TYPE]` [Description of gap]

### Gap Impact Assessment
[Which gaps are most important to address before implementation?]

## Optimization Recommendations

### Before Task Creation (Address in Spec)

| Improvement | Type | Current Spec | Proposed Change | Impact |
|-------------|------|--------------|-----------------|--------|
| ... | ... | ... | ... | ... |

### During Implementation (Note for Tasks)

[Optimizations that can be handled during task execution]

## Automation Assessment

| Step | Feasibility | Pros | Cons | Recommendation |
|------|-------------|------|------|----------------|
| ... | ... | ... | ... | ... |

## Summary

### Key Findings
1. [Finding 1]
2. [Finding 2]
3. [Finding 3]

### Spec Changes Recommended
[List specific changes to make to spec.md before creating tasks]

### Confidence Level
[Low/Medium/High] - [Rationale]

## Assumptions

[List key assumptions made during analysis]
```

### 8. Display Summary

After the review, output a summary to the user:

```
⚡ Process Optimization Review Complete (Pre-Implementation)

Workflow analyzed: [process name]
Gaps identified: [number]
Optimization opportunities: [number]
Automation candidates: [number]

Full report: product/specs/[spec]/planning/process-optimizer-review.md

💡 Review recommendations before creating tasks. Addressing gaps now is cheaper than fixing after implementation.
```

## Quality Standards

- **Conciseness**: Keep analysis focused and actionable
- **Specificity**: Reference specific parts of the spec
- **Pre-Implementation Focus**: Emphasize changes to make before building
- **Actionability**: Every recommendation must be implementable
- **Evidence-Based**: Ground recommendations in the spec details

## Notes

- This is a RECOMMENDATIONS-ONLY review. Findings do not block task creation.
- Focus on high-impact improvements that are cheap to fix now but expensive later.
- Consider user experience and workflow efficiency.
- Some complexity may be necessary - document trade-offs.
- This review happens BEFORE implementation, making changes cheap.
- Reports go in `product/specs/<spec>/planning/` since this is pre-implementation.

## Display

Optimizer review output:

```
Process Optimizer Review — [spec-name]
  Spec score:     [N]/10
  Must-fix gaps:  [N]
  Nice-to-have:   [N]
  Report:         product/specs/[spec]/planning/optimizer-review.md
```
