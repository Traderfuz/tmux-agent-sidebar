# Runbook: Pipeline Interruption Recovery

| Field | Value |
|-------|-------|
| Service | DevOS pipelines — `.dev-os/workflows/pipelines/` |
| Runbook type | Operational |
| Severity | P2 |
| Owner team | DevOS operator |
| Last reviewed | 2026-03-29 |
| Automation status | Manual |

---

## 1. Trigger & Detection

**Trigger:** A DevOS pipeline was interrupted mid-session — context window exhausted, session closed, tool error, or user exit — and must be resumed without restarting from Step 1.

**Symptoms:**
- Session resumes but the agent starts repeating completed work
- Resume point artifact exists on disk but the agent ignores it
- `product/runtime/reports/` contains a partial pipeline report from today
- User says "we got cut off" or "continue from where we left off"

---

## 2. Impact Assessment

**Low impact (resume possible):**
- Partial report artifact exists and contains at least one complete section
- Git working tree shows completed changes from prior steps

**High impact (restart required):**
- No artifact on disk from the pipeline run
- Git working tree is clean with no changes (nothing was saved)

---

## 3. Recovery Steps

### Step 1: Identify the interrupted pipeline

Ask or determine which pipeline was running. Common pipelines:
- `feature-delivery` — check `product/specs/<spec>/tasks.md` for last completed group
- `maintenance-session` — check `.dev-os/runtime/context-refresh-state.json` for last step
- `audit-and-remediate` — check `product/runtime/reports/audit-*-{today}.md`
- `os-coverage-audit` — check `product/runtime/reports/os-coverage-audit-{today}.md`
- `deployment-release` — check git log for last release commit

### Step 2: Read the pipeline's Resume Points table

Open the pipeline file at `.dev-os/workflows/pipelines/<name>.md`. Find the `## Resume Points` section. Match the artifacts that exist on disk to determine which step to resume at.

```bash
# Example: check os-coverage-audit resume state
ls product/runtime/reports/os-coverage-audit-*.md
# Check which sections are present
grep "^##" product/runtime/reports/os-coverage-audit-*.md
```

### Step 3: Confirm git state

```bash
git status
git log --oneline -5
```

- If steps that should have produced commits have no commits: those steps need to re-run
- If commits exist: skip those steps (their gate condition is already met)

### Step 4: Resume from the correct step

State explicitly: "Resuming `<pipeline-name>` at Step N (`<step-name>`). Skipping Steps 1–N-1 (artifacts confirmed on disk)."

Do NOT re-run completed steps. Re-running creates duplicate artifacts, duplicate commits, and wasted context.

### Step 5: Verify resume point before proceeding

Before executing the resumed step, confirm:
- The artifact from the prior step exists and is non-empty
- Any git changes from prior steps are committed (or at least staged)
- The task checklist in `tasks.md` reflects what is actually done

---

## 4. Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent re-runs all steps from Step 1 | No resume point artifacts on disk | Full restart; nothing was saved |
| Agent skips to wrong step | Multiple partial runs from different dates | Identify the correct date's artifact; delete stale ones |
| Resume point artifact exists but is empty | Crash during write | Delete empty file; restart from the prior checkpoint |
| Git state contradicts artifact state | Manual git operations between sessions | Trust git log over artifacts; sync artifact state to match git |

---

## 5. Prevention

- Every pipeline step that produces a file artifact uses `product/runtime/reports/` as output
- Never close a session mid-pipeline without confirming the current step's artifact was written
- Run `git status` before closing any session to confirm staged or committed state

---

## 6. Escalation

If resume is not possible and a full restart is required:
1. Delete partial artifacts from the interrupted run
2. State "Restarting `<pipeline-name>` from Step 1 — no resume points found"
3. Log the interruption in `product/runtime/learnings-log.jsonl` if the cause was a tool failure
