#!/usr/bin/env bash
# PostToolUse hook
# visual-review-gate-posttooluse.sh — emits review events for visual Write/Edit artifacts.

set +e

[[ "${DEVOS_SKIP_VISUAL_REVIEW_GATE:-}" == "1" ]] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DEVOS_LIB="${DEVOS_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}/lib"
# shellcheck source=/dev/null
source "$DEVOS_LIB/review-gate.sh" 2>/dev/null || exit 0

review_gate_enabled || exit 0

payload="$(cat || true)"
file_path="$(python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)
tool_input = data.get("tool_input") or {}
print(tool_input.get("file_path") or tool_input.get("path") or "")
' <<< "$payload")"

[[ -n "$file_path" ]] || exit 0
case "${file_path,,}" in
    *.html|*.htm|*.pdf|*.svg|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.excalidraw|*.webm|*.mp4|*.mmd|*.mermaid|planning/wireframes/*.txt|*/planning/wireframes/*.txt|planning/wireframes/*.md|*/planning/wireframes/*.md|planning/diagrams/*.md|*/planning/diagrams/*.md) ;;
    *) exit 0 ;;
esac

if [[ -f "$DEVOS_LIB/review-emit.sh" ]]; then
    # shellcheck source=/dev/null
    source "$DEVOS_LIB/review-emit.sh" 2>/dev/null || true
fi

if declare -F review_emit_artifact >/dev/null 2>&1; then
    review_emit_artifact "visual-review-gate-posttooluse" "$file_path" || true
else
    _vrg_os="${DEVOS_OS:-}"
    if [[ -z "$_vrg_os" ]]; then
        for _vrg_cfg in "${PWD}/.dev-os/config.yml" "${DEVOS_DIR:-${HOME}/.dev-os}/config.yml"; do
            [[ -f "$_vrg_cfg" ]] || continue
            _vrg_os="$(awk -F: '/^[[:space:]]*project:[[:space:]]*/ { sub(/^[[:space:]]+/, "", $2); sub(/[[:space:]]+$/, "", $2); gsub(/^["'\'']|["'\'']$/, "", $2); print $2; exit }' "$_vrg_cfg" 2>/dev/null)"
            [[ -n "$_vrg_os" ]] && break
        done
    fi
    devos_review_event "${_vrg_os:-dev-os}" "visual-review-gate-posttooluse" "$file_path" || true
fi
exit 0
