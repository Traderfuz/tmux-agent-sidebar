<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/llm-agnostic-primitives.md and re-run profile-sync. -->
# LLM-Agnostic Primitives Standard

## Overview

DevOS primitives — skills, hooks, standards, chains, and commands — are designed to execute on any LLM platform without modification. Claude Code, Codex, Pi, Kimi, Gemini, OpenCode, and future platforms all consume the same SKILL.md files, the same bash hook scripts, and the same markdown standards. This is not an aspiration: it is an architectural constraint that must be enforced at authoring time.

The constraint matters because platforms shift. An LLM primitive that leaks Claude-specific constructs, assumes a particular context window, or calls platform APIs directly is a primitive that fails silently when the platform changes — or when the same user runs a different CLI on the same project. DevOS's value proposition is that its capabilities are portable across the AI tooling landscape. That value is lost the moment a skill calls `<tool>Task</tool>` or a hook hardcodes `$CLAUDECODE`.

This standard governs primitive design. For SKILL.md syntax rules see `cross-llm-portability.md`. For external service provider selection see `provider-agnostic-architecture.md`.

## Scope

This standard covers the design constraints — structure, interface contracts, execution assumptions, and fallback declarations — that keep DevOS primitives (skills, hooks, standards, chains) portable across LLM platforms.

It applies to **all DevOS-compatible OS packages**: dev-os, marketing-os, creative-os, research-os, design-os, km-os, boxi-ops-os, and any OS added in the future. Every primitive authored within or distributed by any of these OSes is subject to this standard. Because all OSes share the same `~/.dev-os/profiles/general/` inheritance chain, this standard propagates automatically to every OS on install.

It does NOT cover SKILL.md content syntax (see `cross-llm-portability.md`), external API/service provider selection (see `provider-agnostic-architecture.md`), or per-CLI hook registration details (see `cross-cli-fix-propagation.md`).

## Principles

1. **Markdown and bash are the universal interfaces.** A SKILL.md is markdown prose. A hook is a bash script. A standard is a markdown document. These are the two execution substrates that every supported LLM platform can consume without translation.
2. **Declare capabilities; don't invoke runtimes.** A skill describes what an MCP tool does and how to use it by name. It does not use platform-specific invocation syntax to call it. The LLM's own runtime handles dispatch.
3. **Composability over monolith.** Each primitive does one scoped thing. It can be sequenced, chained, or skipped. A primitive that can only operate as part of a platform-specific orchestration pattern is not a primitive — it is a platform feature.
4. **Platform enhancements are additive, never required.** When a platform offers a capability improvement (parallel agent dispatch, structured output, native tool calling), the primitive MAY use it and MUST declare a prose fallback. A primitive that only works with the enhancement is not portable.
5. **Configuration is environment; behavior is primitive.** A hook reads `DEVOS_DIR` from the environment. A skill references the skills registry. Neither hardcodes a path, model name, token limit, or platform API that varies across CLIs.
6. **All surfaces that expose the primitive are kept in sync.** `CLAUDE.md` (Claude Code), `AGENTS.md` (Codex/Pi), `APPEND_SYSTEM.md` (Pi), `KIMI.md` (Kimi) — these are the per-platform entry points. A capability added to one surface must be reflected in all. Stale surfaces defeat portability.

## Rules

### Rule 1: SKILL.md files use only plain markdown prose

Skills are the primary delivery vehicle for DevOS capabilities. The content must be followable by any language model that can read markdown.

```markdown
<!-- OFF-STANDARD: Claude Code tool invocation -->
Use the Task tool to dispatch this as a parallel agent.
<tool_use>{"name": "Task", "input": {...}}</tool_use>

<!-- OFF-STANDARD: slash command (Claude Code namespace) -->
Run /mos-brand-voice to generate copy.

<!-- ON-STANDARD: platform-neutral prose -->
If the platform supports parallel agent dispatch, run steps 2–4 concurrently.
Otherwise, run them sequentially in the order listed.
```

### Rule 2: Hook scripts resolve paths from `DEVOS_DIR`, never hardcoded

```bash
# OFF-STANDARD
source "/home/user/.dev-os/scripts/lib/runtime-state.sh"
REGISTRY="/home/user/.dev-os/scripts/sync/hook-registry.yml"

# ON-STANDARD
: "${DEVOS_DIR:=$HOME/.dev-os}"
source "$DEVOS_DIR/scripts/lib/runtime-state.sh"
REGISTRY="$DEVOS_DIR/scripts/sync/hook-registry.yml"
```

### Rule 3: Platform-specific guards use environment variables, not hardcoded CLI names

```bash
# OFF-STANDARD
if [[ "$CLAUDE_CLI" == "true" ]]; then
    read -r -p "Continue? " answer </dev/tty
fi

# ON-STANDARD
if _health_interactive_ok; then   # scripts/lib/skill-invocation-host.sh::_health_interactive_ok delegates to devos_host_context
    read -r -p "Continue? " answer </dev/tty 2>/dev/null || true
fi
```

### Rule 4: Standards are markdown only — no platform annotations

A standards document must be readable and actionable by any LLM. Do not embed tool call syntax, slash commands, or platform-specific metadata blocks in standards files.

```markdown
<!-- OFF-STANDARD -->
To verify compliance, run: <tool>Bash</tool> `gap-analysis --dalio`

<!-- ON-STANDARD -->
To verify compliance, run the `gap-analysis` skill from your active DevOS CLI.
```

### Rule 5: When a platform enhancement is used, declare the prose fallback

```markdown
<!-- OFF-STANDARD: enhancement used, no fallback -->
Use the Agent tool to run steps 1–3 in parallel.

<!-- ON-STANDARD: enhancement + fallback -->
If your platform supports parallel agent dispatch (Claude Code Agent tool, Codex
agent workers), run steps 1–3 concurrently. If not, run them sequentially —
step 1, then step 2, then step 3. The outcome is the same; only wall time differs.
```

### Rule 6: All per-platform surfaces are kept in sync

When a skill, standard, or chain is added or changed, update all platform entry-point files that expose it. The `context-full-refresh` skill regenerates `CLAUDE.md`, `AGENTS.md`, `APPEND_SYSTEM.md`, and `KIMI.md` from the canonical registry. Run it — do not manually edit one surface and leave others stale.

```bash
# After adding or changing a primitive
/context-full-refresh   # Claude Code
# or equivalent for active CLI
```

### Rule 7: Chains declare platform requirements explicitly

A chain that requires a specific platform capability (e.g., parallel worktree execution) must declare that requirement at the top of its definition and provide a sequential fallback path.

```yaml
# hook-registry.yml or chain config
requires_platform: []          # empty = works on all platforms
requires_platform: [claude]    # explicit: only Claude Code supports this
fallback: sequential-build     # chain to run when requirement is unmet
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `Use the Task tool to...` in SKILL.md | Claude Code-specific. Codex/Pi can't follow it. | "Run the following steps sequentially, or in parallel if your platform supports it." |
| Hardcoded `$HOME/.dev-os/` in hook scripts | Breaks when DEVOS_DIR differs or changes. | `"${DEVOS_DIR:-$HOME/.dev-os}/"` |
| Updating only `CLAUDE.md` after adding a skill | Codex and Pi users don't see the skill. | Run `context-full-refresh` to sync all surfaces. |
| `exit 1` on missing platform capability | Blocks the session on platforms that don't support the feature. | Degrade gracefully; emit a warning and continue. |
| Token-count assumptions in prompts ("in 4096 tokens or less") | Token limits vary by model and context. | "Summarize concisely" without a specific token target. |
| Claude-only escape hatches (`CLAUDECODE` env checks) that skip real work | Creates divergent behavior — Claude gets the feature, others get a no-op. | Guard only interactive prompts with CLAUDECODE checks; core logic runs on all platforms. |

## Deviation guidance

A primitive MAY depend on a platform-specific capability when: (1) the capability is fundamental to the primitive's purpose and cannot be meaningfully replaced by a prose fallback, AND (2) the primitive's `applies_to` array in the registry is restricted to the platform(s) that support it. When this is the case, the primitive MUST document the platform requirement in its header comment or SKILL.md overview section.

## Compliance test

- [ ] Does every SKILL.md use only markdown prose — no tool invocation syntax, no slash commands?
- [ ] Does every hook script resolve `DEVOS_DIR` via environment variable, never hardcoded?
- [ ] Does every hook script source `scripts/lib/skill-invocation-host.sh` and guard interactive-only `read` calls behind `_health_interactive_ok`?
- [ ] When a platform enhancement is used in a skill, is a prose fallback declared for platforms that don't support it?
- [ ] After adding or modifying a primitive, were all per-platform surfaces (`CLAUDE.md`, `AGENTS.md`, `APPEND_SYSTEM.md`, `KIMI.md`) regenerated via `context-full-refresh`?
- [ ] Do chains that require platform-specific capabilities declare `requires_platform` and a `fallback`?
- [ ] Are all `applies_to` arrays in `hook-registry.yml` kept accurate — neither over-broad nor Claude-only by default?

If any check fails: the primitive is not portable. Fix the platform coupling before shipping.

## References

- [Unix Philosophy — Rule of Modularity, Rule of Composition](https://www.catb.org/~esr/writings/taoup/html/ch01s06.html) (Raymond, The Art of Unix Programming) — write simple parts connected by clean interfaces. Applied here: each skill/hook/standard is a simple part; the LLM's runtime is the composition layer.
- [The Twelve-Factor App — Factor III (Config)](https://12factor.net/config) — store config in the environment. Applied here: `DEVOS_DIR`, `CLAUDE_CODE`, and platform capability flags are environment variables, never hardcoded.
- [POSIX.1-2017](https://pubs.opengroup.org/onlinepubs/9699919799/) — the model for platform-agnostic OS primitives. DevOS hooks target POSIX bash as the universal execution substrate.
- [RFC 2119 — Key words for use in RFCs](https://datatracker.ietf.org/doc/html/rfc2119) — MUST/SHOULD/MAY vocabulary used in this standard's rules.
- `cross-llm-portability.md` — SKILL.md syntax rules (this standard covers design; that standard covers content).
- `provider-agnostic-architecture.md` — external service/API portability (this standard covers primitive structure; that standard covers provider binding).
- `cross-cli-fix-propagation.md` — when a fix applies to multiple CLIs, propagate it to all (operational companion to this design standard).
