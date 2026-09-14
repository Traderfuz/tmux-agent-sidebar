# Service CTA Alignment Workflow

Maps a service slug and its core pain point to a complete AI-native CTA package — hero copy, mid-page copy, hero image, and problem stat — ready to wire into `ServicePageTemplate.astro`. Uses the Spec → Build → Validate → Release pattern. Eliminates ad-hoc per-service copy decisions by running every service through the same derivation logic.

## When to Use

Use when adding or updating CTA content on any `src/pages/services/<slug>.astro` page, or when aligning an existing service page to Boxi's AI-native brand posture ("score first, call second"). Run once per service slug.

**Anti-triggers:**
- Do NOT use for blog CTAs (use `BlogShareRow` + `LeadMagnetCallout` pattern instead)
- Do NOT use when the service page doesn't yet exist (create the page first, then run this)
- Do NOT use to change quiz logic or `/marketing-score` page content

## Process

### Step 1: Spec — Gather service inputs

Collect the four required inputs for this service:

| Input | Source | Example |
|---|---|---|
| `slug` | filename in `src/pages/services/` | `facebook-ads` |
| `service.name` | `services.json` → `name` field | `Facebook & Meta Ads` |
| `corePain` | The #1 reason contractors abandon this channel | `Leads don't pick up the phone` |
| `keyStatValue` | A specific number that names the pain | `78%` |
| `keyStatContext` | What that number means | `of jobs go to whoever responds first` |

Read `src/data/services.json` to get `name`. Read the existing page's `problem` prop for the core pain — it's already written there.

Display:
```
  [Step 1] Service inputs
  slug:          facebook-ads
  name:          Facebook & Meta Ads
  corePain:      Leads don't pick up the phone
  keyStat:       78% — of jobs go to whoever responds first
```

### Step 2: Build — Derive CTA package

Using the inputs from Step 1, produce all four CTA elements.

#### 2a. Hero heading (H1 fragment — HTML allowed for `<span>` accent)

Formula: **"[Provocative question or bold claim about the corePain]. [amber span: the fix]."**

Rules:
- Lead with what the prospect already feels or fears
- The amber span names what Boxi does differently
- Max 12 words before the span, 4–6 words in the span
- No passive voice, no "we", no agency jargon

Example output for `facebook-ads`:
```
heroHeading='You Got 50 Facebook Leads Last Month. <span class="text-[#E8A838]">Why Did Zero of Them Book a Job?</span>'
```

#### 2b. Hero CTA line (trust signal under the buttons)

Formula: **"90 seconds · No charge · No sales call · [social proof]"**

Always keep "90 seconds · No charge · No sales call" — these are non-negotiable AI-native signals. Add one service-specific social proof if available from `services.json` stats.

Example:
```
"90 seconds · No charge · No sales call · 4.9★ from 40+ clients"
```

#### 2c. Mid-page ServiceAICTA heading

Formula: **"See exactly where your [service name lowercase] is [pain verb]."**

Pain verb options (pick the most accurate):
- `leaking leads` — for ad/paid channels
- `losing rankings` — for SEO services
- `losing reviews` — for reputation
- `missing follow-ups` — for automation/AI services
- `underperforming` — generic fallback

Example:
```
heading="See exactly where your facebook & meta ads are leaking leads."
```

#### 2d. problemStat + problemStatLabel

Use `keyStatValue` as `problemStat`. Derive `problemStatLabel` from `keyStatContext` — expand it to a full insight sentence (max 12 words, no period).

Example:
```
problemStat="78%"
problemStatLabel="of jobs go to whoever responds first — most contractors call back hours later"
```

#### 2e. Hero image mapping

Check `public/images/heroes/` against this priority table:

| Service slug | Desktop hero | Mobile hero |
|---|---|---|
| `google-ppc` | `hero-homepage.png` | `mobile/hero-homepage-mobile.png` |
| `facebook-ads` | `hero-ai-marketing.png` | `mobile/hero-homepage-mobile.png` |
| `local-seo` | `hero-location.png` | `mobile/hero-homepage-mobile.png` |
| `reputation` | `hero-about.png` | `mobile/hero-about-mobile.png` |
| `social-media` | `hero-ai-marketing.png` | `mobile/hero-homepage-mobile.png` |
| `web-design` | `hero-blog-editorial.png` | `mobile/hero-homepage-mobile.png` |
| `web-cro` | `hero-blog-editorial.png` | `mobile/hero-homepage-mobile.png` |
| `ai-automation` | `hero-ai-receptionist.png` | `mobile/hero-homepage-mobile.png` |
| `ai-seo` | `hero-aeo.png` | `mobile/hero-aeo-mobile.png` |
| `database-reactivation` | `hero-ai-voice-agents.png` | `mobile/hero-homepage-mobile.png` |

If the slug is not in this table, pick the thematically closest image. Prefer images where the subject is in the right 30% of frame (right-third composition rule).

Display:
```
  [Step 2] CTA package derived
  heroImage:          /images/heroes/hero-ai-marketing.png
  heroImageMobile:    /images/heroes/mobile/hero-homepage-mobile.png
  problemStat:        78%
  problemStatLabel:   of jobs go to whoever responds first — most contractors call back hours later
  aiCTA heading:      See exactly where your facebook & meta ads are leaking leads.
```

### Step 3: Validate — Check output quality

Before writing to the file, verify each element passes its check:

| Check | Pass condition |
|---|---|
| heroHeading has `<span class="text-[#E8A838]">` | Yes — amber accent required |
| heroHeading ≤ 18 words total | Count words excluding HTML tags |
| heroImage file exists on disk | `ls public/images/heroes/<filename>` exits 0 |
| heroImageMobile file exists on disk | `ls public/images/heroes/<filename>` exits 0 |
| problemStat is a number, percentage, or time value | Must be specific — no vague words |
| problemStatLabel ≤ 14 words | Count words |
| ServiceAICTA heading ends with `.` | Sentence, not fragment |
| No "Book a call" / "Schedule" / "Demo" language | AI-native posture: score-first |

Display:
```
  [Step 3] Validation
  heroHeading:        ✓ has amber span, 14 words
  heroImage:          ✓ file exists
  heroImageMobile:    ✓ file exists
  problemStat:        ✓ "78%" — specific value
  problemStatLabel:   ✓ 12 words
  aiCTA heading:      ✓ ends with period, no call language
  Posture check:      ✓ no "book a call" found
```

If any check fails, return to Step 2 and revise before continuing.

### Step 4: Release — Write to service page

Update `src/pages/services/<slug>.astro` with the derived CTA package. The page is a thin wrapper — only the `ServicePageTemplate` props change.

Props to add/update on `<ServicePageTemplate>`:

```astro
heroImage="/images/heroes/<desktop-hero>"
heroImageMobile="/images/heroes/<mobile-hero>"
problemStat="<keyStatValue>"
problemStatLabel="<keyStatContext expanded>"
```

The `heroHeading` prop is already set per-page — update it only if the current copy violates the AI-native formula (check: does it lead with prospect pain? does it have an amber span?).

The `ServiceAICTA` heading/subheading are derived from `service.name` in the template dynamically — no prop needed unless you want a custom override (use `heading` prop on `<ServiceAICTA>` if custom copy is required).

After writing, run:

```bash
bun run build 2>&1 | tail -5
```

Confirm `[build] Complete!` with no errors.

Display:
```
  [Step 4] Released
  File updated:   src/pages/services/facebook-ads.astro
  Props added:    heroImage, heroImageMobile, problemStat, problemStatLabel
  Build:          ✓ Complete
```

## Display Format

Full session output for one service:

```
Service CTA Alignment — facebook-ads
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Step 1] Service inputs
  slug:          facebook-ads
  name:          Facebook & Meta Ads
  corePain:      Leads don't pick up the phone
  keyStat:       78% — of jobs go to whoever responds first

[Step 2] CTA package derived
  heroImage:          /images/heroes/hero-ai-marketing.png
  heroImageMobile:    /images/heroes/mobile/hero-homepage-mobile.png
  problemStat:        78%
  problemStatLabel:   of jobs go to whoever responds first — most contractors call back hours later
  aiCTA heading:      See exactly where your facebook & meta ads are leaking leads.

[Step 3] Validation
  heroHeading:        ✓ has amber span, 14 words
  heroImage:          ✓ file exists
  heroImageMobile:    ✓ file exists
  problemStat:        ✓ "78%" — specific value
  problemStatLabel:   ✓ 12 words
  aiCTA heading:      ✓ ends with period, no call language
  Posture check:      ✓ no "book a call" found

[Step 4] Released
  File updated:   src/pages/services/facebook-ads.astro
  Props added:    heroImage, heroImageMobile, problemStat, problemStatLabel
  Build:          ✓ Complete

Done. Next: run this workflow for the next service slug.
```

## Differences from ad-hoc CTA writing

| Dimension | Ad-hoc | This workflow |
|---|---|---|
| Copy source | Written from scratch each time | Derived from `services.json` + corePain formula |
| Image selection | Manual lookup | Priority table in Step 2e |
| Brand posture check | Not checked | Step 3 validates "no call language" |
| Build verification | Often skipped | Step 4 requires `[build] Complete!` |
| Repeatability | None | Same 4 steps for all 10 service pages |

## Notes

- Run this workflow once per service slug. 10 services = 10 runs.
- The hero image priority table in Step 2e is the canonical mapping. Update it here when new hero images are generated.
- `ServiceAICTA` heading/subheading derive from `service.name` automatically via the template — only override via prop if the auto-derived copy is wrong for a specific service.
- The workflow does NOT generate new hero images. If no thematic match exists in the table, use `hero-blog-editorial.png` as fallback and file a separate image generation task.

## Failure handling

| Issue | Resolution |
|---|---|
| `heroImage` file missing | Use `hero-blog-editorial.png` fallback. File image generation task separately. |
| `heroHeading` exceeds 18 words | Cut the preamble — lead directly with the pain. Remove filler clauses. |
| Build fails after update | Read the error. Most common: unclosed JSX attribute, missing prop type. Fix and re-run. |
| Service not in `services.json` | Stop. The service page shouldn't exist without a `services.json` entry. Fix data first. |
| `problemStat` is vague (e.g. "Many") | Find the specific number from the FAQ section of the same page — it's usually there. |
