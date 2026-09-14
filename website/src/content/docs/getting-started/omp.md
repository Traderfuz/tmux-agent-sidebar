---
title: OMP
description: Connect OMP lifecycle events to tmux-agent-sidebar.
---

OMP support is provided by an extension that forwards session, prompt, tool-result, and agent-completion events to the sidebar.

## Install the extension

For a checkout of this fork, OMP discovers the extension automatically from `.omp/extensions/tmux-agent-sidebar.ts` when you run OMP in the repository.

To enable it from any project, symlink the extension into your user extension directory:

```sh
mkdir -p ~/.omp/extensions
ln -s /path/to/tmux-agent-sidebar/.omp/extensions/tmux-agent-sidebar.ts \
  ~/.omp/extensions/tmux-agent-sidebar.ts
```

Build the sidebar binary, then enable the tmux sidebar as usual:

```sh
cargo build --release
```

## What appears in the sidebar

- An `omp` agent label and dedicated color
- Prompt text and running/idle state
- Activity entries for completed OMP tools
- Completion state when an OMP agent finishes
- Cleanup when OMP shuts down

OMP's extension API does not expose a separate approval-request event. Approval prompts therefore remain visible in OMP itself rather than becoming a sidebar waiting badge.
