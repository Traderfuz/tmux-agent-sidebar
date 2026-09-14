# Open Artifact For Review

Shared preview/open micro-workflow that turns a durable artifact into a reviewable `preview_open_path`. It is the `draft` → `preview-ready` step of the client artifact review gate and the operational side of the standard's preview/open contract.

## When to Use

Use whenever a gated client-facing or operator-facing artifact needs a concrete, openable preview before review — HTML, image, PDF, rendered API preview, local file, or an authenticated external URL.

- Use as step 2 of `workflows/_shared/quality/client-artifact-review-gate.md`.
- Use standalone when a reviewer only needs to see the artifact, not yet approve it.

**Do not use** to approve or deliver anything — opening an artifact is evidence of reviewability, not approval. Never treat a successful open as a pass; approval is a separate state transition. Do not use for scratch outputs with no delivery claim.

## When to Include

```markdown
{{include workflows/_shared/quality/open-artifact-for-review}}
```

Viewer selection by artifact type follows the `.dev-os/standards/global/open-artifact-viewer.md` standard.

## Gate Checklist

### 1. Determine the artifact type and viewer

- [ ] Identify the artifact type (HTML, image, PDF, markdown, JSON, rendered preview, external URL).
- [ ] Select the open path per `open-artifact-viewer.md`: platform default viewer, browser, image/PDF viewer, browser-CDP for authenticated URLs, or an API-rendered preview saved to disk.

**Gate:** If no viewer can open the artifact type → STOP; the artifact is not reviewable until a preview can be produced.

### 2. Open and confirm the preview is real

- [ ] Open the artifact through the selected path.
- [ ] Confirm the preview is non-empty and renders (not a blank page, broken link, or zero-byte file).

**Gate:** If the preview is empty, errors, or fails to render → STOP; fix the artifact or its export before recording a preview path.

### 3. Record the preview_open_path

- [ ] Write the exact `preview_open_path` (file path or URL) into the artifact's review record.
- [ ] Advance the review record state to `preview-ready`.

**Gate:** `preview_open_path` must be exact and re-openable by another reviewer. A path only you can open does not satisfy the contract.

## Output

```
Artifact:          <artifact_id>
Type:              html | image | pdf | markdown | json | rendered | url
preview_open_path: <path-or-url>
State:             preview-ready   (reviewability only — NOT approval)
```

## Error Handling

| Scenario | Action |
|----------|--------|
| No viewer for the artifact type | Stop. Produce a rendered preview to disk first, then open that. |
| Preview opens empty/blank | Stop. Re-export the artifact; do not record a preview path. |
| Authenticated URL will not load | Stop. Use browser-CDP with the required session; do not record an unreachable URL. |
| Path only openable locally | Stop. Save a shareable/re-openable preview and record that path. |

## Usage in Workflows

Called by `client-artifact-review-gate.md` (step 2) and by any handoff/export surface that must present an artifact for human review before delivery.

## Project-Specific Configuration

- **Viewer commands** — per OS/platform; see `open-artifact-viewer.md`.
- **Preview storage** — where rendered previews are saved (`product/reviews/`, `creative/reviews/`, etc.).
- **Auth handling** — which artifacts require browser-CDP with a live session.
