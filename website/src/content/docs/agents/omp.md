---
title: OMP
description: OMP lifecycle and tool activity surfaced in tmux-agent-sidebar.
---

OMP is integrated through a typed extension event bridge rather than a JSON hook configuration.

## What you get

- Live `running` and `idle` status from prompt submission and agent completion
- Prompt text from OMP's `input` event
- Activity-log entries for completed tools from `tool_result`
- Session cleanup from `session_shutdown`
- A dedicated OMP row color, configurable with `@sidebar_color_agent_omp`

## Setup

Follow [OMP setup](/tmux-agent-sidebar/getting-started/omp/).

## Limitation

The public OMP extension event bus does not provide a permission-approval event. The sidebar cannot reliably show an approval waiting badge without upstream support for that lifecycle event.
