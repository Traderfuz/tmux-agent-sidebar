# Orchestrate Context Workflow

Shared context gathering and recommendation inputs for `orchestrate`.

## When to Use

Use this workflow at the start of each implementation session to load the minimal context needed for the current spec — preventing token bloat from irrelevant context.

Do not use this workflow to load context for exploratory or planning work. For full project context, rely on AGENTS.md and the context bundle directly.

## Read Sources

Gather the smallest context that still supports a correct recommendation:

1. `product/specs/feature-backlog.md`
2. `product/specs/*/spec.md`
3. `product/specs/*/tasks.md`
4. `.dev-os/config.yml`
5. `git status --short`
6. `git branch --show-current`
7. relevant runtime ownership or drift artifacts if they exist

## Classification

Classify each candidate item as one of:

- blocked
- near-complete
- in progress
- ready
- needs tasking
- needs spec
- maintenance
- complete

## Recommendation Inputs

When ranking work, consider:

- explicit blocker state
- completion percentage
- active branch or session context
- dependency or unblock value
- whether the next step is deterministic and immediately actionable

## Output Contract

The default navigator response should provide:

1. current project state summary
2. one primary recommendation
3. exact next command
4. one to three alternatives only when useful
