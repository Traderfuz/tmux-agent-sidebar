# Icon and Graphic Generation

Generate a consistent set of icons, hero images, illustrations, and logo variants that match the project's brand identity. Uses the `production_injection` string from `style-tokens.json` as the visual anchor for every generation prompt, ensuring all assets share the same aesthetic even when produced by different tools.

## When to Use

- A project needs UI icons, hero images, or illustrations that match its brand
- After running `ai-style-system` and establishing the visual identity
- When building a landing page or marketing site that needs custom graphics
- When the existing icon set needs expansion with brand-consistent additions
- When converting raster assets (PNG logos) to scalable SVG format

**Do NOT use when:** The project uses a third-party icon library (e.g., Lucide, Heroicons) and doesn't need custom icons. Do not use when no `style-tokens.json` exists — run `ai-style-system` first to establish the brand. Do not use for UI component building (use `ui-creator` or `new-project-ui`).

## Process

### Step 1: Get the production injection string

Read the archetype's production injection from `style-tokens.json`. This string is appended to every image generation prompt to maintain visual coherence.

- **Read from:** `creative/style-system/{client}/style-tokens.json` — the `production_injection` field
- **Or read from:** `creative/style-system/{client}/production-injection.txt` — ready-to-paste version
- **If neither exists:** Run `ai-style-system` first to generate the tokens

```
Display:
  Production injection loaded
  Source: creative/style-system/acme/style-tokens.json
  Archetype: Soft Gradient Premium
  Injection string: "soft gradient tones, premium feel, rounded forms, warm neutrals..."
```

### Step 2: Generate SVG icons

Run `replicate: generate_svg_recraft` for each icon needed.

- **Prompt pattern:** `"minimalist {icon-name} icon, clean line art, 1.5px stroke, {color} on transparent background, 24x24 grid"` + production_injection
- **Output:** SVG files (embed directly in React components)
- **Batch:** Generate all needed icons in sequence, using consistent prompt structure

Icon prompt patterns by type:
- **UI icons (line):** `"minimalist {name} icon, clean line art, 1.5px stroke, {color} on transparent background, 24x24 grid"`
- **App icon / logo mark:** `"logo mark for {product}, {shape metaphor}, bold geometric, {palette colors}, no text"`
- **Illustration:** `"editorial illustration of {concept}, flat design, {palette colors}, minimal detail"`

```
Display:
  Icons generated: 8 SVGs
    ✓ nav-home.svg (24x24, line style)
    ✓ nav-settings.svg (24x24, line style)
    ✓ nav-profile.svg (24x24, line style)
    ✓ action-save.svg (24x24, line style)
    ✓ action-delete.svg (24x24, line style)
    ✓ status-success.svg (24x24, line style)
    ✓ status-error.svg (24x24, line style)
    ✓ status-loading.svg (24x24, line style)
```

### Step 3: Generate hero and section images

Run `nano-banana: generate_image` for hero images, section backgrounds, and feature illustrations.

- **Prompt pattern:** `"hero image for {product}, {visual metaphor}"` + production_injection
- **Output:** PNG/JPG files
- **Sizes:** Generate at 2x resolution for retina displays

```
Display:
  Images generated: 3
    ✓ hero-main.png (2880x1600, hero section)
    ✓ feature-dashboard.png (1440x800, feature section)
    ✓ feature-analytics.png (1440x800, feature section)
```

### Step 4: Vectorize raster assets (if needed)

If the project has a raster logo (PNG/JPG) that needs to be SVG, run `replicate: vectorize_recraft`.

- **Input:** Existing PNG/JPG logo file
- **Output:** Clean SVG with preserved detail
- **Skip if:** Logo is already SVG or no logo exists yet

```
Display:
  Vectorization: 1 asset
    ✓ logo.png → logo.svg (clean vector, 4 paths)
```

### Step 5: Generate logo variations

Run `nano-banana: generate_logo_variations` to create the full logo system.

- **Input:** Base logo + brand palette from style-tokens.json
- **Output:** 3-4 logo variants covering common use cases
- **Variants:** full-dark, full-light, icon-only-dark, icon-only-light

```
Display:
  Logo variations: 4
    ✓ logo-full-dark.svg (dark background variant)
    ✓ logo-full-light.svg (light background variant)
    ✓ logo-icon-dark.svg (icon only, dark)
    ✓ logo-icon-light.svg (icon only, light)
```

### Step 6: Verify visual coherence

Review all generated assets together to confirm they share a consistent visual language.

- **Check:** Do all icons use the same stroke weight and style?
- **Check:** Do hero images share the same color temperature and mood?
- **Check:** Do logo variants work on both light and dark backgrounds?
- **Check:** Does every asset feel like it belongs to the same brand?

If any asset feels off, regenerate with a more specific prompt. The production_injection string should handle most consistency issues, but individual assets may need per-item prompt tuning.

```
Display:
  Coherence check
  Icons: 8/8 consistent (same stroke weight, same palette) ✓
  Images: 3/3 consistent (same color temperature, same style) ✓
  Logos: 4/4 consistent (readable on target backgrounds) ✓
  Status: PASS — asset set is brand-aligned
```

## Notes

- **Always append `production_injection`** to every generation prompt. This is the single mechanism that keeps all assets visually coherent. Without it, each tool generates in its own default style.
- Generate icons at 24x24 grid for UI consistency. Use 48x48 or 64x64 for larger display contexts.
- Generate hero images at 2x resolution (2880px wide) so they look sharp on retina displays.
- SVG icons from `generate_svg_recraft` can be embedded directly in React with `dangerouslySetInnerHTML` or imported as React components via SVGR.
- If an icon set needs more than 20 icons, consider using a consistent third-party set (Lucide, Heroicons) for the base and generating only custom icons for brand-specific concepts.
- Store all generated assets in `creative/assets/{client}/` or the project's `public/` directory.

## Display Format

```
Icon & Graphic Generation — [project/client]
  Archetype: [name]
  Icons: [N] SVGs generated
  Images: [N] hero/section images
  Logo variants: [N]
  Coherence: [PASS | NEEDS REGEN — N assets off-brand]
```
