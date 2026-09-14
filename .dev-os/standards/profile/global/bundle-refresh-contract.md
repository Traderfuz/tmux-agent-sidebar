<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/bundle-refresh-contract.md and re-run profile-sync. -->
# Bundle Refresh Contract Standard

**Standard ID:** `bundle-refresh-contract`
**Scope:** General (inherited by all profiles)
**Applies to:** Any DevOS subsystem that maps between bundle manifests, bundle JSON definitions, and knowledge-pull artifacts under `docs/references/`

---

## Overview

Bundle refresh reads documentation from `docs/references/`, compresses it, and stores it in `~/.dev-os/bundles/<tier>/<name>@<version>.json` so agents can load library context without re-fetching. This contract defines the naming and resolution rules that connect three independent naming layers — bundle name, library identifier, and knowledge-pull artifact slug — so bundle refresh succeeds without per-bundle manual wiring.

**The principle:** Every bundle definition MUST declare a `reference_slug` that points at the on-disk knowledge-pull artifact. Implicit name matching is fragile and produces silent stale-bundle drift.

---

## Scope

This standard covers:

- Bundle JSON schema (`name`, `library_id`, `version`, `tier`, `reference_slug`)
- Bundle manifest schema (`~/.dev-os/bundles/bundle-manifest.json`)
- `_artifact_path` resolution in `bundle_refresh_generator.py` (and any future equivalent)
- Knowledge-pull artifact naming (`docs/references/<slug>.md`)

It does NOT cover:

- Knowledge-pull artifact *content* structure (see `knowledge-pull` standard)
- Bundle *compression* or *storage* (see `bundle_author.py` internals)
- Manifest *staleness* detection (separate signal in `daily-start`)

---

## Principles

### 1. Explicit over implicit

When three layers (bundle name, library identifier, artifact slug) can have three different values, the relationship between them MUST be declared explicitly on the bundle. The fallback chain (last-path-segment, prefix-match, fuzzy) is too fragile for production refresh at scale.

### 2. The slug is the knowledge-pull artifact stem

`docs/references/<slug>.md` is the file written by `knowledge-pull`. The slug is whatever short, human-friendly name the operator passed to `knowledge-pull` (e.g. `prisma`, `ai-sdk`, `stripe`). The bundle's `reference_slug` field MUST equal this slug stem — without the `.md` extension.

### 3. Bundle name is for agents, slug is for the filesystem

Bundle `name` is a descriptive identifier chosen for agent context (e.g. `vercel-ai`, `replicate-rest-api`). It is the natural key in `bundles/`. The `reference_slug` is the filesystem stem of the knowledge-pull artifact. They MAY differ; when they do, both MUST be present and correct.

### 4. Silent stale bundles are a correctness regression

A bundle that fails to refresh but stays in the manifest is worse than one that errors loudly — agents serve months-old `compressed_docs` from the manifest cache without knowing it. Every bundle MUST either refresh successfully or be removed from the manifest within one refresh cycle.

---

## Rules

### Rule 1 — Bundle JSON MUST declare `reference_slug`

**MUST** include `reference_slug` on every bundle JSON when it differs from `name`. When `name == reference_slug`, the field MAY be omitted for terseness, but SHOULD be declared for explicitness.

```json
{
  "name": "vercel-ai",
  "library_id": "github:vercel/ai",
  "reference_slug": "ai-sdk",
  "version": "latest",
  "tier": "tier1_core"
}
```

### Rule 2 — `_artifact_path` MUST consult `reference_slug` first

**MUST** resolve candidate paths in this order:

1. `<docs_dir>/<reference_slug>@<version>.md`
2. `<docs_dir>/<reference_slug>-<version>.md`
3. `<docs_dir>/<reference_slug>.md`
4. `<docs_dir>/<name>@<version>.md`
5. `<docs_dir>/<name>.md`

The first existing file wins. If none exist, the function MUST raise `FileNotFoundError` listing all five candidates so the operator can see which names were tried.

**MUST NOT** rely on substring/prefix matching, path-segment extraction from `library_id`, or any other heuristic. The `reference_slug` is the only allowed alias.

### Rule 3 — Manifest entries MUST NOT outlive their JSON

**MUST** regenerate bundle JSON whenever `reference_slug` changes. A bundle whose JSON is removed but whose manifest entry remains will fail to refresh on every cycle.

**MUST** prune manifest entries whose underlying JSON no longer exists. Run `bundle-refresh --status` and `detect.py --prune-orphans` periodically.

### Rule 4 — `library_id` is informational, never a filesystem key

**MUST NOT** use `library_id` for artifact lookup. The `library_id` field exists for cross-system correlation (matching bundle to upstream library metadata); it is NOT a filename stem.

`library_id` formats observed in the wild:

- `github:owner/repo` — GitHub repository
- `owner/repo` — bare repository path
- `/websites/<domain>` — Context7 website ref
- `/github/<owner>_<repo>` — Context7 GitHub ref
- `<vendor>/<api>` — vendor-specific (e.g. `replicate/rest-api`)

None of these formats produce a usable filename stem without manual transformation, so they MUST NOT be used as such.

### Rule 5 — Knowledge-pull artifact filename MUST equal `<reference_slug>.md`

When an operator runs `knowledge-pull <slug>`, the artifact is written to `docs/references/<slug>.md`. The slug they pass MUST equal the `reference_slug` of every bundle that consumes it. If multiple bundles need the same artifact, list the same `reference_slug` on all of them.

---

## When This Standard Applies

Apply this contract whenever:

- Adding a new bundle to the bundle manifest
- Migrating an old bundle to the new schema
- Debugging a stale-bundle failure (`FileNotFoundError: knowledge-pull artifact not found`)
- Refreshing bundles via `bundle-refresh.sh --all`
- Reviewing bundle definitions for compliance

---

## Compliance test

- [ ] Every bundle JSON under `~/.dev-os/bundles/<tier>/*.json` contains `reference_slug`, OR `name` exactly matches the corresponding knowledge-pull artifact stem
- [ ] `bundle_refresh_generator.py::_artifact_path` raises `FileNotFoundError` with all five candidate paths listed when none resolve
- [ ] No bundle `library_id` value is used as a filesystem path by `_artifact_path`
- [ ] After running `bundle-refresh --all --inline`, the manifest's `last_refreshed` field for each refreshed bundle is within the last 24 hours
- [ ] No bundle in the manifest has a missing or unreadable underlying JSON file

Verify with:

```bash
# bundles missing reference_slug where name != slug
python3 -c "
import json, glob
missing = []
for f in glob.glob(os.path.expanduser('~/.dev-os/bundles/*/*.json')):
    b = json.load(open(f))
    if not b.get('reference_slug') and b['name'] != b.get('library_id', '').split('/')[-1].split(':')[-1]:
        missing.append((b['name'], b.get('library_id')))
print(f'bundles missing reference_slug: {len(missing)}')
for n, lib in missing[:5]: print(f'  {n} (library_id={lib})')
"
```

---

## Anti-patterns

### Anti-pattern A — Heuristic slug derivation

```python
# WRONG: derive slug from library_id via string manipulation
slug = library_id.split('/')[-1].split(':')[-1]  # produces "ai" not "ai-sdk"
```

**Why it's wrong:** `library_id` formats are inconsistent (slash-separated paths, colon-separated URIs, Context7's underscore-separated form). The last path segment is not guaranteed to match the operator's `knowledge-pull` slug. This silently fails for any bundle where the slug is a product/feature name rather than a vendor name.

### Anti-pattern B — Implicit name == slug assumption

```python
# WRONG: assume bundle name and reference slug are always equal
candidates = [f"{name}@{version}.md", f"{name}.md"]
```

**Why it's wrong:** This assumption breaks the moment a bundle is named descriptively (`vercel-ai`) instead of by its product slug (`ai-sdk`). Of 77 bundles inspected, only 7 had `name == library_id`, and only 1 (`prisma`) had `name == reference_slug`. Implicit matching fails 76/77 cases.

### Anti-pattern C — Silent fallback to a fake path

```python
# WRONG: return the last candidate even when it doesn't exist
return candidates[-1]
```

**Why it's wrong:** Returning a non-existent path makes `read_text()` raise a generic `FileNotFoundError` that omits the candidates the lookup tried. Operators debug by reading the error, not by adding prints. The error MUST list all candidates.

---

## Deviation guidance

You MAY deviate from this contract when:

- The bundle JSON is regenerated from a third-party source (e.g. external `bundle-manifest.json` from a different DevOS fork) and the upstream schema doesn't carry `reference_slug`. In that case, the local copy SHOULD add `reference_slug` before consuming.

You MUST NOT deviate from:

- Rule 2 (resolution order) — changing the order or adding heuristics reintroduces the bug this standard fixes
- Rule 4 (`library_id` is never a filesystem key) — silent transforms of `library_id` are exactly what caused the original failure

---

## References

- Bug report: `/tmp/devos-bug-bundle-refresh.md` (captured the failure mode this standard prevents)
- Implementation: `~/.dev-os/.claude/skills/generate-agents-md/scripts/bundle_refresh_generator.py::_artifact_path`
- Knowledge-pull output contract: `~/.dev-os/profiles/general/standards/global/knowledge-pull.md`
- Bundle manifest schema: `~/.dev-os/bundles/bundle-manifest.json`
