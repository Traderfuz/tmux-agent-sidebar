<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/maintenance/acp-exclusion-policy.md and re-run profile-sync. -->
---
standard: acp-exclusion-policy
title: ACP Exclusion Policy — Non-ACP Commands
category: maintenance
applies_to: [cli, general]
updated: 2026-04-22
---

# ACP Exclusion Policy

ACP (Agent Completion Protocol) routes commands from headless agent runtimes via `devos-command-router.sh`.
Not every command belongs in the allowlist. This document records which commands are **intentionally non-ACP**
and why, so future contributors do not accidentally add them — or accidentally omit legitimate ones.

## Decision criteria

A command is ACP-eligible when **all three** are true:
1. Its output is useful to an agent runtime without a live Claude Code session
2. It can complete without interactive prompts or browser access
3. Its backing skill or script does not require GUI state

A command is intentionally non-ACP when it falls into one of the categories below.

---

## Category A — Interactive / Session-bound (requires live Claude Code session)

These commands invoke skills that run inside Claude Code. An agent runtime calling them headlessly would get a
guide-text response at best, nothing useful at worst. Guide-only wiring is available for high-value ones, but
most are excluded because no agent consumer has been identified.

| Command | Reason |
|---------|--------|
| `abort` | Writes abort.signal — useful only to a running session |
| `brainstorm` | Collaborative design dialogue; requires human back-and-forth |
| `browser-cdp` | Requires a running Chrome instance |
| `ci-setup` | Interactive wizard — GitHub Actions config requires human decisions |
| `clarify` | Structured requirement interview — requires human responses |
| `commit` | Stages and confirms changes — agent should not auto-commit without human review |
| `convex-clerk-setup` | Local dev setup wizard; interactive |
| `diagnose-first` | Diagnostic workflow; requires human to confirm hypothesis |
| `doc-coauthoring` | 3-stage co-authoring; requires human input at each stage |
| `docs-architect` | Long-form narrative generation; multi-pass synthesis with human review checkpoints |
| `eco` | Thin alias for `--eco` flag; not a command target |
| `frontend-design` | Design framing skill; session-context-dependent |
| `init-project-local` | Project-local setup wizard |
| `devos-init` | Project initialization wizard |
| `mcp-builder` | Interactive 4-phase MCP server builder |
| `monthly-retro` | Interactive retrospective |
| `os-orchestrate` | Interactive durable cross-OS planner/executor; approval and resume state are session-dependent |
| `route-guide` | Reference document; no runtime output |
| `systematic-debugging` | 4-phase investigation; requires human iteration |
| `weekly-review` | Interactive review ritual |
| `worktree-sessions` | tmux+worktree session manager; requires interactive terminal |
| `worktrees` | Git worktree operations; interactive branching |
| `daily-review` | Daily review ritual |
| `daily-start` | Session onboarding — reads user context interactively |
| `workflows` | Reference command; no runtime output |

---

## Category B — UI / Browser-dependent

These require a live browser, screenshot capability, or rendered UI.

| Command | Reason |
|---------|--------|
| `ui-clone` | Reproduces UI from URL/screenshot — requires browser |
| `ui-review` | Heuristic visual review; requires live URL or screenshot file |
| `ui-design-iteration` | Screenshot-based iteration loop |
| `ui-design-qa` | Reference-based comparison; requires screenshot artifact |
| `ui-review --scope full` | Multi-page visual audit pipeline |
| `ui-design-system-audit` | Design token adoption audit; requires rendered pages |
| `e2e` | Live running-app journey validation |
| `site-audit` | Live URL QA; requires browser access |
| `browser-cdp` | Chrome DevTools Protocol session |

---

## Category C — Secrets / Infrastructure ops (too destructive for agent headless calls)

These touch live infrastructure, secrets, or external services. Agent runtimes should not invoke them
without explicit human confirmation per-call.

| Command | Reason |
|---------|--------|
| `rotate-tokens` | Rotates live MCP barrier tokens — requires human confirmation |
| `deploy` | Production deployment; adapter-pattern deploy |
| `go-live` | Interactive deployment guide |
| `convex-deploy` | Deploys to Convex production |
| `mcp-ops --sync-cli` | Syncs MCP servers across all AI CLIs — mutates system config |
| `mcp-ops` | Smoke-check tool; output only meaningful interactively |

---

## Category D — Batch / Long-running (inappropriate for single ACP call)

These are multi-hour or multi-session workflows; calling them headlessly from ACP would time out or produce
no coherent single-response output.

| Command | Reason |
|---------|--------|
| `audit-deps` | External dep version audit; may require network + human review |
| `commands-to-skills` | Multi-wave migration; tracked in spec W5/W6 |
| `compound-learnings` | Transforms session learnings into permanent skills; post-session only |
| `cross-os-verify` | Cross-OS compatibility check; multi-project |
| `project-artifacts-audit` | Gap-analysis + creation loop; multi-phase |
| `project-health-audit` | Breadth-first health scan; produces large report |
| `pull-shared-profiles` | Profile sync from upstream; mutates global config |
| `validate-standards` | Profile standards compliance; not a single-call artifact |
| `bx-pipeline-creator` | Pipeline creation wizard |

---

## Category E — Reference / Metadata (no executable behavior)

These output reference text or configuration; no agent consumer has been identified.

| Command | Reason |
|---------|--------|
| `ai-sdk-api` | SDK reference guide; static content |
| `devos-autoresearch` | Research loop; requires Brave/Exa/Perplexity MCP |
| `check-skills-updates` | Checks upstream for skill updates; interactive diff review |
| `find-skills` | Skill search; interactive result browsing |
| `help` | Shows command reference; not an agent target |
| `import-skill` | Downloads skills; interactive |
| `list-importable` | Lists popular community skills; reference only |
| `logs` | Reads DevOS error logs; informational |
| `route-guide` | OS router documentation |
| `standards-guide` | Lists active standards; reference only |
| `testing-standards` | Standards reference; not executable |
| `workflows` | Workflow reference; not executable |
| `structured-note` | Creates structured notes; session-output artifact |
| `visual-architect` | Mermaid diagram creator; interactive |
| `skill-creator` | Interactive skill creation wizard |
| `skill-documenter` | Skill documentation generator; interactive |

---

## Category F — Migration / Maintenance (too stateful for ACP)

These mutate the DevOS installation itself and should not be called by agent runtimes.

| Command | Reason |
|---------|--------|
| `normalize-structure` | Normalizes project directory layout; mutates project |
| `organize-plans` | Re-sorts planning artifacts; mutates specs dir |
| `repair-hooks` | Scans and repairs hook installations; mutates system |
| `extract-architecture` | Architecture extraction; large artifact, not ACP-shaped |
| `extract-standards` | Standards extraction; installer-class operation |

---

## Category G — Alias / Thin wrappers for ACP-allowed commands

These are thin aliases for commands already in the ACP allowlist. Adding them would create confusion
without new capability.

| Command | Reason |
|---------|--------|
| `optimize-process` | Explicit form of `optimize` (already ACP-allowed) |
| `rollback-checkpoint` | Restore from checkpoint; checkpoint is ACP-allowed |

---

## Category H — Not yet ACP-wired (candidates for future allowlist)

These commands have real executable output but have not yet been evaluated for ACP suitability.
Any addition requires: (1) bx-command-creator ACP wiring decision, (2) three-list sync, (3) BATS test.

| Command | Notes |
|---------|-------|
| `abort` | Could be useful for agent-initiated abort; needs signal-write handler |
| `code-review` | Deep codebase audit; output is a report — candidate |
| `consume-creative` | OS handoff consumption; could be automated |
| `consume-design` | Same |
| `consume-marketing` | Same |
| `consume-research` | Same |
| `ground-truth-recon` | Reconciliation run; could produce report |
| `harden` | QA cycling loop; useful in agent pipelines |
| `health` | Signal-based health check; candidate |
| `knowledge-pull` | Knowledge pull; candidate for agent pipelines |
| `learnings` | Session learnings extraction; post-session use |
| `polish` | AI slop cleanup; could run headlessly |
| `provider-registry` | Provider config management; candidate |
| `runbook` | Runbook creation; candidate |
| `security-review` | OWASP audit; report output — strong candidate |
| `verify` | Mandatory verification gate; candidate |
| `statusline` | Statusline segments; candidate once skill exists |
| `bundle-manager` | Bundle ecosystem management; candidate |
| `dev-server` | Dev server start/stop; candidate once W5b skill exists |
| `generate-user-flows` | User flow generation; candidate once W5c skill exists |

---

## Maintenance

When adding a new command to `ACP_ALLOWED_COMMANDS`:
1. Remove it from Category H (candidates) above or add a note explaining the change
2. Update `scripts/lib/command-router.sh` allowlist + case handler
3. Update `scripts/devos-agent-runtime.py` (ALLOWED_COMMANDS + TOOL_TO_COMMAND + `_mcp_tools()`)
4. Update all three lists and inspect the diff; automated command-surface parity is currently unavailable

When adding a new command to the command surface:
1. Determine ACP category immediately (use `bx-command-creator` Mode 0 ACP decision step)
2. If non-ACP: add it to the appropriate category above with rationale
3. If ACP-eligible: wire all three lists and note it as wired

**Current status:** `scripts/lib/command-surface-parity.sh` is absent and no automated command-surface parity gate is wired. Do not claim enforcement; restore the checker and wire it through `profiles/default/hooks/pre-commit.sh` as a separate slice.

---

## Counts (2026-04-22)

| Category | Count |
|----------|-------|
| ACP-allowed | 59 |
| Non-ACP (A–G, intentional) | 68 |
| Non-ACP (H, candidates) | 21 |
| **Total command surface** | **148** |

## Compliance test

- [ ] Does `python3 -c "import json; data=open(\"scripts/lib/command-router.sh\").read(); import re; cmds=re.findall(r\"ACP_ALLOWED_COMMANDS.*?\)", data, re.DOTALL)"` — i.e. does the ACP-allowed count in this document match `grep -c` of the `ACP_ALLOWED_COMMANDS` array in `scripts/lib/command-router.sh`?
- [ ] Does every non-ACP command listed in this document have an inline rationale comment in `acp-exclusion-policy.md` (not just a category label)?
- [ ] Does `command grep -c "ACP_ALLOWED_COMMANDS" scripts/lib/command-router.sh` match the count in the "Counts" table above?

If any check fails: update the counts table and add missing rationale comments before merging.
