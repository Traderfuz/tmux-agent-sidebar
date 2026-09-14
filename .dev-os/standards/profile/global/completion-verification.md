<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/completion-verification.md and re-run profile-sync. -->
---
title: Completion Verification Standard
version: 1.0.0
status: Accepted
---

# Completion Verification Standard

## Overview

Completion questions — "is this merged", "is this complete", "is this done", "is it safe to delete" — MUST be answered against actual code content and live work state, never against commit ancestry alone. Commit reachability (`merge-base`, `rev-list --count`, `branch --no-merged`) establishes history topology; it does not establish content presence or work completion. This standard defines the evidence layers required before any completion claim.

Named anchors: Pro Git, "Git Internals" — Git is a content-addressable filesystem and a commit is a **snapshot**, so "commit is an ancestor" means "history contains that snapshot", not "main's current tree contains that content". The Scrum Guide (2020) "Definition of Done" — done is a defined, verifiable state, not a location of work. Normative vocabulary follows RFC 2119.

## Scope

This standard covers completion evidence for branch, merge, and work-state questions within any DevOS-managed project. It does NOT cover pre-claim test execution gates, branch retention or deletion policy, or CI merge approval workflow.

## Principles

1. **Content over lineage:** Ancestry answers "does history contain it"; only a tree comparison answers "does the code contain it". Both MUST be checked when the question is about completeness.
2. **Work is more than commits:** Uncommitted files, staged changes, and owning progress artifacts (spec `PROGRESS.md`, task lists) carry work state that no git history records. Completion claims MUST read the live surface, not only the object database.
3. **State the evidence:** An answer that does not name which evidence layers were verified is unverifiable and MUST NOT be treated as a completion determination.
4. **Cheap proofs first:** The evidence stack is three or four git commands and one file read. Cost is never a reason to skip a layer; cost is a reason to automate it.

## Rules

### R1 — Ancestry is context, not evidence (`MUST NOT`)

MUST NOT answer a completeness question from reachability output alone. `0 ahead` proves the branch tip is an ancestor of the target; it proves nothing about content presence after later reverts and nothing about worktree state.

```bash
# OFF-STANDARD — lineage cited as completion proof
git rev-list --left-right --count main..."$branch"   # "2 0" → "fully merged, safe to delete"
```

### R2 — Content diff on the touched files (`MUST`)

MUST verify content presence by diffing between the branch tip (or the merge commit that introduced the change) and the target ref, restricted to the files the change touched. For small deltas a whole-tree diff is acceptable. The comparison is satisfied when the touched files are byte-identical or the delta is reviewed and attributed.

```bash
# ON-STANDARD — content check on the merge's touched set
merge_point=4d068945e
for f in $(git diff --name-only "$merge_point^1" "$merge_point"); do
  git diff --quiet "$merge_point" main -- "$f" \
    && echo "IDENTICAL  $f" || echo "DIFFERS    $f"
done
```

### R3 — Revert sweep (`MUST`)

Before asserting content is present because a merge commit is an ancestor, MUST sweep the target range for reverts that could have removed it:

```bash
git log --oneline --grep='[Rr]evert' "$merge_point..main"
```

An empty revert sweep plus passing R2 is the content-presence proof. A non-empty sweep re-opens the question; do not assert presence until each revert is attributed.

### R4 — Live worktree state (`MUST`)

MUST inspect the branch's worktree for uncommitted or staged work before calling it complete or deletable:

```bash
git -C "$worktree" status --porcelain
```

A non-empty status means work exists that no branch comparison can see. Deletion or cleanup recommendations are blocked until this surface is read.

### R5 — Owning progress artifact (`MUST` when present)

When the worktree carries a spec, plan, or task surface (`product/specs/*/PROGRESS.md`, `tasks.md`), MUST read its completion state. A spec at 0% with a merged ancestor commit is in-flight work, not a completed feature. Merge status and work completion are independent axes; a completion claim MUST state where the work sits on both.

```bash
# Real case that motivated this standard:
#   wt/mcp-hub-runtime-trust: merge commit 4d068945e is an ancestor of main and all
#   11 touched files byte-identical in main (R2+R3 pass) — yet the worktree held
#   product/specs/2026-09-04-mcp-hub-runtime-trust/PROGRESS.md at "0% (0/63)",
#   staged and uncommitted (R4+R5 fail). Verdict: merged code, in-flight session.
```

### R6 — State the evidence (`MUST`)

The completion answer MUST name the layers verified (ancestry, content, reverts, worktree state, progress artifact). Claims without evidence attribution are non-compliant even when accidentally correct.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `0 ahead` cited as "complete" | Ancestry is topology; reverts and worktree state are invisible to it | R2 content diff + R4 status + R5 progress read |
| Merge commit in history cited as "feature is live" | A later revert removes content while ancestry still holds | R3 revert sweep before asserting presence |
| Branch audit that never opens the worktrees | Uncommitted specs and staged files live outside git history | R4 `status --porcelain` per checked-out worktree |
| "Safe to delete" without reading the spec surface | Deletes in-flight work carriers (day-0 specs, staged progress) | R5 progress read gates any cleanup recommendation |
| Completion claim with no evidence attribution | Unverifiable; cannot distinguish evidence from inference | R6 name the layers checked |

## Deviation guidance

You MAY answer from ancestry alone when the question is explicitly topological ("is branch X an ancestor of main", "which branches are unmerged") — reachability is the correct and complete answer for that question. The moment the question uses completion vocabulary (complete, done, finished, safe to delete, shipped), the full evidence stack is REQUIRED. You MAY skip R5 when no spec, plan, or task artifact exists in the worktree — but R4 still applies, because "no artifact" must be observed, not assumed.

## Compliance test

- [ ] **CV1:** Does the completion answer include a content-level comparison (R2) and not only reachability output?
- [ ] **CV2:** Was a revert sweep (R3) run over the target range before content presence was asserted?
- [ ] **CV3:** Was live worktree state checked with `git status --porcelain` (R4) before any complete/deletable verdict?
- [ ] **CV4:** When a progress artifact exists, was its completion state read (R5) and reported alongside merge status?
- [ ] **CV5:** Does the answer name which evidence layers were verified (R6)?

If any check fails: the answer is not a completion determination — re-run the missing layer, or explicitly record the deviation and its justification in the answer.

## References

- Pro Git, "Git Internals — Git Objects" (content-addressable storage; a commit is a snapshot, not a diff) — https://git-scm.com/book/en/v2/Git-Internals-Git-Objects — establishes why ancestry cannot prove content presence.
- The Scrum Guide (2020), "Definition of Done" — https://scrumguides.org/scrum-guide.html — completion as a defined, verifiable state.
- RFC 2119 — https://www.rfc-editor.org/rfc/rfc2119 — normative vocabulary used in this standard.
