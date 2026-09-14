# Cross-OS Handoff Pipeline

Consume research, marketing, design, and creative outputs from OS packages into the active DevOS project in a single coordinated pass — updating project context, standards, and AGENTS.md to reflect all available upstream work.

## When to Use

- Starting a development session after an OS package (Research OS, Marketing OS, Creative OS) has produced new outputs
- "Load the latest research into context", "consume what marketing produced", "pull in the design handoff"
- Before a feature spec or implementation session that should draw on OS-produced artifacts
- After a cross-team handoff where multiple OS packages produced outputs simultaneously
- Orchestrate routes here for goal types: "Load research", "Consume OS output", "Sync from Research/Marketing/Design/Creative"
- Anti-trigger: do NOT use to RUN the OS pipelines themselves — this pipeline only consumes their output
- Anti-trigger: do NOT use when no OS packages are installed — check `os-registry.yml` first

## Prerequisites

- DevOS initialized in the project (`start` has been run)
- At least one OS package installed (check `os-registry.yml`)
- OS package has produced outputs in its `output_root/` directory (e.g. `research/`, `marketing/`, `creative/`, `design/`)

## Process

1. Run backfill gate for each installed OS package.
2. Detect available OS outputs from `os-registry.yml`.
3. Consume outputs from each ready OS (research, marketing, creative, design).
4. Update project context (AGENTS.md, standards, capabilities index).
5. Confirm handoff consumed and log to `os-handoff-state.json`.

## Steps

### Step 0: Backfill Gate

**Command:** Inline audit step — invoke each OS's `*-post-update-backfill` skill
**Input:** Each installed OS package's `install-manifest.json` (detected from `os-registry.yml`)
**Output:** Per-OS readiness status; remediation commands for any OS with MISSING foundation artifacts
**Gate to next step:** All installed OSes report no MISSING artifacts (warnings are non-blocking; MISSING is blocking per-OS)
**Skip if:** `--skip-backfill` flag is set

For each installed OS package found in `os-registry.yml`, run its backfill skill:

```
research-os  → /ros-post-update-backfill
marketing-os → /mos-post-update-backfill   (skill: marketing-os-mos-post-update-backfill)
creative-os  → /cos-post-update-backfill   (skill: creative-os-cos-post-update-backfill)
design-os    → /dos-post-update-backfill   (skill: design-os-dos-post-update-backfill)
```

**Per-OS handling:**
- If backfill reports all artifacts PRESENT → mark OS as `ready`, continue to next OS
- If backfill reports any artifact MISSING → mark OS as `blocked`, print the remediation commands for that OS, and **skip that OS's consume step** (Steps 2–5) rather than failing the entire pipeline
- OSes that are `ready` proceed through their consume steps normally even if other OSes are `blocked`

**Backfill Gate summary output:**
```
Backfill Gate
  research-os   [READY]
  marketing-os  [BLOCKED] — run /mos-brand-voice --client {client} to unblock
  creative-os   [READY]
  design-os     [READY]

Proceeding with consume for: research-os, creative-os, design-os
Skipping (blocked): marketing-os
```

### Step 1: Detect Available OS Outputs

**Command:** Inline detection step (read `os-registry.yml`)
**Input:** `os-registry.yml` in project root
**Output:** List of installed OS packages with their `output_root` paths; confirmation that each output directory has new or unread content
**Gate to next step:** At least one OS package installed with non-empty output directory
**Skip if:** `os-registry.yml` does not exist or lists no installed packages (warn user)

Detection checklist (for each entry in `os-registry.yml`):
```
research-os  → research/     → check for research/**/*.md modified since last consume
marketing-os → marketing/    → check for marketing/**/*.md modified since last consume
creative-os  → creative/     → check for creative/**/*.md modified since last consume
design-os    → design/       → check for design/**/*.md modified since last consume
```

Last consume timestamp recorded in `.dev-os/runtime/os-handoff-state.json`.

### Step 2: Consume Research OS Output

**Skill:** `consume-research`
**Input:** `research/` directory (or `research-os/` config root)
**Output:** Research findings injected into project context; relevant findings added to `product/context/` or summarized in session notes
**Gate to next step:** Command exits 0
**Skip if:** Research OS not installed OR `research/` has no changes since last consume OR research-os was marked `blocked` in Step 0

**Pre-consume export check (skip if `--skip-export` flag is set):**
Compare the newest mtime of `research/**/*.md` against the mtime of `research/export/handoff-to-*.json`:
- If newest `.md` mtime > handoff JSON mtime → the research content has changed since the last export; automatically call `/ros-export-handoff` before consuming, then proceed
- If handoff JSON mtime ≥ newest `.md` mtime → handoff is current; skip re-export and consume directly

What `consume-research` loads:
- Competitor analysis reports
- Market research summaries
- User research findings
- Opportunity frameworks

### Step 3: Consume Marketing OS Output

**Skill:** `consume-marketing`
**Input:** `marketing/` directory
**Output:** Brand voice, positioning angles, audience profiles, keyword lists loaded into project context
**Gate to next step:** Command exits 0
**Skip if:** Marketing OS not installed OR `marketing/` has no changes since last consume OR marketing-os was marked `blocked` in Step 0

**Pre-consume export check (skip if `--skip-export` flag is set):**
Compare the newest mtime of `marketing/**/*.md` against the mtime of `marketing/export/handoff-to-*.json`:
- If newest `.md` mtime > handoff JSON mtime → call `/mos-export-handoff --target-os dev-os` (and creative-os if installed) before consuming, then proceed
- If handoff JSON mtime ≥ newest `.md` mtime → handoff is current; skip re-export and consume directly

What `consume-marketing` loads:
- Brand voice guidelines (affects copy in feature specs and UI text)
- Positioning angles (affects product copy and differentiators)
- Audience profiles (affects UX decisions and feature prioritization)

### Step 4: Consume Design OS Output

**Skill:** `consume-design`
**Input:** `design/` directory
**Output:** Design system tokens, component specs, style guidelines loaded into project context
**Gate to next step:** Command exits 0
**Skip if:** Design OS not installed OR `design/` has no changes since last consume OR design-os was marked `blocked` in Step 0

**Pre-consume export check (skip if `--skip-export` flag is set):**
Compare the newest mtime of `design/**/*.md` against the mtime of `design/export/handoff-to-dev-os.json`:
- If newest `.md` mtime > handoff JSON mtime → call `/dos-export-handoff` before consuming, then proceed
- If handoff JSON mtime ≥ newest `.md` mtime → handoff is current; skip re-export and consume directly

What `consume-design` loads:
- Design tokens (colors, typography, spacing)
- Component specifications
- Interaction patterns

### Step 5: Consume Creative OS Output

**Skill:** `consume-creative`
**Input:** `creative/` directory
**Output:** Creative briefs, campaign assets, brand collateral loaded into project context
**Gate to next step:** Command exits 0
**Skip if:** Creative OS not installed OR `creative/` has no changes since last consume OR creative-os was marked `blocked` in Step 0

**Pre-consume export check (skip if `--skip-export` flag is set):**
Compare the newest mtime of `creative/**/*.md` against the mtime of `creative/export/handoff-to-*.json`:
- If newest `.md` mtime > handoff JSON mtime → call `/cos-export-handoff` before consuming, then proceed
- If handoff JSON mtime ≥ newest `.md` mtime → handoff is current; skip re-export and consume directly

What `consume-creative` loads:
- Campaign briefs (affects feature copy and CTAs)
- Brand asset inventory (affects image/media references in features)

### Step 6: Regenerate AGENTS.md

**Skill:** `generate-agents-md`
**Input:** Updated project context from Steps 2-5
**Output:** `AGENTS.md` regenerated with OS-derived context injected (research findings, brand guidelines, design tokens)
**Gate to next step:** `AGENTS.md` updated with current date in header
**Skip if:** No OS outputs were consumed in Steps 2-5 (no content changed)

### Step 7: Update Handoff State

**Command:** Inline state update
**Input:** Consume results from Steps 2-5
**Output:** `.dev-os/runtime/os-handoff-state.json` updated with consume timestamps per OS package
**Gate to completion:** State file written
**Skip if:** N/A — always update state after a handoff session

State file structure:
```json
{
  "last_consume": {
    "research-os": "2026-03-29T10:00:00Z",
    "marketing-os": "2026-03-28T15:30:00Z",
    "creative-os": null,
    "design-os": null
  }
}
```

## Pipeline Variants

### Fast Mode (`--skip-backfill`)

Skip Step 0 (Backfill Gate). All installed OS packages proceed directly to change detection and consume.
Use when you've already run backfill audits in this session and know the foundation artifacts are present.

### Fast Mode (`--skip-export`)

Skip the pre-consume export check in Steps 2–5. Consume handoff JSON as-is without checking if output files are newer.
Use when you know the handoff JSON is current or when you explicitly want to consume a specific snapshot.

### Fully Fast (`--skip-backfill --skip-export`)

Skip both Step 0 and all pre-consume export checks. Jump directly from Step 1 (detect) to consuming.
Use for rapid context reloads when you've already run backfill + export this session (e.g. after `/cross-os-sync`).

### Research Only (`--research-only`)

Run Steps 1, 2, 6, 7. Consume only Research OS output.
Use when only research has new content and you don't want to reload everything.

### Design Only (`--design-only`) [G-012]

Run Steps 1, 4, 6, 7. Consume only Design OS output.
Use during design sprints when only Design OS has new content and reloading research context is undesirable.

### Design + Research (`--design`)

Run Steps 1, 2, 4, 6, 7. Most common combination for feature development sessions.
Use at the start of any spec-writing or implementation session.

### Full Sync (`--all`)

Run all steps regardless of change detection. Forces a complete reload of all OS outputs.
Use when context seems stale or you suspect change detection missed something.

## Resume Points

| Artifact | Indicates | Resume at |
|----------|-----------|-----------|
| `os-registry.yml` exists and backfill reported no MISSING | Backfill gate passed | Step 1 (detect outputs) |
| `.dev-os/runtime/os-handoff-state.json` exists | Previous consume recorded | Step 1 (detect new changes since last consume) |
| Each OS `output_root/` inventoried in console output | Outputs detected | Step 2 (consume research, or first unblocked OS) |
| `product/context/research-summary.md` updated | Research consumed | Step 3 (marketing) or Step 4 (design) if marketing skipped |
| `product/context/marketing-summary.md` updated | Marketing consumed | Step 4 (design) |
| `product/context/design-summary.md` updated | Design consumed | Step 5 (creative) |
| `product/context/creative-summary.md` updated | Creative consumed | Step 6 (AGENTS.md regen) |
| `AGENTS.md` header date today | AGENTS.md regenerated | Step 7 (state update) |
| `.dev-os/runtime/os-handoff-state.json` `last_consume` timestamps all updated | State file written | Pipeline complete |

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Step 1 | `os-registry.yml` not found | Run `start` to initialize DevOS; OS packages register themselves on install |
| Step 1 | No OS packages installed | Inform user — no OS outputs to consume; pipeline exits cleanly |
| Step 2 | `consume-research` fails (no research dir) | Research OS installed but no outputs yet; skip gracefully |
| Step 3 | `consume-marketing` fails | Same as Step 2 — Marketing OS may not have produced output yet |
| Step 4 | `consume-design` fails | Same — Design OS may not have run |
| Step 5 | `consume-creative` fails | Same — Creative OS may not have run |
| Step 6 | AGENTS.md regeneration fails | Check that context files from consume steps were written correctly; retry |
| Step 7 | State file write fails | Non-blocking — note manually which packages were consumed; continue |

## Display Format

```
Cross-OS Handoff Pipeline
  Packages ready: [N] / [total] ([list])
  Consumed:       research-os | marketing-os | creative-os | design-os
  Context updated: AGENTS.md, standards, capabilities index
  Status: complete
```
