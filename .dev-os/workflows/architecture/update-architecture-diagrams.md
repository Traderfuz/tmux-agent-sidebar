# Update Architecture Diagrams Workflow

Update architecture diagrams when implementation changes structural system behavior.

## When to Use

Run this workflow after completing any implementation that changes module boundaries, data flows, agent handoffs, or shared service contracts.

Do not run this workflow for cosmetic code changes, test-only changes, or refactors that preserve existing structural interfaces unchanged.

## Process

1. Identify affected components from implementation diff.
2. Update corresponding Mermaid/diagram sections in `ARCHITECTURE.md`.
3. Ensure diagram labels and flows reflect current runtime behavior.

## Display Format

```
Architecture diagram update complete.
  Modified: ARCHITECTURE.md (sections: [Component Map, Data Flow])
  Diagrams updated: 2
  Next: commit updated diagrams alongside implementation
```
