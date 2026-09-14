<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/verify-live-state-before-acting.md and re-run profile-sync. -->
# Verify Live State Before Acting

## Overview

Every action carries premises. When you start a test suite, you are asserting "no
equivalent run is already in flight." When you begin work on a branch, you are
asserting "no other actor owns this." These premises are never spoken, so no
verification gate ever fires on them — and the companion standards in this
directory all trigger on an *uttered* claim. An unspoken premise is the one
place a confident wrong answer can reach production without passing a single
check.

This standard exists because of a specific, reproducible failure: an agent asked
to supervise existing work probed `herdr pane list --workspace $HERDR_WORKSPACE_ID`
— scoped to its own workspace — saw one pane, concluded nothing else was running,
and launched a duplicate 951-file test suite into a worktree where another live
agent was already mid-verification. Load average reached 21.4 on 6 cores, the
other agent's run failed inside that window, and three load artifacts were
reported to the operator as real defects. The probe was real. Its scope was
narrower than the claim it was used to support.

## Scope

This standard covers verification of shared live runtime state before an action
whose safety depends on that state. It does NOT cover completion-status claims
(see `verify-status-against-artifact.md`), pre-fix failure diagnosis (see
`verification-before-implementation.md`), workspace isolation mechanics (see
`worktree-first-mutating-work.md`), or the design of multi-agent decompositions
you originate (see `agents/multi-agent-patterns.md`).

"Shared live runtime state" means anything another actor can be holding right
now: branches, worktrees, running suites and builds, dev servers, ports, locks,
leases, review queues, terminal panes, and agent sessions.

## Principles

1. **An action asserts its premises.** Starting the work is the claim. Surface
   the premise in words before you act, or it never gets tested.
2. **Probe scope must equal claim scope.** A probe narrower than the assertion it
   backs is not weak evidence — it is the wrong evidence. This is the
   time-of-check/time-of-use defect applied to environment discovery.
3. **Absence must be produced, not assumed.** "I saw nothing" is not "there is
   nothing." A negative existence claim requires a search wide enough to have
   found the thing had it been there.
4. **Concurrency is a property of the shared resource, not of your view of it.**
   Two worktrees of one repository are one critical section. Exclusion is keyed
   on the shared identity, never on the path you happen to be standing in.
5. **Another actor's in-flight work is state you can corrupt.** The blast radius
   of a duplicate run lands on them, and the damage is silent — it arrives as
   their failure, not yours.

## Rules

Keywords per RFC 2119.

### LSV-1 — Name the premise before acting (`MUST`)

Before any long-running, mutating, or load-bearing action, state the negative
premise the action depends on. If you cannot write it as a sentence, you cannot
verify it.

```text
# OFF-STANDARD — premise never surfaced, so never tested
[launches full BATS suite in bats-release-gate-repair]

# ON-STANDARD — premise named, then tested
Premise: no other agent owns wt/bats-release-gate-repair and no suite is
running for this repo. Verifying before launch.
```

### LSV-2 — Probe at the scope of the claim, not the scope of your view (`MUST`)

An enumeration scoped to your own workspace, worktree, or session `MUST NOT` be
used to support a claim about the host, the repository, or all actors.

```bash
# OFF-STANDARD — workspace-scoped probe backing a host-wide conclusion
herdr pane list --workspace "$HERDR_WORKSPACE_ID"   # 1 pane
# → "nothing else is running"

# ON-STANDARD — probe scope matches claim scope
herdr workspace list   # 12 workspaces
herdr agent list       # 10 live agents, 3 already own the target branches
```

### LSV-3 — Establish ownership of the target before loading or mutating it (`MUST`)

Resolve the target worktree/branch and map it against live actors. If another
live actor owns it, `STOP`. Proceeding in parallel without explicit operator
authorization is prohibited (`MUST NOT`).

```bash
# ON-STANDARD — ownership map before action
herdr agent list | jq -r '.result.agents[] | "\(.pane_id)\t\(.cwd)"'
git worktree list
# target /…/bats-release-gate-repair is owned by wHN:p1 (idle, bg job running)
# → coordinate via `herdr agent read` / `herdr agent prompt`, do not duplicate
```

Coordination beats duplication: prefer delegating to the owning actor over
performing the work yourself in its workspace.

### LSV-4 — Exclusive shared resources take a lock, not a look (`MUST`)

A check followed by an unprotected action is a TOCTOU window. When an action
must not run twice concurrently, guard it with an exclusion primitive keyed on
the **shared** identity of the resource.

```bash
# OFF-STANDARD — per-worktree lock; siblings of one repo still collide
lock="$PWD/.suite.lock"

# ON-STANDARD — keyed on the shared git object store, so every linked
# worktree of the repository contends for the same lock
lock="$(git rev-parse --git-common-dir)/devos-suite.lock"
exec 9>"$lock"
flock -n 9 || { echo "suite already running for this repo" >&2; exit 1; }
```

### LSV-5 — A probe that cannot run yields "unverified", never "empty" (`MUST`)

A missing tool, unset `HERDR_ENV`, suppressed stderr, or a non-zero exit is not a
zero result. Report the state as unverified and name what could not be checked.

```bash
# OFF-STANDARD — failure and emptiness are indistinguishable
agents=$(herdr agent list 2>/dev/null | jq -r '.result.agents[].pane_id')
[ -z "$agents" ] && echo "no other agents"   # also true when herdr is absent

# ON-STANDARD — separate the two
if ! out=$(herdr agent list 2>&1); then
  echo "agent enumeration UNVERIFIED: ${out}" >&2; exit 1
fi
```

### LSV-6 — Reconcile against the actor before reporting its results (`SHOULD`)

When a live actor already owns the target, read its state before producing
analysis. Re-deriving conclusions the owner already published wastes the run and
loses facts only the owner holds.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `pane list --workspace $MINE` treated as a topology check | Scoped to your own view; cannot see other workspaces | `workspace list` + `agent list` |
| "I only saw one pane, so nothing else runs" | Passive non-observation is not a search | Enumerate at claim scope; show the command |
| Starting a suite because *your* worktree is idle | Idle worktree ≠ idle repository | Lock on `git rev-parse --git-common-dir` |
| Per-worktree lock file | Sibling worktrees share one object store and one fixture surface | Key exclusion on the shared identity |
| `2>/dev/null` around a probe, empty result read as absence | A failed probe looks identical to a clean one | Capture stderr, check exit code, report unverified |
| Re-deriving analysis an owning agent already produced | Loses facts only that agent holds; duplicates cost | `agent read` first, then extend |
| Reporting failures from a run made under self-inflicted contention | Load artifacts get escalated as defects | Re-run clean, or label the result contended |

## Deviation guidance

You MAY act without full actor enumeration when the action is read-only, adds no
measurable load, and holds no lock — for example a single `git log`, a file read,
or a status query.

When you deviate, you MUST label any state conclusion drawn from the narrow probe
as "unverified — scoped to <what you checked>". You MUST NOT let a narrow probe
silently promote to a host-wide fact.

If enumeration is impossible (the control plane is absent), you MUST report state
as unverified and ask the operator before starting a load-bearing or mutating
action.

## Profile inheritance notes

Authored at the `general` level; inherited by all downstream profiles (cli,
webapp, pwa, business, agents, skills, installable-os, cloudflare-workers,
astro-*, boxi-ops, devos-platform). The failure class is control-plane agnostic —
`herdr` appears in examples because it is this workspace's multiplexer, but the
rules apply equally to tmux sessions, CI runners, container orchestrators, and
bare process tables.

Relationship to sibling standards:

```text
[verify-live-state-before-acting]  → act → [verify-status-against-artifact]
        (premises, before)                        (claims, after)
```

`verification-before-implementation.md` brackets a *known failure*; this standard
brackets a *shared environment*. They do not overlap.

## Compliance test

- [ ] Did you write the action's negative premise ("no other actor owns X / nothing is in flight") as a sentence before acting?
- [ ] Does the scope of the probe you ran match the scope of the claim it supports — host-wide claim backed by host-wide enumeration?
- [ ] Did you produce an owner-or-unowned result for every shared resource the action loads or mutates, with the command shown?
- [ ] If a live actor already owned the target, did you stop and either coordinate with it or obtain explicit operator authorization?
- [ ] For an action that must not run twice, is the exclusion primitive keyed on the shared resource identity rather than your local path?
- [ ] Was every probe that failed or could not run reported as "unverified" rather than as an empty result?

If any check fails: stop before acting, widen the probe to claim scope, and
re-derive ownership — or label the state unverified and ask the operator.

## References

- [CWE-367: Time-of-check Time-of-use (TOCTOU) Race Condition](https://cwe.mitre.org/data/definitions/367.html) — the check/use scope-and-window defect this standard generalizes from filesystem paths to shared runtime state.
- [Atomicity for Agents: Exposing, Exploiting, and Mitigating TOCTOU Vulnerabilities in Browser-Use Agents (arXiv 2603.00476)](https://arxiv.org/pdf/2603.00476) — TOCTOU applied to autonomous agents; "a pathname is not a stable reference" is the same defect as "a workspace view is not a host view."
- [Altman DG, Bland JM. "Absence of evidence is not evidence of absence." BMJ 1995;311:485](https://doi.org/10.1136/bmj.311.7003.485) — a non-detection under insufficient power is not a negative result; backs Principle 3 and rule LSV-5.
- [Dijkstra EW. "Solution of a problem in concurrent programming control." CACM 1965](https://lamport.azurewebsites.net/pubs/dijkstra.pdf) — the mutual-exclusion formulation; exclusion belongs to the critical section, backing rule LSV-4.
- [RFC 2119 normative vocabulary](https://datatracker.ietf.org/doc/html/rfc2119) — MUST / MUST NOT / SHOULD / MAY levels used above.
- [Genchi Genbutsu — Toyota Production System](https://global.toyota/en/company/vision-and-philosophy/production-system/) — go and see the actual place; shared with `verify-status-against-artifact.md`.
- `verify-status-against-artifact.md` — companion: verifying a *claim* after the fact. This standard verifies a *premise* before acting.
- `verification-before-implementation.md` — companion: the diagnostic gate before fixing a known failure.
- `../../../devos-platform/standards/maintenance/worktree-first-mutating-work.md` — workspace isolation mechanics; this standard adds the liveness and ownership check that isolation alone does not provide.
