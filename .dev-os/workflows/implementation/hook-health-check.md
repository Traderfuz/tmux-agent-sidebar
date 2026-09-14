# Hook Health Check Workflow

Checks the health of all registered DevOS hooks. Used by `project-status` (compact/degraded mode)
and `runtime-diagnostics` (full mode).

## When to Use

Use this workflow as an inline health check inside other commands (e.g., `project-status`) to report on registered hook status without blocking the parent command.

Do not invoke this workflow directly from the user prompt — it is a shared workflow designed to be included in other commands via `{{workflows/}}` reference.


## Process

1. Read global Claude hook declarations from `scripts/sync/hook-registry.yml` through `scripts/lib/hook-registry-reader.sh`; check each resolved file exists and is executable.
2. Check circuit breaker state for each hook (open/closed/half-open).
3. Read learnings backlog count from `product/runtime/learnings-log.jsonl`.
4. Check error rate limiter state from `product/runtime/hook-error-state.json`.
5. Render hook health table (OK / MISSING / NOT-EXEC / ERROR per hook).
## Registered Hooks

The canonical inventory is `scripts/sync/hook-registry.yml`. The health check
below reads that registry through `scripts/lib/hook-registry-reader.sh`, filters
to Claude's global hooks, expands its path variables, and checks every entry.
Do not duplicate hook names or paths in this workflow. Add or change hooks in
the registry, then regenerate the installed settings from that source.

## Health Check

Run this bash block in the Bash tool.

**Output modes:**
- Default (`HOOK_HEALTH_FULL` unset or `0`): shows `✅ Hooks: all healthy` when OK, or a degraded-only panel listing only failures. Used by `project-status`.
- Full (`HOOK_HEALTH_FULL=1`): always shows all registered Claude hooks with status, circuit breaker states, and backlog count. Used by `runtime-diagnostics` and `project-status --hooks`.

```bash
#!/usr/bin/env bash
# Hook health check — shared by project-status and runtime-diagnostics
# Set HOOK_HEALTH_FULL=1 for always-full output (runtime-diagnostics / --hooks mode)
# Default (HOOK_HEALTH_FULL=0 or unset): degraded-only output

_DEVOS_DIR="${DEVOS_DIR:-$HOME/.dev-os}"
_STATE_DIR="${HOME}/.claude/state"
_LEARNINGS_LOG="${_DEVOS_DIR}/product/runtime/learnings-log.jsonl"
_FULL="${HOOK_HEALTH_FULL:-0}"

# --- Step 1: Hook file checks (registry-backed) ---
declare -a _HOOK_NAMES=()
declare -a _HOOK_PATHS=()
declare -a _HOOK_RESULTS=()
_registry_health_issue=""

_expand_registry_path() {
    local path="$1"
    path="${path//\$\{DEVOS_DIR\}/$_DEVOS_DIR}"
    path="${path//\$DEVOS_DIR/$_DEVOS_DIR}"
    path="${path//\$\{HOME\}/$HOME}"
    path="${path//\$HOME/$HOME}"
    path="${path/#\~/$HOME}"
    printf '%s\n' "$path"
}

_registry_file="${_DEVOS_DIR}/scripts/sync/hook-registry.yml"
if [[ -r "${_DEVOS_DIR}/scripts/lib/hook-registry-reader.sh" ]]; then
    # shellcheck source=/dev/null
    HOOK_REGISTRY_FILE="$_registry_file"
    source "${_DEVOS_DIR}/scripts/lib/hook-registry-reader.sh"
    if ! hook_registry_validate; then
        _registry_health_issue="✗ hook registry — UNPARSEABLE (${_registry_file})"
    else
        while IFS=$'\x1f' read -r _kind _event _matcher _name _path _args _applies _scope _gate; do
            [[ "$_kind" == "hook" ]] || continue
            case ",${_applies}," in
                *,claude,*) ;;
                *) continue ;;
            esac
            [[ -z "$_scope" || "$_scope" == "global" ]] || continue
            _index="${#_HOOK_NAMES[@]}"
            _HOOK_NAMES[$_index]="${_event}/${_name}"
            _HOOK_PATHS[$_index]="$(_expand_registry_path "$_path")"
        done < <(_hook_registry_dump)
        if [[ "${#_HOOK_NAMES[@]}" -eq 0 ]]; then
            _registry_health_issue="✗ hook registry — no global Claude hooks found"
        fi
    fi
else
    _registry_health_issue="✗ hook registry reader — MISSING (${_DEVOS_DIR}/scripts/lib/hook-registry-reader.sh)"
fi

_tmpdir=$(mktemp -d)
for i in "${!_HOOK_NAMES[@]}"; do
    _path="${_HOOK_PATHS[$i]}"
    (
        if [[ ! -f "$_path" ]]; then
            echo "MISSING"
        elif [[ ! -x "$_path" ]]; then
            echo "NOT-EXEC"
        else
            echo "OK"
        fi
    ) > "${_tmpdir}/${i}.status" &
done
wait

for i in "${!_HOOK_NAMES[@]}"; do
    _HOOK_RESULTS[$i]=$(cat "${_tmpdir}/${i}.status" 2>/dev/null || echo "UNKNOWN")
done
command rm -rf "$_tmpdir"

# --- Step 2: Circuit breaker states ---
_cb_issues=()
for _cb_file in \
    "${_STATE_DIR}/memory-context-breaker.json" \
    "${_STATE_DIR}/learnings-processor-breaker.json"; do
    if [[ ! -f "$_cb_file" ]]; then
        continue
    fi
    _cb_name=$(basename "$_cb_file" .json)
    _cb_parsed=$(python3 -c "
import json, sys
try:
    with open('${_cb_file}') as f:
        d = json.load(f)
    state = d.get('state', '')
    failures = d.get('failures', 0)
    since = (d.get('open_since') or d.get('last_failure') or '')[:16]
    print(f'{state}|{failures}|{since}')
except Exception as e:
    print(f'unknown|0|')
" 2>/dev/null || echo "unknown|0|")
    _cb_state="${_cb_parsed%%|*}"
    _cb_rest="${_cb_parsed#*|}"
    _cb_failures="${_cb_rest%%|*}"
    _cb_since="${_cb_rest#*|}"
    if [[ "$_cb_state" == "open" ]]; then
        _cb_issues+=("${_cb_name} — OPEN (${_cb_failures} failures since ${_cb_since})")
    fi
done

# --- Step 3: Learnings backlog ---
_backlog_msg=""
if [[ -f "$_LEARNINGS_LOG" ]]; then
    _pending=$(python3 -c "
import json, sys
count = 0
try:
    with open('${_LEARNINGS_LOG}') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                if not d.get('processed', False):
                    count += 1
            except Exception:
                pass
except Exception:
    pass
print(count)
" 2>/dev/null || echo "0")
    if [[ "$_pending" -ge 2000 ]]; then
        _backlog_msg="✗ Learnings backlog: ${_pending} entries pending (critically large)"
    elif [[ "$_pending" -ge 500 ]]; then
        _backlog_msg="⚠ Learnings backlog: ${_pending} entries pending"
    fi
fi

# --- Step 4: Error rate limiter ---
_rate_limit_msg=""
if [[ -f "${_STATE_DIR}/error-rate-limiter.json" ]]; then
    _rate_limit_msg="⚠ Error rate limiter active — hook errors being suppressed"
fi

# --- Step 5: Process accounting ---
_accounting_issues=()
if [[ -f "$_LEARNINGS_LOG" ]]; then
    _acct_output=$(python3 -c "
import json, sys
issues = []
try:
    with open('${_LEARNINGS_LOG}') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                if d.get('category') != 'process-accounting':
                    continue
                details = d.get('details', {})
                if not isinstance(details, dict):
                    continue
                spec = details.get('spec', '')
                missing = details.get('missing', [])
                incomplete = details.get('incomplete_tasks', False)
                if missing or incomplete:
                    parts = []
                    if missing:
                        parts.append('missing: ' + ', '.join(missing))
                    if incomplete:
                        parts.append('tasks incomplete')
                    issues.append(spec + ' — ' + '; '.join(parts))
            except Exception:
                pass
except Exception:
    pass
for i in issues:
    print(i)
" 2>/dev/null)
    while IFS= read -r line; do
        [[ -n "$line" ]] && _accounting_issues+=("$line")
    done <<< "$_acct_output"
fi

# --- Step 6: Project discipline hooks (Scope 3) ---
_project_hook_issues=()
_PROJECT_HOOKS_DIR=".claude/hooks"
_PROJECT_SETTINGS=".claude/settings.json"

# Project-local hooks are owned by the checkout rather than the global registry.
# Discover event-driven hook scripts from the live settings file so this check
# cannot silently age as project hook names change.
if [[ -f ".dev-os/config.yml" ]]; then
    _project_hook_commands="$(python3 -c "
import json
import re
try:
    with open('${_PROJECT_SETTINGS}') as f:
        settings = json.load(f)
    hooks = settings.get('hooks', {})
    for event in hooks.values():
        for group in event if isinstance(event, list) else []:
            for hook in group.get('hooks', []) if isinstance(group, dict) else []:
                command = hook.get('command', '') if isinstance(hook, dict) else ''
                match = re.search(r'\\.claude/hooks/([^\\\" ]+\\.sh)', command)
                if match:
                    print(match.group(1))
except Exception:
    pass
" 2>/dev/null || true)"
    while IFS= read -r _ph; do
        [[ -n "$_ph" ]] || continue
        _ph_path="${_PROJECT_HOOKS_DIR}/${_ph}"
        if [[ ! -f "$_ph_path" ]]; then
            _project_hook_issues+=("✗ project:${_ph} — MISSING (run start or repair-hooks --claude-hooks)")
        elif [[ ! -x "$_ph_path" ]]; then
            _project_hook_issues+=("✗ project:${_ph} — NOT-EXEC (chmod +x ${_ph_path})")
        fi
    done <<< "$_project_hook_commands"

    if [[ ! -f "$_PROJECT_SETTINGS" ]]; then
        _project_hook_issues+=("✗ project:.claude/settings.json — MISSING (run start)")
    fi
fi


# --- Step 7: Registry-to-live-settings parity (shared JSON emitter) ---
_parity_issues=()
_parity_registry="${_DEVOS_DIR}/scripts/sync/hook-registry.yml"
_parity_lib="${_DEVOS_DIR}/scripts/lib/hook-registry-parity.sh"
_parity_settings="${DEVOS_CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
_parity_json=""
_parity_status=0

if [[ -f "$_parity_registry" && -f "$_parity_lib" && -f "$_parity_settings" ]]; then
    # shellcheck source=/dev/null
    source "$_parity_lib" 2>/dev/null || true
    if [[ "$(type -t hook_registry_parity_check)" == "function" ]]; then
        _parity_json="$(hook_registry_parity_check "$_parity_registry" "$_parity_settings" --json 2>/dev/null)" || _parity_status=$?
        while IFS= read -r _parity_issue; do
            [[ -n "$_parity_issue" ]] && _parity_issues+=("$_parity_issue")
        done < <(python3 - "$_parity_json" "$_parity_status" <<'PY'
import json
import sys

payload, status = sys.argv[1], int(sys.argv[2])
try:
    report = json.loads(payload)
except (TypeError, ValueError):
    print(f"✗ Hook registry parity — checker unavailable (exit {status})")
    raise SystemExit(0)

if report.get("config_error"):
    print(f"✗ Hook registry parity — {report['config_error']}")
    raise SystemExit(0)

missing = report.get("missing", [])
duplicates = report.get("duplicates", [])
if missing or duplicates:
    parts = []
    if missing:
        parts.append(f"{len(missing)} missing")
    if duplicates:
        parts.append(f"{len(duplicates)} duplicate registration(s)")
    print("✗ Hook registry parity — " + ", ".join(parts))
PY
)
    fi
elif [[ ! -f "$_parity_settings" ]]; then
    _parity_issues+=("⚠ Hook registry parity — live settings missing ($_parity_settings)")
fi

# --- Aggregate degradation flag ---
_degraded=false
_hook_failures=()

for i in "${!_HOOK_NAMES[@]}"; do
    _name="${_HOOK_NAMES[$i]}"
    _st="${_HOOK_RESULTS[$i]:-UNKNOWN}"
    if [[ "$_st" != "OK" ]]; then
        _degraded=true
        case "$_st" in
            MISSING)  _hook_failures+=("✗ ${_name} — MISSING (file not found)") ;;
            NOT-EXEC) _hook_failures+=("✗ ${_name} — NOT-EXEC (not executable)") ;;
            *)        _hook_failures+=("✗ ${_name} — ${_st}") ;;
        esac
    fi
done

[[ -n "$_registry_health_issue" ]] && _degraded=true
[[ "${#_cb_issues[@]}" -gt 0 ]] && _degraded=true
[[ -n "$_backlog_msg" ]] && _degraded=true
[[ -n "$_rate_limit_msg" ]] && _degraded=true
[[ "${#_accounting_issues[@]}" -gt 0 ]] && _degraded=true
[[ "${#_project_hook_issues[@]}" -gt 0 ]] && _degraded=true
[[ "${#_parity_issues[@]}" -gt 0 ]] && _degraded=true

# --- Output ---
if [[ "$_FULL" == "1" ]]; then
    # Full mode: always show everything (runtime-diagnostics / --hooks)
    echo ""
    echo "⚙️  Hook Health (full)"
    if [[ "${#_parity_issues[@]}" -gt 0 ]]; then
        for _parity in "${_parity_issues[@]}"; do
            printf "  %s\n" "$_parity"
        done
    else
        echo "  ✅ Hook registry parity: all declared hooks registered"
    fi
    [[ -n "$_registry_health_issue" ]] && printf "  %s\n" "$_registry_health_issue"
    for i in "${!_HOOK_NAMES[@]}"; do
        _name="${_HOOK_NAMES[$i]}"
        _st="${_HOOK_RESULTS[$i]:-UNKNOWN}"
        if [[ "$_st" == "OK" ]]; then
            printf "  ✅ %s\n" "$_name"
        else
            printf "  ✗  %s — %s\n" "$_name" "$_st"
        fi
    done
    echo ""
    if [[ "${#_cb_issues[@]}" -gt 0 ]]; then
        for _cb in "${_cb_issues[@]}"; do
            printf "  ⚠ %s\n" "$_cb"
        done
    else
        echo "  Circuit breakers: all closed"
    fi
    if [[ -n "$_backlog_msg" ]]; then
        printf "  %s\n" "$_backlog_msg"
    else
        echo "  Learnings backlog: healthy"
    fi
    if [[ -n "$_rate_limit_msg" ]]; then
        printf "  %s\n" "$_rate_limit_msg"
    else
        echo "  Error rate limiter: inactive"
    fi
    if [[ "${#_accounting_issues[@]}" -gt 0 ]]; then
        echo ""
        echo "  Process accounting issues:"
        for _acct in "${_accounting_issues[@]}"; do
            printf "  ⚠ spec: %s\n" "$_acct"
        done
        echo "  → Retroactively create spec.md/tasks.md or run autonomous --force-skip-spec-gate"
    else
        echo "  Process accounting: clean"
    fi
    echo ""
    if [[ "${#_project_hook_issues[@]}" -gt 0 ]]; then
        echo "  Project discipline hooks:"
        for _phi in "${_project_hook_issues[@]}"; do
            printf "  %s\n" "$_phi"
        done
    else
        echo "  Project discipline hooks: healthy"
    fi

elif [[ "$_degraded" == "true" ]]; then
    # Degraded mode: show only failing items
    echo ""
    echo "⚙️  Hook Health"
    [[ -n "$_registry_health_issue" ]] && printf "  %s\n" "$_registry_health_issue"
    for _parity in "${_parity_issues[@]}"; do
        printf "  %s\n" "$_parity"
    done
    for _f in "${_hook_failures[@]}"; do
        printf "  %s\n" "$_f"
    done
    for _cb in "${_cb_issues[@]}"; do
        printf "  ⚠ %s\n" "$_cb"
    done
    [[ -n "$_backlog_msg" ]] && printf "  %s\n" "$_backlog_msg"
    [[ -n "$_rate_limit_msg" ]] && printf "  %s\n" "$_rate_limit_msg"
    if [[ "${#_accounting_issues[@]}" -gt 0 ]]; then
        echo "  Process accounting issues:"
        for _acct in "${_accounting_issues[@]}"; do
            printf "  ⚠ spec: %s\n" "$_acct"
        done
        echo "  → Retroactively create spec.md/tasks.md or run autonomous --force-skip-spec-gate"
    fi
    for _phi in "${_project_hook_issues[@]}"; do
        printf "  %s\n" "$_phi"
    done
    echo "→ Run runtime-diagnostics for full details"

else
    # All healthy
    echo "✅ Hooks: all healthy"
    echo "✅ Hook registry parity: all declared hooks registered"
fi
```

## Display Format

```
Hook Health
  Registry-declared global Claude hooks: [one row per registry entry]
  Project-local settings hooks: [one row per live settings command]
  Circuit breakers:               [all closed | [N] open]
  Learnings backlog:              [N] entries
```
