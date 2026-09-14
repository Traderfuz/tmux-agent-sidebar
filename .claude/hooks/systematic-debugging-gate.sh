#!/usr/bin/env bash
# PreToolUse hook: systematic-debugging-gate
#
# Fires before Bash/Edit/Write tool calls.
# Detects fix-intent + error-context in tool input, counts fix attempts per
# error-fingerprint over a rolling window, and:
#
#   - Attempt 1-2: prints Phase 1 advisory checklist + next-command marker
#   - Attempt 3+:  BLOCKS (exit 2) unless systematic-debugging skill was invoked
#                  since last fix, OR DEVOS_DEBUG_GATE=allow set.
#
# Every trigger appends a structured entry to:
#   product/runtime/learnings-log.jsonl   (telemetry)
#   .dev-os/runtime/debug-attempts.jsonl  (state for counter, append-only)
#
# Closes gaps G-001 + G-002 + G-003 + G-004 from
# product/gap-analysis/2026-04-18-systematic-debugging-reoccurrence-multi-angle.md
#
# Escape hatches:
#   DEVOS_DEBUG_GATE=allow  — bypass block (logged)
#   DEVOS_DEBUG_GATE=off    — disable gate entirely

set -uo pipefail

# Locate project root (git) or fall back to cwd
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="${DEVOS_DEBUG_GATE_STATE_DIR:-$PROJECT_ROOT/.dev-os/runtime}"
STATE_FILE="$STATE_DIR/debug-attempts.jsonl"
LEARNINGS_LOG="${DEVOS_DEBUG_GATE_LEARNINGS_LOG:-$PROJECT_ROOT/product/runtime/learnings-log.jsonl}"

# Rolling window: attempts older than this (seconds) don't count.
WINDOW_SECONDS="${DEVOS_DEBUG_GATE_WINDOW:-1800}"   # default 30 min
BLOCK_AT="${DEVOS_DEBUG_GATE_BLOCK_AT:-3}"          # block on 3rd attempt

# Session-level counter: tracks consecutive gate fires regardless of fingerprint.
# Root cause fix: per-fingerprint count stays at 1 when fingerprints rotate on
# every tool call (observed: 420 fires/week, all at attempt=1, 0 blocks).
SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
SESSION_COUNTER_FILE="${DEVOS_DEBUG_GATE_SESSION_DIR:-/tmp}/devos-gate-session-${SESSION_ID}"

# Kill switch
if [[ "${DEVOS_DEBUG_GATE:-}" == "off" ]]; then
    exit 0
fi

input_json="$(cat 2>/dev/null || true)"
# Extract only code-relevant content — never the description/metadata fields.
# Bash: analyze 'command' only. Edit: 'old_string'+'new_string'. Write: 'content'.
# Bug that caused 12 false fires in 14 min: d.get('tool_input') returned the full
# dict including the 'description' field, so any descriptive text with "resolve +
# null" or "fix + error" in a maintenance-task description triggered the gate.
tool_input="$(echo "$input_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    if isinstance(ti, dict):
        # Bash tool: code lives in 'command' only
        if 'command' in ti:
            print(ti['command'])
        # Edit tool: analyze the strings being changed/added
        elif 'old_string' in ti or 'new_string' in ti:
            print((ti.get('old_string', '') or '') + ' ' + (ti.get('new_string', '') or ''))
        # Write tool: analyze the content being written
        elif 'content' in ti:
            print(ti['content'])
        else:
            print('')
    elif isinstance(ti, str):
        print(ti)
    else:
        print(d.get('command', '') or '')
except Exception:
    print('')
" 2>/dev/null || true)"

if [[ -z "$tool_input" ]]; then
    exit 0
fi

# Word boundaries (\b) prevent substring matches:
#   "prefix" / "suffix" must NOT trigger on "fix"
#   "fallback" / "failure_mode" must NOT trigger on "fail"
#   "incorrect" must NOT trigger on "correct"
FIX_INTENT_PATTERN='\bfix\b|\bpatch\b|\bresolve\b|\bcorrect\b|\bworkaround\b|\brevert\b'
ERROR_CONTEXT_PATTERN='\berror\b|\bfail(ed|ure)?\b|\bbug\b|\bbroken\b|\bcrash\b|\bexception\b|\bundefined\b|\bnull\b|\btraceback\b|not working|went wrong'

has_fix_intent=0
has_error_context=0
if echo "$tool_input" | command grep -qiE "$FIX_INTENT_PATTERN" 2>/dev/null; then
    has_fix_intent=1
fi
if echo "$tool_input" | command grep -qiE "$ERROR_CONTEXT_PATTERN" 2>/dev/null; then
    has_error_context=1
fi

# Pattern didn't match — exit silently
if [[ "$has_fix_intent" -ne 1 || "$has_error_context" -ne 1 ]]; then
    exit 0
fi

# Error fingerprint — semantic extraction: exception class, file, line number.
# Extracts structured error tokens to group the same root error across fix attempts,
# even when surrounding context differs (variable names, whitespace, minor edits).
fingerprint="$(python3 - "$tool_input" <<'PYFP'
import sys, re, hashlib

text = sys.argv[1].lower()

# Extract semantic error tokens in priority order
tokens = []

# Exception class (e.g. TypeError, AttributeError, AssertionError)
exc = re.findall(r'\b([a-z][a-z]+error|[a-z]+exception|[a-z]+failure)\b', text)
tokens.extend(exc[:2])

# File + line number (e.g. foo.py:42, test_bar.bats:17)
fileline = re.findall(r'([\w.-]+\.(py|sh|bats|ts|js)):(\d+)', text)
for f, _, n in fileline[:2]:
    tokens.append(f"{f}:{n}")

# Test name pattern (bats: "test name", pytest: "FAILED test_foo")
test_names = re.findall(r'(?:failed|error in)\s+(test_\w+|\w+_test\b)', text)
tokens.extend(test_names[:1])

# Fall back to normalized raw text if no semantic tokens found
if not tokens:
    normalized = re.sub(r'\s+', ' ', re.sub(r'[^a-z0-9 ]', '', text)).strip()
    fp = hashlib.sha1(normalized[:200].encode()).hexdigest()[:12]
else:
    fp = hashlib.sha1(' '.join(tokens).encode()).hexdigest()[:12]

print(fp)
PYFP
)"
[[ -z "$fingerprint" ]] && fingerprint="unknown"

mkdir -p "$STATE_DIR" "$(dirname "$LEARNINGS_LOG")" 2>/dev/null || true

now_epoch="$(date +%s)"
now_iso="$(date -Iseconds)"
cutoff=$((now_epoch - WINDOW_SECONDS))

# Count prior attempts with same fingerprint inside rolling window.
# State file schema: {"ts_epoch":N, "fingerprint":"...", "skill_invoked":false}
attempt_count=1
skill_invoked_since=0
if [[ -f "$STATE_FILE" ]]; then
    attempt_count=$(python3 - "$STATE_FILE" "$fingerprint" "$cutoff" <<'PY'
import json, sys
path, fp, cutoff = sys.argv[1], sys.argv[2], int(sys.argv[3])
n = 1  # current attempt
try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get("fingerprint") == fp and rec.get("ts_epoch", 0) >= cutoff:
                n += 1
except FileNotFoundError:
    pass
print(n)
PY
)

    # Check if skill was invoked since the last attempt for this fingerprint.
    # Compare by file order (line index) AND epoch — line order wins when
    # events fall in the same epoch second (sub-second resolution).
    skill_invoked_since=$(python3 - "$STATE_FILE" "$fingerprint" <<'PY'
import json, sys
path, fp = sys.argv[1], sys.argv[2]
last_attempt_idx = -1
skill_idx = -1
try:
    with open(path) as f:
        for i, line in enumerate(f):
            s = line.strip()
            if not s:
                continue
            try:
                rec = json.loads(s)
            except Exception:
                continue
            if rec.get("event") == "gate_fired" and rec.get("fingerprint") == fp:
                last_attempt_idx = i
            if rec.get("event") == "skill_invoked":
                skill_idx = i
except FileNotFoundError:
    pass
print(1 if skill_idx > last_attempt_idx else 0)
PY
)
fi

# Prune state file to keep only entries within rolling window (G-010)
# Runs on every fire; bounded O(N) where N = entries in file.
if [[ -f "$STATE_FILE" ]]; then
    python3 - "$STATE_FILE" "$cutoff" <<'PY' 2>/dev/null || true
import json, os, sys, tempfile
path, cutoff = sys.argv[1], int(sys.argv[2])
kept = []
try:
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            try:
                rec = json.loads(s)
            except Exception:
                continue
            if rec.get("ts_epoch", 0) >= cutoff:
                kept.append(s)
except FileNotFoundError:
    sys.exit(0)
# Only rewrite if pruning actually removed something (avoid thrash)
with open(path) as f:
    original_lines = sum(1 for _ in f)
if len(kept) != original_lines:
    fd, tmp = tempfile.mkstemp(prefix=".debug-attempts.", dir=os.path.dirname(path))
    with os.fdopen(fd, "w") as f:
        for line in kept:
            f.write(line + "\n")
    os.replace(tmp, path)
PY
fi

# Append telemetry (always, before any blocking decision)
telem_line="$(python3 -c '
import json, sys
rec = {
    "event": "gate_fired",
    "source": "systematic-debugging-gate",
    "ts": sys.argv[1],
    "ts_epoch": int(sys.argv[2]),
    "fingerprint": sys.argv[3],
    "attempt": int(sys.argv[4]),
    "skill_invoked_since_last": bool(int(sys.argv[5])),
}
print(json.dumps(rec))
' "$now_iso" "$now_epoch" "$fingerprint" "$attempt_count" "${skill_invoked_since:-0}")"
printf '%s\n' "$telem_line" >> "$STATE_FILE" 2>/dev/null || true
printf '%s\n' "$telem_line" >> "$LEARNINGS_LOG" 2>/dev/null || true

# Session-level counter: increment on every gate fire; reset when skill invoked.
# Reads/writes a plain integer in SESSION_COUNTER_FILE.
session_count=0
if [[ -f "$SESSION_COUNTER_FILE" ]]; then
    session_count="$(cat "$SESSION_COUNTER_FILE" 2>/dev/null || echo 0)"
    # Sanitize: if file contains non-integer, reset to 0
    [[ "$session_count" =~ ^[0-9]+$ ]] || session_count=0
fi
# Reset counter if skill was invoked since the session counter file was created.
# Use the session file mtime as a proxy for "session start" — skill_invoked events
# written after the file was created mean the designer invoked the skill.
session_start_epoch=0
if [[ -f "$SESSION_COUNTER_FILE" ]]; then
    session_start_epoch="$(python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$SESSION_COUNTER_FILE" 2>/dev/null || echo 0)"
fi
skill_invoked_in_session=0
if [[ -f "$STATE_FILE" && "$session_start_epoch" -gt 0 ]]; then
    skill_invoked_in_session="$(python3 - "$STATE_FILE" "$session_start_epoch" <<'PY'
import json, sys
path, cutoff = sys.argv[1], int(sys.argv[2])
try:
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s: continue
            try:
                rec = json.loads(s)
            except Exception:
                continue
            if rec.get("event") == "skill_invoked" and rec.get("ts_epoch", 0) >= cutoff:
                print(1)
                sys.exit(0)
except FileNotFoundError:
    pass
print(0)
PY
)"
fi
if [[ "${skill_invoked_in_session:-0}" -eq 1 ]]; then
    session_count=0
fi
session_count=$(( session_count + 1 ))
printf '%s' "$session_count" > "$SESSION_COUNTER_FILE" 2>/dev/null || true

# --- Cross-session recurrence + closure-signal check (G-DBG-001/002/003) ---
# 7-day window; emits one needs_closure prompt per fingerprint per session.
CLOSURE_SENTINEL="/tmp/devos-gate-closure-${SESSION_ID}-${fingerprint}"
if [[ ! -f "$CLOSURE_SENTINEL" ]]; then
    _closure_status="$(python3 - "$STATE_FILE" "$fingerprint" "$now_epoch" <<'PYCL' 2>/dev/null || echo "OK"
import json, sys
path, fp, now = sys.argv[1], sys.argv[2], int(sys.argv[3])
cutoff_7d = now - 604800
cutoff_48h = now - 172800
total_fires = 0
has_closure = False
try:
    with open(path) as f:
        for line in f:
            s = line.strip()
            if not s: continue
            try:
                rec = json.loads(s)
            except Exception:
                continue
            ev = rec.get("event", "")
            rfp = rec.get("fingerprint", "")
            ts = rec.get("ts_epoch", 0)
            if ev == "gate_fired" and rfp == fp and ts >= cutoff_7d:
                total_fires += 1
            if rfp == fp and ev in ("gate_closed", "gate_acknowledged", "fix_shipped", "learning_recorded") and ts >= cutoff_48h:
                has_closure = True
except FileNotFoundError:
    pass
if total_fires >= 3 and not has_closure:
    print(f"NEEDS_CLOSURE:{total_fires}")
else:
    print("OK")
PYCL
)"
    if [[ "$_closure_status" == NEEDS_CLOSURE:* ]]; then
        _fire_count="${_closure_status#NEEDS_CLOSURE:}"
        touch "$CLOSURE_SENTINEL" 2>/dev/null || true
        cat <<CLOSURE

[systematic-debugging] Recurring pattern (fingerprint ${fingerprint}) — ${_fire_count} fires across sessions, no recorded closure.
Closure options:
  1. systematic-debugging           (structured root-cause)
  2. source ~/.dev-os/scripts/lib/learnings-capture.sh && devos_acknowledge_gate_fingerprint "${fingerprint}" "reason"
  3. Add to product/inbox.jsonl or a spec task  (track for later)

CLOSURE
    fi
fi

# Blocking decision — per-fingerprint (3rd+ same fingerprint) OR session-level
# (3+ consecutive gate fires without any skill invocation this session).
if [[ ( "$attempt_count" -ge "$BLOCK_AT" || "$session_count" -ge "$BLOCK_AT" ) && "${skill_invoked_since:-0}" -eq 0 && "${skill_invoked_in_session:-0}" -eq 0 && "${DEVOS_DEBUG_GATE:-}" != "allow" ]]; then
    # Log the block
    block_line="$(python3 -c '
import json, sys
print(json.dumps({
    "event": "gate_blocked",
    "source": "systematic-debugging-gate",
    "ts": sys.argv[1],
    "ts_epoch": int(sys.argv[2]),
    "fingerprint": sys.argv[3],
    "attempt": int(sys.argv[4]),
}))
' "$now_iso" "$now_epoch" "$fingerprint" "$attempt_count")"
    printf '%s\n' "$block_line" >> "$STATE_FILE" 2>/dev/null || true
    printf '%s\n' "$block_line" >> "$LEARNINGS_LOG" 2>/dev/null || true

    # Emit message on stderr (visible to user) and block the tool call
    cat >&2 <<BLOCK

[systematic-debugging] BLOCKED — attempt ${attempt_count} on same error
fingerprint (${fingerprint}) without invoking the systematic-debugging
skill since the last failure.

Per .dev-os/standards/profile/maintenance/debugging-escalation.md:
  "Do not make a third fix attempt on the same error without first
   completing at least Phase 1 of systematic-debugging."

Required next step:
  systematic-debugging

Escape hatches:
  DEVOS_DEBUG_GATE=allow  — one-shot bypass (logged)
  DEVOS_DEBUG_GATE=off    — disable gate for this session

<<next>>systematic-debugging<</next>>

BLOCK
    exit 2
fi

# Non-blocking advisory — attempt 1 or 2
cat <<CHECKLIST

[systematic-debugging] Root cause required before fix. (attempt ${attempt_count}/${BLOCK_AT} for fingerprint ${fingerprint})
Phase 1 checklist:
□ Error message read completely?
□ Reproduced consistently?
□ Recent changes checked (git log)?
□ Hypothesis formed: "I think X is the root cause because Y"
Only proceed if all four are checked.

Next recommended command:

<<next>>systematic-debugging<</next>>

CHECKLIST

exit 0
