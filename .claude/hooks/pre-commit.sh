#!/usr/bin/env bash
# DevOS Pre-Commit Hook — thin compatibility entry (profile-aware policy).
#
# This file is a public compatibility path only. It owns no gate list: the
# shared Git-hook policy runtime (scripts/lib/git-hook-policy.sh) resolves the
# active profile policy and executes the event entries. Exit 0 = allow commit;
# non-zero = block commit.

# On macOS, git invokes hooks via /usr/bin/env bash which resolves to /bin/bash
# (3.2). Re-exec under a Homebrew bash 4+ if available so the shared runtime and
# its validators (Bash 4+ required) don't bail out.
if [[ "${BASH_VERSINFO[0]}" -lt 4 && -z "${DEVOS_BASH_REEXEC:-}" ]]; then
    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$candidate" ]]; then
            # The command is evaluated by the re-exec'd Bash, so its variables must expand there.
            # shellcheck disable=SC2016
            candidate_major="$("$candidate" -lc 'printf "%s" "${BASH_VERSINFO[0]}"' 2>/dev/null || printf "0")"
            if [[ "$candidate_major" =~ ^[0-9]+$ ]] && [[ "$candidate_major" -ge 4 ]]; then
                exec env DEVOS_BASH_REEXEC=1 "$candidate" "$0" "$@"
            fi
        fi
    done
fi

set -uo pipefail

DEVOS_DIR="${DEVOS_DIR:-$HOME/.dev-os}"

# Prefer the installation tree, then the invocation worktree (source checkouts
# and linked worktrees both satisfy this).
POLICY_LIB="$DEVOS_DIR/scripts/lib/git-hook-policy.sh"
if [[ ! -f "$POLICY_LIB" ]]; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    POLICY_LIB="$PROJECT_ROOT/scripts/lib/git-hook-policy.sh"
fi
if [[ ! -f "$POLICY_LIB" ]]; then
    echo "[pre-commit] DevOS git-hook policy runtime not found; install DevOS to enable gates" >&2
    exit 1
fi

exec bash "$POLICY_LIB" __run pre-commit "$@"
