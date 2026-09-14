<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/architecture/orca-tool-usage.md and re-run profile-sync. -->
# Orca Tool Usage Standard

## Overview

When Orca is the requested control plane, an agent has two ways to act: the public `orca`
CLI (stable, JSON, scriptable) or ad-hoc desktop automation (screenshots, raw clicks). The
public CLI is the contract; the ad-hoc path is fragile and unsafe. This standard names the
policy an agent follows when driving Orca — which interface to use, what may be done without
asking, and what requires explicit operator consent — so the rule is governed and discoverable
instead of buried in a generator's heredoc.

It is the **owner** of the Orca-usage policy. The `orca-control` managed block injected into
`CLAUDE.md` / `AGENTS.md` is a *consumer* that renders the agent-facing subset below; per the
`single-source-of-truth` standard there is one owner (this file) and the injected block points
back to it.

## Scope

This standard covers how an agent should *use* Orca as a control plane: which interface to
prefer, read-only vs side-effecting operations, sandbox-failure recovery, and the consent
boundary for mutating actions. It does NOT cover Orca's installation/runtime internals (the
`orca-cli` skill and bundle), tool *naming* prefixes (see `canonical-tool-prefixes.md`), or
command output contracts (see `agent-native-cli.md`).

## Principles

1. **Public interface over private internals:** drive Orca through the public `orca` CLI
   (`orca-ide` on Linux) and the `orca-cli` / `computer-use` skills, never ad-hoc desktop tools.
2. **Least privilege by default:** read-only inspection needs no consent; anything that
   clicks, types, sends, deletes, or changes settings is side-effecting and gated.
3. **Human-in-the-loop for side effects:** mutating actions run only when the operator
   explicitly requested that action — not because they were convenient.
4. **Recover before concluding failure:** a sandbox/socket error is retried via the public
   command path before declaring Orca down.

## Named frameworks

### Principle of Least Privilege (Saltzer & Schroeder, 1975)
"Every program and every user should operate using the least set of privileges necessary."
Applied here: an agent defaults to read-only Orca operations and escalates to side-effecting
ones only on explicit operator request.
**Use this when:** deciding whether an Orca call needs consent — if it changes observable
state, it is privileged and gated.

### Capability/CLI contract over GUI scripting (the "public API" rule)
Automate against the stable public surface (the documented `orca` CLI + JSON), not the
private GUI. This is the same discipline as "call the API, don't scrape the UI" — the
contract is versioned and won't silently break.
**Use this when:** choosing between `orca computer ... --json` and a screenshot+click; prefer
the CLI contract every time it can express the task.

### Human-in-the-loop (HITL) confirmation for irreversible/outward actions
Established agent-safety practice: actions that are hard to reverse or visible to others
require explicit human authorization. Mirrors the DevOS `live-client-action-gate`.
**Use this when:** an Orca operation would click/submit/send/delete/change settings — require
the operator to have asked for it.

## Rules

<!-- ORCA_AGENT_POLICY_START -->
When Orca is the requested control plane, use the public `orca` CLI (`orca-ide`
on Linux) and the `orca-cli` / `computer-use` skills before falling back to ad
hoc desktop tools.

- Codex and similar sandboxed sessions may be unable to reach Orca's runtime
  socket under the user's application-support directory. If `orca status --json`
  or `orca computer ... --json` reports `runtime_unavailable`,
  `stale_bootstrap`, or a connection failure from inside the sandbox, retry the
  same public `orca` / `orca-ide` command with the minimal approval/escalation
  needed before concluding Orca is down.
- Use `orca open --json` (`orca-ide open --json` on Linux) when Orca is not
  running. If the runtime points at a stale PID, prefer a graceful app
  quit/reopen, then rerun `orca status --json`.
- For read-only checks, use `orca status --json`,
  `orca computer capabilities --json`, `orca computer list-apps --json`,
  `orca computer list-windows --app <bundle> --json`,
  `orca computer get-app-state --app <bundle> --json`, `orca tab list --json`,
  `orca snapshot --page <pageId> --json`, and `orca terminal list/read --json`.
- Do not click, type, submit, send messages, delete data, change settings, or
  expose sensitive app content unless the user explicitly requested that action.
<!-- ORCA_AGENT_POLICY_END -->

The delimited block above is the **agent-facing policy** rendered into `CLAUDE.md`/`AGENTS.md`
by `canonical_section_orca_control()` (which reads it from this file — single source).

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Screenshot + raw click to drive an app | brittle, no contract, can mis-click | `orca computer ... --json` against the public CLI |
| Declaring "Orca is down" on first socket error | sandbox sockets transiently fail | retry the public `orca`/`orca-ide` command first |
| Clicking/submitting/sending without being asked | side effect the operator did not authorize | read-only by default; mutate only on explicit request |
| Copying this policy into a second file/heredoc | drift between copies | one owner (this standard); the block reads it |

## Deviation guidance

You MAY use a non-CLI/desktop fallback only when the public `orca` CLI genuinely cannot
express the task AND the operator asked for the action; when you do, state the limitation and
the action taken. You MUST NOT perform a side-effecting Orca action the operator did not
explicitly request, regardless of convenience.

## Profile inheritance notes

Standalone architecture standard (no parent override). The injected `orca-control` managed
block consumes the `ORCA_AGENT_POLICY` section of this file via
`scripts/lib/canonical-sections.sh`.

## Compliance test

- [ ] Does the agent reach for the public `orca`/`orca-ide` CLI before any ad-hoc desktop tool?
- [ ] Are read-only inspections done without asking, and side-effecting actions only on explicit operator request?
- [ ] On a sandbox/socket error, is the public command retried before concluding Orca is down?
- [ ] Does the injected `orca-control` block render this file's `ORCA_AGENT_POLICY` section (not a hand-copied duplicate)?

If any check fails: route the action through the public CLI, gate the side effect on explicit
consent, or re-point the generator at this file's policy block.

## References

- [Saltzer & Schroeder — Least Privilege (1975)](https://www.cs.virginia.edu/~evans/cs551/saltzer/) — default to minimal capability.
- DevOS `live-client-action-gate` — the HITL consent gate for outward/irreversible actions.
- DevOS `single-source-of-truth` — why the policy has one owner (this file) and the block consumes it.
- `orca-cli` skill + bundle — the runtime/usage surface this policy governs.
