<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/gap-closure-posture.md and re-run profile-sync. -->
<!-- source: profile:default -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/default/standards/global/gap-closure-posture.md and re-run profile-sync. -->
---
id: gap-closure-posture
category: global
version: 1.0.0
created: 2026-04-17
status: active
---

# Gap Closure Posture

## Overview

Gap analysis and gap closure are one atomic unit of work — not two separate tasks. Finding a gap without closing it or tracking it is incomplete work.

The gap analysis report is not the deliverable. Closure is.

A common failure pattern looks like this: "I ran gap analysis, found 3 Critical gaps, filed the report, then committed." This is incomplete work. The report describes the problem. The closure resolves it. Filing a report and walking away leaves the product in a worse-documented but no less broken state than before analysis ran.

This standard governs the required posture from the moment a gap is discovered to the moment a session or commit is considered done. It applies to any session that includes running `gap-analysis`, manually auditing the gap registry, or discovering gaps incidentally during implementation or review work.

## Scope

Applies to all DevOS-managed projects, all sessions that touch `product/gap-analysis/gap-registry.jsonl`, and all agents or workflows that produce gap entries. Does not govern how to run gap analysis itself (see the `gap-analysis` skill), nor how to prioritize features that are not yet discovered gaps.

## Severity Definitions

| Severity | Meaning |
|----------|---------|
| `critical` | Broken, missing, or incorrect behavior that blocks a user flow or violates a hard requirement |
| `high` | Significant gap that degrades the product or introduces risk; not an immediate blocker |
| `medium` | Meaningful but non-urgent gap; impairs quality without blocking core flows |
| `low` | Minor polish, edge case, or improvement opportunity |

## Rules

### R1 — Critical gaps block commit, verify, and "done" (`MUST`)

No commit, no `verify` pass, and no session "done" declaration is valid while any entry with `"severity": "critical"` AND `"status": "open"` exists in `product/gap-analysis/gap-registry.jsonl`.

Before running `commit`, check:

```bash
grep -c '"severity": "critical"' product/gap-analysis/gap-registry.jsonl
# Then confirm all critical entries also have "status": "closed"
```

If any open Critical entries exist: stop, list the open gaps explicitly, resolve them first, then re-check.

**Exception:** If a Critical gap is out of scope for the current session (e.g., it belongs to a different subsystem with no current spec), it must be escalated — create a blocker task via `create-tasks` and add a `"blocked_by_task": "<task-id>"` field to the registry entry. It cannot be silently left open.

### R2 — High gaps must be closed or tasked before session ends (`MUST`)

A High gap that is discovered and neither closed nor assigned a remediation task by session end is a violation of this standard.

"I'll fix it later" is only acceptable if it is backed by a concrete task created via `create-tasks`. The task ID must be referenced in the registry entry.

Acceptable end states for a High gap at session end:
- `"status": "closed"` — gap was fixed in this session
- `"status": "open"` with `"remediation_task": "<task-id>"` — task created, gap tracked

Not acceptable:
- `"status": "open"` with no task reference

### R3 — Medium and Low gaps must be tracked, not dropped (`SHOULD`)

Medium and Low gaps discovered during analysis must be added to the backlog or task list. They may be deferred, but they must not be silently discarded.

Acceptable end states for Medium/Low gaps:
- Added to task list or backlog with appropriate priority
- Registry entry updated to reflect deferred status with a note

Not acceptable:
- Identified verbally or in a report then never entered into the registry

### R4 — The registry is the single source of gap truth (`MUST`)

All gaps live in `product/gap-analysis/gap-registry.jsonl`. Gaps mentioned in notes, chat, or spec comments but not entered into the registry do not exist from a compliance standpoint.

If you discover a gap mid-session (not during a formal analysis run), add it to the registry immediately before continuing other work.

### R5 — Status fields must reflect actual state (`MUST`)

Never mark a gap `"status": "closed"` without having applied the fix. Closing a registry entry is a claim that the underlying issue no longer exists in the codebase or product — not that it was acknowledged.

---

## Session End Check

Before ending any session that included gap analysis or registry work, verify all three:

1. No entries with `"severity": "critical"` AND `"status": "open"` remain in the registry (without a blocking task escalation)
2. All High gaps are either `"status": "closed"` or have a `"remediation_task"` reference
3. All Medium/Low gaps discovered this session are in the registry or backlog

If any check fails, the session is not done.

---

## Enforcement

### Before `commit`

```bash
# Check for open critical gaps
python3 -c "
import json, sys
gaps = [json.loads(l) for l in open('product/gap-analysis/gap-registry.jsonl') if l.strip()]
blocking = [g for g in gaps if g.get('severity') == 'critical' and g.get('status') == 'open' and not g.get('remediation_task')]
if blocking:
    print(f'BLOCKED: {len(blocking)} open critical gap(s):')
    for g in blocking:
        print(f'  [{g.get(\"id\", \"?\")}] {g.get(\"title\", \"untitled\")}')
    sys.exit(1)
print('Gap check passed.')
"
```

If the check exits non-zero, commit is blocked until the gaps are resolved.

### Before `verify`

Run the same check. A verification pass is not valid if open Critical gaps exist.

---

## Anti-patterns

**The Filed Report:** Running gap analysis, writing up findings, marking the analysis task "done," and committing — without closing a single gap. The analysis is the input to work, not the work itself.

**The Deferred Pile:** Logging every gap as "will fix later" without creating tasks. Later never arrives. Gaps accumulate until the registry is too noisy to be useful.

**The Verbal Gap:** "Yeah I noticed the export button doesn't work, I'll handle it." Never entered into the registry, never tracked, never closed. Invisible debt.

**The Fake Close:** Marking a gap `"status": "closed"` in the registry without applying the fix, to unblock a commit. This is a registry integrity violation and must be corrected immediately on discovery.

**The Severity Downgrade:** Reclassifying a Critical gap as High or Medium to avoid the commit block, without evidence that the actual severity changed. Severity changes require justification in the registry entry's `notes` field.

---

## The Test

A session passes this standard if, at the moment the final commit is pushed:

1. You can open `product/gap-analysis/gap-registry.jsonl` and find zero entries where `severity == "critical"` AND `status == "open"` AND no `remediation_task` reference exists.
2. Every High gap discovered this session is either closed or has a task ID traceable in the task list.
3. Every gap of any severity that was identified this session exists in the registry — none were mentioned and dropped.

If you cannot confirm all three, the session is not complete.

---

## Post-Fix Horizontal Grep Rule (SR-005)

When a gap is closed by fixing a grep-findable pattern (e.g., hardcoded path, missing guard, incorrect flag), a horizontal re-grep **must** be run across the full codebase before the gap is marked `"status": "closed"` in the registry.

**When this applies:** Any gap where the root cause was found by grepping for a string pattern and fixing one or more instances. If a pattern was greppable to find it, it is greppable to verify it is fully closed.

**Required step:**
```bash
# After fixing all known instances:
grep -rn "<the pattern>" <scope> | grep -v "test\|expected\|comment"
# If any non-trivial results remain → gap is not fully closed
```

**Registry requirement:** The `closed_by` field must include the grep command and its output (or "zero results"):
```json
{"closed_by": "grep -rn 'hardcoded-path' scripts/lib/integrations/ → zero results after fix"}
```

**Root cause note:** MI-SC-001 was initially closed after fixing one file out of five. Series retrospective found the remaining four. A horizontal grep at close-time would have caught them immediately.
