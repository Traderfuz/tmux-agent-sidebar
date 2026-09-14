<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/shell-config-source-guards.md and re-run profile-sync. -->
# Shell Config Source Guards Standards

## Overview

This standard governs how user shell startup files source other files and mutate `PATH`. It exists because the 2026-08-28 audit found `~/.zshrc` sourcing `~/.codex/mcp-tokens.env` twice — once guarded, once not — meaning a single `rm` of that file would have broken every new shell, and the duplication was invisible until a line-by-line audit.

## Scope

This standard covers `source`/`.` blocks and `PATH` mutations in user-owned shell startup files (zsh, bash, fish rc trees). It does NOT cover plugin or theme choices or shell startup performance.

## Principles

1. **Idempotency:** Sourcing a startup file twice must be safe — or impossible.
2. **Single definition:** Any given file is sourced from exactly one site in the rc tree.
3. **Optional dependencies fail quiet:** A missing optional file degrades to "feature absent", never to "shell errors on startup".

## Rules

### Sourcing

- **Every `source`/`.` of an optional user-level file MUST be guarded** (`MUST`):

```zsh
# OFF-STANDARD (what line 911 of ~/.zshrc did)
source "$HOME/.codex/mcp-tokens.env"

# ON-STANDARD (what line 595 already did)
if [[ -f "$HOME/.codex/mcp-tokens.env" ]]; then
  source "$HOME/.codex/mcp-tokens.env"
fi
```

- **A given file MUST be sourced from exactly one site; duplicates are removed, not re-guarded** (`MUST`). Guarding a duplicate leaves double execution and drift between the two copies.
- **Secrets files (`*tokens*`, `*.env`) MUST be sourced guarded and from exactly one site** (`MUST`).

### PATH mutations

- **Repeated PATH additions SHOULD use a dedupe-safe mechanism** (`SHOULD`):

```zsh
# OFF-STANDARD — grows $PATH on every re-source, hides duplicates
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"   # somewhere else in the file

# ON-STANDARD (zsh)
typeset -U path PATH
path=("$HOME/.local/bin" $path)

# ON-STANDARD (bash)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH";; esac
```

### Block hygiene

- **Appended blocks SHOULD carry a one-line comment naming the owning tool** (`SHOULD`), e.g. `# Codex MCP bearer tokens (managed by mcp-sync.sh)`.

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Unguarded `source` of an optional file | File removal breaks every new shell at startup | `[[ -f ]]` guard |
| Duplicate source sites | Double execution; edits to one copy drift from the other | One site; delete the rest |
| Bare `export PATH=...` re-runs | PATH bloat and shadowing bugs | `typeset -U path` (zsh) or case-guard (bash) |
| Absolute paths to moved tools inside rc files | Silent breakage after reorganization (see relocatable-service-installs standard) | Relative to a guarded variable, or verify after moves |

## Deviation guidance

You MAY `source` unguarded when the file is part of the shell's own contract and an earlier guard in the same file already proved it exists (for example, oh-my-zsh's init after its own existence check). When you do: add a comment at the source site pointing to the earlier guard.

## Compliance test

- [ ] Does every `source`/`.` line in the rc tree have a guard on the same line or in the same block?
- [ ] Does any single file appear as a source target more than once across the rc tree?
- [ ] Does every PATH export either dedupe (`typeset -U`) or case-guard?
- [ ] Does `zsh -n` (or `bash -n`) pass on each modified file?
- [ ] Does a fresh interactive shell start with zero "no such file or directory" errors (`zsh -i -c exit 2>&1`)?

If any check fails: fix the block (guard, deduplicate, or dedupe) before finishing; re-run the parser check after every edit.

## References

- Ansible documentation: Idempotency — the design goal startup files should share with automation.
- XDG Base Directory Specification — canonical user-level config/cache locations so guards and paths stay conventional.
- Declarative dotfile managers (dotbot, chezmoi, GNU Stow) — the managed end-state these rules approximate for unmanaged rc files.
