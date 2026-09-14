<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/verify-status-against-artifact.md and re-run profile-sync. -->
# Verify Status Against the Artifact

## Overview

When you report that something is done, closed, complete, wired, satisfied, or
missing, that claim must come from reading the **actual artifact** — the code, the
config file, the live command output, the rendered page — never from a status
field, a checkbox, a registry marker, or a prior summary that *describes* the
artifact. Markers record **intent**; only the artifact records **reality**. The two
drift constantly, and trusting the marker over the artifact produces confident wrong
answers that the user then has to correct.

This standard exists because of a recurring, expensive failure: an agent reads a
spec's `Status: active`, a registry's `status: open`, or a tasks.md `[ ]` and reports
the underlying work as not-done — when the code/config already shipped the fix.
Equally: reporting work *as done* from a `complete` marker when the artifact never
changed.

## Scope

This standard covers **completion-status verification** — answering "is X
done / closed / wired / present?" within any DevOS project. It does NOT cover
backlog surfacing and auto-flip mechanics (see `verify-before-surface.md`) or
pre-implementation planning readiness (see `verification-before-implementation.md`).

## Principles

1. **Genchi Genbutsu — go and see:** Reach the actual artifact and observe its
   real state. A report about the artifact is not the artifact.
2. **The map is not the territory:** A status field, checkbox, or registry entry is
   a map drawn at some past moment. The code/config is the territory. When they
   disagree, the territory wins.
3. **Right artifact, right scope:** Reading the wrong file is the same failure as
   reading no file. Confirm you opened the scope that actually governs the behavior
   (e.g. global vs project config, source vs installed copy, branch vs branch).
4. **Cite or it didn't happen:** Every completion claim carries the evidence that
   backs it — a `file:line`, a command and its output, the artifact inspected.

## Rules

### Status claims must trace to an artifact read

- **Any "done/closed/complete/wired/satisfied/missing" claim MUST be backed by a
  fresh read of the governing artifact this session** (`MUST`). A spec status field,
  registry `status`, tasks.md checkbox, or prior agent summary is a lead to verify —
  never the proof itself (`MUST NOT` be the sole source).
- **When a marker and the artifact disagree, trust the artifact and flag the marker
  as stale** (`MUST`). Do not reconcile by trusting the marker.

```text
# OFF-STANDARD — sourced from the marker
The spec says Status: active and the registry says status: open,
so G-mos-004 (SessionStart hooks) is pending dev-os implementation.

# ON-STANDARD — sourced from the artifact
$ python3 -c "import json,os; d=json.load(open(os.path.expanduser(
  '~/.claude/settings.json'))); print(len(... SessionStart commands ...))"
15
G-mos-004 is already satisfied — global ~/.claude/settings.json wires all 15
SessionStart hooks [verified]. The spec's "active" marker is stale; flipping
the registry entry to closed.
```

### Confirm the scope before reading

- **Identify which artifact actually governs the behavior, and read THAT one**
  (`MUST`). Global vs project config, source vs installed/extracted copy, the
  checked-out branch vs the merge target are distinct artifacts.

```text
# OFF-STANDARD — wrong scope, right-looking answer
Project .claude/settings.json has no SessionStart hooks → bundle not wired.

# ON-STANDARD — the governing scope
SessionStart hooks live in GLOBAL ~/.claude/settings.json, not the project file.
Read the global file: 15/15 present [verified].
```

### Absence requires an active search, not a glance

- **"X is missing" MUST be backed by a search across the locations X could live**
  (`grep`/`glob`/`ls` with the command shown), and the absence confirmed from a
  second angle when the count matters (`MUST`). "I didn't see it" is not evidence.
- **Scope the search to reality:** "all" means every relevant location — other
  dirs, other repos (the source repo vs the installed copy), other branches — and
  you state the scope you actually checked (`MUST`).

## Strong-signal contract

A status is "verified as closed/done" ONLY on a strong signal from the artifact.
Trust nothing weaker.

| Claim | Strong signal (verify-as-true) | Weak signal (does NOT prove it) |
|---|---|---|
| "Hook/feature is wired" | The governing config/code contains the entry, read this session at the correct scope | A spec or registry says it was wired |
| "Gap/spec is closed" | The fix is present in code/config at `file:line`, OR a closing commit whose subject names the id + a fix verb | `status: closed`, `[x]` checkbox, or a summary asserting closure |
| "Capability is missing" | `grep`/`glob` across all plausible locations returns nothing, shown | "I didn't notice it" / a single narrow grep |
| "Versions match / are synced" | Both values read from their files this session and compared | A doc or report stating they match |

**Conservative bias:** if you cannot reach a strong signal, report the status as
*unverified* and say what you could not check — do not upgrade a marker to a fact.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| "Spec says active → work is pending" | Spec status is intent, set in the past; code may have shipped | Read the code/config; report its real state |
| "Registry says open → gap is open" | Registry markers go stale the moment the fix lands | Verify the fix in the artifact; flip stale markers |
| Reading project `.claude/settings.json` for SessionStart hooks | Wrong scope — those hooks are global | Read global `~/.claude/settings.json` |
| "I didn't see it, so it's missing" | Passive non-observation isn't a search | `grep -r`/`glob` the plausible paths; show the command |
| Trusting a prior summary's "done" | A summary is a map of a map | Re-derive from the artifact this session |

## Deviation guidance

You MAY cite a marker (spec status, registry entry, checkbox) as the *current
claim under test* — but when you do, you MUST in the same turn either (a) verify it
against the artifact before reporting it as fact, or (b) explicitly label it
"unverified — sourced from <marker>, not yet confirmed against code." Never let an
unverified marker read as a confirmed fact.

## Compliance test

- [ ] Is every "done/closed/complete/wired/satisfied/missing" claim backed by a
      read of the actual artifact performed this session?
- [ ] Did you confirm you read the artifact at the scope that governs the behavior
      (global vs project, source vs installed, correct branch)?
- [ ] Is no completion claim sourced solely from a spec status field, registry
      marker, tasks.md checkbox, or prior summary?
- [ ] When a marker disagreed with the artifact, did you trust the artifact and
      flag the marker as stale?
- [ ] Does each claim cite its evidence (`file:line`, command + output, or the
      artifact inspected)?

If any check fails: stop, read the governing artifact, and re-derive the status
from it before reporting — or label the claim "unverified" with the gap named.

## Enforcement & operational skills

This standard states the rule; these skills operationalize and enforce it. When
you are about to make a completion/status claim, route through them rather than
self-asserting:

- **`devos-verify`** — the per-claim enforcement skill. Runs the mandatory
  verification workflow before any "done / fixed / passes / wired / complete"
  claim, commit, or PR. Its own ground-truth rule mirrors this standard:
  fresh command output / direct artifact inspection before assertion. Gated at
  session level by the `verification-gate.sh` and `review-gate-stop-hook.sh`
  Stop hooks — so the enforcement is mechanical, not merely advisory.
- **`ground-truth-recon`** — the repo-scale reconciliation loop. Re-derives
  project state from the repository and reconciles docs, completed work, flows,
  standards, backlog, and status against it. Use when markers across artifacts
  disagree and the whole surface needs to be brought back to the territory.
- **`docs-verify`** — applies this standard to documentation: verifies doc
  content against the code, not against other docs.

## References

- [Genchi Genbutsu (現地現物) — Toyota Production System](https://global.toyota/en/company/vision-and-philosophy/production-system/) — "go and see for yourself" at the actual place (*gemba*) rather than relying on reports.
- [Korzybski, "the map is not the territory" — general semantics (1933)](https://en.wikipedia.org/wiki/Map%E2%80%93territory_relation) — a representation of a thing is not the thing.
- [RFC 2119 normative vocabulary](https://datatracker.ietf.org/doc/html/rfc2119) — MUST / MUST NOT authority levels used above.
- `verify-before-surface.md` — companion standard: how backlog surfaces auto-flip resolved items (this standard governs the human-facing status *claim*; that one governs the storage *reconciliation*).
- `verification-before-implementation.md` — companion standard: verifying readiness before writing code (vs. this standard's verifying status after the fact).
- `~/.dev-os/rules/verify-against-ground-truth.md` — the cross-CLI behavioral rule this standard formalizes for the DevOS standards system.
