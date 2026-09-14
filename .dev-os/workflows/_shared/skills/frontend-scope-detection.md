# Frontend Scope Detection

<!-- Shared snippet: profiles/general/workflows/_shared/skills/frontend-scope-detection.md -->
<!-- Reference via: {{workflows/_shared/skills/frontend-scope-detection}} -->

Determine whether the current spec or task group involves frontend UI work, then conditionally load the full frontend design pipeline.

## When to Use

Use this snippet when a workflow (implement-tasks, write-spec) needs to decide whether to inject the frontend design pipeline before implementation begins.

Do not invoke directly — embed via `{{workflows/_shared/skills/frontend-scope-detection}}` in a parent workflow.

## Process

1. Run the 6 detection steps in order against project config, task group name, spec content, and design artifacts.
2. If any step sets `frontend_scope = true`, load the design pipeline precursors and `frontend-design` skill.
3. If `frontend_scope = false`, proceed silently without any design pipeline injection.

## Output Format

No user-visible output when `frontend_scope = false`. When `frontend_scope = true`, prints one confirmation line per loaded component:

```
frontend-design v1.2.0 loaded — aesthetic direction frameworks active.
```

## Design Pipeline

```
                  Frontend Dev Pipeline
  ┌─────────────────────────────────────────────────────┐
  │  write-spec / implement-tasks                        │
  │       |                                              │
  │  {{frontend-scope-detection}}                        │
  │       |                                              │
  │       +-- frontend_scope = false --> continue        │
  │       |                                              │
  │       +-- frontend_scope = true                      │
  │              |                                       │
  │              v                                       │
  │   [Gate: design-preview-approved.html exists?]       │
  │         |              |                             │
  │        YES             NO                            │
  │         |              v                             │
  │         |        ai-design-draft v1.1.0              │
  │         |        (ASCII wireframe -> HTML spec)      │
  │         |              |                             │
  │         |        ai-style-system v1.0.0              │
  │         |        (style archetype -> tokens)         │
  │         |              |                             │
  │         +──────────────+                             │
  │                  |                                   │
  │           frontend-design v1.2.0                     │
  │           (aesthetic direction active)               │
  │                  |                                   │
  │           implementation                             │
  │                  |                                   │
  │           design-iteration (review loop)             │
  │                  |                                   │
  │           ui-design-handoff -> ui-design-qa --mode verify       │
  └─────────────────────────────────────────────────────┘
```

## Detection Steps

Run each step in order. Stop and set `frontend_scope = true` at the first positive match. If no step matches, set `frontend_scope = false`.

**Step 1 — Project opt-out check:**
Read `.dev-os/config.yml`. If `frontend_design_skill: false` is set, set `frontend_scope = false` and stop — auto-injection is disabled for this project.
If `.dev-os/config.yml` does not exist, skip this step and proceed to step 2.

**Step 2 — Profile config check:**
Read the active profile's `profile-config.yml` (path: `profiles/<active-profile>/profile-config.yml`, where active profile comes from `.dev-os/config.yml` `profile:` key, defaulting to `general`).
If the config contains a `tech_stack.frontend` key (at any nesting level), set `frontend_scope = true` and stop.

**Step 3 — Task group name check (implement-tasks path only):**
Read the name of the current task group from `tasks.md`.
If the name contains any keyword from the UI keyword list (case-insensitive), set `frontend_scope = true` and stop.
Skip this step when called from write-spec (no current task group context).

**Step 4 — Spec content check:**
Read the Summary and Scope sections of `spec.md` (or `product/specs/[this-spec]/spec.md`).
If either section contains any keyword from the UI keyword list (case-insensitive), set `frontend_scope = true` and stop.

**Step 5 — Emotion-first / design system check:**
Check whether `planning/requirements.md` contains a `## Emotion-First Direction` section, OR whether `planning/design-system.md` exists.
If either is true, set `frontend_scope = true` and stop.

**Step 6 — Default:**
No signal matched. Set `frontend_scope = false`.

## UI Keyword List

```
ui, frontend, component, page, layout, design, style, css, tailwind, animation,
dashboard, landing, view, screen, modal, form, interface, web, react, vue,
svelte, next, nuxt, html, aesthetics, wireframe, design-draft, ascii-wireframe,
style-system, visual-spec, mockup, prototype
```

<!-- MAINTAINER NOTE: Keep this keyword list in sync with verify-spec check 6.
     Both use the same keyword set. If you add a keyword here, add it there too. -->

## Activation

**If `frontend_scope = true`:**

**Step 1 — Design artifact pre-flight:**

Check for an existing approved design spec:

- If `.dev-os/state/design-preview-approved.html` exists:
  Print: `Approved design spec found — skipping ai-design-draft.`
  Skip to Step 3.

- If `.dev-os/state/style-registry.json` does NOT exist AND no approved spec:
  Print:
  ```
  No approved design spec or style registry found.
  Run ai-design-draft to produce a layout-locked visual spec before implementation,
  or proceed without it.
  ```
  Ask: `Draft design spec now? (y/n)` — if yes, proceed to Step 2; if no, skip to Step 3.

- If approved spec exists but style-registry.json does NOT:
  Print: `No style registry found. Run ai-style-system to set aesthetic direction, or proceed without it.`
  Ask: `Set up style system now? (y/n)` — if yes, load ai-style-system in Step 2; if no, skip to Step 3.

**Step 2 — Load design pipeline precursors (if no approved spec):**

If no `design-preview-approved.html` exists and user chose to proceed:

Load and apply the `ai-design-draft` skill:
{{skills/ai-design-draft}}
Print: `ai-design-draft v1.1.0 loaded — ASCII wireframe pipeline active.`

If no `style-registry.json` exists and user chose to proceed:

Load and apply the `ai-style-system` skill:
{{skills/ai-style-system}}
Print: `ai-style-system v1.0.0 loaded — style registry active.`

**Step 3 — Load frontend-design:**

Load and apply the `frontend-design` skill:
{{skills/frontend-design}}
Print: `frontend-design v1.2.0 loaded — aesthetic direction frameworks active.`

**If `frontend_scope = false`:**

No output. Proceed silently with the calling workflow.
