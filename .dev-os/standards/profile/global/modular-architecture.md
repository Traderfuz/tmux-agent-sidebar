<!-- source: profile:cli -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/cli/standards/global/modular-architecture.md and re-run profile-sync. -->
# CLI Modular Architecture Standards

Extends: [../../../general/standards/global/modular-architecture.md](../../../general/standards/global/modular-architecture.md)

## Overview

Bash projects don't have `import` statements, package managers, or build tools that enforce dependency direction. They have `source` — a single keyword that executes another file in the current shell context, with no compile-time checks, no circular dependency detection, and no module isolation. A library file that sources another library that sources the first creates an infinite loop. A command script that is sourced by a library inverts the dependency direction silently. This standard maps the general modular architecture principles to Bash: explicit sourcing order, declared library dependencies, and a strict `command → library` dependency direction.

## Scope

This standard covers Bash library file organization in `scripts/lib/`, library-to-library dependency declarations, command-to-library sourcing rules, and circular sourcing prevention. It does NOT cover command argument parsing patterns (see `modular-integration.md`), test file organization (see BATS testing standards), or CLI plugin architecture (see `modular-integration.md`).

---

## Principles

1. **Source is not import:** `source` executes code immediately in the caller's scope with no isolation, no namespacing, and no dependency graph. Every `source` statement is a deliberate architectural decision — not a convenience.

2. **Commands call libraries; libraries never call commands:** Command scripts (`scripts/deploy.sh`, `scripts/install.sh`) source library files. Library files (`scripts/lib/logger.sh`, `scripts/lib/cache.sh`) provide functions. A library that sources a command script inverts the dependency direction and creates untestable circular coupling.

3. **Library dependencies are declared, not discovered:** Each library file declares its dependencies in a header comment. If `auto.sh` depends on `task-queue.sh`, `git-workflow.sh`, and `agent-coordinator.sh`, that dependency list is visible at the top of the file — not buried in a conditional `source` on line 200.

---

## Rules

### 1. Library file organization

- **All shared library functions MUST live in `scripts/lib/`** (`MUST`)
- **Each library file MUST serve a single concern** — `logger.sh` for logging, `cache.sh` for caching, `recovery.sh` for recovery (`MUST`)
- **A monolithic `scripts/lib/utils.sh` containing unrelated functions is prohibited** (`MUST NOT`)
- **Each library file MUST begin with `set -euo pipefail`** (`MUST`)

```
# OFF-STANDARD — monolithic utility file
scripts/lib/
  utils.sh              # 1500 lines: logging, caching, git ops, string formatting, all mixed

# ON-STANDARD — one concern per library
scripts/lib/
  logger.sh             # log_info, log_warn, log_error, log_debug
  cache.sh              # cache_get, cache_set, cache_invalidate
  git-workflow.sh       # git_commit, git_create_pr, git_auto_commit
  recovery.sh           # create_checkpoint, rollback_to_checkpoint
  task-queue.sh         # task_queue_add, task_queue_execute
```

---

### 2. Dependency declaration header

- **Every library file MUST declare its dependencies** in a header comment block (`MUST`)
- **The header format MUST be:** `# Dependencies: <list>` or `# Dependencies: none` (`MUST`)
- **Only declared dependencies MAY be sourced** — undeclared `source` calls are violations (`MUST NOT`)

```bash
# OFF-STANDARD — no dependency declaration
#!/usr/bin/env bash
set -euo pipefail

# ... 200 lines later ...
source "${DEVOS_DIR}/scripts/lib/logger.sh"  # surprise dependency

# ON-STANDARD — dependencies declared at the top
#!/usr/bin/env bash
# auto.sh — Autonomous development workflow orchestration
# Dependencies: logger.sh, task-queue.sh, git-workflow.sh, agent-coordinator.sh, recovery.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"
source "${SCRIPT_DIR}/task-queue.sh"
source "${SCRIPT_DIR}/git-workflow.sh"
source "${SCRIPT_DIR}/agent-coordinator.sh"
source "${SCRIPT_DIR}/recovery.sh"
```

---

### 3. Command → library dependency direction

- **Command scripts MUST source libraries** — this is the correct direction (`MUST`)
- **Library files MUST NOT source command scripts** (`MUST NOT`)
- **Library files MUST NOT source the entry point** (`scripts/install.sh`, `scripts/uninstall.sh`, etc.) (`MUST NOT`)
- **The dependency direction is:** `entry-point → command → library → (declared library dependencies)` (`MUST`)

```
# Dependency direction (correct)
scripts/install.sh ──source──→ scripts/lib/logger.sh
scripts/install.sh ──source──→ scripts/lib/profile-resolver.sh
scripts/lib/profile-resolver.sh ──source──→ scripts/lib/logger.sh     (declared dep)

# PROHIBITED
scripts/lib/logger.sh ──source──→ scripts/install.sh    (library → command: INVERTED)
scripts/lib/cache.sh ──source──→ scripts/lib/logger.sh ──source──→ scripts/lib/cache.sh  (CYCLE)
```

---

### 4. Circular sourcing prevention

- **The library dependency graph MUST be a directed acyclic graph (DAG)** (`MUST`)
- **Circular `source` chains MUST be detected and broken** before they cause infinite loops (`MUST`)
- **Guard patterns SHOULD be used** in libraries that are likely to be sourced multiple times (`SHOULD`)

```bash
# ON-STANDARD — source guard to prevent double-sourcing
#!/usr/bin/env bash
# logger.sh — Structured logging library
# Dependencies: none

# Guard: prevent double-sourcing
[[ -n "${_LOGGER_LOADED:-}" ]] && return 0
readonly _LOGGER_LOADED=1

set -euo pipefail

log_info() { ... }
log_warn() { ... }
log_error() { ... }
log_debug() { ... }
```

```bash
# Detecting circular dependencies (CI check)
#!/usr/bin/env bash
# scripts/check-circular-deps.sh
for lib in scripts/lib/*.sh; do
  deps=$(command grep -oP '(?<=source.*lib/)\S+\.sh' "$lib" 2>/dev/null || true)
  for dep in $deps; do
    if command grep -q "source.*$(basename "$lib")" "scripts/lib/$dep" 2>/dev/null; then
      echo "CIRCULAR: $(basename "$lib") ↔ $dep"
      exit 1
    fi
  done
done
echo "No circular dependencies found"
```

---

### 5. Library public API

- **Each library file MUST document its public functions** in a header block (`MUST`)
- **Internal helper functions (not part of the public API) MUST be prefixed with `_`** (e.g., `_parse_log_level`) (`MUST`)
- **Command scripts MUST NOT call `_`-prefixed functions** from libraries (`MUST NOT`)

```bash
# ON-STANDARD — public API documented, internals prefixed
#!/usr/bin/env bash
# cache.sh — In-memory caching with TTL
# Dependencies: logger.sh
#
# Public API:
#   cache_get <key>               — returns cached value or empty
#   cache_set <key> <value> <ttl> — stores value with TTL in seconds
#   cache_invalidate <key>        — removes cached entry
#
# Internal:
#   _cache_is_expired <key>       — checks TTL expiry (do not call directly)

_cache_is_expired() {
  # internal implementation
  ...
}

cache_get() {
  if _cache_is_expired "$1"; then
    cache_invalidate "$1"
    return 1
  fi
  echo "${_CACHE_STORE[$1]}"
}
```

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| `scripts/lib/utils.sh` with 50 unrelated functions | Not a module — it's a dumping ground; every change risks breaking unrelated callers | Split by concern: `logger.sh`, `cache.sh`, `validation.sh` |
| Library sourcing a command script | Inverted dependency direction; library becomes untestable without running the command | Commands source libraries, never the reverse |
| No dependency declaration header | Cannot determine source order without reading the entire file; surprises at line 200 | `# Dependencies: logger.sh, cache.sh` header on every library |
| `source` inside a function body (conditional sourcing) | Dependency is invisible at the file level; only discovered at runtime | Source all dependencies at file top, unconditionally |
| No source guard in heavily-used library | Double-sourcing re-executes `set` commands, redefines functions, may reset state | `[[ -n "${_LIB_LOADED:-}" ]] && return 0` guard pattern |
| Calling `_internal_helper()` from a command script | Bypasses public API; couples to internal implementation | Use only documented public functions |

---

## Deviation guidance

You MAY skip the dependency declaration header for single-function utility scripts (< 20 lines) that have zero dependencies. MUST add the header when the script grows past 20 lines or gains a dependency.

You MAY use conditional sourcing (`[[ -f "$path" ]] && source "$path"`) for optional dependencies (e.g., `learnings-capture.sh` which is optional in several libraries). MUST document the optional dependency in the header: `# Optional: learnings-capture.sh`.

---

## Profile inheritance notes

Extends: `general/standards/global/modular-architecture.md` (feature boundaries, dependency direction, public APIs, no cycles, shared kernel).
Adds: Bash-specific sourcing rules, dependency declaration headers, source guard pattern, `_`-prefix convention for internal functions, circular sourcing detection.
Overrides: Module terminology — "feature module" in the general standard maps to "library file" in Bash context. "Public API via `index.ts`" maps to "public API via documented functions in the header block."

---

## Compliance test

1. Does each library file in `scripts/lib/` serve a single concern — no monolithic `utils.sh`? (Y/N)
2. Does every library file have a `# Dependencies:` header declaring all sourced files? (Y/N)
3. Do library files avoid sourcing command scripts — dependency direction is always command → library? (Y/N)
4. Is the library dependency graph acyclic — no circular `source` chains? (Y/N)
5. Are internal helper functions prefixed with `_` and not called from command scripts? (Y/N)
6. Do heavily-sourced libraries use the `_LOADED` guard pattern to prevent double-sourcing? (Y/N)

---

## References

- [Bash `source` builtin](https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html) — executes commands from a file in the current shell environment
- [DevOS library dependency map](../../../CLAUDE.md) — documented dependency graph for all `scripts/lib/*.sh` files
- [Robert C. Martin — Acyclic Dependencies Principle](https://www.pearson.com/en-us/subject-catalog/p/agile-software-development-principles-patterns-and-practices/P200000009509) — module dependency graphs must be DAGs
- Parent standard: [general/standards/global/modular-architecture.md](../../../general/standards/global/modular-architecture.md)
