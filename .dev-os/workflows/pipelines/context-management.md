# Context Management Pipeline

<!-- This pipeline is reachable via orchestrate for goals: "Fix context", "Context stale", "Debug context", "Shrink context". -->

Diagnose, repair, and optimize the DevOS context layer — covering context size, staleness, drift, and corruption — without triggering a full context rebuild.

## When to Use

- "Context feels stale", "AGENTS.md is out of date", "context is too big / too slow"
- Debugging why a session has poor project awareness or incorrect suggestions
- After an aggressive cleanup where context files may have been inadvertently removed
- Context size has grown and is causing slow session startup
- Spot-check before an important session without running the full context-full-refresh pipeline
- Orchestrate routes here for goal types: "Fix context", "Context stale", "Debug context", "Shrink context"
- Anti-trigger: do NOT use for a full context rebuild — use context-full-refresh instead
- Anti-trigger: do NOT use for standards sync — use standards-refresh instead

## Prerequisites

- DevOS initialized in the project (`start` has been run)
- Access to `.dev-os/runtime/context-refresh-state.json`

## Steps

### Step 1: Size Audit

**Skill:** `context-surface-audit` (size and context-artifact audit)
**Input:** Current context artifacts (`docs/context/`, `AGENTS.md`, `.dev-os/standards/`)
**Output:** Size report — total tokens, largest files, files above threshold
**Gate to next step:** Report written; proceed regardless of findings
**Skip if:** Context size is not a concern and this step was not the trigger for running the pipeline

Size thresholds (from DevOS defaults):
- `AGENTS.md` > 50KB → warn
- `docs/context/DEVOS_CONTEXT_BUNDLE.md` > 100KB → warn
- Total context > 200KB → escalate to context-full-refresh recommendation

### Step 2: Debug Context State

**Skill:** `context-surface-audit` (context drift and freshness audit)
**Input:** `.dev-os/runtime/context-refresh-state.json`, `AGENTS.md`, `docs/context/DEVOS_CAPABILITIES_INDEX.md`
**Output:** Diagnostic summary — context age, which files are stale, which are current
**Gate to next step:** Diagnostic complete; findings recorded
**Skip if:** No staleness or corruption symptoms (pipeline triggered for size-only concerns)

Staleness thresholds:
- `context-refresh-state.json` older than 7 days → context refresh recommended
- `AGENTS.md` header date older than current session start → regeneration needed
- `docs/context/` files older than `context-refresh-state.json` → regeneration needed

### Step 3: Reset Context State (conditional)

**Skill:** `devos-clear`
**Input:** `.dev-os/runtime/context-refresh-state.json`
**Output:** Context state cleared; ready for fresh context generation
**Gate to next step:** State file reset; `context-refresh-state.json` shows clean state
**Skip if:** Only regeneration is needed (not a full state reset); skip unless Step 2 found corruption or irrecoverable staleness

Context reset removes cached state but does NOT delete source artifacts. It forces the next context generation step to recompute from scratch.

### Step 4: Regenerate Context Bundle

**Skill:** `context-full-refresh`
**Input:** Project source artifacts, `docs/`, `profiles/general/`, `.dev-os/standards/`
**Output:** `docs/context/DEVOS_CONTEXT_BUNDLE.md`, `docs/context/DEVOS_CAPABILITIES_INDEX.md` regenerated
**Gate to next step:** Bundle files updated with current date in header
**Skip if:** Bundle files are already current (Step 2 confirmed no staleness, and size is the only concern)

### Step 5: Regenerate AGENTS.md

**Skill:** `generate-agents-md`
**Input:** Regenerated context bundle from Step 4
**Output:** `AGENTS.md` updated with current date and fresh content
**Gate to completion:** `AGENTS.md` header date matches today
**Skip if:** `AGENTS.md` is already current (Step 2 confirmed no staleness)

### Step 6: Verify Context

**Skill:** Inline verification — ask 2-3 questions answerable from current context
**Input:** Regenerated `AGENTS.md` and context bundle
**Output:** Confirmation that context answers known questions correctly
**Gate to completion:** At least 2 of 3 context questions answered correctly
**Skip if:** Time-constrained session — skip verification and trust the regeneration

Verification questions (pick 2-3 that match this project):
1. "What is the current version of this project?"
2. "What commands are available in DevOS?"
3. "What profile is active for this project?"

## Pipeline Variants

### Size Reduction Only (`--shrink`)

Run Step 1 only (size audit). Report which files are oversized without making changes.
Use when investigating why sessions are slow without committing to a full repair.

### Staleness Check Only (`--check-staleness`)
Run Steps 1-2 only (size + context audit). Report context age and staleness without regenerating.
Use before deciding whether to run context-full-refresh or this lighter pipeline.

### Force Regen (`--force`)

Skip Steps 1-2 (size + debug). Run Steps 3-6 (reset + full regen + verify).
Use when context is known to be stale and you want to skip diagnosis.

## Resume Points

| Artifact | Indicates | Resume at |
|----------|-----------|-----------|
| `context-surface-audit` output recorded | Size and context audit done | Step 3 (reset if needed) or Step 4 (refresh) |
| `.dev-os/runtime/context-refresh-state.json` shows clean state | Reset done | Step 4 (regen bundle) |
| `docs/context/DEVOS_CONTEXT_BUNDLE.md` header date today | Bundle regenerated | Step 5 (regen AGENTS.md) |
| `AGENTS.md` header date today | AGENTS.md current | Step 6 (verify) |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | Context surface audit fails (files missing) | Run `start` to reinitialize DevOS project structure |
| Step 2 | Context audit finds corruption | Escalate to `context-full-refresh` for complete rebuild |
| Step 3 | Context reset fails | Run `devos-clear` again after confirming the state path |
| Step 4 | Context refresh fails (missing source files) | Check that `docs/`, `profiles/general/`, `.dev-os/standards/` exist; run `extract-standards` first |
| Step 5 | AGENTS.md generation fails | Run `generate-agents-md --force` |
| Step 6 | Verification fails (context answers wrong) | Context refreshed but incorrect — escalate to `context-full-refresh` |

## Display Format

```
Context Management Pipeline
  Diagnostics: [context-size | drift | staleness | corruption]
  Action taken: [repair | shrink | rebuild-partial | refresh]
  Context bundle: [current | updated]
  Status: [complete]
```
