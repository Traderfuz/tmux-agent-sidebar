---
title: Agent support overview
description: What the sidebar shows for Claude Code, Codex, OMP, and OpenCode, side by side.
---

Claude Code, Codex, OMP, and OpenCode work with the sidebar, but they expose different event surfaces — so the sidebar's surface area is narrower for the event-bridge integrations than it is for Claude Code.

## Feature support by agent

| Feature | Claude Code | Codex | OMP | OpenCode | Notes |
| --- | --- | --- | --- | --- | --- |
| Base status tracking | ✓ | ✓ | ✓ | ✓ | Covers `running` and `idle`; `waiting` and `background` depend on agent-specific events |
| Prompt text display | ✓ | ✓ | ✓ | ✓ | Saved from `UserPromptSubmit` or the equivalent bridge event |
| Response text display (`▷ ...`) | ✓ | ✓ | — | ✓ | OMP currently exposes completion but not a response-preview payload |
| Background shell state | ✓ | — | — | — | Claude Bash tools can report `run_in_background` |
| Waiting status + wait reason | ✓ | — | — | ✓ | OMP's public event bus has no approval-request event |
| API failure reason display | ✓ | — | — | ✓ | Requires a `StopFailure` event |
| Permission badge | ✓ | ✓ | — | — | Codex badges are inferred from process arguments; OMP does not expose a permission mode |
| Git branch display | ✓ | ✓ | ✓ | ✓ | Uses the pane `cwd` |
| Elapsed time | ✓ | ✓ | ✓ | ✓ | Since the last prompt |
| Task progress | ✓ | — | — | — | Requires task lifecycle events |
| Task lifecycle notifications | ✓ | ✓ | ✓ (`Stop` only) | ✓ | Completion notifications are available for all four |
| Sub-agent display | ✓ | — | — | — | Requires sub-agent lifecycle events |
| Activity log | ✓ | ✓ (Bash only) | ✓ | ✓ | OMP records completed tool results through its extension bridge |
| Worktree lifecycle tracking | ✓ | — | — | — | Requires worktree lifecycle events |
