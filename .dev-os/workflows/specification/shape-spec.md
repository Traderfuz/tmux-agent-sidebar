# Shape Specification Workflow

Gather requirements and, for eligible specs, capture emotional direction with a visual design preview.

## When to Use

Run this workflow at the start of any new spec to gather requirements, confirm scope, and optionally capture visual direction before writing the formal spec.

Do not use this workflow on specs that already have a complete `spec.md` — use `write-spec` to update an existing specification instead.

## Step 0: Determine Spec Directory Name

Before collecting requirements, resolve `[this-spec]`:

1. Get today's date: `date +%Y-%m-%d`
2. Ask for (or infer from context) a short feature name and convert to a kebab-case slug.
3. Set `[this-spec]` = `YYYY-MM-DD-<slug>` (e.g. `2026-03-15-auth-login-gap-closure`).
4. If `--spec <name>` was passed: check whether `<name>` already starts with `\d{4}-\d{2}-\d{2}-`. If yes, use as-is. If no, prepend today's date.
5. If `product/specs/<slug>` exists without a date prefix from a previous run, rename it to `product/specs/YYYY-MM-DD-<slug>` and report the rename to the user.

## Step 1: Functional Requirements (All Specs)

Collect the following from the user or source material:

1. **Problem statement** — What problem does this solve?
2. **Goals** — What are the desired outcomes (3-5 goals)?
3. **Non-goals** — What is explicitly out of scope?
4. **Primary users** — Who benefits from this?
5. **Functional requirements** — What must the system do?
6. **Acceptance criteria** — How do we know it's done?
7. **Constraints** — Technical, timeline, or resource limitations?

Write output to `product/specs/[this-spec]/planning/requirements.md`.
## Contract impact final handoff

Before handing requirements and architecture to `write-spec`, call the shared
`contract_impact_preflight` port in `plan` mode with the owner artifact and
canonical implementation target. Reuse only a fresh target-matched record.
Ambiguous targets, missing required classes, stale evidence, invalid records,
and failed required adapters block. A complete evidenced not-applicable result
passes without creating a ledger.

Persist only record ID/path/revision/fingerprint and open-blocker references
in the requirements and architecture handoff. Do not duplicate policy or
mutate records manually. An injected handoff failure preserves the prior
record/audit and cannot advance downstream revision claims.


## Step 1b: Process Friction Probe (Conditional)

Run this probe **only if** the spec touches an existing user-facing flow. Detect by checking whether the functional requirements or problem statement reference any of these keywords: `existing`, `current`, `update`, `improve`, `fix`, `extend`, `onboarding`, `checkout`, `settings`, `dashboard`, `invite`, `billing`, `notification`, `search`, `filter`, or any named feature that already exists in the product.

**Skip this step if:**
- The spec is a net-new feature with no overlap with existing flows
- `--skip-friction` flag is passed
- The spec is infrastructure, internal tooling, or a patch

**If triggered**, ask the user these 3 questions:

1. **What are the steps in the current flow this spec touches?** (Walk me through what a user does today)
2. **Where do users currently get stuck, slow down, or abandon?** (Known friction points, workarounds, complaints)
3. **What manual steps exist today that this spec could eliminate?**

**On completion:** Append findings as a `## Current Flow Friction` section in `planning/requirements.md`. If the user has no data ("I don't know"), note that and proceed — do not block on it.

## Step 2: Eligibility Check

Determine whether this spec requires emotion-first capture. The spec is eligible if **any** of the following are true:

1. The spec targets UX, brand, marketing, onboarding, or user interaction.
2. The user explicitly requests product feel or identity direction.
3. The spec metadata includes `user-facing: true` or `branding-sensitive: true`.

The spec is **not eligible** (skip to Step 6) if:

1. It is infrastructure hardening, internal tooling, or runtime maintenance.
2. It is low-level refactoring with no user-visible changes.
3. The user explicitly indicates no branding direction is needed.

**If not eligible:** Skip Steps 3-5. Proceed directly to Step 6.

**If eligible:** Continue to Step 2b.

## Step 2b: Handoff Context Check (Eligible Specs Only)

Before prompting for emotion-first fields, check whether upstream OS handoff state files are present. These files are written by `consume-marketing` and `consume-creative`.

```python
import json, os

handoff_context = {}

marketing_path = ".dev-os/state/marketing-handoff.json"
creative_path  = ".dev-os/state/creative-handoff.json"

if os.path.exists(marketing_path):
    with open(marketing_path) as f:
        m = json.load(f)
    handoff_context["has_marketing"]   = True
    handoff_context["marketing_path"]  = m.get("handoff_path", marketing_path)
    handoff_context["marketing_source_root"] = m.get("source_root")
    counts = m.get("artifact_counts", {})
    handoff_context["has_brand_voice"] = counts.get("brand_voice", 0) > 0
    handoff_context["has_copy"]        = counts.get("copy", 0) > 0
    handoff_context["has_keywords"]    = counts.get("keywords", 0) > 0
else:
    handoff_context["has_marketing"] = False

if os.path.exists(creative_path):
    with open(creative_path) as f:
        c = json.load(f)
    handoff_context["has_creative"]      = True
    handoff_context["creative_path"]     = c.get("handoff_path", creative_path)
    handoff_context["creative_source_root"]  = c.get("source_root")
    counts = c.get("artifact_counts", {})
    handoff_context["has_brand_assets"]  = counts.get("brand_assets", 0) > 0
    handoff_context["has_heroes"]        = counts.get("heroes", 0) > 0
    handoff_context["usage_map_entries"] = c.get("usage_map_entries", 0)
else:
    handoff_context["has_creative"] = False

print(json.dumps(handoff_context, indent=2))
```

If **either** handoff is present, display a context notice before the emotion-first prompts. Show only the sections that are present:

```
Upstream handoff context detected:

  Marketing OS: [brand voice available] [copy available] [keywords available]
    → Reference marketing/copy/ for real headlines and CTAs
    → Reference marketing/brand-voice/ for tone guidance

  Creative OS: [brand assets available] [N hero images] [N usage map entries]
    → Reference creative/brand/ for approved colors, typography, and logos
    → Usage map assigns hero images to specific page sections

Use this context to inform your answers below.
```

Additional guidance based on what is present:
- If **brand assets** are present in the creative handoff: suggest referencing `creative/brand/` for the Visual Metaphor Anchor (Step 3, Field 5).
- If **copy artifacts** are present in the marketing handoff: suggest using real headlines from `marketing/copy/` for the First Impression Narrative (Step 3, Field 4).

If **no state files** are present: skip this step silently — no output, no error.

All emotion-first fields in Step 3 are still required. The context notice informs the answers; it does not replace them.

## Step 3: Emotion-First Capture (Eligible Specs Only)

Prompt the user for the following emotional direction fields. Append the answers to `planning/requirements.md` under a `## Emotion-First Direction` heading.

### Required Fields

1. **User Emotional Archetype**
   - Who is the target user emotionally? What state are they in when they arrive?
   - Example: "A founder who is overwhelmed by choices and wants to feel confident that this tool has their back."

2. **Desired Emotional Keywords**
   - 5-7 words that describe how the product should feel.
   - Example: "confident, calm, precise, trustworthy, effortless, premium, focused"

3. **What This Product Is Not**
   - Explicit anti-patterns. What feelings or aesthetics must be avoided?
   - Example: "Not playful. Not cluttered. Not generic SaaS. Not corporate. Not cheap."

4. **First Impression Narrative**
   - Describe the user's first 10 seconds with the product like a movie scene. Focus on the beginning.
   - Example: "A dark interface loads instantly. One clear headline. No noise. The user exhales — this already feels different."

5. **Visual Metaphor Anchor**
   - A single metaphor or reference that anchors the design direction.
   - Example: "A Japanese zen garden — minimal, intentional, every element placed with purpose."

### Guidance

- Push for specificity. Reject answers like "modern and clean" — those describe everything and nothing.
- Anti-patterns are as important as positive direction. If the user can't articulate what the product is NOT, the emotional direction isn't clear enough.
- The visual metaphor should be concrete enough to generate a design preview from.

## Step 3b: ASCII Wireframe Generation (Eligible Specs Only)

Before generating the visual design preview, lock the structural layout by producing ASCII wireframes. This step ensures section order and column layout are agreed upon before any visual styling decisions are made.

### Identify Pages

Scan `planning/requirements.md` for user-facing pages or sections listed in the functional requirements. Look for explicit page names (e.g., "landing page", "dashboard", "pricing page", "onboarding flow"). If no pages are explicitly listed, default to a single `landing` page.

### Generate Wireframes

For each identified page, generate one ASCII wireframe using 80-column box-drawing format:

- **Desktop layout**: 80 columns wide using `┌`, `┐`, `└`, `┘`, `─`, `│`, `├`, `┤`, `┬`, `┴`, `┼` characters
- **Mobile layout**: 40-column abbreviated version below the desktop, showing stacking behavior
- Label each section clearly: e.g., `[HERO]`, `[NAV]`, `[CTA]`, `[FEATURES]`, `[FOOTER]`
- Annotate column layout with ratios: e.g., `[LEFT 60%] | [RIGHT 40%]`
- Mark CTA hierarchy: `[CTA-PRIMARY]`, `[CTA-SECONDARY]`
- Mark heading levels: `[H1]`, `[H2]`, `[H3]`

Example format:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [NAV] Logo                                    Links          [CTA-PRIMARY]   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  [HERO]                                                                      │
│  [H1] Main headline here                                                     │
│  [H2] Supporting subheadline                                                 │
│  [CTA-PRIMARY] Get Started    [CTA-SECONDARY] Learn More                     │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ [FEATURES]  [LEFT 33%]  │  [CENTER 33%]  │  [RIGHT 33%]                     │
│  [H3] Feature           │  [H3] Feature   │  [H3] Feature                   │
│  Description text        │  Description    │  Description                    │
├──────────────────────────────────────────────────────────────────────────────┤
│ [FOOTER]  Links                                         Legal               │
└──────────────────────────────────────────────────────────────────────────────┘

── Mobile (40 col) ──────────────────────
┌────────────────────────────────────────┐
│ [NAV] Logo           ☰                │
├────────────────────────────────────────┤
│ [HERO]                                 │
│ [H1] Main headline                     │
│ [CTA-PRIMARY] Get Started              │
├────────────────────────────────────────┤
│ [FEATURES - stacked]                   │
│ [H3] Feature 1                         │
│ [H3] Feature 2                         │
│ [H3] Feature 3                         │
├────────────────────────────────────────┤
│ [FOOTER]                               │
└────────────────────────────────────────┘
```

### Write Wireframe Files

Write each wireframe to:

```
product/specs/[this-spec]/planning/wireframes/<page>.txt
```

For example: `planning/wireframes/landing.txt`, `planning/wireframes/pricing.txt`.

Create the `wireframes/` directory if it does not exist.

### Approval Gate

Present each wireframe to the user and ask for explicit approval before proceeding to Step 4:

```
ASCII wireframe generated for: <page>

[wireframe content displayed here]

Options:
  1. Approve — lock this layout and proceed
  2. Revise — describe what should change (regenerate wireframe)
  3. Skip — proceed without locking this page layout
```

Do NOT proceed to Step 4 until the user approves or skips **all** wireframes. If the user requests revisions, regenerate the wireframe and ask again before proceeding.

If the user revises: regenerate the full wireframe incorporating their feedback, write the updated file, and re-present the approval gate.

## Step 4: Design Preview Generation (Eligible Specs Only)

After capturing emotional direction and locking wireframe layouts, generate a visual design preview for the user to review before proceeding.

**Note:** The HTML structure in the design preview must follow the approved wireframe(s):
- Section order matches wireframe top-to-bottom
- Column layouts match wireframe column annotations
- Element hierarchy (CTA levels, heading levels) matches wireframe labels
- Mobile stacking matches the mobile wireframe layout

### Determine Format

- **Web profiles (webapp, business, pwa):** Generate `planning/design-preview.html` — a self-contained HTML file using Tailwind CSS CDN.
- **CLI profiles:** Ask the user which format they prefer:
  - `planning/design-preview.html` — HTML/Tailwind rendering of terminal aesthetic
  - `planning/design-preview.txt` — ASCII art representation

### Preview Content Requirements

The design preview must include all of the following sections:

1. **Color Palette**
   - Semantic color names with hex values: primary, secondary, accent, surface, text, error, success, warning
   - Show color swatches with labels
   - Show example foreground/background combinations

2. **Typography Scale**
   - Font family (or families: heading, body, mono)
   - Size scale (xs through 3xl) with rendered examples
   - Font weights used (regular, medium, semibold, bold)
   - Line height conventions

3. **Spacing & Rhythm**
   - Spacing scale (4px base or similar)
   - Show spacing applied to sample elements

4. **Border Radius & Shadows**
   - Border radius tokens (none, sm, md, lg, full)
   - Shadow tokens (sm, md, lg) with examples

5. **Sample Components (2-3)**
   - For web: button (primary + secondary), card, input field
   - For CLI: output block, status message, error display
   - Each component shown in default, hover/active, and disabled states where applicable

6. **Anti-Pattern Examples**
   - Show 1-2 examples of what the design explicitly avoids
   - Label them clearly as "NOT THIS"

7. **Visual Metaphor Rendering**
   - A hero section or mood board element that embodies the visual metaphor anchor

### HTML Preview Template

For HTML previews, use this structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Design Preview: [spec-name]</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script>
    tailwind.config = {
      theme: {
        extend: {
          colors: {
            /* Design system colors here */
          }
        }
      }
    }
  </script>
</head>
<body>
  <!-- Color Palette Section -->
  <!-- Typography Section -->
  <!-- Spacing Section -->
  <!-- Component Samples Section -->
  <!-- Anti-Patterns Section -->
  <!-- Visual Metaphor Section -->
</body>
</html>
```

The HTML must be fully self-contained — no external dependencies beyond the Tailwind CDN.

## Step 5: Approval Gate and Design System Persistence (Eligible Specs Only)

### Approval Gate

Present the design preview to the user and ask for explicit approval:

```
The design preview has been generated at:
  product/specs/[this-spec]/planning/design-preview.html

Open this file in your browser to review the visual direction.

Options:
  1. Approve — save as design system and proceed to write-spec
  2. Revise — describe what should change (regenerate preview)
  3. Restart — re-capture emotional direction from scratch
```

Do NOT proceed to write-spec until the user approves. If the user requests revisions, update the preview and ask again.

### Design System Persistence

On approval, create `planning/design-system.md` by extracting the design tokens from the approved preview:

```markdown
# Design System: [spec-name]

Generated from emotion-first design preview.
Approved: [date]

## Source Direction

- **Emotional Keywords:** [from Step 3]
- **Visual Metaphor:** [from Step 3]
- **Anti-Patterns:** [from Step 3]

## Color Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| primary | #XXXXXX | Primary actions, key UI elements |
| secondary | #XXXXXX | Secondary actions, supporting elements |
| accent | #XXXXXX | Highlights, badges, emphasis |
| surface | #XXXXXX | Card backgrounds, containers |
| background | #XXXXXX | Page background |
| text | #XXXXXX | Primary text |
| text-muted | #XXXXXX | Secondary text, placeholders |
| error | #XXXXXX | Error states, destructive actions |
| success | #XXXXXX | Success states, confirmations |
| warning | #XXXXXX | Warning states, caution |

## Typography Tokens

| Token | Value |
|-------|-------|
| font-heading | [font family] |
| font-body | [font family] |
| font-mono | [font family] |
| text-xs | [size] |
| text-sm | [size] |
| text-base | [size] |
| text-lg | [size] |
| text-xl | [size] |
| text-2xl | [size] |
| text-3xl | [size] |
| font-weight-normal | 400 |
| font-weight-medium | 500 |
| font-weight-semibold | 600 |
| font-weight-bold | 700 |
| line-height-tight | 1.25 |
| line-height-normal | 1.5 |
| line-height-relaxed | 1.75 |

## Spacing Scale

| Token | Value |
|-------|-------|
| space-1 | 0.25rem (4px) |
| space-2 | 0.5rem (8px) |
| space-3 | 0.75rem (12px) |
| space-4 | 1rem (16px) |
| space-6 | 1.5rem (24px) |
| space-8 | 2rem (32px) |
| space-12 | 3rem (48px) |
| space-16 | 4rem (64px) |

## Border & Shadow Tokens

| Token | Value |
|-------|-------|
| radius-none | 0 |
| radius-sm | 0.25rem |
| radius-md | 0.5rem |
| radius-lg | 1rem |
| radius-full | 9999px |
| shadow-sm | [value] |
| shadow-md | [value] |
| shadow-lg | [value] |

## Component Patterns

### Buttons
- Primary: [description of appearance, states]
- Secondary: [description of appearance, states]
- Destructive: [description of appearance, states]

### Cards
- [description of card style, padding, borders, shadows]

### Inputs
- [description of input style, focus states, error states]

## Anti-Patterns

Things this design system explicitly avoids:

1. [anti-pattern with brief description of why]
2. [anti-pattern with brief description of why]
3. [anti-pattern with brief description of why]
```

Also optionally save the approved preview HTML as `planning/design-system.html` for rendered reference.

## Step 6: Output Summary

Confirm completion to the user with the list of artifacts created:

**For all specs:**
- `product/specs/[this-spec]/planning/requirements.md`

**For eligible specs (additional):**
- `product/specs/[this-spec]/planning/wireframes/<page>.txt` (one per page)
- `product/specs/[this-spec]/planning/design-preview.html`
- `product/specs/[this-spec]/planning/design-system.md`
- `product/specs/[this-spec]/planning/design-system.html` (optional)

## Metadata Convention

Specs that are eligible for emotion-first capture should include one of these markers in the spec frontmatter or requirements:

```yaml
user-facing: true
```

or

```yaml
branding-sensitive: true
```

When neither marker is present, eligibility is determined by keyword detection (see Step 2). Specs matching UX/brand/marketing/onboarding keywords are treated as eligible. Infrastructure, refactoring, and internal tooling specs are not.

## Display Format

```
Spec shaped: product/specs/[YYYY-MM-DD-spec-name]/
  spec.md:          [created | updated]
  Design preview:   [attached | skipped]
  Next: write-spec --spec [spec-name]
```
