# Sync Documentation Workflow

Update impacted documentation after implementation changes.

## When to Use

Run this workflow after completing implementation changes that affect public interfaces, command surfaces, or documented behavior.

Do not run this workflow for implementation changes that are purely internal (no changed interfaces, no new commands, no altered public behavior).

## Process

1. Identify changed behavior and newly introduced interfaces.
2. Update relevant docs (`README.md`, guides, and product spec artifacts).
3. Ensure command examples still match implemented command surfaces.

## Display Format

```
Documentation sync complete.
  Files updated: [N]
  Sections patched: [list of changed sections]
  Next: review docs/ changes before commit
```
