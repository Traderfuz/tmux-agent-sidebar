# Implementer Agent — Design Notes

## Why Prompt Chaining?

The implementer's work is a well-defined sequence: read spec → write code → verify → commit. There is no ambiguity in step order and no branching based on intermediate tool results that would require ReAct. Prompt Chaining gives predictable, auditable progress — each step's output feeds directly into the next.

## Why Default-to-action?

The implementer is a high-frequency agent invoked on every `implement-tasks` run. Pausing for confirmation on routine writes would interrupt flow and add friction. The non-negotiables cover the three cases where autonomous action is genuinely unsafe (already-done tasks, out-of-repo files, destructive git ops).

## Why max_turns: 40?

Complex implementation specs routinely span 15–25 tasks across 4–6 groups. Each group consumes roughly 4–6 turns (read, write, verify, commit, report). 40 turns comfortably covers a full spec in one session with buffer for retry on failures.

## Reversibility Design

File writes and commits are classified as free because they are cheap to undo via git. File deletes and destructive git operations are elevated because they can permanently lose work outside the git history. The classify-at-operation-level approach (vs. a blanket rule) lets the agent move fast on safe operations while being explicit on dangerous ones.

## Subdirectory Layout Rationale

Promoting from a flat `.md` to a subdirectory (`implementer/`) follows the `git-automation/` reference pattern. Benefits:
- `system-prompt.md` can be loaded separately by agent coordinators that need only the behavioral contract
- `DESIGN-NOTES.md` keeps rationale out of the entry-point file, keeping `implementer.md` concise
- Future `CHANGELOG.md` and `evals/` can be added without cluttering the profile root

## Relationship to spec-writer

`implementer` is downstream of `spec-writer`. It consumes `tasks.md` produced by spec-writer's output. The two agents share no state — implementer reads from disk, not from spec-writer's memory. This clean separation means either agent can be upgraded independently.
