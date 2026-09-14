#!/usr/bin/env bash
# review-gate-stop-hook.sh — Stop hook.
# Surfaces missing review events when visual_review_gate is enabled.
# Emits human-readable output on stderr. Emits stdout only for valid Stop hook
# JSON when any unacknowledged requires_revision verdict exists.

set -uo pipefail

[[ "${DEVOS_SKIP_VISUAL_REVIEW_GATE:-}" == "1" ]] && exit 0

# Operational toggle (spec 2026-06-28-high-value-toggles): honor `review-gate-toggle off
# --scope review`. Default state is `on` (current behavior) — additive, never blocks legacy.
_DEVOS_TOG="${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib/toggles.sh"
if [[ -f "$_DEVOS_TOG" ]]; then
    # shellcheck source=/dev/null
    . "$_DEVOS_TOG" 2>/dev/null || true
    if declare -f toggles_resolve_state >/dev/null 2>&1; then
        _rg_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
        [[ "$(toggles_resolve_state "$_rg_root" review review 2>/dev/null | cut -f1)" == "off" ]] && exit 0
    fi
fi

DEVOS_LIB="${DEVOS_DIR:-$HOME/.dev-os}/scripts/lib"
# shellcheck source=/dev/null
source "$DEVOS_LIB/review-gate.sh" 2>/dev/null || exit 0

rc=0
output="$(review_gate_stop_hook_check 2>&1)" || rc=$?

if [[ "$rc" -ne 0 ]]; then
    [[ -n "$output" ]] && printf '%s\n' "$output" >&2
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$output" <<'PYEOF'
import json
import sys

reason = sys.argv[1] or "visual-review-gate blocked stop"
print(json.dumps({"decision": "block", "reason": reason}))
PYEOF
    else
        printf '{"decision":"block","reason":"visual-review-gate blocked stop"}\n'
    fi
    exit 0
fi

[[ -n "$output" ]] && printf '%s\n' "$output" >&2
exit 0
