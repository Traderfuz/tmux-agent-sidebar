# Session Context Refresh Workflow

Displays a compact summary of what changed since the last session, then continues automatically. No user prompt.

## When to Use

Invoked at the start of every `resume` and `implement-tasks` session, before any pre-flight checks.


Do not use at the start of a new session — this workflow refreshes context mid-session. Do not use when context is already current (no new commits since last refresh).
## Process

### Step 1: Locate State Reference

Read `.dev-os/runtime/context-refresh-state.json` to get the last-known SHA and mtime for each tracked file.

If the state file does not exist, treat all files as "first run" — skip comparison and display:

```
Session Context Refresh — first run, no baseline to compare.
```

Then proceed.

### Step 2: Compare Tracked Files

For each file in this list, compare current state against the stored baseline:

| File | Signal |
|------|--------|
| `CLAUDE.md` | SHA changed |
| `AGENTS.md` | SHA changed |
| `product/specs/<spec>/spec.md` | mtime newer than session checkpoint mtime |
| `product/specs/<spec>/tasks.md` | SHA changed AND/OR new `- [x]` items not recorded in checkpoint |
| `.dev-os/config.yml` | SHA changed |
| `product/roadmap.md` | SHA changed |
| `product/product-overview.md` | SHA changed |
| `product/tech-stack.md` | SHA changed |

For `tasks.md` specifically: if the SHA changed, also count how many `- [x]` items exist now vs. how many were recorded at the last checkpoint. The difference = "tasks completed externally".

### Step 3: Build Summary

Construct a one-line-per-file table:

```
Session Context Refresh
-----------------------
CLAUDE.md          unchanged
spec.md            CHANGED (updated 14h ago)
tasks.md           2 tasks completed externally since last checkpoint
AGENTS.md          unchanged
config.yml         unchanged
```

Rules:
- If a file does not exist, show `missing`
- If a file changed, show `CHANGED` with a human-readable age (e.g., "14h ago", "2d ago")
- If tasks were completed externally, show the count explicitly
- If ALL files are unchanged, collapse the entire block to a single line:

```
Session Context Refresh — no changes since last session.
```

### Step 4: Handle Externally Completed Tasks

If tasks.md shows tasks marked `- [x]` that were not recorded in the checkpoint:

1. Count them
2. Include in the summary line: `tasks.md  N tasks completed externally since last checkpoint`
3. Update the session's current position to account for them — skip those tasks during implementation
4. Do NOT re-implement already-completed tasks

### Step 5: Display and Continue

Print the summary block, then immediately continue to the next step (pre-flight checks or implementation). No pause, no prompt.

Format:
```
Session Context Refresh
-----------------------
[one line per file]

Continuing from [task position] — [task name]
```

Or if first run / no session position known:
```
Session Context Refresh — no changes since last session.
```

## Display

Context refresh status:

```
Session context refreshed
  CLAUDE.md:    current
  AGENTS.md:    current
  Standards:    [N] files injected
  Last updated: [timestamp]
```
