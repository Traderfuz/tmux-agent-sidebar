#!/usr/bin/env bash
# posttooluse-session-state-refresh.sh — PostToolUse hook (Bash tool).
#
# Refreshes .dev-os/runtime/session-state.yml after commits or merges that
# represent spec-shape, gap-convergence, release-bump, feature-merge, or
# spec-closure milestones. This gives daily-review a live view of active
# intent vs shipped work.
#
# Trigger: PostToolUse on Bash — filters for git commit / git merge commands
# whose message matches a milestone pattern.
#
# Closes: cap-20260604-0cc8
# Broadened: cap-20260627-session-state-stale-on-closeout
#
# CRITICAL: Must always exit 0 to never block tool execution.
# PERFORMANCE: Target <100ms — grep + source + one function call.

set -euo pipefail
trap 'exit 0' ERR

: "${DEVOS_DIR:=$HOME/.dev-os}"

# SIGTTIN guard: non-Claude CLIs (codex/omp/zed/orca) attach the live TTY as
# stdin; reading it from a hook subprocess sends SIGTTIN and suspends the session.
# Only read when stdin is a pipe (non-TTY); Claude always pipes, so this is a no-op there.
if [[ ! -t 0 ]]; then
    input="$(cat)"
else
    input=""
fi
tool_name="$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || true)"

[[ "$tool_name" == "Bash" ]] || exit 0

tool_input="$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || true)"

# Only fire on git commit OR git merge commands
if [[ "$tool_input" != *"git commit"* && "$tool_input" != *"git merge"* ]]; then
  exit 0
fi

# Extract commit message from the command
_msg=""
if [[ "$tool_input" == *"-m "* ]]; then
  _msg="$tool_input"
fi

# Match milestone patterns in the commit message
_phase=""
_event=""

if [[ "$_msg" == *"shape-spec"* || "$_msg" == *"spec: shape"* || "$_msg" == *"feat(spec)"* ]]; then
  _phase="spec-shape"
  _event="spec-shaped"
elif [[ "$_msg" == *"gap-convergence"* || "$_msg" == *"converge"* && "$_msg" == *"gap"* || "$_msg" == *"dalio"* && "$_msg" == *"fix"* ]]; then
  _phase="gap-convergence"
  _event="converged"
elif [[ "$_msg" == *"release"* && "$_msg" == *"bump"* ]]; then
  # release-bump already handled by git-release.sh — skip to avoid double-write
  exit 0
# NEW: feature merges (merge-feature skill, PR merges, fast-forward landings)
elif [[ "$_msg" == *"git merge"* || "$_msg" == *"Merge pull request"* || "$_msg" == *"Merge branch"* || "$_msg" == *"merge-feature"* ]]; then
  _phase="merged"
  _event="feature-merged"
# NEW: spec closure via backlog row edit or status:complete marker
elif [[ "$_msg" == *"chore(backlog)"* || "$_msg" == *"Completed:"* || "$_msg" == *"status:complete"* || "$_msg" == *"status: complete"* ]]; then
  _phase="closed"
  _event="spec-closed"
# NEW: feature implementation commits on feature branches (feat(), fix() with scope)
elif [[ "$_msg" == *"feat("* || "$_msg" == *"fix("* ]]; then
  _phase="implemented"
  _event="feature-implemented"
fi

[[ -z "$_phase" ]] && exit 0

# Source recovery.sh and call the refresh function
_recovery_lib="${DEVOS_DIR}/scripts/lib/recovery.sh"
[[ -f "$_recovery_lib" ]] || exit 0

# The installation root is configurable, so this dynamic source cannot be followed statically.
# shellcheck disable=SC1090,SC1091
source "$_recovery_lib"

if declare -f recovery_refresh_runtime_session_state >/dev/null 2>&1; then
  recovery_refresh_runtime_session_state "-" "$_phase" "$_event" 2>/dev/null || true
fi

exit 0
