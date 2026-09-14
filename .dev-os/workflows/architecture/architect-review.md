# Architect Review Workflow

Perform an architectural review of the specification to identify design issues, anti-patterns, and potential technical debt **before implementation begins**. This review produces WARNINGS only - it does not block task creation.

## When to Use

This workflow is invoked after a spec is written but before tasks are created. Catching architectural issues early prevents costly rework during implementation.



Do not use this workflow after implementation has started — its purpose is to catch design issues before code is written, not to review completed work.

## Process

## Process

1. Gather specification context (read `spec.md`, requirements, visuals).
2. Analyze business goals, NFRs, existing architecture, and scope boundaries.
3. Audit proposed design against architectural patterns (Clean Architecture, layered, event-driven, SOLID).
4. Check integration points and cross-cutting concerns.
5. Produce a WARNINGS report with severity ratings (do not block task creation).

### 1. Gather Specification Context

Read and analyze the specification documents:

```bash
# Read the spec
cat product/specs/[this-spec]/spec.md

# Read the requirements
cat product/specs/[this-spec]/planning/requirements.md

# Check for visual assets
ls -la product/specs/[this-spec]/planning/visuals/ 2>/dev/null
```

### 2. Context Analysis

Before reviewing, understand:
- **Business goals**: What problem is this feature solving?
- **Non-functional requirements**: Performance, scalability, maintainability targets
- **Existing architecture**: Current patterns and conventions in the codebase
- **Scope boundaries**: What's explicitly out of scope?

### 3. Architectural Pattern Audit

Evaluate the proposed design against architectural patterns:

#### Pattern Compliance
- **Clean Architecture**: Will dependencies point inward? Is business logic isolated from infrastructure?
- **Layered Architecture**: Are layer boundaries clear? No UI logic mixed with data access?
- **Hexagonal/Ports & Adapters**: Are external dependencies abstracted through ports?

#### SOLID Principles Assessment
- **Single Responsibility**: Does each proposed component have one reason to change?
- **Open/Closed**: Can the design be extended without modifying existing code?
- **Liskov Substitution**: Are inheritance hierarchies sound?
- **Interface Segregation**: Are interfaces focused and minimal?
- **Dependency Inversion**: Do high-level modules depend on abstractions?

#### Domain-Driven Design (if applicable)
- **Bounded Contexts**: Are service boundaries aligned with business domains?
- **Aggregates**: Are aggregate roots properly identified?
- **Domain Events**: Are cross-boundary communications event-driven?

### 4. Anti-Pattern Detection

Check for common architectural anti-patterns in the proposed design:

| Anti-Pattern | Description | Warning Signs |
|--------------|-------------|---------------|
| **God Object** | Component that does too much | Spec describes one component handling many concerns |
| **Distributed Monolith** | Microservices that must deploy together | Tight coupling between proposed services |
| **Anemic Domain Model** | Domain objects with only data | Business logic specified in services, not entities |
| **Golden Hammer** | Using one pattern for everything | Same solution regardless of problem type |
| **Leaky Abstraction** | Implementation details exposed | Database types in API responses |
| **Circular Dependencies** | Modules that depend on each other | A→B→C→A dependency chains |
| **Over-Engineering** | Unnecessary complexity | Features beyond stated requirements |

### 5. Quality Attributes Assessment

Evaluate non-functional characteristics of the proposed design:

#### Scalability
- Can components scale independently?
- Are there potential bottlenecks (shared state, synchronous calls)?
- Is caching strategy appropriate for expected load?

#### Maintainability
- Is the design self-documenting?
- Are changes isolated (low blast radius)?
- Is cognitive load reasonable for the team?

#### Testability
- Can components be tested in isolation?
- Are dependencies injectable?
- Are side effects controlled and mockable?

#### Performance
- Are N+1 query patterns likely?
- Are expensive operations deferred appropriately?
- Is pagination planned for large datasets?

### 6. Reusability Analysis

Check alignment with existing codebase:
- Are existing components being leveraged?
- Are new abstractions justified?
- Does the design follow established patterns?

### 7. Generate Report

Create an architectural review report in `product/specs/[this-spec]/planning/architect-review.md`:

```markdown
# Architect Review Report

**Date:** [ISO 8601 date]
**Spec:** [Spec name]
**Reviewer:** Automated Architect Review
**Phase:** Pre-Implementation

## Specification Analyzed

- `spec.md`: [Brief summary of what's proposed]
- `requirements.md`: [Key requirements noted]

## Architectural Impact

**Weight:** [High/Medium/Low]
**Rationale:** [Why this level of impact]

## Findings

### 🔴 Critical (0)
[Issues that should be resolved before creating tasks]
None

### 🟠 High (0)
[Significant design issues to address]
None

### 🟡 Medium (0)
[Design smells to consider]
None

### 🔵 Low (0)
[Minor improvement opportunities]
None

### ℹ️ Informational (0)
[Worth noting, not problems]
None

## SOLID Compliance

| Principle | Status | Notes |
|-----------|--------|-------|
| Single Responsibility | ✅/⚠️/❌ | [details] |
| Open/Closed | ✅/⚠️/❌ | [details] |
| Liskov Substitution | ✅/⚠️/❌ | [details] |
| Interface Segregation | ✅/⚠️/❌ | [details] |
| Dependency Inversion | ✅/⚠️/❌ | [details] |

## Pattern Recommendations

[Specific patterns to apply during implementation]

## Refactoring Suggestions

[Concrete changes to the spec before task creation]

## Trade-off Analysis

[Document rationale and compromises]

## Summary

[Overall assessment - Ready for task creation? Needs spec revision?]
```

### 8. Display Summary

After the review, output a summary to the user:

```
🏛️ Architect Review Complete (Pre-Implementation)

Spec analyzed: [spec name]
Architectural impact: [High/Medium/Low]
Findings: [X critical, X high, X medium, X low, X informational]

Full report: product/specs/[spec]/planning/architect-review.md

⚠️ Review findings before creating tasks. Critical issues should be addressed in the spec first.
```

## Severity Guidelines

| Severity | Definition | Example |
|----------|------------|---------|
| 🔴 Critical | Fundamental architectural flaw | Missing core abstraction, circular dependency design |
| 🟠 High | Significant design issue | God object planned, no separation of concerns |
| 🟡 Medium | Design smell, should address | Unclear boundaries, potential coupling |
| 🔵 Low | Minor improvement opportunity | Could use existing pattern |
| ℹ️ Informational | Worth noting, not a problem | Consider future extensibility |

## Notes

- This is a WARNINGS-ONLY review. Findings do not block task creation.
- Focus on structural issues that are expensive to fix later.
- Consider the team's experience level and project constraints.
- Some "violations" may be intentional trade-offs - document them.
- Critical findings should ideally be addressed in the spec before creating tasks.
- This review happens BEFORE implementation, making changes cheap.

## Display Format

```
Architect Review — [spec-name]
  Patterns:      [N checked]
  Warnings:      [N issues]
  Blockers:      [N | none]
  Verdict:       [proceed | warnings — review before tasking]
```
