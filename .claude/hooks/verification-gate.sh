#!/usr/bin/env bash
# Stop hook: verification-gate
#
# Fires when Claude is about to end its response (Stop event).
# Reads the transcript file to extract the last assistant turn text,
# then emits a verification gate advisory if completion-signal language is detected.
#
# Non-blocking — always exits 0. Stop hook stdout must stay empty unless the
# hook emits valid JSON; human-readable advisories go to stderr.
# Input: JSON on stdin with session_id, transcript_path, cwd, stop_hook_active.
# Transcript format: JSONL where assistant turns have type="assistant",
#   message.content = [{type: "text", text: "..."}]
#
# Part of: wire-systematic-debugging-verification spec (2026-02-27)
# Detector-pattern testing governed by: profiles/general/standards/testing/committed-fixture-freshness.md
# (fixtures recorded verbatim from real failures; verified to fail pre-fix; precision+recall reported)

set -euo pipefail
trap 'exit 0' ERR

# Require python3
if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

# Parse transcript_path from stdin JSON
input_json="$(cat 2>/dev/null || true)"
if [[ -z "$input_json" ]]; then
    exit 0
fi

# Extract last assistant turn text from transcript
last_assistant_text="$(python3 -c "
import json, sys, os

try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)

transcript_path = data.get('transcript_path', '')
if not transcript_path or not os.path.exists(transcript_path):
    sys.exit(0)

last_text = ''
try:
    with open(transcript_path, 'r', encoding='utf-8', errors='replace') as f:
        for raw_line in f:
            raw_line = raw_line.strip()
            if not raw_line:
                continue
            try:
                entry = json.loads(raw_line)
            except Exception:
                continue
            if entry.get('type') != 'assistant':
                continue
            # Extract text from message.content array
            msg = entry.get('message', {})
            content = msg.get('content', [])
            for item in content:
                if isinstance(item, dict) and item.get('type') == 'text':
                    last_text = item.get('text', '')
except Exception:
    pass

print(last_text)
" <<< "$input_json" 2>/dev/null || true)"

if [[ -z "$last_assistant_text" ]]; then
    exit 0
fi

# Completion-signal keywords (case-insensitive)
# Signals the assistant is claiming work is done or working
COMPLETION_PATTERN='done|fixed|complete|all tests pass|it works|resolved|implemented|should work|looks good|finished|great|perfect|that.s it|there we go'

if echo "$last_assistant_text" | command grep -qiE "$COMPLETION_PATTERN" 2>/dev/null; then
    cat >&2 <<'GATE'

[verify] Claim detected. Gate required.
Before this claim stands:
□ What command proves this claim? (identify it)
□ Run it fresh — not from a previous session
□ Read full output including exit code
□ Cite the output in your response
Uncited claims are not verified claims.

GATE
fi

# Absence-signal keywords (case-insensitive)
# Signals the assistant is claiming a tool, API, or capability does not exist.
# Owners: general/standards/maintenance/mcp-tool-first.md (lookup procedure)
#         general/standards/global/verify-status-against-artifact.md (active search)
#
# Tuned 2026-08-14 against 656 real assistant turns in ~/.claude/projects:
#   absence 6.6% hit rate, presence 0.3%, combined 6.9% (noise threshold ~20%).
#   The gap-tolerant "no (\w+ ){0,2}(tool|api|...)" form is required: the flat
#   "no api" alternative missed "no keyword API mounted", the exact claim that
#   motivated this gate. Recall on 6 recorded real errors: 3/6 -> 6/6.
ABSENCE_PATTERN='no (\w+ ){0,2}(mcp )?(tool|api|server|capability|provider|integration)s?\b|not available|unavailable|not supported|does(n.t| not) exist|no such|is missing|are missing|not found|could ?n.t find|could not find|not installed|there.s no|there is no|not present|zero (hits|results|matches|tools)|evidence_posture: insufficient'

# Presence/history-signal keywords (case-insensitive)
# Signals a positive claim about past state — "was never invoked", "X is false",
# "still contains". These are NOT caught by the absence branch, yet four of the
# five real errors on 2026-08-14 took this form, each written while correcting
# the previous one with more confidence and less verification.
PRESENCE_PATTERN='was never|were never|never (invoked|ran|happened|existed|called|generated)|did not (happen|run|exist)|didn.t (happen|run|exist)|no record of|never been|(was|were|is|are) false\b|still contains|was fabricated|hand.written'

if echo "$last_assistant_text" | command grep -qiE "$ABSENCE_PATTERN" 2>/dev/null; then
    cat >&2 <<'ABSENCE_GATE'

[verify] Absence claim detected. Active search required.
An absence claim needs a shown search, not a glance:
□ Did you call hub__capabilities to check live server status?
□ Did you call hub__list_server_tools for the relevant server?
□ Did you vary the search PATTERN, not just widen the PATH?
  (naming variants: hub__capabilities vs mcp_hub_capabilities)
□ Absence from one registry is not absence from another
□ If genuinely absent, state that explicitly before the fallback
Never write an unverified absence into a durable artifact.

ABSENCE_GATE
fi

if echo "$last_assistant_text" | command grep -qiE "$PRESENCE_PATTERN" 2>/dev/null; then
    cat >&2 <<'PRESENCE_GATE'

[verify] Claim about past state detected. Read the artifact.
"never ran" / "is false" / "still contains" are positive claims:
□ Did you open the artifact, or infer from a summary or a tracking row?
□ Is it STALE (true when written) or FALSE (wrong when written)?
  These need different corrections — check git log before choosing.
□ For false-when-written, can you prove state AT write time?
  Config presence is not proof a running service served it that day.
□ Are you correcting a prior correction? Verify harder, not less.

PRESENCE_GATE
fi

exit 0
