<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/autonomous-next-step-offer.md and re-run profile-sync. -->
# Standard: Autonomous Next-Step Offer

**Category:** global  
**Version:** 1.0  
**Added:** 2026-04-30

## Purpose

All major pipeline skills must emit a machine-readable next-step signal at completion. The `next-command-prefill.sh` Stop hook reads this signal and prefills the tmux pane input — the user presses Enter to advance, no copy-paste required. This standard defines the canonical format, emission order, headless detection, and deduplication contract.

## Canonical Marker Format

**Skill name, not slash command.** Different CLIs invoke skills differently, and DevOS treats the bare skill name as the portable public surface. Using the bare skill name keeps markers universally parseable; adapters may translate internally when a legacy compatibility layer requires it.

```
<<next>><skill-name> [--flags]<</next>>
NEXT STEP 👉 <skill-name> [--flags]
```

**Examples:**
```
<<next>>implement-tasks --spec workflow-autonomy-surfacing<</next>>
NEXT STEP 👉 implement-tasks --spec workflow-autonomy-surfacing
```

`NEXT STEP 👉` is always emitted — it is the human-readable line and doubles
as the fallback when no hook consumes the marker. `<<next>>` is emitted only
when `_devos_next_prefill_wired` confirms a `next-command-prefill.sh`
consumer is actually registered for the *active* host (Claude Code:
`.claude/settings.json` Stop hooks; OMP: the resolved `hooks.yaml`).
Unconditional emission previously leaked `<<next>>...<</next>>` as literal
visible text on hosts with no consumer wired — see `next-step-offer.sh` for
the detection implementation.

## Emission Order

Every skill completion must emit outputs in this fixed sequence:

1. **Summary block** — task counts, status, any metrics
2. **Zero-wired skill offers** — `_offer_skill <name>` calls (Y/n, interactive mode only)
3. **`<<next>>` marker** — `_emit_next_step <skill> [flags]` (always emitted)
4. **`NEXT STEP 👉` line** — human-readable fallback (emitted by `_emit_next_step`)
5. **Primary Y/n prompt** — `Ready to run <skill>? (Y/n)` (interactive mode only)

Step 2 offers use abbreviated format: `Run [implementation-review]? (Y/n)` — no full path needed for inline offers. The step 3 marker always uses skill name + flags for tmux prefill.

## Shared Library

Source `scripts/lib/next-step-offer.sh` to implement the pattern. Do not inline the logic.

```bash
# In SKILL.md completion phase (or sourced script):
source "${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/next-step-offer.sh"

# Offer an optional upstream skill (dedup-protected):
_offer_skill implementation-review "--spec $SPEC_SLUG"

# Emit the primary next-step marker (always):
_emit_next_step merge-feature
```

## Headless Detection

Suppression is triggered by any of these environment variables:

| Variable | Value | Effect |
|----------|-------|--------|
| `DEVOS_ACP_SESSION` | `1` | Running in ACP/agent session |
| `DEVOS_RESOLVED_MODE` | `eco` or `agent` | Eco or agent execution mode |
| `DEVOS_NO_NEXT_OFFER` | `1` | Explicit opt-out |

**Headless behavior:** Emit `<<next>>` + `NEXT STEP 👉` markers only. Skip all Y/n prompts. Do NOT invoke the next skill inline — the tmux prefill hook handles advancement. This avoids unbounded recursion while preserving one-key advancement for the user.

**Why not auto-invoke?** Auto-invocation in headless creates uncontrolled skill chains. `autonomous` handles fully-automatic chaining via its own loop. This pattern is for interactive-adjacent sessions where the user confirms each step.

## Session-Scoped Deduplication

Track offered skill names in `DEVOS_OFFERED_SKILLS` (colon-separated, exported env var). A skill only emits one `_offer_skill` Y/n per session regardless of how many pipeline skills offer it.

- Dedup applies to: secondary offers (`_offer_skill` calls)
- Dedup does NOT apply to: primary pipeline next-step markers (`_emit_next_step`)
- Reset: automatically on new session (new transcript = new env)

## Pipeline Step Registry

Canonical next-step map for the three major pipelines:

### Planning pipeline
| From | Condition | Next |
|------|-----------|------|
| `shape-spec` | requirements.md written | `write-spec --spec <slug>` |
| `write-spec` | spec.md written | `create-tasks --spec <slug>` |
| `create-tasks` | tasks.md written | `implement-tasks --spec <slug>` |

### Implementation pipeline
| From | Condition | Next |
|------|-----------|------|
| `implement-tasks` | last task `[x]` | offer: `security-review` (if auth/secrets tasks) → `implementation-review` → then `merge-feature` |
| `implementation-review` | review complete | `merge-feature` |
| `merge-feature` | auth/secrets diff | offer: `security-review` before triage gate |
| `merge-feature` | merged | `project-status` |

### Quality/ops pipeline
| From | Condition | Next |
|------|-----------|------|
| `triage` | 3+ issues, no single root cause | `systematic-debugging` |
| `triage` | clear fix targets | `implement-tasks` |
| `gap-analysis` | report written | routing-aware (use existing routing prompt + standardized marker) |
| `start` (new project) | init complete | `guided-start` |
| `start` (return) | re-init | `daily-start` |

## Suppression Flags

| Flag / Env | Scope | Effect |
|-----------|-------|--------|
| `DEVOS_ACP_SESSION=1` | global | Suppress all Y/n, keep markers |
| `DEVOS_NO_NEXT_OFFER=1` | global | Suppress all Y/n, keep markers |
| `DEVOS_RESOLVED_MODE=eco\|agent` | global | Same as above |
| `DEVOS_SKIP_TASK_CONVERGENCE=1` | create-tasks only | Skip pre-confirmation gap pass |
| `--subprocess` flag | calling pipeline | Suppress routing prompt (gap-analysis) |
| `--quiet-routing` flag | calling pipeline | Suppress routing block (gap-analysis) |

## Compliance

A skill is compliant with this standard when:
1. Its completion output contains `NEXT STEP 👉 <skill-name>`, plus `<<next>><skill-name><</next>>` when `_devos_next_prefill_wired` confirms a consumer for the active host (grep-verifiable)
2. The marker uses skill name, not slash-command format (no `` prefix in marker)
3. Headless mode suppresses all Y/n without suppressing the marker
4. Secondary skill offers use `_offer_skill` (dedup-protected)
5. The lib is sourced, not copy-pasted
