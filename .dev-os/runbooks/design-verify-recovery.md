# Runbook: Design Verify Recovery

| Field | Value |
|-------|-------|
| Service | Design verification pipeline — `design-verify`, `design-qa` workflow, `design-handoff` workflow |
| Runbook type | Operational |
| Severity | P3 (blocks frontend slice completion but not production) |
| Owner team | DevOS operator |
| Last reviewed | 2026-04-05 |
| Automation status | Manual |

---

## 1. Trigger & Detection

**Trigger:** `design-verify` fails, exits with an error, or produces a FAIL score below threshold.

**Symptoms:**
- "No approved design artifact found" error on `design-verify` Step 1
- Playwright not found or not functional
- ImageMagick not available (scoring falls back to MANUAL REVIEW REQUIRED)
- FAIL score below threshold (default 95%) despite implementation looking correct

**Detection commands:**

```bash
# Check approved artifact exists at any canonical location
ls product/specs/*/design/design-preview-approved.html 2>/dev/null \
  || ls product/design/*/design-preview-approved.html 2>/dev/null \
  || ls .dev-os/state/design-preview-approved.html 2>/dev/null \
  || echo "NO APPROVED ARTIFACT FOUND"

# Check Playwright (canonical detection: playwright-cli > bunx > npx)
playwright-cli --version 2>/dev/null \
  || bunx playwright --version 2>/dev/null \
  || npx playwright --version 2>/dev/null \
  || echo "PLAYWRIGHT NOT FOUND"

# Check ImageMagick
magick --version 2>/dev/null || convert --version 2>/dev/null || echo "IMAGEMAGICK NOT FOUND"

# Check design-handoff.json age (stale if >30 days)
python3 -c "
import json, os, datetime
p = '.dev-os/state/design-handoff.json'
if os.path.exists(p):
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(p))
    age = (datetime.datetime.now() - mtime).days
    print(f'design-handoff.json age: {age} days')
else:
    print('design-handoff.json NOT FOUND')
" 2>/dev/null
```

---

## 2. Failure Scenario A — No approved design artifact

**Error message:**
```
✗ No approved design artifact found for spec '<spec-name>'.
```

**Cause:** `design-preview-approved.html` was never created. Either the design-handoff workflow was not completed, or the file was created with the wrong name (`design-preview.html` instead of `design-preview-approved.html`).

**Triage checklist:**
- [ ] Run the detection commands above to confirm absence
- [ ] Check whether `design-preview.html` (without `-approved`) exists in any of the canonical locations
- [ ] Check whether `design/export/handoff-to-dev-os.json` exists (Design OS export)
- [ ] Check whether the design-handoff workflow was skipped in this spec's delivery

**Recovery — path A (design-handoff workflow was run, file has wrong name):**

```bash
# Find the draft preview file
find . -name "design-preview.html" -not -path "*/node_modules/*" 2>/dev/null

# Copy to approved location (update spec name and path)
SPEC="<your-spec-name>"
mkdir -p "product/specs/${SPEC}/design/"
cp <found-path>/design-preview.html "product/specs/${SPEC}/design/design-preview-approved.html"
echo "Approved artifact written to: product/specs/${SPEC}/design/design-preview-approved.html"
```

**Recovery — path B (design-handoff was never completed):**

```
1. Run design-review to evaluate the design
2. If APPROVED or APPROVED WITH CONDITIONS → run the design-handoff workflow
3. After handoff Step 5 checklist passes, rename design-preview.html → design-preview-approved.html
4. Re-run design-verify
```

**Recovery — path C (Design OS handoff.json present but consume-design not run):**

```bash
# Design OS export exists — consume it
consume-design
# This writes .dev-os/state/design-preview-approved.html automatically
# Then re-run design-verify
```

---

## 3. Failure Scenario B — Playwright not found

**Error message:**
```
✗ Playwright is required for design-verify.
```

**Cause:** Playwright is not installed in this project.

**Triage checklist:**
- [ ] Confirm the project has a `package.json` (Playwright is an npm package)
- [ ] Check if the project uses bun, npm, or yarn

**Recovery:**

```bash
# Install Playwright (bun preferred; npx fallback)
bun add -D playwright 2>/dev/null || npm install -D playwright

# Install browser — use whichever runner is available
playwright-cli install-browser chromium 2>/dev/null \
  || bunx playwright install chromium 2>/dev/null \
  || npx playwright install chromium

# Verify
playwright-cli --version 2>/dev/null \
  || bunx playwright --version 2>/dev/null \
  || npx playwright --version
```

**Alternative — skip pixel-diff and use manual screenshot comparison:**
If Playwright cannot be installed, use `design-check` instead:

```bash
design-check --screenshot <path-to-screenshot> --spec <spec-name>
```

This provides a heuristic visual review without pixel-diff scoring.

---

## 4. Failure Scenario C — ImageMagick not available

**Symptom:** `design-verify` runs but outputs `MANUAL REVIEW REQUIRED` with no match score.

**Cause:** ImageMagick (`magick` or `convert` CLI) is not installed. Screenshots are captured but diff scoring is not possible.

**Recovery — install ImageMagick:**

```bash
# Ubuntu/Debian
sudo apt-get install -y imagemagick

# macOS
brew install imagemagick

# Verify
magick --version
```

**Alternative — proceed with manual review:**

If ImageMagick cannot be installed, compare the screenshots manually:
1. Open `product/design-verify/<spec>/approved/desktop.png` and `implementation/desktop.png` side by side
2. Note any visual differences
3. Classify each as regression or intentional
4. If no regressions found, override the MANUAL REVIEW status with a comment in the report:
   ```
   Manual review completed — no regressions found. Approved by: <reviewer> on <date>
   ```

---

## 5. Failure Scenario D — FAIL score below threshold

**Symptom:** `design-verify` runs successfully but reports FAIL with overall score <95% (or custom threshold).

**Cause:** Visual differences exist between the approved design and the implementation. May be regressions, intentional changes, or rendering environment differences.

**Triage checklist:**
- [ ] Open the diff screenshots in `product/design-verify/<spec>/` and compare approved vs implementation
- [ ] Check if the differences are font rendering (anti-aliasing artifacts) — these are false positives
- [ ] Check if the differences are intentional improvements that were not in the approved design
- [ ] Check if the differences are actual regressions (wrong colors, sizes, or layout)

**Recovery — font rendering false positives:**

```bash
# Raise the threshold slightly to account for rendering variance
design-verify --spec <spec> --url <url> --threshold 90
```

**Recovery — genuine regressions found:**

```
1. Identify which component/section has the regression (check diff screenshots)
2. Fix the implementation to match the approved design
3. Re-run design-verify
```

**Recovery — intentional improvements (not regressions):**

```
1. Update the approved design artifact to reflect the intentional improvement:
   - Re-run design-handoff workflow to regenerate design-preview.html
   - Rename to design-preview-approved.html at the canonical location
2. Re-run design-verify
```

---

## 6. Quick Reference

| Scenario | First command |
|----------|--------------|
| No approved artifact | `find . -name "design-preview*.html" 2>/dev/null` |
| Playwright missing | `bun add -D playwright && bunx playwright install chromium` |
| ImageMagick missing | `sudo apt-get install -y imagemagick` or `brew install imagemagick` |
| Score below threshold | Open `product/design-verify/<spec>/` and compare screenshots manually |
| Not sure | Run detection commands from Section 1 |

---

## 7. Prevention

- Always complete the `design-handoff` workflow before running `design-verify` (Step 5 checklist enforces this)
- Ensure `design-preview-approved.html` is written at the end of `design-handoff` (Step 5 checklist item)
- Install Playwright in any project that uses frontend-design or design-iteration (`bun add -D playwright`)
- Install ImageMagick on the development machine (one-time setup)
- Run `design-check` first as a fast heuristic pass before the full `design-verify` pixel-diff
